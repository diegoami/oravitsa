"""Install the validated, approved eight-direction render as a Godot resource."""
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'build/fal-walk/render'
TARGET = ROOT / 'scenes/forest_2d/art/oravitsa'
DIRECTIONS = ('s', 'se', 'e', 'ne', 'n', 'nw', 'w', 'sw')


def main():
    manifest = json.loads((SOURCE / 'manifest.json').read_text())
    for name in ('shoe-validation.json', 'skirt-validation.json', 'arm-validation.json'):
        assert json.loads((SOURCE / name).read_text())['poses_checked'] == 65
    assert all(row['penetrating_vertices'] == 0 for row in json.loads((SOURCE / 'arm-validation.json').read_text())['reported_pose_clearance'])
    assert len(manifest['export_checks']) == 8
    assert all(row['unique_images'] == 8 and row['opaque_border_pixels'] == 0 for row in manifest['export_checks'])
    TARGET.mkdir(parents=True, exist_ok=True)
    lines = ['[gd_resource type="SpriteFrames" load_steps=73 format=3]', '']
    hashes = {}
    for direction in DIRECTIONS:
        filename = direction + '.png'
        shutil.copy2(SOURCE / direction / 'atlas.png', TARGET / filename)
        hashes[filename] = hashlib.sha256((TARGET / filename).read_bytes()).hexdigest()
        lines.append(f'[ext_resource type="Texture2D" path="res://scenes/forest_2d/art/oravitsa/{filename}" id="{direction}"]')
    lines.append('')
    for direction in DIRECTIONS:
        for frame in range(8):
            lines += [f'[sub_resource type="AtlasTexture" id="{direction}_{frame}"]', f'atlas = ExtResource("{direction}")', f'region = Rect2({frame * 256}, 0, 256, 384)', '']
    lines += ['[resource]', 'animations = [']
    fps = 8 / manifest['source_cycle_seconds']
    for index, direction in enumerate(DIRECTIONS):
        frames = ', '.join(f'{{"duration": 1.0, "texture": SubResource("{direction}_{i}")}}' for i in range(8))
        lines += ['{', f'"frames": [{frames}],', '"loop": true,', f'"name": &"{direction}",', f'"speed": {fps:.12f}', '}' + (',' if index < 7 else '')]
    px, py = manifest['pivot']
    lines += [']', f'metadata/pivot = Vector2({px:.12f}, {py:.12f})', f'metadata/display_scale = {manifest["preview_scale"]:.12f}', f'metadata/cycle_seconds = {manifest["source_cycle_seconds"]:.12f}', '']
    (TARGET / 'walk.tres').write_text('\n'.join(lines), encoding='utf-8')
    provenance = {'source': manifest['source'], 'cycle_seconds': manifest['source_cycle_seconds'], 'pivot': manifest['pivot'], 'display_scale': manifest['preview_scale'], 'atlas_sha256': hashes, 'repairs': {name: manifest[name] for name in ('foot_repair', 'skirt_repair', 'arm_clearance')}, 'note': 'Approved walking export; original provider downloads retained locally. Rebuild with art/render_imported_walk.py, package and validate before installing.'}
    (TARGET / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n', encoding='utf-8')
    print('Installed 8 atlases and walk.tres (64 approved frames)')


if __name__ == '__main__':
    main()
