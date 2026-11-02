import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UUID = "11111111-2222-3333-4444-555555555555"

FAKE_XCRUN = r"""#!/bin/bash
echo "xcrun $*" >> "$FAKE_LOG"
case "$1 $2" in
  "notarytool submit")
    [ -f "$3" ] && echo "zip-present" >> "$FAKE_LOG"
    echo "$3" > "$FAKE_ZIP_PATH"
    printf '{"id":"%s","status":"%s"}' "$FAKE_ID" "$FAKE_STATUS"
    [ "$FAKE_STATUS" = Accepted ] ;;
  "notarytool log")
    out=""; for a in "$@"; do case "$a" in *.json) out=$a;; esac; done
    printf '{"status":"%s","issues":[{"path":"x/y","message":"bad thing"}]}' "$FAKE_STATUS" > "$out" ;;
  "stapler staple") [ "$FAKE_STAPLE" = fail ] && exit 65; exit 0 ;;
  "stapler validate") exit 0 ;;
esac
"""
FAKE_CODESIGN = """#!/bin/bash
echo "codesign $*" >> "$FAKE_LOG"
case "$1" in
  -dv) echo "Authority=Developer ID Application: Test (TEAM)" >&2 ;;
esac
exit 0
"""
FAKE_SPCTL = """#!/bin/bash
echo "spctl $*" >> "$FAKE_LOG"
echo "app: $FAKE_SPCTL_RESULT"
[ "$FAKE_SPCTL_RESULT" = accepted ]
"""


class NotarizeStapleTests(unittest.TestCase):
    def run_script(self, status="Accepted", staple="ok", spctl="accepted"):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            bin_dir = base / "bin"
            bin_dir.mkdir()
            for name, body in (("xcrun", FAKE_XCRUN), ("codesign", FAKE_CODESIGN),
                               ("spctl", FAKE_SPCTL)):
                (bin_dir / name).write_text(body)
                (bin_dir / name).chmod(0o755)
            app = base / "Glassmacs.app/Contents"
            app.mkdir(parents=True)
            (app / "Info.plist").write_text("x")
            out = base / "out"
            tmp = base / "tmp"
            tmp.mkdir()
            env = dict(os.environ, PATH=f"{bin_dir}:{os.environ['PATH']}", TMPDIR=str(tmp),
                       FAKE_LOG=str(base / "log"), FAKE_ID=UUID, FAKE_STATUS=status,
                       FAKE_STAPLE=staple, FAKE_SPCTL_RESULT=spctl,
                       FAKE_ZIP_PATH=str(base / "zippath"))
            (base / "log").write_text("")
            result = subprocess.run(
                ["bash", str(ROOT / "scripts/notarize-staple"), str(base / "Glassmacs.app"),
                 "my-profile", str(out), "run"],
                text=True, capture_output=True, env=env)
            return (result, (base / "log").read_text(),
                    {p.name: p.read_text() for p in out.glob("*")} if out.exists() else {},
                    list(tmp.iterdir()), (base / "zippath").read_text().strip())

    def test_accepted_submission_is_stapled_validated_and_recorded(self):
        result, log, files, leftovers, _ = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        for expected in ("notarytool submit", "--wait", "stapler staple", "stapler validate",
                         "codesign --verify --deep --strict", "spctl --assess --type execute"):
            self.assertIn(expected, log)
        self.assertLess(log.index("stapler staple"), log.index("stapler validate"))
        self.assertIn(f"SUBMISSION_ID={UUID}", files["run.notary.env"])
        self.assertIn("STATUS=Accepted", files["run.notary.env"])
        self.assertIn("SPCTL=accepted", files["run.notary.env"])
        self.assertIn("run.notary-log.json", files)
        self.assertEqual(leftovers, [])

    def test_uses_keychain_profile_and_never_altool(self):
        _, log, _, _, _ = self.run_script()
        self.assertIn("--keychain-profile my-profile", log)
        self.assertNotIn("altool", log)
        self.assertNotIn("password", log.lower())

    def test_rejected_submission_preserves_log_and_never_staples(self):
        result, log, files, leftovers, _ = self.run_script(status="Invalid")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("stapler", log)
        self.assertIn("bad thing", result.stderr)
        self.assertIn("run.notary-log.json", files)
        self.assertEqual(json.loads(files["run.notary-log.json"])["status"], "Invalid")
        self.assertIn("STATUS=Invalid", files["run.notary.env"])
        self.assertEqual(leftovers, [])

    def test_staple_failure_and_gatekeeper_rejection_fail(self):
        result, *_ = self.run_script(staple="fail")
        self.assertNotEqual(result.returncode, 0)
        result, _, files, *_ = self.run_script(spctl="rejected")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("SPCTL=rejected", files["run.notary.env"])

    def test_orchestrator_notarizes_before_creating_final_zip(self):
        script = (ROOT / "scripts/update-build-sign").read_text()
        for flag in ("--notarize", "--require-notarization", "--notary-profile",
                     "--ref", "--branch", "--no-pull", "--skip-tests", "--install"):
            self.assertIn(flag, script)
        self.assertLess(script.index("scripts/notarize-staple"),
                        script.index('ditto -c -k --keepParent --sequesterRsrc'))
        self.assertLess(script.index("scripts/sign-macos-app"),
                        script.index("scripts/notarize-staple"))
        self.assertIn("-unnotarized", script)
        self.assertNotIn("altool", script)

    def test_release_mode_rejects_skipped_tests(self):
        result = subprocess.run(
            ["bash", str(ROOT / "scripts/update-build-sign"), "--require-notarization",
             "--skip-tests"], text=True, capture_output=True, cwd=ROOT)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("cannot be combined with --skip-tests", result.stderr)


if __name__ == "__main__":
    unittest.main()
