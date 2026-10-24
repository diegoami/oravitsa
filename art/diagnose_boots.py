"""Measure foot skinning and compare the actual bind geometry with posed geometry."""
import json,math
from pathlib import Path
import bpy
from mathutils import Matrix

ROOT=Path(__file__).resolve().parents[1]
OUTPUT=ROOT/"build/fal-walk"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUTPUT/"walking.glb"))
rig=next(obj for obj in bpy.context.scene.objects if obj.type=="ARMATURE")
obj=next(obj for obj in bpy.context.scene.objects if obj.type=="MESH" and obj.parent==rig)
report={"armature_world":[list(row) for row in rig.matrix_world],"rest_bones":{},"vertex_groups":[g.name for g in obj.vertex_groups],"modifiers":[{"name":m.name,"type":m.type,"preserve_volume":m.use_deform_preserve_volume if m.type=="ARMATURE" else None} for m in obj.modifiers]}
for name in ("Hips","LeftUpLeg","LeftLeg","LeftFoot","LeftToeBase","RightUpLeg","RightLeg","RightFoot","RightToeBase"):
    bone=rig.data.bones[name]
    report["rest_bones"][name]={"head":list(bone.head_local),"tail":list(bone.tail_local),"length":bone.length,"inherit_scale":bone.inherit_scale}
action=rig.animation_data.action
for track in rig.animation_data.nla_tracks:track.mute=True
rig.animation_data.action=None
for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.update()
report["bind_bounds"]=[list(point) for point in obj.bound_box]
rig.animation_data.action=action
frame=float(action.frame_range[0]+(action.frame_range[1]-action.frame_range[0])*.25)
bpy.context.scene.frame_set(math.floor(frame),subframe=frame-math.floor(frame))
report["contact_pose"]={bone.name:{"head":list(bone.head),"tail":list(bone.tail),"scale":list(bone.scale)} for bone in rig.pose.bones if "Foot" in bone.name or "Toe" in bone.name}
(OUTPUT/"boot-diagnosis.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
print(json.dumps(report,indent=2))
