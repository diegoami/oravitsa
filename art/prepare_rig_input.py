"""Prepare a textured copy of the approved Tripo asset for fal/Meshy rigging."""
import hashlib
import json
import math
from pathlib import Path
import bpy
from mathutils import Matrix,Vector

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/"build/fal-tripo-trial/candidate.glb"
OUTPUT=ROOT/"build/fal-walk"
OUTPUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
meshes=[obj for obj in bpy.context.scene.objects if obj.type=="MESH"]
bpy.context.view_layer.update()
points=[obj.matrix_world@Vector(corner) for obj in meshes for corner in obj.bound_box]
low=Vector(tuple(min(p[i] for p in points) for i in range(3)))
high=Vector(tuple(max(p[i] for p in points) for i in range(3)))
before=sum(len(obj.data.polygons) for obj in meshes)
# The static eight-view review locates the reconstructed front at +X,+Y in
# Blender. Rotate it to Blender -Y, which the glTF exporter maps to glTF +Z.
normalization=Matrix.Rotation(math.radians(-135),4,"Z")@Matrix.Scale(1.5/(high.z-low.z),4)@Matrix.Translation(Vector((-(low.x+high.x)/2,-(low.y+high.y)/2,-low.z)))
bpy.ops.object.select_all(action="DESELECT")
for obj in meshes:
    transform=normalization@obj.matrix_world
    obj.parent=None
    obj.data.transform(transform)
    obj.matrix_world=Matrix.Identity(4)
    obj.select_set(True)
    bpy.context.view_layer.objects.active=obj
    modifier=obj.modifiers.new("RiggingBudget","DECIMATE")
    modifier.ratio=min(1,200000/before)
    modifier.use_collapse_triangulate=True
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)
after=sum(len(obj.data.polygons) for obj in meshes)
assert 0<after<=300000,after
for obj in meshes: obj.select_set(True)
target=OUTPUT/"rig-input.glb"
bpy.ops.export_scene.gltf(filepath=str(target),export_format="GLB",use_selection=True,export_apply=True,export_yup=True,export_materials="EXPORT")
report={"source":str(SOURCE),"source_sha256":hashlib.sha256(SOURCE.read_bytes()).hexdigest(),"output":str(target),"triangles_before":before,"triangles_after":after,"height_meters":1.5,"blender_heading_rotation_degrees":-135,"gltf_forward_axis":"+Z","textures":"Preserved from approved reconstruction; no regeneration or repainting","original_unchanged":True}
(OUTPUT/"preparation.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
print("RIG_INPUT_READY="+json.dumps(report))
