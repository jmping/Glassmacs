import os
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class MacOSReleaseScriptTests(unittest.TestCase):
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
