"""Regression tests for the fail-closed packaged GUI acceptance gate."""
import json
import runpy
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "check-alpha-gui-results"
gate = runpy.run_path(str(SCRIPT))
check = gate["check"]
required = gate["REQUIRED"]


class AlphaGuiGateTests(unittest.TestCase):
    def verify(self, scenarios):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "results.json"
            path.write_text(json.dumps({"scenarios": scenarios}), encoding="utf-8")
            return check(path)

    def test_all_required_pass(self):
        self.assertEqual([], self.verify([
            {"name": name, "status": "pass"} for name in required
        ]))

    def test_missing_required_fails(self):
        issues = self.verify([])
        self.assertEqual(len(required), len(issues))

    def test_skipped_required_fails(self):
        scenarios = [{"name": name, "status": "pass"} for name in required]
        scenarios[0]["status"] = "not-run"
        self.assertEqual(1, len(self.verify(scenarios)))

    def test_unrelated_failure_fails(self):
        scenarios = [{"name": name, "status": "pass"} for name in required]
        scenarios.append({"name": "other", "status": "fail"})
        self.assertEqual(1, len(self.verify(scenarios)))

    def test_optional_not_run_is_not_false_failure(self):
        scenarios = [{"name": name, "status": "pass"} for name in required]
        scenarios.append({"name": "optional", "status": "not-run"})
        self.assertEqual([], self.verify(scenarios))

    def test_duplicate_scenario_rejected(self):
        with self.assertRaises(ValueError):
            self.verify([{"name": "duplicate", "status": "pass"}] * 2)


if __name__ == "__main__":
    unittest.main()
