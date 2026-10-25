"""Check the baked garment for holes, height loss, jumps, and loop mismatch."""
import bpy,json,math
import numpy as np
from pathlib import Path

rig=bpy.data.objects['Armature'];skirt=bpy.data.objects['SkirtDrape']
start,end=map(float,rig.animation_data.action.frame_range)
edges=[tuple(edge.vertices) for edge in skirt.data.edges]
usage={edge:0 for edge in (tuple(sorted(pair)) for pair in edges)}
for face in skirt.data.polygons:
    for i,a in enumerate(face.vertices):
        b=face.vertices[(i+1)%len(face.vertices)]
        usage[tuple(sorted((a,b)))]+=1
assert all(value in (1,2) for value in usage.values())
assert sum(value==1 for value in usage.values())==192,'Only the waist and hem may be open'
previous=None;first=None;max_step=0.;max_edge=0.;max_height_loss=0.;first_height=None
for step in range(65):
    at=start+(end-start)*step/64
    bpy.context.scene.frame_set(math.floor(at),subframe=at-math.floor(at))
    posed=skirt.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=posed.to_mesh()
    coords=np.array([v.co[:] for v in mesh.vertices])
    height=coords[:96,2].mean()-coords[-96:,2].mean()
    if first_height is None:first_height=height
    assert height>.20,height
    max_height_loss=max(max_height_loss,abs(height-first_height))
    if previous is not None:max_step=max(max_step,float(np.linalg.norm(coords-previous,axis=1).max()))
    max_edge=max(max_edge,max(float(np.linalg.norm(coords[a]-coords[b])) for a,b in edges))
    if step==0:first=coords.copy()
    previous=coords;posed.to_mesh_clear()
loop_error=float(np.linalg.norm(coords-first,axis=1).max())
assert loop_error<.001,loop_error
assert max_height_loss<.001,max_height_loss
assert max_step<.06,max_step
assert max_edge<.12,max_edge
report={'poses_checked':65,'boundary_edges_waist_and_hem_only':192,'maximum_height_error_m':max_height_loss,'maximum_local_vertex_step_m':max_step,'maximum_mesh_edge_m':max_edge,'loop_error_m':loop_error}
(Path(bpy.data.filepath).parent/'skirt-validation.json').write_text(json.dumps(report,indent=2))
print('SKIRT_DRAPE_VALIDATED='+json.dumps(report))
