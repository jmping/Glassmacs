#!/usr/bin/env python3
"""Shared Mach-O inspection helpers for the macOS bundle scripts."""

import os
from pathlib import Path
import re
import shlex
import stat
import subprocess


MACHO_MAGICS = {
    b"\xfe\xed\xfa\xce",  # 32-bit, big-endian
    b"\xce\xfa\xed\xfe",  # 32-bit, little-endian
    b"\xfe\xed\xfa\xcf",  # 64-bit, big-endian
    b"\xcf\xfa\xed\xfe",  # 64-bit, little-endian
    b"\xca\xfe\xba\xbe",  # FAT_MAGIC
    b"\xbe\xba\xfe\xca",  # FAT_CIGAM
    b"\xca\xfe\xba\xbf",  # FAT_MAGIC_64
    b"\xbf\xba\xfe\xca",  # FAT_CIGAM_64
}
MACHO_IMAGE_FILETYPES = {2, 6, 8}


def _thin_filetype(header):
    if len(header) < 16:
        raise RuntimeError("Truncated Mach-O header")
    magic = header[:4]
    byte_order = {
        b"\xfe\xed\xfa\xce": ">",
        b"\xce\xfa\xed\xfe": "<",
        b"\xfe\xed\xfa\xcf": ">",
        b"\xcf\xfa\xed\xfe": "<",
    }.get(magic)
    if byte_order is None:
        return None
    return int.from_bytes(header[12:16], "big" if byte_order == ">" else "little")


def _image_filetypes(file_handle, magic):
    if magic in {
        b"\xfe\xed\xfa\xce", b"\xce\xfa\xed\xfe",
        b"\xfe\xed\xfa\xcf", b"\xcf\xfa\xed\xfe",
    }:
        file_handle.seek(0)
        return [_thin_filetype(file_handle.read(32))]

    fat_formats = {
        b"\xca\xfe\xba\xbe": (">", False),
        b"\xbe\xba\xfe\xca": ("<", False),
        b"\xca\xfe\xba\xbf": (">", True),
        b"\xbf\xba\xfe\xca": ("<", True),
    }
    fat_format = fat_formats.get(magic)
    if fat_format is None:
        return []

    byte_order, is_64_bit = fat_format
    file_handle.seek(0)
    header = file_handle.read(8)
    if len(header) < 8:
        raise RuntimeError("Truncated universal Mach-O header")
    slice_count = int.from_bytes(header[4:8], "big" if byte_order == ">" else "little")
    if slice_count == 0 or slice_count > 4096:
        raise RuntimeError(f"Invalid universal Mach-O slice count: {slice_count}")

    entry_size = 32 if is_64_bit else 20
    entries = file_handle.read(slice_count * entry_size)
    if len(entries) != slice_count * entry_size:
        raise RuntimeError("Truncated universal Mach-O architecture table")

    filetypes = []
    for index in range(slice_count):
        entry = entries[index * entry_size:(index + 1) * entry_size]
        if is_64_bit:
            offset = int.from_bytes(entry[8:16], "big" if byte_order == ">" else "little")
        else:
            offset = int.from_bytes(entry[8:12], "big" if byte_order == ">" else "little")
        file_handle.seek(offset)
        slice_header = file_handle.read(32)
        if slice_header.startswith(b"!<arch>\n"):
            filetypes.append(None)
            continue
        if slice_header[:4] not in {
            b"\xfe\xed\xfa\xce", b"\xce\xfa\xed\xfe",
            b"\xfe\xed\xfa\xcf", b"\xcf\xfa\xed\xfe",
        }:
            raise RuntimeError(
                f"Invalid universal Mach-O slice at offset {offset}: "
                f"{slice_header[:4].hex()}"
            )
        filetypes.append(_thin_filetype(slice_header))
    return filetypes


def is_runtime_macho_image(file_handle, magic):
    """Return whether a Mach-O file contains only runtime-loadable image slices."""
    filetypes = _image_filetypes(file_handle, magic)
    return bool(filetypes) and all(
        filetype in MACHO_IMAGE_FILETYPES for filetype in filetypes
    )


