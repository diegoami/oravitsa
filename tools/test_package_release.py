"""Release archives must reject files not covered by export provenance."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import package_release
import export as exporter

COMMIT = "a" * 40


class PackageReleaseTests(unittest.TestCase):
    def setUp(self):
        scratch = Path(__file__).resolve().parents[1] / "build" / "package-tests"
        scratch.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=scratch)
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "project.godot").write_text('config/version="0.1.0-alpha.1"\n')
        for folder, filename in [("windows", "oravitsa.exe"), ("linux", "oravitsa.x86_64"), ("site", "index.html")]:
            target = self.root / "build" / folder
            target.mkdir(parents=True)
            data = b"exported content"
            (target / filename).write_bytes(data)
            (target / "EXPORT_SOURCE.json").write_text(json.dumps({
                "source_commit": COMMIT, "source_dirty": False,
                "files": {filename: hashlib.sha256(data).hexdigest()}}))

    def package(self):
        with patch.object(package_release, "ROOT", self.root), patch.object(
                package_release.subprocess, "check_output", side_effect=[COMMIT + "\n", ""]):
            package_release.main()

    def test_clean_export_packages_only_manifested_files(self):
        self.package()
        archive = self.root / "build/releases/v0.1.0-alpha.1/oravitsa-v0.1.0-alpha.1-windows-x86_64.zip"
        with zipfile.ZipFile(archive) as bundle:
            self.assertEqual(set(bundle.namelist()), {"oravitsa.exe", "EXPORT_SOURCE.json", "PLAY.txt", "SOURCE.json"})

    def test_stray_pack_is_rejected(self):
        (self.root / "build/windows/oravitsa.pck").write_bytes(b"stale pack")
        with self.assertRaisesRegex(SystemExit, "contents"):
            self.package()

    def test_changed_executable_is_rejected(self):
        (self.root / "build/windows/oravitsa.exe").write_bytes(b"different executable")
        with self.assertRaisesRegex(SystemExit, "contents"):
            self.package()

    def test_stray_web_file_is_rejected(self):
        (self.root / "build/site/old-engine.bin").write_bytes(b"stale engine")
        with self.assertRaisesRegex(SystemExit, "contents"):
            self.package()

    def test_native_export_resets_old_pack_before_build(self):
        target = self.root / "build/windows"
        (target / "oravitsa.pck").write_bytes(b"old pack")
        with patch.object(exporter, "ROOT", self.root):
            result = exporter.reset_export_dir("windows")
        self.assertEqual(result, target)
        self.assertEqual(list(target.iterdir()), [])

    def test_export_reset_rejects_arbitrary_paths(self):
        with patch.object(exporter, "ROOT", self.root):
            with self.assertRaises(ValueError):
                exporter.reset_export_dir("../project.godot")
        self.assertTrue((self.root / "project.godot").is_file())
