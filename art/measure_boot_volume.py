"""Compare rotation-invariant shoe volume across the complete source walk."""
import json,math,runpy
from pathlib import Path
import bpy
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
OUTPUT=ROOT/"build/fal-walk/foot-diagnosis"
OUTPUT.mkdir(parents=True,exist_ok=True)
def volume(points):
    covariance=np.cov(points.T,bias=True)
    return float(np.sqrt(max(0,np.linalg.det(covariance))))
results=[]
for mode in ("none","toe","volume","both"):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/"build/fal-walk/walking.glb"))
    rig=next(obj for obj in bpy.context.scene.objects if obj.type=="ARMATURE")
    obj=next(obj for obj in bpy.context.scene.objects if obj.type=="MESH" and obj.parent==rig)
    for track in rig.animation_data.nla_tracks:track.mute=True
    action=rig.animation_data.action
    regions={};baseline={}
    for side in ("Left","Right"):
        groups={obj.vertex_groups[side+suffix].index for suffix in ("Foot","ToeBase")}
        center=rig.matrix_world@rig.data.bones[side+"Foot"].head_local
        selected=[v.index for v in obj.data.vertices if sum(g.weight for g in v.groups if g.group in groups)>.75 and (obj.matrix_world@v.co-center).length<.25]
        assert len(selected)>50,(side,len(selected))
        regions[side]=selected
        baseline[side]=volume(np.array([obj.data.vertices[i].co[:] for i in selected]))
    fixes=runpy.run_path(str(ROOT/"art/foot_skinning.py"))["correct"]([obj],mode)
    ratios={side:[] for side in regions}
    for index in range(32):
        start,end=action.frame_range
        at=start+(end-start)*index/32
        bpy.context.scene.frame_set(math.floor(at),subframe=at-math.floor(at))
        posed=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh=posed.to_mesh()
        data=np.empty(len(mesh.vertices)*3,dtype=np.float32)
        mesh.vertices.foreach_get("co",data);data=data.reshape(-1,3)
        for side,selected in regions.items():ratios[side].append(volume(data[selected])/baseline[side])
        posed.to_mesh_clear()
    result={"mode":mode,"regions":{side:len(indices) for side,indices in regions.items()},"relative_shoe_volume":{side:{"minimum":min(values),"maximum":max(values),"samples":values} for side,values in ratios.items()},"fixes":fixes}
    results.append(result)
    print(json.dumps({"mode":mode,"range":{side:[min(values),max(values)] for side,values in ratios.items()}}),flush=True)
(OUTPUT/"comparison.json").write_text(json.dumps(results,indent=2),encoding="utf-8")