def parse_otool_dependencies(output):
    """Return dependency load-command lines, excluding image/archive member headings."""
    dependencies = []
    for line in output.splitlines():
        stripped = line.strip()
        if not stripped or stripped.endswith(":"):
            continue
        match = re.match(r"^\s*(.+?)\s+\(compatibility version [^)]+\)", line)
        if match:
            dependencies.append(match.group(1))
        else:
            raise RuntimeError(f"Unrecognized otool -L dependency line: {stripped}")
    return dependencies


def run_tool(*arguments, context, timeout=30):
    command = shlex.join(str(argument) for argument in arguments)
    try:
        result = subprocess.run(
            [str(argument) for argument in arguments],
            check=True,
            text=True,
            capture_output=True,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired as error:
        raise RuntimeError(
            f"Timed out after {timeout}s while {context}: {command}"
        ) from error
    except subprocess.CalledProcessError as error:
        detail = (error.stderr or error.stdout or "").strip()
        suffix = f": {detail}" if detail else ""
        raise RuntimeError(
            f"Could not {context} (exit {error.returncode}): {command}{suffix}"
        ) from error
    except OSError as error:
        raise RuntimeError(f"Could not {context}: {command}: {error}") from error
    return result.stdout


def is_within_bundle(path, contents):
    try:
        Path(path).resolve(strict=True).relative_to(Path(contents))
        return True
    except (OSError, ValueError):
        return False


def discover_macho_binaries(contents, progress_interval=1000):
    """Find unique in-bundle Mach-O files without spawning a process per file."""
    contents = Path(contents).resolve(strict=True)
    candidates = []

    def walk_error(error):
        raise RuntimeError(f"Could not enumerate application bundle: {error}") from error

    for directory, _, filenames in os.walk(contents, onerror=walk_error):
        candidates.extend(Path(directory) / filename for filename in filenames)

    binaries = []
    resolved_binaries = set()
    for scanned, candidate in enumerate(candidates, start=1):
        try:
            if not stat.S_ISREG(candidate.stat().st_mode):
                continue
            with candidate.open("rb") as bundled_file:
                magic = bundled_file.read(4)
                is_macho_magic = magic in MACHO_MAGICS
                runtime_image = (
                    is_runtime_macho_image(bundled_file, magic)
                    if is_macho_magic else False
                )
        except OSError as error:
            raise RuntimeError(f"Could not inspect bundle file {candidate}: {error}") from error
        except RuntimeError as error:
            raise RuntimeError(f"Could not classify Mach-O file {candidate}: {error}") from error

        if is_macho_magic:
            try:
                resolved = candidate.resolve(strict=True)
                resolved.relative_to(contents)
            except (OSError, ValueError) as error:
                raise RuntimeError(
                    f"Bundled Mach-O symlink resolves outside the app or is unavailable: {candidate}"
                ) from error
            if runtime_image and resolved not in resolved_binaries:
                resolved_binaries.add(resolved)
                binaries.append(resolved)

        if progress_interval and scanned % progress_interval == 0:
            print(
                f"Scanned {scanned}/{len(candidates)} bundle files; "
                f"found {len(binaries)} Mach-O files",
                flush=True,
            )

    print(
        f"Scanned {len(candidates)} bundle files; found {len(binaries)} unique Mach-O files",
        flush=True,
    )
    return binaries


def index_macho_names(contents, binaries):
    """Index bundle-visible filenames, including symlink aliases, by resolved Mach-O."""
    contents = Path(contents).resolve(strict=True)
    binary_set = set(binaries)
    names = {}

    def walk_error(error):
        raise RuntimeError(f"Could not enumerate application bundle: {error}") from error

    for directory, _, filenames in os.walk(contents, onerror=walk_error):
        for filename in filenames:
            candidate = Path(directory) / filename
            try:
                resolved = candidate.resolve(strict=True)
            except OSError:
                continue
            if resolved in binary_set:
                names.setdefault(candidate.name, set()).add(resolved)
    return names
