#!/usr/bin/env python3
"""Package Godot 4.7.2 with explicit decompression and hashed static assets.

The browser decompresses the engine, without host Content-Encoding settings.
Native exports and source artwork are unaffected.
"""
import argparse
import gzip
import hashlib
import json
from pathlib import Path
import re
import shutil


def package(source: Path, destination: Path) -> None:
    if source.resolve() == destination.resolve():
        raise ValueError("Use a separate output directory to preserve the export")
    if destination.exists():
        shutil.rmtree(destination)
    destination.mkdir(parents=True)
    for file in source.iterdir():
        if file.is_file() and file.suffix not in (".import", ".wasm", ".pck"):
            shutil.copy2(file, destination / file.name)

    def asset(data: bytes, prefix: str) -> dict:
        name = f"{prefix}-{hashlib.sha256(data).hexdigest()[:16]}.bin"
        (destination / name).write_bytes(data)
        return {"name": name, "size": len(data)}

    parts = []
    with (source / "index.pck").open("rb") as stream:
        while data := stream.read(16 * 1024 * 1024):
            parts.append(asset(data, "forest"))
    engine = asset(gzip.compress((source / "index.wasm").read_bytes(), compresslevel=9, mtime=0), "engine")
    html = destination / "index.html"
    marker = "/* ORAVITSA_ASSETS */ null"
    text = html.read_text()
    if marker not in text:
        raise ValueError("Export must use Oravitsa's Web shell")
    html.write_text(text.replace(marker, json.dumps({"engine": engine, "pack": parts}, separators=(",", ":"))))

    # A narrow adapter for the pinned non-.NET 4.7.2 export. Preserve normal
    # audio worklet paths while supplying a decompressed WebAssembly Response.
    javascript = destination / "index.js"
    text = javascript.read_text()
    loader = "preloader.loadPromise(" + chr(96) + "$" + "{loadPath}.wasm" + chr(96) + ", size, true)"
    if text.count(loader) != 1:
        raise ValueError("Unsupported Godot loader; expected the 4.7.2 template")
    text = text.replace(loader, "window.oravitsaLoadEngine ? window.oravitsaLoadEngine() : " + loader)
    # Propagate errors omitted by Godot's nested initializer, so a network or
    # WebAssembly failure reaches the retry UI instead of leaving it pending.
    initializer = r"function doInit\(promise\) \{.*?\n\t{4}\}\n(?=\t{4}preloader.setProgressFunc)"
    replacement = """async function doInit(promise) {
                    const response = await promise;
                    const cloned = new Response(response.body, {headers: {'Content-Type': 'application/wasm'}});
                    const module = await Godot(me.config.getModuleConfig(loadPath, cloned));
                    await module['initFS'](me.config.persistentPaths);
                    me.rtenv = module;
                    if (me.config.unloadAfterInit) Engine.unload();
                }
"""
    text, count = re.subn(initializer, lambda _: replacement, text, flags=re.DOTALL)
    if count != 1:
        raise ValueError("Unsupported Godot initializer; expected the 4.7.2 template")
    javascript.write_text(text)
    (destination / "_headers").write_text(
        "/index.html\n  Cache-Control: no-cache\n"
        "/*.bin\n  Cache-Control: public, max-age=31536000, immutable\n")
    files = [p for p in destination.iterdir() if p.is_file()]
    if any(p.stat().st_size > 25 * 1024 * 1024 for p in files):
        raise ValueError("Static asset exceeds 25 MiB")
    total = sum(p.stat().st_size for p in files)
    print(f"Packaged {len(parts)} artwork parts; {total / 1048576:.1f} MiB total; no compression headers required")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    package(args.source, args.destination)
