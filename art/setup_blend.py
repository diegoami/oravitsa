"""Build art/oravitsa.blend: a Blender scene set up to model Oravitsa in.

Run headless from the project root:

    blender --background --python art/setup_blend.py

It does the fiddly setup that is easy to get wrong and expensive to discover
later -- metric units at 1 unit = 1 metre, a near viewport clip so a 1.5 m
figure is workable, and the blockout imported as a locked reference at true
scale. Modelling happens in the Model collection, on top of that reference.

Blender is Z-up and Godot is Y-up; the glTF importer handles the conversion,
so in here her height runs along +Z.
"""
import sys
import bpy
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
REFERENCE = PROJECT / "docs" / "oravitsa_blockout.glb"
OUT = PROJECT / "art" / "oravitsa.blend"

CANONICAL_HEIGHT = 1.5  # metres; docs/character.md


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def set_units(scene):
    u = scene.unit_settings
    u.system = "METRIC"
    u.scale_length = 1.0
    u.length_unit = "METERS"


def set_viewport_ranges():
    """A 1.5 m subject needs a near clip well under Blender's 0.1 m default,
    or detail at the scale of a braid disappears when you zoom in."""
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type != "VIEW_3D":
                continue
            for space in area.spaces:
                if space.type == "VIEW_3D":
                    space.clip_start = 0.005
                    space.clip_end = 200.0
                    space.shading.type = "SOLID"


def collection(name, parent):
    col = bpy.data.collections.new(name)
    parent.children.link(col)
    return col


def world_bounds(objects):
    lo = [float("inf")] * 3
    hi = [float("-inf")] * 3
    for obj in objects:
        if obj.type != "MESH":
            continue
        for corner in obj.bound_box:
            p = obj.matrix_world @ type(obj.location)(corner)
            for i in range(3):
                lo[i] = min(lo[i], p[i])
                hi[i] = max(hi[i], p[i])
    return lo, hi


def main():
    if not REFERENCE.exists():
        sys.exit(f"missing reference: {REFERENCE}")

    clear_scene()
    scene = bpy.context.scene
    set_units(scene)
    set_viewport_ranges()

    root = scene.collection
    ref_col = collection("Reference", root)
    model_col = collection("Model", root)

    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(REFERENCE))
    imported = [o for o in bpy.data.objects if o not in before]

    # Move everything imported into Reference, and lock it so it cannot be
    # selected by accident while modelling on top of it.
    for obj in imported:
        for col in list(obj.users_collection):
            col.objects.unlink(obj)
        ref_col.objects.link(obj)
        obj.hide_select = True

    lo, hi = world_bounds(imported)
    height = hi[2] - lo[2]
    print(f"REF_OBJECTS={len(imported)}")
    print(f"REF_BOUNDS_Z={lo[2]:.4f}..{hi[2]:.4f}")
    print(f"REF_HEIGHT={height:.4f}")
    print(f"REF_WIDTH_X={hi[0] - lo[0]:.4f}")
    print(f"REF_DEPTH_Y={hi[1] - lo[1]:.4f}")

    # The reference is only worth anything if it came in at true scale.
    if not (CANONICAL_HEIGHT - 0.02 <= height <= CANONICAL_HEIGHT + 0.05):
        sys.exit(f"reference imported at {height:.4f} m, expected ~{CANONICAL_HEIGHT} m")

    # Make Model the active collection so new geometry lands in the right place.
    layer_root = bpy.context.view_layer.layer_collection
    for child in layer_root.children:
        if child.collection is model_col:
            bpy.context.view_layer.active_layer_collection = child

    OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT))
    print(f"SAVED={OUT}")


main()
