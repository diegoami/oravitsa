#!/usr/bin/env python3
"""Export the same Godot project for static Web hosting and/or native Linux."""
import argparse
import os
from pathlib import Path
import subprocess
import re
import shutil

from package_web import package

ROOT = Path(__file__).resolve().parents[1]


def run(godot: str, *arguments: str, project: Path = ROOT) -> None:
    subprocess.run([godot, "--headless", "--path", str(project), *arguments], check=True)


def web_project(build: Path) -> Path:
    """Compress only the Web copy; native imports and source PNGs stay intact."""
    target = build / "web-project"
    if target.exists():
        shutil.rmtree(target)
    target.mkdir()
    for name in ["project.godot", "export_presets.cfg", "icon.svg", "icon.svg.import"]:
        shutil.copy2(ROOT / name, target / name)
    shutil.copytree(ROOT / "web", target / "web")
    shutil.copytree(ROOT / "scenes/forest_2d", target / "scenes/forest_2d",
                    ignore=shutil.ignore_patterns("*.md", "*smoke_test*", "oravitsa_walk_side.png*"))
    art = target / "prototypes/foraging_2d/art"
    art.mkdir(parents=True)
    for name in ["boar_walk.png", "deer_walk.png", "mushrooms.png"]:
        for file in (ROOT / "prototypes/foraging_2d/art").glob(name + "*"):
            shutil.copy2(file, art / file.name)
    for file in target.rglob("*.png.import"):
        text = re.sub(r"compress/mode=\d+", "compress/mode=1", file.read_text())
        text = re.sub(r"compress/lossy_quality=[\d.]+", "compress/lossy_quality=0.85", text)
        file.write_text(text)
    return target


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", choices=["web", "linux", "all"], default="web", nargs="?")
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    args = parser.parse_args()
    build = ROOT / "build"
    build.mkdir(exist_ok=True)
    (build / ".gdignore").touch()
    if args.target in ("web", "all"):
        project = web_project(build)
        run(args.godot, "--editor", "--import", project=project)
        web = build / "web"
        web.mkdir(exist_ok=True)
        run(args.godot, "--export-release", "Web", str(web / "index.html"), project=project)
        package(web, build / "site")
    if args.target in ("linux", "all"):
        run(args.godot, "--editor", "--import")
        linux = build / "linux"
        linux.mkdir(exist_ok=True)
        run(args.godot, "--export-release", "Linux", str(linux / "oravitsa.x86_64"))


if __name__ == "__main__":
    main()
