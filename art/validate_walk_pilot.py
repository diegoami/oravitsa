"""Validate the baked Blender walk: joints, floor, planted feet and closure."""
import json
from pathlib import Path
import bpy

output=Path(bpy.data.filepath).parent
scene=bpy.context.scene
rig=bpy.data.objects["OravitsaWalkRig"]
max_joint=0.0
min_floor=1.0
support_floor_error=0.0
planted={"R":[],"L":[]}
snapshots={}
for frame in range(1,50):
    scene.frame_set(frame)
    phase=(frame-1)/48
    deps=bpy.context.evaluated_depsgraph_get()
    for side,delta in (("R",0),("L",.5)):
        for child,parent in (("shin_","thigh_"),("foot_","shin_"),("forearm_","upperarm_")):
            max_joint=max(max_joint,(rig.pose.bones[child+side].head-rig.pose.bones[parent+side].tail).length)
        p=(phase+delta)%1
        boot=bpy.data.objects["Boot_"+side].evaluated_get(deps)
        mesh=boot.to_mesh()
        floor=min((boot.matrix_world@v.co).z for v in mesh.vertices)
        boot.to_mesh_clear()
        min_floor=min(min_floor,floor)
        if p<.6: support_floor_error=max(support_floor_error,abs(floor))
        # Only compare one uninterrupted stance segment per foot.
        if p<.6 and (side=="R" and phase<.6 or side=="L" and .5<=phase<1):
            foot=rig.pose.bones["foot_"+side].head.copy()
            foot.y+=(.34/.6)*phase
            planted[side].append(foot)
    if frame in (1,49):
        snapshots[frame]=[]
        for name in ("Skirt","Boot_R","Boot_L","Head","BandanaTail_R"):
            obj=bpy.data.objects[name].evaluated_get(deps)
            mesh=obj.to_mesh()
            snapshots[frame].extend(obj.matrix_world@v.co for v in mesh.vertices)
            obj.to_mesh_clear()
closure=max((a-b).length for a,b in zip(snapshots[1],snapshots[49]))
slip=max(max((p-points[0]).length for p in points) for points in planted.values())
report={"frames_checked":49,"max_joint_gap_m":max_joint,"minimum_boot_height_m":min_floor,"support_floor_error_m":support_floor_error,"planted_foot_slip_m":slip,"loop_vertex_error_m":closure}
assert max_joint<1e-5,report
assert min_floor>-.0001,report
assert support_floor_error<1e-5,report
assert slip<1e-5,report
assert closure<1e-5,report
(output/"validation.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
print("WALK_VALIDATED="+json.dumps(report))
