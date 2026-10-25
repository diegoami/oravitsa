"""Measure the provided walk before rendering its loop."""
import json,math
from pathlib import Path
import bpy

ROOT=Path(__file__).resolve().parents[1]
OUTPUT=ROOT/"build/fal-walk"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUTPUT/"walking.glb"))
rig=next(obj for obj in bpy.context.scene.objects if obj.type=="ARMATURE")
for track in rig.animation_data.nla_tracks:track.mute=True
action=rig.animation_data.action or next(iter(bpy.data.actions))
rig.animation_data.action=action
start,end=map(float,action.frame_range)
samples=[]
for index in range(65):
    at=start+(end-start)*index/64
    bpy.context.scene.frame_set(math.floor(at),subframe=at-math.floor(at))
    samples.append({bone.name:list(rig.matrix_world@bone.head) for bone in rig.pose.bones})
hip_delta=[samples[-1]["Hips"][i]-samples[0]["Hips"][i] for i in range(3)]
errors={}
for name in samples[0]:
    delta=[samples[-1][name][i]-samples[0][name][i]-hip_delta[i] for i in range(3)]
    errors[name]=math.sqrt(sum(value*value for value in delta))
report={"action":action.name,"frame_range":[start,end],"seconds":(end-start)/bpy.context.scene.render.fps,"hips_travel":hip_delta,"loop_joint_error_after_root_travel":errors,"samples":samples}
(OUTPUT/"loop-analysis.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
print(json.dumps({key:value for key,value in report.items() if key!="samples"}))
