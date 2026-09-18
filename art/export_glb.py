"""Export a collection from art/oravitsa.blend to res://models/<name>.glb.

    blender --background art/oravitsa.blend --python art/export_glb.py -- Model

Godot imports the result directly. The settings below are the ones that
matter: +Y up (Blender is Z-up, Godot is Y-up), modifiers applied, and no
scaling applied on the way out -- the project is 1 unit = 1 metre on both
sides, so the numbers must pass through untouched.
"""
import sys
import bpy
from pathlib import Path

PROJECT = Path(bpy.data.filepath).resolve().parent.parent
DEFAULT_COLLECTION = "Model"


def argv_after_dashes():
    if "--" in sys.argv:
        return sys.argv[sys.argv.index("--") + 1:]
    return []


def main():
    args = argv_after_dashes()
    name = args[0] if args else DEFAULT_COLLECTION

    col = bpy.data.collections.get(name)
    if col is None:
        sys.exit(f"no collection named {name!r}")

    meshes = [o for o in col.all_objects if o.type == "MESH"]
    if not meshes:
        sys.exit(f"collection {name!r} has no meshes to export")

    out_dir = PROJECT / "models"
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / f"{name.lower()}.glb"

    # Export just this collection: select it and use the selection filter, so
    # the locked Reference geometry never leaks into a shipped model.
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.hide_select = False
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]

    bpy.ops.export_scene.gltf(
        filepath=str(out),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_materials="EXPORT",
    )
    print(f"EXPORTED={out}")
    print(f"MESHES={len(meshes)}")


main()
