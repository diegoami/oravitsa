#!/usr/bin/env python3
"""Prepare a Godot Web export for static hosting with a 25 MiB file limit.

Keep the original export intact: output goes to a separate directory. Artwork
is unchanged. Godot's preload API reassembles PCK parts before starting, and
standard Content-Encoding headers let the browser decompress WebAssembly.
"""
import argparse
import gzip
import json
from pathlib import Path
import shutil


def package(source: Path, destination: Path) -> None:
    if source.resolve() == destination.resolve():
        raise ValueError("Use a separate output directory to preserve the export")
    destination.mkdir(parents=True, exist_ok=True)
    for file in source.iterdir():
        if file.is_file() and file.suffix != ".import":
            shutil.copy2(file, destination / file.name)
    pack = destination / "index.pck"
    parts = []
    with pack.open("rb") as stream:
        while data := stream.read(16 * 1024 * 1024):
            name = f"forest-{len(parts):02d}.bin"
            (destination / name).write_bytes(data)
            parts.append({"name": name, "size": len(data)})
    pack.unlink()
    html = destination / "index.html"
    marker = "/* ORAVITSA_PACK */ null"
    text = html.read_text()
    if marker not in text:
        raise ValueError("Export must use Oravitsa's Web shell")
    html.write_text(text.replace(marker, json.dumps(parts, separators=(",", ":"))))
    wasm = destination / "index.wasm"
    wasm.write_bytes(gzip.compress(wasm.read_bytes(), compresslevel=9, mtime=0))
    (destination / "_headers").write_text(
        "/index.wasm\n  Content-Type: application/wasm\n  Content-Encoding: gzip\n"
        "/index.html\n  Cache-Control: no-cache\n"
        "/*.bin\n  Cache-Control: no-cache\n"
    )
    for file in destination.iterdir():
        if file.is_file() and file.stat().st_size > 25 * 1024 * 1024:
            raise ValueError(f"Static asset exceeds 25 MiB: {file.name}")
    print(f"Packaged {len(parts)} artwork parts and compressed WebAssembly in {destination}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    package(args.source, args.destination)
