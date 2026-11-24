import hashlib
import io
import json
import os
import plistlib
from pathlib import Path
import runpy
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
VERSION = runpy.run_path(str(ROOT / "scripts" / "set-release-version"))
RELEASE = runpy.run_path(str(ROOT / "scripts" / "publish-macos-release"))


def write_source_archive(path):
    data = b"corresponding source"
    with tarfile.open(path, "w:gz") as archive:
        member = tarfile.TarInfo("source.txt")
        member.size = len(data)
        archive.addfile(member, io.BytesIO(data))


class DistributionTests(unittest.TestCase):
    def test_release_version_preserves_identifier_and_prerelease(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "Info.plist"
            original = {"CFBundleIdentifier": "org.glassmacs.Glassmacs",
                        "CFBundleShortVersionString": "31.1"}
            path.write_bytes(plistlib.dumps(original))
            VERSION["set_version"](path, "0.2.0-beta.3", "2026.11.23")
            data = plistlib.loads(path.read_bytes())
            self.assertEqual(data["CFBundleShortVersionString"], "0.2.0")
            self.assertEqual(data["CFBundleVersion"], "2026.11.23")
            self.assertEqual(data["GlassmacsReleaseVersion"], "0.2.0-beta.3")
            self.assertEqual(data["CFBundleIdentifier"], original["CFBundleIdentifier"])

    def test_invalid_version_does_not_change_plist(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "Info.plist"
            initial = plistlib.dumps({"CFBundleIdentifier": "org.glassmacs.Glassmacs"})
            path.write_bytes(initial)
            for version, build in (("v1.0.0", "1"), ("1.0.0-rc", "1"), ("1.0.0", "0")):
                with self.subTest(version=version, build=build):
                    with self.assertRaises(ValueError):
                        VERSION["set_version"](path, version, build)
                    self.assertEqual(path.read_bytes(), initial)

    def test_evidence_binds_both_artifacts_and_every_required_review(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            dmg = root / "Glassmacs-v0.2.0-beta.3.dmg"
            source = root / "source.tar.gz"
            dmg.write_bytes(b"disk image")
            write_source_archive(source)
            evidence = {
                "version": "0.2.0-beta.3",
                "commit": "a" * 40,
                "dmg_sha256": hashlib.sha256(dmg.read_bytes()).hexdigest(),
                "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                "checks": {name: {"result": "pass", "reviewer": "reviewer",
                                  "evidence": "https://example.org/evidence"}
                           for name in RELEASE["CHECKS"]},
            }
            validate = RELEASE["validate_evidence"]
            self.assertEqual(validate(evidence, dmg, source), ("0.2.0-beta.3", "a" * 40, True))
            del evidence["checks"]["native_gui_x86_64"]
            with self.assertRaisesRegex(ValueError, "native_gui_x86_64"):
                validate(evidence, dmg, source)
            evidence["checks"]["native_gui_x86_64"] = {
                "result": "pass", "reviewer": "reviewer", "evidence": "checked"}
            dmg.write_bytes(b"changed")
            with self.assertRaisesRegex(ValueError, "SHA-256"):
                validate(evidence, dmg, source)

    def test_validation_prerelease_records_unperformed_gui_but_requires_source_review(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            dmg = root / "Glassmacs-v0.1.0-alpha.3.dmg"
            source = root / "source.tar.gz"
            dmg.write_bytes(b"disk image")
            write_source_archive(source)
            evidence = {
                "version": "0.1.0-alpha.3", "commit": "a" * 40,
                "application_commit": "b" * 40, "provenance": "previous signed build",
                "dmg_sha256": hashlib.sha256(dmg.read_bytes()).hexdigest(),
                "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
                "checks": {
                    name: {"result": "pass" if name in RELEASE["VALIDATION_REQUIRED_CHECKS"]
                           else "not_tested", "reviewer": "reviewer", "evidence": "record"}
                    for name in RELEASE["CHECKS"]
                },
            }
            validate = RELEASE["validate_evidence"]
            self.assertTrue(validate(evidence, dmg, source, validation=True)[2])
            with self.assertRaisesRegex(ValueError, "native_gui_arm64"):
                validate(evidence, dmg, source)
            evidence["checks"]["corresponding_source_and_licenses"]["result"] = "not_tested"
            with self.assertRaisesRegex(ValueError, "corresponding_source_and_licenses"):
                validate(evidence, dmg, source, validation=True)

    def test_legacy_candidate_requires_exact_bundle_version(self):
        validate = RELEASE["validate_bundle_version"]
        info = {"CFBundleIdentifier": "org.glassmacs.Glassmacs",
                "CFBundleShortVersionString": "31.1"}
        validate(info, "0.1.0-alpha.3", "31.1")
        with self.assertRaisesRegex(ValueError, "bundle identifier or release version"):
            validate(info, "0.1.0-alpha.3", None)
        with self.assertRaisesRegex(ValueError, "bundle identifier or release version"):
            validate(info, "0.1.0-alpha.3", "31.2")
        info["GlassmacsReleaseVersion"] = "0.1.0-alpha.2"
        with self.assertRaisesRegex(ValueError, "bundle identifier or release version"):
            validate(info, "0.1.0-alpha.3", "31.1")

    def test_source_archive_must_really_be_an_archive(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "source.tar.gz"
            path.write_bytes(b"not an archive")
            with self.assertRaisesRegex(ValueError, "readable"):
                RELEASE["validate_source_archive"](path)

    def test_packaging_refuses_an_adhoc_app(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            app = root / "Glassmacs.app"
            (app / "Contents").mkdir(parents=True)
            (app / "Contents" / "Info.plist").write_text("placeholder")
            tools = root / "bin"
            tools.mkdir()
            identity = "A" * 40
            (tools / "security").write_text(
                f'#!/bin/sh\nprintf \'1) {identity} "Developer ID Application: Test"\\n\'\n')
            (tools / "codesign").write_text(
                '#!/bin/sh\n[ "$1" != -dv ] || echo "Authority=Ad Hoc" >&2\nexit 0\n')
            for path in tools.iterdir():
                path.chmod(0o755)
            output = root / "candidate.dmg"
            env = dict(os.environ, PATH=f"{tools}:{os.environ['PATH']}",
                       GLASSMACS_SIGN_IDENTITY=identity)
            result = subprocess.run(
                ["bash", str(ROOT / "scripts" / "package-macos-dmg"),
                 str(app), str(output), "test-profile"],
                env=env, text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("not signed with Developer ID", result.stderr)
            self.assertFalse(output.exists())

    def test_release_refuses_log_for_another_disk_image(self):
        with tempfile.TemporaryDirectory() as temp:
            dmg = Path(temp) / "candidate.dmg"
            Path(str(dmg) + ".notary-log.json").write_text(json.dumps({
                "status": "Accepted", "archiveFilename": "Glassmacs.dmg",
                "ticketContents": [{"path": "Glassmacs.dmg", "digestAlgorithm": "SHA-256",
                                    "cdhash": "a" * 40}]}))
            metadata = ("Authority=Developer ID Application: Test\n"
                        "Timestamp=now\nCDHash=" + "b" * 40 + "\n")
            with mock.patch.object(subprocess, "run") as process:
                process.return_value.stderr = metadata
                with self.assertRaisesRegex(ValueError, "does not match"):
                    RELEASE["verify_signed_artifact"](dmg, "0.2.0")

    @unittest.skipUnless(sys.platform == "darwin", "requires macOS system tools")
    def test_validation_report_records_versions_without_app_path(self):
        with tempfile.TemporaryDirectory() as temp:
            app = Path(temp) / "Glassmacs.app"
            (app / "Contents").mkdir(parents=True)
            (app / "Contents" / "Info.plist").write_bytes(plistlib.dumps({
                "CFBundleShortVersionString": "31.1",
                "CFBundleVersion": "311",
            }))
            result = subprocess.run(
                ["bash", str(ROOT / "scripts" / "collect-validation-report"), str(app)],
                capture_output=True, text=True, check=True)
            self.assertIn("Bundle short version: 31.1", result.stdout)
            self.assertIn("not recorded in this bundle", result.stdout)
            self.assertIn("Session restoration and crash recovery", result.stdout)
            self.assertNotIn(str(app), result.stdout)


if __name__ == "__main__":
    unittest.main()
