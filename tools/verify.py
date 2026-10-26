#!/usr/bin/env python3
"""Run the Godot gates; script errors and incomplete tests must fail CI."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SMOKES = (
    ("scenes/forest_2d/smoke_test.gd", "Forest smoke test passed:"),
    ("scenes/forest_2d/mobile_smoke_test.gd", "Mobile smoke test passed:"),
    ("scenes/forest_2d/sling_smoke_test.gd", "Sling smoke test passed:"),
    ("scenes/forest_2d/controller_smoke_test.gd", "Controller smoke test passed:"),
    ("scenes/forest_25d/smoke_test.gd", "2.5D smoke test passed:"),
    ("scenes/forest_25d/world_smoke_test.gd", "Expanded world test passed:"),
)
ERROR = re.compile(r"^\s*(?:(?:SCRIPT|SHADER|USER) ERROR:|ERROR:)", re.MULTILINE)
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")


def run_checked(command: list[str], label: str, marker: str | None = None,
                timeout: float = 180, cwd: Path = ROOT) -> str:
    try:
        result = subprocess.run(command, cwd=cwd, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True,
                                encoding="utf-8", errors="replace", timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise RuntimeError(f"{label}: could not complete: {error}") from error
    output = ANSI.sub("", result.stdout)
    if result.returncode or ERROR.search(output) or (marker and not any(
            line.startswith(marker) for line in output.splitlines())):
        raise RuntimeError(f"{label}: failed (exit {result.returncode}; expected completion marker: {marker!r})\n{output}")
    return output


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--timeout", type=float, default=180,
                        help="Maximum seconds for each import or smoke process")
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    command = [args.godot, "--headless", "--path", str(ROOT)]
    try:
        run_checked([*command, "--editor", "--import"], "Godot import", timeout=args.timeout)
        print("PASS Godot import", flush=True)
        for script, marker in SMOKES:
            run_checked([*command, "--script", script], script, marker, args.timeout)
            print(f"PASS {script}", flush=True)
    except RuntimeError as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
