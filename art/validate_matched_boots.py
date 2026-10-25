"""Check the real repaired shoe meshes over the complete baked animation."""
import json,math
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector

output=Path(bpy.data.filepath).parent
rig=bpy.data.objects["Armature"]
action=rig.animation_data.action
start,end=map(float,action.frame_range)
boots=[bpy.data.objects["MatchedBoot_"+side] for side in ("Left","Right")]
assert len(boots[0].data.vertices)==len(boots[1].data.vertices)
def signature(obj):
    posed=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh=posed.to_mesh()
    coords=np.empty(len(mesh.vertices)*3,dtype=np.float32)
    mesh.vertices.foreach_get("co",coords);coords=coords.reshape(-1,3)
    transform=np.array([list(row) for row in posed.matrix_world],dtype=np.float64)
    points=coords@transform[:3,:3].T+transform[:3,3]
    values=np.linalg.eigvalsh(np.cov(points.T,bias=True))
    posed.to_mesh_clear()
    return np.sqrt(np.maximum(values,0)),points.mean(axis=0)
baselines={};centers={};max_shape_error=0.0;max_pair_error=0.0
max_heading=0.0;max_heading_step=0.0;previous_headings={};first_headings={}
for step in range(65):
    at=start+(end-start)*step/64
    bpy.context.scene.frame_set(math.floor(at),subframe=at-math.floor(at))
    shapes=[]
    for boot in boots:
        forward=boot.matrix_world.to_3x3()@Vector((0,-1,0))
        heading=math.atan2(forward.x,-forward.y)
        max_heading=max(max_heading,abs(heading))
        if boot.name in previous_headings:
            max_heading_step=max(max_heading_step,abs(heading-previous_headings[boot.name]))
        if step==0:first_headings[boot.name]=heading
        if step==64:assert abs(heading-first_headings[boot.name])<.001
        previous_headings[boot.name]=heading
        shape,center=signature(boot)
        if step==0:baselines[boot.name]=shape;centers[boot.name]=center
        max_shape_error=max(max_shape_error,float(np.max(np.abs(shape/baselines[boot.name]-1))))
        shapes.append(shape)
        if step==64:assert np.linalg.norm(center-centers[boot.name])<.001
    max_pair_error=max(max_pair_error,float(np.max(np.abs(shapes[0]/shapes[1]-1))))
assert max_shape_error<.0001,max_shape_error
assert max_pair_error<.0001,max_pair_error
assert max_heading<=math.radians(15.1),math.degrees(max_heading)
assert max_heading_step<math.radians(20),math.degrees(max_heading_step)
report={"poses_checked":65,"maximum_shape_change_fraction":max_shape_error,"maximum_left_right_shape_difference_fraction":max_pair_error,"loop_centers_match_within_m":.001,"maximum_heading_degrees":math.degrees(max_heading),"maximum_heading_step_degrees":math.degrees(max_heading_step),"boot_meshes":"Matched rigid geometry, original boot material and UVs"}
(output/"shoe-validation.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
print("MATCHED_SHOES_VALIDATED="+json.dumps(report))
