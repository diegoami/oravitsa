"""Build a matched, rigid pair from the intact right boot; keep original UVs."""
import bpy,bmesh,math
from mathutils import Matrix,Vector


def cut(mesh,plane_point,plane_normal,keep):
    bm=bmesh.new();bm.from_mesh(mesh)
    bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=plane_point,plane_no=plane_normal,clear_inner=False,clear_outer=False)
    remove=[face for face in bm.faces if not keep(face.calc_center_median())]
    if remove:bmesh.ops.delete(bm,geom=remove,context="FACES")
    loose=[vertex for vertex in bm.verts if not vertex.link_faces]
    if loose:bmesh.ops.delete(bm,geom=loose,context="VERTS")
    bm.to_mesh(mesh);bm.free();mesh.update()


def create(rig,objects):
    source=next(obj for obj in objects if len(obj.data.polygons)>1000)
    right=rig.matrix_world@rig.data.bones["RightFoot"].matrix_local
    left=rig.matrix_world@rig.data.bones["LeftFoot"].matrix_local
    world=source.matrix_world.copy()
    inverse=world.inverted()
    ankle=right.translation
    extraction_height=ankle.z+.13
    body_height=ankle.z+.09
    middle=(right.translation.x+left.translation.x)/2
    normal=world.to_3x3().transposed()@Vector((0,0,1))
    template=source.data.copy()
    cut(template,inverse@Vector((0,0,extraction_height)),normal,
        lambda point:(world@point).z<=extraction_height+.00001 and (world@point).x<middle)
    bm=bmesh.new();bm.from_mesh(template)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.0001)
    pending=set(bm.verts);components=[]
    while pending:
        seed=pending.pop();component={seed};queue=[seed]
        while queue:
            for edge in queue.pop().link_edges:
                for neighbor in edge.verts:
                    if neighbor in pending:pending.remove(neighbor);component.add(neighbor);queue.append(neighbor)
        components.append(component)
    largest=max(components,key=len)
    remove=[vertex for vertex in bm.verts if vertex not in largest]
    if remove:bmesh.ops.delete(bm,geom=remove,context="VERTS")
    bm.to_mesh(template);bm.free();template.update()
    assert len(template.polygons)>100,"Failed to isolate an intact boot"
    # Remove the original pair below a collar plane; the replacement overlaps
    # the retained sock slightly to avoid a gap at the ankle.
    cut(source.data,inverse@Vector((0,0,body_height)),normal,
        lambda point:(world@point).z>=body_height-.00001)
    # Track the actual cut sock rings through the existing deformation. This
    # avoids depending on the generated foot bone's inconsistent bind roll.
    rings={"Left":[],"Right":[]}
    for vertex in source.data.vertices:
        point=world@vertex.co
        if abs(point.z-body_height)<.00005:
            rings["Right" if point.x<middle else "Left"].append(vertex.index)
    assert all(len(indices)>3 for indices in rings.values()),rings
    collar_points=[world@vertex.co for vertex in template.vertices if abs((world@vertex.co).z-extraction_height)<.00005]
    assert len(collar_points)>3
    collar=sum(collar_points,Vector())/len(collar_points)
    new=[]
    for side,mirror in (("Right",False),("Left",True)):
        mesh=template.copy()
        reflection=Matrix.Diagonal(Vector((-1,1,1,1))) if mirror else Matrix.Identity(4)
        transform=reflection@Matrix.Translation(-collar)@world
        mesh.transform(transform)
        bm=bmesh.new();bm.from_mesh(mesh)
        deform=bm.verts.layers.deform.active
        if deform:
            for vertex in bm.verts:vertex[deform].clear()
        if mirror:bmesh.ops.reverse_faces(bm,faces=list(bm.faces))
        bm.to_mesh(mesh);bm.free()
        obj=bpy.data.objects.new("MatchedBoot_"+side,mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.vertex_groups.clear()
        for face in mesh.polygons:face.use_smooth=True
        new.append(obj)
    toe=rig.matrix_world@rig.data.bones["RightToeBase"].head_local
    vector=toe-right.translation
    rest_pitch=math.atan2(vector.z,math.hypot(vector.x,vector.y))
    state={"rig":rig,"body":source,"rings":rings,"boots":dict(zip(("Right","Left"),new)),"rest_scale":rig.matrix_world.to_scale().x,"rest_pitch":rest_pitch,"overlap":extraction_height-body_height}
    return new,{"method":"Matched intact boot geometry, mirrored anatomically, following actual sock collars; baked rigid transforms","heading":"Forward hemisphere, limited to 15 degrees; yaw fades near vertical toe-down poses to avoid projection flips","boot_triangles":len(template.polygons),"collar_overlap_m":extraction_height-body_height,"face_and_costume_unchanged":True,"original_source_files_unchanged":True,"textures":"Original boot UVs/material, shared by both shoes"},state


def update(state,keyframe=None):
    rig=state["rig"];body=state["body"]
    scale=rig.matrix_world.to_scale().x/state["rest_scale"]
    posed=body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh=posed.to_mesh()
    for side,obj in state["boots"].items():
        indices=state["rings"][side]
        center=sum((posed.matrix_world@mesh.vertices[index].co for index in indices),Vector())/len(indices)
        ankle=rig.matrix_world@rig.pose.bones[side+"Foot"].head
        knee=rig.matrix_world@rig.pose.bones[side+"Leg"].head
        toe=rig.matrix_world@rig.pose.bones[side+"ToeBase"].head
        vector=toe-ankle
        # A toe-down swing passes through vertical. Its horizontal projection
        # then reverses, but this is ankle flexion, not a half-turn of the shoe.
        # Keep the projection in the walking-forward hemisphere, and fade its
        # unreliable yaw near vertical so a tiny sideways offset cannot spin it.
        heading=vector.copy()
        if heading.y>0:heading=-heading
        horizontal=math.hypot(heading.x,heading.y)
        confidence=min(1.0,horizontal/max(vector.length*.35,1e-8))
        yaw=max(math.radians(-15),min(math.radians(15),math.atan2(heading.x,-heading.y)))*confidence
        pitch=math.atan2(vector.z,math.hypot(vector.x,vector.y))-state["rest_pitch"]
        pitch=max(math.radians(-20),min(math.radians(35),pitch))
        rotation=Matrix.Rotation(yaw,4,"Z")@Matrix.Rotation(-pitch,4,"X")
        anchor=center+(knee-ankle).normalized()*state["overlap"]*scale
        obj.rotation_mode="QUATERNION"
        obj.matrix_world=Matrix.Translation(anchor)@rotation@Matrix.Scale(scale,4)
        if keyframe is not None:
            for channel in ("location","rotation_quaternion","scale"):obj.keyframe_insert(channel,frame=keyframe)
    posed.to_mesh_clear()
    bpy.context.view_layer.update()
