#!/usr/bin/env python3
"""Export the same Godot project for static Web hosting and/or native Linux."""
import argparse
import os
from pathlib import Path
import subprocess

from package_web import package

ROOT = Path(__file__).resolve().parents[1]


def run(godot: str, *arguments: str) -> None:
    subprocess.run([godot, "--headless", "--path", str(ROOT), *arguments], check=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", choices=["web", "linux", "all"], default="web", nargs="?")
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    args = parser.parse_args()
    build = ROOT / "build"
    build.mkdir(exist_ok=True)
    (build / ".gdignore").touch()
    run(args.godot, "--editor", "--import")
    if args.target in ("web", "all"):
        web = build / "web"
        web.mkdir(exist_ok=True)
        run(args.godot, "--export-release", "Web", str(web / "index.html"))
        package(web, build / "site")
    if args.target in ("linux", "all"):
        linux = build / "linux"
        linux.mkdir(exist_ok=True)
        run(args.godot, "--export-release", "Linux", str(linux / "oravitsa.x86_64"))


if __name__ == "__main__":
    main()
