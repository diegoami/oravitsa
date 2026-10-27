"""Hash the exact file set produced by an export, excluding its own stamp."""
import hashlib
from pathlib import Path


def file_manifest(target: Path) -> dict[str, str]:
    if target.is_symlink() or getattr(target, "is_junction", lambda: False)():
        raise ValueError("Export contents must not use a linked root")
    root = target.resolve()
    files = {}
    for path in sorted(target.rglob("*")):
        relative = path.relative_to(target)
        if path.is_symlink() or path.resolve() != root / relative:
            raise ValueError(f"Export contents contain a linked path: {relative}")
        if not path.is_file() or relative.as_posix() == "EXPORT_SOURCE.json":
            continue
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
        files[relative.as_posix()] = digest.hexdigest()
    return files
