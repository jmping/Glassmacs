import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from macos_macho import (
    MACHO_MAGICS,
    discover_macho_binaries,
    index_macho_names,
    parse_otool_dependencies,
    run_tool,
)


THIN_MAGIC_FORMATS = {
    b"\xfe\xed\xfa\xce": ">",
    b"\xce\xfa\xed\xfe": "<",
    b"\xfe\xed\xfa\xcf": ">",
    b"\xcf\xfa\xed\xfe": "<",
}
FAT_MAGIC_FORMATS = {
    b"\xca\xfe\xba\xbe": (">", False),
    b"\xbe\xba\xfe\xca": ("<", False),
    b"\xca\xfe\xba\xbf": (">", True),
    b"\xbf\xba\xfe\xca": ("<", True),
}


def make_thin_macho(magic, filetype):
    byte_order = THIN_MAGIC_FORMATS[magic]
    endian = "big" if byte_order == ">" else "little"
    return magic + bytes(8) + filetype.to_bytes(4, endian) + bytes(16)


def make_fat_macho(magic, slices):
    byte_order, is_64_bit = FAT_MAGIC_FORMATS[magic]
    endian = "big" if byte_order == ">" else "little"
    record_size = 32 if is_64_bit else 20
    data_offset = 8 + record_size * len(slices)
    records = []
    for index, data in enumerate(slices):
        record = (
            index.to_bytes(4, endian)
            + bytes(4)
            + data_offset.to_bytes(8 if is_64_bit else 4, endian)
            + len(data).to_bytes(8 if is_64_bit else 4, endian)
            + bytes(4)
        )
        if is_64_bit:
            record += bytes(4)
        records.append(record)
        data_offset += len(data)
    return (
        magic
        + len(slices).to_bytes(4, endian)
        + b"".join(records)
        + b"".join(slices)
    )


