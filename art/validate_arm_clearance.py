"""Check the baked arm loop and actual hand clearance at the reported poses."""
import bpy,json,math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

root=Path(bpy.data.filepath).parent
manifest=json.loads((root/'manifest.json').read_text())
rig=bpy.data.objects['Armature'];action=rig.animation_data.action
source=bpy.data.actions[manifest['arm_clearance']['source_action_retained']]
start,end=map(float,action.frame_range)
body=next(o for o in bpy.context.scene.objects if o.type=='MESH' and o.parent==rig)
hand_group=body.vertex_groups['LeftHand'].index
indices=[v.index for v in body.data.vertices if any(g.group==hand_group and g.weight>.5 for g in v.groups)]
assert len(indices)>50
skirt=bpy.data.objects['SkirtDrape']
first={};maximum_loop_error=0.;minimum_outward_shift=1.;clearance=[]
for step in range(65):
    at=start+(end-start)*step/64
    def sample(current):
        rig.animation_data.action=current
        bpy.context.scene.frame_set(math.floor(at),subframe=at-math.floor(at))
        return {name:(rig.matrix_world@rig.pose.bones[name].head).copy() for name in ('LeftArm','LeftForeArm','LeftHand')}
    before=sample(source);after=sample(action)
    for a,b in (('LeftArm','LeftForeArm'),('LeftForeArm','LeftHand')):
        assert abs((after[a]-after[b]).length-(before[a]-before[b]).length)<.00001
    minimum_outward_shift=min(minimum_outward_shift,after['LeftHand'].x-before['LeftHand'].x)
    if step==0:first=after
    if step==64:maximum_loop_error=max((after[n]-first[n]).length for n in first)
    if step in (16,24):
        graph=bpy.context.evaluated_depsgraph_get()
        cloth=skirt.evaluated_get(graph);cm=cloth.to_mesh()
        tree=BVHTree.FromPolygons([v.co for v in cm.vertices],[list(f.vertices) for f in cm.polygons])
        posed=body.evaluated_get(graph);mesh=posed.to_mesh();inverse=cloth.matrix_world.inverted()
        penetrations=0;minimum=1.;rays=0
        for index in indices:
            p=inverse@(posed.matrix_world@mesh.vertices[index].co)
            origin=Vector((-.016,-.025,p.z));radial=p-origin
            if radial.length<.0001:continue
            hit,normal,face,distance=tree.ray_cast(origin,radial.normalized())
            if hit is None:continue
            rays+=1;gap=radial.length-distance;minimum=min(minimum,gap)
            if gap<-.003:penetrations+=1
        clearance.append({'pose':1 if step==16 else 2,'hand_vertices_checked':len(indices),'rays_intersecting_garment':rays,'penetrating_vertices':penetrations,'minimum_radial_clearance_m':minimum})
        posed.to_mesh_clear();cloth.to_mesh_clear()
assert maximum_loop_error<.001,maximum_loop_error
assert minimum_outward_shift>0,minimum_outward_shift
assert all(row['penetrating_vertices']==0 for row in clearance),clearance
report={'poses_checked':65,'arm_segment_lengths_preserved':True,'loop_error_m':maximum_loop_error,'minimum_outward_wrist_shift_m':minimum_outward_shift,'reported_pose_clearance':clearance}
(root/'arm-validation.json').write_text(json.dumps(report,indent=2))
print('ARM_CLEARANCE_VALIDATED='+json.dumps(report))
