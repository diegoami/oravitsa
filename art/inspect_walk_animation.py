"""Inspect the imported rig and its animation ranges before choosing samples."""
import json
from pathlib import Path
import bpy

ROOT=Path(__file__).resolve().parents[1]
OUTPUT=ROOT/"build/fal-walk"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUTPUT/"walking.glb"))
report={"fps":bpy.context.scene.render.fps,"actions":[],"armatures":[],"objects":[]}
for action in bpy.data.actions:
    report["actions"].append({"name":action.name,"range":list(action.frame_range)})
for obj in bpy.context.scene.objects:
    if obj.type=="ARMATURE":
        report["armatures"].append({"name":obj.name,"bones":[bone.name for bone in obj.data.bones],"active_action":obj.animation_data.action.name if obj.animation_data and obj.animation_data.action else None,"nla":[{"name":track.name,"strips":[{"name":strip.name,"action":strip.action.name,"range":[strip.frame_start,strip.frame_end]} for strip in track.strips]} for track in obj.animation_data.nla_tracks] if obj.animation_data else []})
    report["objects"].append({"name":obj.name,"type":obj.type,"parent":obj.parent.name if obj.parent else None,"polygons":len(obj.data.polygons) if obj.type=="MESH" else None})
(OUTPUT/"animation-inspection.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
print(json.dumps(report))
