"""Prove the gate rejects Godot's exit-zero failure modes, not just crashes."""
from pathlib import Path
import sys
import unittest

from verify import run_checked


class VerifyTests(unittest.TestCase):
    def run_program(self, code, marker="Test passed:", timeout=10):
        return run_checked([sys.executable, "-c", code], "fixture", marker,
                           timeout, Path(__file__).resolve().parent)

    def test_success(self):
        self.assertIn("Test passed:", self.run_program("print('Test passed: done')"))

    def test_script_failure_with_exit_zero(self):
        with self.assertRaisesRegex(RuntimeError, "SCRIPT ERROR"):
            self.run_program("print('SCRIPT ERROR: Assertion failed.'); print('Test passed: done')")

    def test_error_on_stderr(self):
        with self.assertRaisesRegex(RuntimeError, "ERROR: broken"):
            self.run_program("import sys; print('ERROR: broken', file=sys.stderr); print('Test passed: done')")

    def test_shader_failure_with_color_codes(self):
        with self.assertRaisesRegex(RuntimeError, "SHADER ERROR"):
            self.run_program("print('\\x1b[31mSHADER ERROR: broken\\x1b[0m'); print('Test passed: done')")

    def test_missing_completion(self):
        with self.assertRaises(RuntimeError):
            self.run_program("print('Godot started but test never completed')")

    def test_nonzero_exit_despite_completion(self):
        with self.assertRaisesRegex(RuntimeError, "exit 7"):
            self.run_program("print('Test passed: done'); raise SystemExit(7)")

    def test_timeout(self):
        with self.assertRaisesRegex(RuntimeError, "could not complete"):
            self.run_program("import time; time.sleep(10)", timeout=0.05)

    def test_missing_executable(self):
        with self.assertRaisesRegex(RuntimeError, "could not complete"):
            run_checked([str(Path(__file__).parent / 'missing-godot-executable')], "fixture")


if __name__ == "__main__":
    unittest.main()
