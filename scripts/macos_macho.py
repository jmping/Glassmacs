#!/usr/bin/env python3
"""Shared Mach-O inspection helpers for the macOS bundle scripts."""

import os
from pathlib import Path
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
        except OSError as error:
            raise RuntimeError(f"Could not inspect bundle file {candidate}: {error}") from error

        if magic in MACHO_MAGICS:
            try:
                resolved = candidate.resolve(strict=True)
                resolved.relative_to(contents)
            except (OSError, ValueError) as error:
                raise RuntimeError(
                    f"Bundled Mach-O symlink resolves outside the app or is unavailable: {candidate}"
                ) from error
            if resolved not in resolved_binaries:
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