class MacOSReleaseScriptTests(unittest.TestCase):
    def test_macho_magic_detection_covers_endian_and_fat_variants(self):
        self.assertEqual(len(MACHO_MAGICS), 8)
        for magic in MACHO_MAGICS:
            with self.subTest(magic=magic):
                with tempfile.TemporaryDirectory() as temp:
                    contents = Path(temp) / "Contents"
                    contents.mkdir()
                    if magic in THIN_MAGIC_FORMATS:
                        data = make_thin_macho(magic, 6)
                    else:
                        data = make_fat_macho(
                            magic,
                            [make_thin_macho(b"\xcf\xfa\xed\xfe", 6)],
                        )
                    (contents / "binary").write_bytes(data)
                    self.assertEqual(
                        discover_macho_binaries(contents, progress_interval=0),
                        [(contents / "binary").resolve()],
                    )

    def test_macho_discovery_skips_objects_and_universal_static_archives(self):
        with tempfile.TemporaryDirectory() as temp:
            contents = Path(temp) / "Contents"
            contents.mkdir()
            object_file = contents / "relocatable.o"
            object_file.write_bytes(make_thin_macho(b"\xcf\xfa\xed\xfe", 1))
            archive = contents / "libkmod.a"
            archive.write_bytes(make_fat_macho(
                b"\xca\xfe\xba\xbf",
                [
                    b"!<arch>\narm64e archive",
                    b"!<arch>\nx86_64 archive",
                    b"!<arch>\nx86_64h archive",
                ],
            ))
            dynamic = contents / "libdynamic.a"
            dynamic.write_bytes(make_fat_macho(
                b"\xca\xfe\xba\xbe",
                [
                    make_thin_macho(b"\xcf\xfa\xed\xfe", 6),
                    make_thin_macho(b"\xce\xfa\xed\xfe", 6),
                ],
            ))
            self.assertEqual(
                discover_macho_binaries(contents, progress_interval=0),
                [dynamic.resolve()],
            )
            self.assertTrue(archive.is_file())
            self.assertTrue(object_file.is_file())

    def test_otool_dependency_parser_skips_archive_member_headings_strictly(self):
        archive_output = """\
/bundle/libkmod.a:
/bundle/libkmod.a(c_stop.o):
/bundle/libkmod.a(c_init.o):
"""
        self.assertEqual(parse_otool_dependencies(archive_output), [])
        universal_output = """\
/bundle/libdynamic.dylib (architecture arm64):
    @rpath/libc++.1.dylib (compatibility version 1.0.0, current version 1.0.0)
/bundle/libdynamic.dylib (architecture x86_64):
    /nix/store/missing/libbad.dylib (compatibility version 1.0.0, current version 1.0.0)
"""
        self.assertEqual(parse_otool_dependencies(universal_output), [
            "@rpath/libc++.1.dylib",
            "/nix/store/missing/libbad.dylib",
        ])
        with self.assertRaisesRegex(RuntimeError, "Unrecognized otool"):
            parse_otool_dependencies("/bundle/libdynamic.dylib:\n    malformed dependency")

    def test_macho_discovery_deduplicates_and_rejects_outside_symlink(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            contents = root / "Contents"
            contents.mkdir()
            binary = contents / "Emacs"
            binary.write_bytes(make_thin_macho(b"\xcf\xfa\xed\xfe", 2))
            (contents / "Emacs-alias").symlink_to(binary)
            self.assertEqual(
                discover_macho_binaries(contents, progress_interval=0),
                [binary.resolve()],
            )
            self.assertEqual(
                index_macho_names(contents, [binary.resolve()])["Emacs-alias"],
                {binary.resolve()},
            )

            outside = root / "outside"
            outside.write_bytes(make_fat_macho(
                b"\xca\xfe\xba\xbf",
                [make_thin_macho(b"\xcf\xfa\xed\xfe", 2)],
            ))
            (contents / "escaped").symlink_to(outside)
            with self.assertRaisesRegex(RuntimeError, "resolves outside"):
                discover_macho_binaries(contents, progress_interval=0)

    def test_macho_discovery_reports_files_it_cannot_inspect(self):
        with tempfile.TemporaryDirectory() as temp:
            contents = Path(temp) / "Contents"
            contents.mkdir()
            (contents / "unreadable").write_bytes(b"not macho")
            with mock.patch.object(Path, "open", side_effect=PermissionError("denied")):
                with self.assertRaisesRegex(RuntimeError, "Could not inspect bundle file"):
                    discover_macho_binaries(contents, progress_interval=0)

    def test_macho_tool_failures_are_bounded_and_actionable(self):
        with mock.patch(
            "macos_macho.subprocess.run",
            side_effect=subprocess.TimeoutExpired(["otool", "-L"], 30),
        ):
            with self.assertRaisesRegex(RuntimeError, "Timed out.*otool"):
                run_tool("otool", "-L", "binary", context="inspect binary")

        failure = subprocess.CalledProcessError(9, ["otool", "-L"], stderr="bad file")
        with mock.patch("macos_macho.subprocess.run", side_effect=failure):
            with self.assertRaisesRegex(RuntimeError, "exit 9.*bad file"):
                run_tool("otool", "-L", "binary", context="inspect binary")

    def run_dependency_relocator(
        self,
        dependencies,
        extra_libraries=(),
        fail_otool=False,
        executable_arch="arm64",
        binary_relative="MacOS/Emacs",
    ):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        app = root / "Glassmacs.app"
        contents = app / "Contents"
        executable_dir = contents / "MacOS"
        executable_dir.mkdir(parents=True)

        def make_binary(path, arch, dependency=None):
            path.parent.mkdir(parents=True, exist_ok=True)
            lines = [f"ARCH={arch}"]
            if dependency:
                lines.append(f"DEP={dependency}")
            path.write_bytes(
                make_thin_macho(b"\xcf\xfa\xed\xfe", 6)
                + ("\n".join(lines) + "\n").encode()
            )
            return path

        executable = make_binary(contents / binary_relative, executable_arch)
        libraries = []
        for item in extra_libraries:
            relative, arch = item if isinstance(item, tuple) else (item, "arm64")
            libraries.append(make_binary(contents / relative, arch))
        executable.write_bytes(
            make_thin_macho(b"\xcf\xfa\xed\xfe", 2)
            + (
                f"ARCH={executable_arch}\n"
                + "".join(f"DEP={item}\n" for item in dependencies)
            ).encode()
        )
        archive = contents / "MacOS/lib-x86_64-11/libgccjit/sdk-libs/libkmod.a"
        archive.parent.mkdir(parents=True, exist_ok=True)
        archive.write_bytes(make_fat_macho(
            b"\xca\xfe\xba\xbf",
            [
                b"!<arch>\narm64e archive",
                b"!<arch>\nx86_64 archive",
                b"!<arch>\nx86_64h archive",
            ],
        ))
        tools = root / "tools"
        tools.mkdir()
        otool = tools / "otool"
        otool.write_text("""#!/usr/bin/env python3
import os, sys
if os.environ.get("OTOOL_FAIL") == "1":
    sys.exit(8)
operation, binary = sys.argv[1], sys.argv[2]
if binary.endswith(".a"):
    sys.exit(77)
data = open(binary, "rb").read()[32:].decode()
if operation == "-L":
    print(binary + ":")
    for line in data.splitlines():
        if line.startswith("DEP="):
            print("    " + line[4:] + " (compatibility version 1.0.0, current version 1.0.0)")
elif operation == "-D":
    print(binary + ":")
    for line in data.splitlines():
        if line.startswith("ID="):
            print(line[3:])
""")
        otool.chmod(0o755)
        lipo = tools / "lipo"
        lipo.write_text("""#!/usr/bin/env python3
import sys
data = open(sys.argv[2], "rb").read()[32:].decode()
print(next(line[5:] for line in data.splitlines() if line.startswith("ARCH=")))
""")
        lipo.chmod(0o755)
        installer = tools / "install_name_tool"
        installer.write_text("""#!/usr/bin/env python3
import sys
_, old, new, binary = sys.argv[1:]
data = open(binary, "rb").read()
text = data[32:].decode().replace("DEP=" + old + "\\n", "DEP=" + new + "\\n")
open(binary, "wb").write(data[:32] + text.encode())
""")
        installer.chmod(0o755)
        environment = os.environ.copy()
        environment.update({
            "GLASSMACS_OTOOL": str(otool),
            "GLASSMACS_LIPO": str(lipo),
            "GLASSMACS_INSTALL_NAME_TOOL": str(installer),
        })
        if fail_otool:
            environment["OTOOL_FAIL"] = "1"
        result = subprocess.run(
            [sys.executable, str(ROOT / "scripts/relocate-macos-dependencies"), str(app)],
            text=True, capture_output=True, check=False, env=environment,
        )
        return result, executable, libraries

    def test_dependency_relocator_targets_the_unique_arch_compatible_bundle_library(self):
        external = "/nix/store/abcd-gettext-0.25.1/lib/libintl.8.dylib"
        result, executable, libraries = self.run_dependency_relocator(
            [external], ["MacOS/lib-arm64-11/libintl.8.dylib"]
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(
            "DEP=@loader_path/lib-arm64-11/libintl.8.dylib",
            executable.read_bytes()[32:].decode(),
        )
        self.assertIn("Relocated 1 external", result.stdout)
        self.assertEqual(libraries[0].name, "libintl.8.dylib")

    def test_dependency_relocator_prefers_the_matching_runtime_directory(self):
        external = "/nix/store/hcs6-gettext-0.22.5/lib/libintl.8.dylib"
        source = "MacOS/lib-x86_64-11/libgccjit/libcc1.0.so"
        result, binary, libraries = self.run_dependency_relocator(
            [external],
            [
                ("MacOS/lib-x86_64-11/libintl.8.dylib", "x86_64"),
                ("MacOS/lib-x86_64-10_12/libintl.8.dylib", "x86_64"),
            ],
            executable_arch="x86_64",
            binary_relative=source,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(
            "DEP=@loader_path/../libintl.8.dylib",
            binary.read_bytes()[32:].decode(),
        )
        self.assertIn("Relocated 1 external", result.stdout)
        self.assertEqual([library.name for library in libraries], [
            "libintl.8.dylib",
            "libintl.8.dylib",
        ])

    def test_dependency_relocator_fails_on_ambiguous_or_unresolved_matches(self):
        external = "/nix/store/abcd-gettext/lib/libintl.8.dylib"
        ambiguous, _, _ = self.run_dependency_relocator(
            [external],
            ["MacOS/lib-arm64-11/libintl.8.dylib", "Frameworks/libintl.8.dylib"],
        )
        self.assertNotEqual(ambiguous.returncode, 0)
        self.assertIn("Ambiguous external dependency", ambiguous.stderr)

        unresolved, _, _ = self.run_dependency_relocator([external])
        self.assertNotEqual(unresolved.returncode, 0)
        self.assertIn("Unresolved external dependency", unresolved.stderr)

        wrong_arch, _, _ = self.run_dependency_relocator(
            [external], [("MacOS/lib-arm64-11/libintl.8.dylib", "x86_64")]
        )
        self.assertNotEqual(wrong_arch.returncode, 0)
        self.assertIn("Unresolved external dependency", wrong_arch.stderr)

    def test_dependency_relocator_requires_a_library_for_every_binary_architecture(self):
        external = "/nix/store/abcd-gettext/lib/libintl.8.dylib"
        universal, _, _ = self.run_dependency_relocator(
            [external],
            [("MacOS/lib-universal/libintl.8.dylib", "arm64 x86_64")],
            executable_arch="arm64 x86_64",
        )
        self.assertEqual(universal.returncode, 0, universal.stderr)

        partial, _, _ = self.run_dependency_relocator(
            [external],
            [("MacOS/lib-arm64/libintl.8.dylib", "arm64")],
            executable_arch="arm64 x86_64",
        )
        self.assertNotEqual(partial.returncode, 0)
        self.assertIn("Unresolved external dependency", partial.stderr)

    def test_dependency_relocator_reports_subprocess_failure(self):
        result, _, _ = self.run_dependency_relocator(
            ["/nix/store/abcd-gettext/lib/libintl.8.dylib"],
            ["MacOS/lib-arm64-11/libintl.8.dylib"],
            fail_otool=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Could not inspect install name", result.stderr)

    def test_bundle_icon_and_minimum_os_are_declared_and_packaged(self):
        plist = plistlib.loads((ROOT / "macos/Info.plist").read_bytes())
        builder = (ROOT / "scripts/build-macos-app").read_text()
        package = (ROOT / "macos/Package.swift").read_text()

        self.assertTrue((ROOT / "assets/icon/Glassmacs.icns").is_file())
        self.assertIn('CFBundleIconFile', plist)
        self.assertEqual(plist["CFBundleIconFile"], "Glassmacs")
        self.assertEqual(plist["LSMinimumSystemVersion"], "13.0")
        self.assertIn(".macOS(.v13)", package)
        self.assertIn('cp "$root/assets/icon/Glassmacs.icns"', builder)

    def test_build_sanitizes_before_strict_bundle_validation(self):
        builder = (ROOT / "scripts/build-macos-app").read_text()
        validator = (ROOT / "scripts/validate-macos-app").read_text()
        sanitizer_call = builder.index('"$root/scripts/sanitize-macos-rpaths" "$output"')
        validator_call = builder.index(
            'GLASSMACS_SKIP_EMACS_STARTUP=1 "$root/scripts/validate-macos-app" "$output"'
        )
        relocator_call = builder.index(
            '"$root/scripts/relocate-macos-dependencies" "$output"'
        )
        self.assertLess(sanitizer_call, relocator_call)
        self.assertLess(relocator_call, validator_call)
        self.assertIn("install_name_tool", (ROOT / "scripts/sanitize-macos-rpaths").read_text())
        self.assertNotIn('"/usr/bin/file"', validator)
        self.assertIn("discover_macho_binaries", validator)

    def test_validator_shell_entrypoint_runs_with_literal_python_heredoc(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            app = root / "Glassmacs.app"
            contents = app / "Contents"
            (contents / "MacOS").mkdir(parents=True)
            (contents / "Resources/Glassmacs/lisp").mkdir(parents=True)
            (contents / "Resources").mkdir(exist_ok=True)
            (contents / "Info.plist").write_bytes(
                (ROOT / "macos/Info.plist").read_bytes()
            )
            bootstrap = contents / "MacOS/GlassmacsBootstrap"
            bootstrap.write_text("#!/bin/sh\nexit 0\n")
            bootstrap.chmod(0o755)
            emacs = contents / "MacOS/Emacs"
            emacs.write_bytes(make_thin_macho(b"\xcf\xfa\xed\xfe", 2))
            emacs.chmod(0o755)
            resources = contents / "Resources/Glassmacs"
            (resources / "init.el").write_bytes((ROOT / "init.el").read_bytes())
            (resources / "lisp/glassmacs.el").write_text(";;; fixture\n")
            (resources / "scripts").mkdir()
            (resources / "scripts/bootstrap").write_text("#!/bin/sh\n")
            (contents / "Resources/Glassmacs.icns").write_bytes(b"icon")
            archive = contents / "MacOS/lib-x86_64-11/libgccjit/sdk-libs/libkmod.a"
            archive.parent.mkdir(parents=True)
            archive.write_bytes(make_fat_macho(
                b"\xca\xfe\xba\xbf",
                [
                    b"!<arch>\narm64 archive",
                    b"!<arch>\nx86_64 archive",
                    b"!<arch>\nx86_64h archive",
                ],
            ))

            plutil = root / "plutil"
            plutil.write_text(f"""#!{sys.executable}
import plistlib, sys
plistlib.loads(open(sys.argv[-1], "rb").read())
print(sys.argv[-1] + ": OK")
""")
            plutil.chmod(0o755)
            plist_buddy = root / "PlistBuddy"
            plist_buddy.write_text(f"""#!{sys.executable}
import plistlib, sys
plist = plistlib.loads(open(sys.argv[-1], "rb").read())
key = sys.argv[2].removeprefix("Print :")
if key == "CFBundleDocumentTypes:0:CFBundleTypeExtensions":
    print("\\n".join(plist["CFBundleDocumentTypes"][0]["CFBundleTypeExtensions"]))
else:
    value = plist
    for component in key.split(":"):
        value = value[int(component)] if isinstance(value, list) else value[component]
    print(value)
""")
            plist_buddy.chmod(0o755)
            otool = root / "otool"
            otool.write_text(f"""#!{sys.executable}
import os
import sys
if sys.argv[-1].endswith(".a"):
    sys.exit(77)
print(sys.argv[-1] + ":")
if sys.argv[1] == "-L" and os.environ.get("OTool_BAD_DEP") == "1":
    print("    /nix/store/missing/libbad.dylib (compatibility version 1.0.0, current version 1.0.0)")
""")
            otool.chmod(0o755)
            environment = os.environ.copy()
            environment.update({
                "GLASSMACS_PLUTIL": str(plutil),
                "GLASSMACS_PLISTBUDDY": str(plist_buddy),
                "GLASSMACS_OTOOL": str(otool),
                "GLASSMACS_SKIP_EMACS_STARTUP": "1",
            })
            result = subprocess.run(
                ["bash", str(ROOT / "scripts/validate-macos-app"), str(app)],
                text=True,
                capture_output=True,
                check=False,
                env=environment,
            )
            archive_exists = archive.is_file()
            bad_environment = environment.copy()
            bad_environment["OTool_BAD_DEP"] = "1"
            unresolved = subprocess.run(
                ["bash", str(ROOT / "scripts/validate-macos-app"), str(app)],
                text=True,
                capture_output=True,
                check=False,
                env=bad_environment,
            )

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotEqual(unresolved.returncode, 0)
        self.assertIn("Unresolved or non-relocatable dependency", unresolved.stderr)
        self.assertIn("Validated Glassmacs.app structure", result.stdout)
        self.assertNotIn("unbound variable", result.stderr)
        self.assertIn("<<'PY'", (ROOT / "scripts/validate-macos-app").read_text())
        self.assertTrue(archive_exists)

    def run_rpath_sanitizer(
        self, fixture, fail_delete=False, fail_otool=False, fail_file=False
    ):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        app = root / "Glass macs.app"
        contents = app / "Contents"
        contents.mkdir(parents=True)
        binary_a = contents / "MacOS/lib-arm64-11/libgccjit/libcc1.0.so"
        binary_a.parent.mkdir(parents=True)
        binary_a.write_text("\n".join(f"RPATH={entry}" for entry in fixture[0]))
        binary_b = contents / "MacOS/Frameworks/other.dylib"
        binary_b.parent.mkdir(parents=True)
        binary_b.write_text("\n".join(f"RPATH={entry}" for entry in fixture[1]))
        tools = root / "tools"
        tools.mkdir()
        log = root / "install-name-tool.log"

        file_tool = tools / "file"
        file_tool.write_text("""#!/bin/bash
if [ "${FILE_FAIL:-0}" = 1 ]; then
  exit 6
fi
case "$2" in
  *.so|*.dylib) printf 'Mach-O 64-bit dynamically linked shared library\\n' ;;
  *) printf 'ASCII text\\n' ;;
esac
""")
        file_tool.chmod(0o755)

        otool = tools / "otool"
        otool.write_text("""#!/usr/bin/env python3
import os, sys
if os.environ.get("OTOOL_FAIL") == "1":
    sys.exit(8)
if sys.argv[1] != "-l":
    sys.exit(9)
for entry in open(sys.argv[2]).read().splitlines():
    if entry.startswith("RPATH="):
        print("Load command 1")
        print("          cmd LC_RPATH")
        print("      cmdsize 56")
        print(f"         path {entry[6:]} (offset 12)")
""")
        otool.chmod(0o755)

        installer = tools / "install_name_tool"
        installer.write_text("""#!/usr/bin/env python3
import os, sys
if os.environ.get("INSTALL_NAME_FAIL") == "1":
    sys.exit(7)
_, operation, entry, binary = sys.argv
with open(os.environ["INSTALL_NAME_LOG"], "a") as log:
    log.write(f"{binary}\\t{entry}\\n")
lines = open(binary).read().splitlines()
lines.remove("RPATH=" + entry)
open(binary, "w").write("\\n".join(lines))
""")
        installer.chmod(0o755)

        environment = os.environ.copy()
        environment.update({
            "GLASSMACS_FILE_TOOL": str(file_tool),
            "GLASSMACS_OTOOL": str(otool),
            "GLASSMACS_INSTALL_NAME_TOOL": str(installer),
            "INSTALL_NAME_LOG": str(log),
        })
        if fail_delete:
            environment["INSTALL_NAME_FAIL"] = "1"
        if fail_otool:
            environment["OTOOL_FAIL"] = "1"
        if fail_file:
            environment["FILE_FAIL"] = "1"
        result = subprocess.run(
            ["bash", str(ROOT / "scripts/sanitize-macos-rpaths"), str(app)],
            text=True, capture_output=True, check=False, env=environment,
        )
        return result, binary_a, binary_b, log

    def test_rpath_sanitizer_cleans_all_binaries_but_preserves_relocatable_entries(self):
        obsolete = [
            "/private/tmp/nix-build-gcc-14.3.0-abc/source/lib",
            "/nix/store/abcd1234-gcc-14.3.0/lib",
            "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib",
        ]
        safe = ["@loader_path/../lib", "@executable_path/../Frameworks", "@rpath"]
        result, binary_a, binary_b, log = self.run_rpath_sanitizer(
            [obsolete + safe, [obsolete[1], "@loader_path"]]
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(log.read_text().splitlines()), len(obsolete) + 1)
        for entry in safe:
            self.assertIn(f"RPATH={entry}", binary_a.read_text())
        self.assertIn("RPATH=@loader_path", binary_b.read_text())
        for entry in obsolete:
            self.assertNotIn(f"RPATH={entry}", binary_a.read_text())
        self.assertNotIn(f"RPATH={obsolete[1]}", binary_b.read_text())

    def test_rpath_sanitizer_fails_when_inspection_or_removal_fails(self):
        nix_rpath = "/nix/store/abcd-gcc/lib"
        remove_result, _, _, _ = self.run_rpath_sanitizer(
            [[nix_rpath], []], fail_delete=True
        )
        self.assertNotEqual(remove_result.returncode, 0)

        inspect_result, _, _, _ = self.run_rpath_sanitizer(
            [[nix_rpath], []], fail_otool=True
        )
        self.assertNotEqual(inspect_result.returncode, 0)

        identify_result, _, _, _ = self.run_rpath_sanitizer(
            [[nix_rpath], []], fail_file=True
        )
        self.assertNotEqual(identify_result.returncode, 0)

    def test_native_compilation_is_configured_before_package_loading(self):
        startup = (ROOT / "init.el").read_text()
        policy = re.search(
            r"^\(glassmacs--configure-native-compilation\)$",
            startup,
            re.MULTILINE,
        )
        self.assertIsNotNone(policy)
        self.assertLess(
            policy.start(),
            startup.index("(require 'glassmacs)"),
        )
        self.assertIn('GLASSMACS_NATIVE_COMP', startup)
        self.assertIn("native-comp-jit-compilation", startup)
        self.assertIn("13.0", (ROOT / "macos/Sources/GlassmacsLauncherCore/LaunchConfiguration.swift").read_text())

    def test_entitlements_are_valid_and_signing_order_is_preserved(self):
        entitlements = plistlib.loads(
            (ROOT / "macos/Glassmacs.entitlements.plist").read_bytes()
        )
        self.assertIs(entitlements["com.apple.security.cs.disable-library-validation"], True)

        signing = (ROOT / "scripts/sign-macos-app").read_text()
        nested_sign = signing.index('/usr/bin/codesign --force --sign "$identity"')
        emacs_sign = signing.index('--entitlements "$entitlements" "$emacs"')
        outer_sign = signing.index('--entitlements "$entitlements" "$app"')
        verification = signing.index(
            '/usr/bin/codesign --verify --deep --strict --verbose=2 "$app"'
        )
        self.assertLess(nested_sign, emacs_sign)
        self.assertLess(emacs_sign, outer_sign)
        self.assertLess(outer_sign, verification)
        self.assertIn('--options runtime --timestamp', signing)

    def test_release_script_requires_arguments_and_valid_bundle(self):
        script = ROOT / "scripts/notarize-macos-app"
        missing = subprocess.run(
            ["bash", str(script)], text=True, capture_output=True, check=False
        )
        self.assertEqual(missing.returncode, 2)

        with tempfile.TemporaryDirectory() as temp:
            invalid = subprocess.run(
                ["bash", str(script), temp, "test-profile"],
                text=True, capture_output=True, check=False,
            )
        self.assertNotEqual(invalid.returncode, 0)
        self.assertIn("Application bundle not found", invalid.stderr)

    def run_release(self, status="Accepted", extra_environment=None):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        app = root / "Application with spaces" / "Glassmacs.app"
        (app / "Contents/MacOS").mkdir(parents=True)
        (app / "Contents/Info.plist").write_text("bundle")
        emacs = app / "Contents/MacOS/Emacs"
        emacs.write_text("mock executable")
        emacs.chmod(0o755)
        mock_bin = root / "mock-bin"
        mock_bin.mkdir()
        log = root / "commands.log"

        commands = {
            "codesign": """#!/bin/bash
printf 'codesign %s\\n' "$*" >> "$MOCK_LOG"
if [[ "$*" == *'--verify'* && "${CODESIGN_FAIL:-0}" == 1 ]]; then exit 1; fi
if [[ "$*" == *'-dv'* ]]; then
  team=TEAM123
  if [[ "$*" == *'/Contents/MacOS/Emacs' ]]; then team="${EMACS_TEAM:-TEAM123}"; fi
  printf 'Authority=Developer ID Application: Test (%s)\\nTeamIdentifier=%s\\n' "$team" "$team" >&2
fi
""",
            "ditto": """#!/bin/bash
printf 'ditto %s\\n' "$*" >> "$MOCK_LOG"
destination=${@: -1}
mkdir -p "$(dirname "$destination")"
printf 'mock-zip' > "$destination"
""",
            "xcrun": """#!/bin/bash
printf 'xcrun %s\\n' "$*" >> "$MOCK_LOG"
if [[ "$1" == notarytool && "$2" == submit ]]; then
  if [[ "${NOTARY_NO_ID:-0}" == 1 ]]; then
    printf '{"status":"%s"}\\n' "${NOTARY_STATUS:-Accepted}"
  else
    printf '{"id":"875456b4-1dd3-4e72-af29-9c0cb4357909","status":"%s"}\\n' "${NOTARY_STATUS:-Accepted}"
  fi
  if [[ "${NOTARY_EXIT:-0}" == 1 ]]; then exit 1; fi
elif [[ "$1" == stapler && "$2" == validate && "${STAPLER_VALIDATE_FAIL:-0}" == 1 ]]; then
  exit 1
fi
""",
            "spctl": """#!/bin/bash
printf 'spctl %s\\n' "$*" >> "$MOCK_LOG"
if [[ "${SPCTL_FAIL:-0}" == 1 ]]; then exit 1; fi
""",
        }
        for name, contents in commands.items():
            command = mock_bin / name
            command.write_text(contents)
            command.chmod(0o755)

        output_dir = root / "dist with spaces"
        environment = os.environ.copy()
        environment.update({
            "PATH": f"{mock_bin}:{environment['PATH']}",
            "MOCK_LOG": str(log),
            "NOTARY_STATUS": status,
        })
        if extra_environment:
            environment.update(extra_environment)
        result = subprocess.run(
            ["bash", str(ROOT / "scripts/notarize-macos-app"),
             str(app), "test-keychain-profile", str(output_dir)],
            text=True, capture_output=True, check=False, env=environment,
        )
        return result, output_dir, log

    def test_accepted_release_staples_then_validates_before_final_archive(self):
        result, output_dir, log = self.run_release()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((output_dir / "Glassmacs-notarization.zip").is_file())
        self.assertTrue((output_dir / "Glassmacs-macOS.zip").is_file())
        self.assertNotIn("test-keychain-profile", result.stdout + result.stderr)

        calls = log.read_text().splitlines()
        submitted = next(i for i, call in enumerate(calls) if "notarytool submit" in call)
        stapled = next(i for i, call in enumerate(calls) if "stapler staple" in call)
        validated = next(i for i, call in enumerate(calls) if "stapler validate" in call)
        gatekeeper = next(i for i, call in enumerate(calls) if call.startswith("spctl "))
        final_archive = next(
            i for i, call in enumerate(calls)
            if "Glassmacs-macOS.zip" in call
        )
        self.assertLess(submitted, stapled)
        self.assertLess(stapled, validated)
        self.assertLess(validated, gatekeeper)
        self.assertLess(gatekeeper, final_archive)

    def test_rejected_notarization_never_staples_or_creates_final_archive(self):
        result, output_dir, log = self.run_release(status="Invalid")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("875456b4-1dd3-4e72-af29-9c0cb4357909", result.stderr)
        self.assertTrue((output_dir / "Glassmacs-notarization.zip").is_file())
        self.assertFalse((output_dir / "Glassmacs-macOS.zip").exists())
        self.assertNotIn("stapler", log.read_text())

    def test_nonzero_notarytool_status_never_staples(self):
        result, output_dir, log = self.run_release(
            extra_environment={"NOTARY_EXIT": "1"}
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((output_dir / "Glassmacs-macOS.zip").exists())
        self.assertNotIn("stapler", log.read_text())

    def test_missing_submission_id_and_gatekeeper_failure_prevent_final_archive(self):
        no_id, no_id_output, no_id_log = self.run_release(
            extra_environment={"NOTARY_NO_ID": "1"}
        )
        self.assertNotEqual(no_id.returncode, 0)
        self.assertIn("without a submission ID", no_id.stderr)
        self.assertFalse((no_id_output / "Glassmacs-macOS.zip").exists())
        self.assertNotIn("stapler", no_id_log.read_text())

        gatekeeper, gatekeeper_output, gatekeeper_log = self.run_release(
            extra_environment={"SPCTL_FAIL": "1"}
        )
        self.assertNotEqual(gatekeeper.returncode, 0)
        self.assertTrue((gatekeeper_output / "Glassmacs-notarization.zip").is_file())
        self.assertFalse((gatekeeper_output / "Glassmacs-macOS.zip").exists())
        self.assertNotIn("Glassmacs-macOS.zip", gatekeeper_log.read_text())

    def test_signing_or_staple_validation_failure_stops_final_archive(self):
        signing_failure, signing_output, signing_log = self.run_release(
            extra_environment={"CODESIGN_FAIL": "1"}
        )
        self.assertNotEqual(signing_failure.returncode, 0)
        self.assertFalse((signing_output / "Glassmacs-notarization.zip").exists())
        self.assertNotIn("notarytool submit", signing_log.read_text())

        staple_failure, staple_output, staple_log = self.run_release(
            extra_environment={"STAPLER_VALIDATE_FAIL": "1"}
        )
        self.assertNotEqual(staple_failure.returncode, 0)
        self.assertTrue((staple_output / "Glassmacs-notarization.zip").is_file())
        self.assertFalse((staple_output / "Glassmacs-macOS.zip").exists())
        self.assertNotIn("Glassmacs-macOS.zip", staple_log.read_text())

    def test_mismatched_emacs_signing_team_is_rejected_before_notarization(self):
        result, output_dir, log = self.run_release(
            extra_environment={"EMACS_TEAM": "OTHERTEAM"}
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("same Developer ID team", result.stderr)
        self.assertFalse((output_dir / "Glassmacs-notarization.zip").exists())
        self.assertNotIn("notarytool submit", log.read_text())


if __name__ == "__main__":
    unittest.main()
