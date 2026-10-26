#!/usr/bin/env python3
"""Archive already exported builds from a clean, exact source commit."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    dirty = subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True).strip()
    if dirty:
        raise SystemExit("Package from a clean checkout of the candidate commit; commit source changes first.")
    version = re.search(r'^config/version="([^"]+)"$', (ROOT / "project.godot").read_text(), re.MULTILINE).group(1)
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:-[a-zA-Z0-9.]+)?", version):
        raise SystemExit("Invalid release version")
    targets = {"windows-x86_64": "windows", "linux-x86_64": "linux", "web": "site"}
    required = {"windows": "oravitsa.exe", "linux": "oravitsa.x86_64", "site": "index.html"}
    for folder, filename in required.items():
        if not (ROOT / "build" / folder / filename).is_file():
            raise SystemExit(f"Missing {folder} export; run tools/export.py all first.")
        stamp = ROOT / "build" / folder / "EXPORT_SOURCE.json"
        if not stamp.is_file():
            raise SystemExit(f"Missing provenance for {folder}; rebuild with tools/export.py.")
        state = json.loads(stamp.read_text(encoding="utf-8"))
        if state.get("source_commit") != commit or state.get("source_dirty") is not False:
            raise SystemExit(f"Stale or dirty {folder} export; rebuild from {commit}.")
    output = ROOT / "build" / "releases" / f"v{version}"
    output.mkdir(parents=True, exist_ok=True)
    readme = f"""Oravitsa v{version} — Mossbank woods
Source commit: {commit}

Windows: extract the entire archive, then run oravitsa.exe.
Linux: extract, chmod +x oravitsa.x86_64 if needed, then ./oravitsa.x86_64.
Web: serve the extracted folder over HTTP (for example python3 -m http.server
8000), then open http://127.0.0.1:8000/. Do not open index.html using file://.
For a public website use an HTTPS static host. No game backend is required.

Move: WASD/arrows, left stick/D-pad, or touch joystick.
Shoo: Space. Sling: select an animal, then right mouse/F.
Controller: LB/RB select skill, Y casts, A collects; right-stick flicks cycle
targets. Map/help: M/H or Select/Start. Both start hidden.

This is an early alpha: progress is not saved across quitting or reloading.
No quests, swimming, or building loot. Art is still prototype quality.
Untested browser/device/live-flicker areas are listed in the release notes.

Project and asset provenance: https://github.com/diegoami/oravitsa/tree/{commit}
"""
    manifest = {"version": version, "source_commit": commit, "artifacts": []}
    for platform, folder in targets.items():
        archive = output / f"oravitsa-v{version}-{platform}.zip"
        source = ROOT / "build" / folder
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
            for file in sorted(source.rglob("*")):
                if file.is_file() and not file.name.endswith(".import"):
                    relative = file.relative_to(source).as_posix()
                    info = zipfile.ZipInfo(relative, (2026, 1, 1, 0, 0, 0))
                    info.create_system = 3
                    mode = 0o755 if platform == "linux-x86_64" and relative == "oravitsa.x86_64" else 0o644
                    info.external_attr = (0o100000 | mode) << 16
                    info.compress_type = zipfile.ZIP_DEFLATED
                    bundle.writestr(info, file.read_bytes())
            bundle.writestr("PLAY.txt", readme)
            bundle.writestr("SOURCE.json", json.dumps({"version": version, "source_commit": commit}, indent=2) + "\n")
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        manifest["artifacts"].append({"name": archive.name, "bytes": archive.stat().st_size, "sha256": digest})
        print(f"Packaged {archive.name}: {archive.stat().st_size / 1048576:.1f} MiB")
    (output / "release-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    checksums = [f"{item['sha256']}  {item['name']}" for item in manifest["artifacts"]]
    digest = hashlib.sha256((output / "release-manifest.json").read_bytes()).hexdigest()
    checksums.append(f"{digest}  release-manifest.json")
    (output / "SHA256SUMS.txt").write_text("\n".join(checksums) + "\n", encoding="utf-8")
    print(f"Release artifacts: {output}")


if __name__ == "__main__":
    main()
