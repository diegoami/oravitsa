#!/usr/bin/env python3
"""Run the Godot gates; script errors and incomplete tests must fail CI."""
import argparse
import os
from pathlib import Path
import queue
import re
import subprocess
import sys
import threading
import time

ROOT = Path(__file__).resolve().parents[1]
SMOKES = (
    ("scenes/forest_2d/smoke_test.gd", "Forest smoke test passed:"),
    ("scenes/forest_2d/mobile_smoke_test.gd", "Mobile smoke test passed:"),
    ("scenes/forest_2d/sling_smoke_test.gd", "Sling smoke test passed:"),
    ("scenes/forest_2d/controller_smoke_test.gd", "Controller smoke test passed:"),
    ("scenes/forest_25d/smoke_test.gd", "2.5D smoke test passed:"),
    ("scenes/forest_25d/world_smoke_test.gd", "Expanded world test passed:"),
    ("scenes/forest_25d/streaming_smoke_test.gd", "Streaming smoke test passed:"),
    ("scenes/forest_25d/spawn_smoke_test.gd", "Spawn smoke test passed:"),
    ("prototypes/foraging_2d/smoke_test.gd", "2D foraging smoke test passed"),
    ("scenes/endless_woods/world_smoke_test.gd", "Endless world smoke test passed:"),
    ("scenes/endless_woods/wildlife_smoke_test.gd", "Endless wildlife smoke test passed:"),
    ("scenes/endless_woods/regrowth_smoke_test.gd", "Food regrowth smoke test passed:"),
    ("scenes/endless_woods/shoo_smoke_test.gd", "Targeted Shoo smoke test passed:"),
    ("scenes/endless_woods/fox_forage_smoke_test.gd", "Fox forage smoke test passed:"),
    ("scenes/endless_woods/hare_meat_smoke_test.gd", "Hare meat smoke test passed:"),
)
ERROR = re.compile(r"^\s*(?:(?:SCRIPT|SHADER|USER) ERROR:|ERROR:)", re.MULTILINE)
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")


def run_checked(command: list[str], label: str, marker: str | None = None,
                timeout: float = 180, cwd: Path = ROOT) -> str:
    try:
        process = subprocess.Popen(command, cwd=cwd, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True,
                                   encoding="utf-8", errors="replace")
    except OSError as error:
        raise RuntimeError(f"{label}: could not complete: {error}") from error
    lines: list[str] = []
    events: queue.Queue[str | None] = queue.Queue()

    def read_output() -> None:
        try:
            for line in process.stdout:
                events.put(line)
        finally:
            events.put(None)

    reader = threading.Thread(target=read_output, daemon=True)
    reader.start()
    deadline = time.monotonic() + timeout
    timed_out = False
    try:
        while True:
            try:
                line = events.get(timeout=max(0.001, deadline - time.monotonic()))
            except queue.Empty:
                timed_out = True
                break
            if line is None:
                break
            lines.append(line)
            if ERROR.search(ANSI.sub("", line)):
                # Godot assertion/runtime failures may never exit on their own.
                break
            if time.monotonic() >= deadline:
                timed_out = True
                break
        if not timed_out and not ERROR.search(ANSI.sub("", "".join(lines))):
            try:
                process.wait(timeout=max(0.001, deadline - time.monotonic()))
            except subprocess.TimeoutExpired:
                timed_out = True
    finally:
        if process.poll() is None:
            process.kill()
        process.wait()
        reader.join(timeout=2)
        while not events.empty():
            line = events.get_nowait()
            if line is not None:
                lines.append(line)
        process.stdout.close()
    output = ANSI.sub("", "".join(lines))
    if timed_out:
        raise RuntimeError(f"{label}: could not complete: timed out after {timeout} seconds\n{output}")
    if process.returncode or ERROR.search(output) or (marker and not any(
            line.startswith(marker) for line in output.splitlines())):
        raise RuntimeError(f"{label}: failed (exit {process.returncode}; expected completion marker: {marker!r})\n{output}")
    return output


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--native-smoke", type=Path,
                        help="Check a native export's startup instead of scene tests")
    parser.add_argument("--timeout", type=float, default=180,
                        help="Maximum seconds for each import or smoke process")
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    command = [args.godot, "--headless", "--path", str(ROOT)]
    try:
        if args.native_smoke:
            run_checked([str(args.native_smoke.resolve()), "--headless", "--quit-after", "120"],
                        "Native package startup", timeout=args.timeout)
            print("PASS Native package startup", flush=True)
            return 0
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
