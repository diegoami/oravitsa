"""Fit a separate, textured drape over the automatically skinned skirt."""
import bpy,math
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform


def create(rig,objects):
    body=next(o for o in objects if len(o.data.polygons)>1000)
    image=next(n.image for m in body.data.materials for n in m.node_tree.nodes if n.type=='TEX_IMAGE')
    pixels=np.asarray(image.pixels[:]).reshape(image.size[1],image.size[0],4)
    uv=body.data.uv_layers.active.data
    points=[body.matrix_world@v.co for v in body.data.vertices]
    faces=[];source_uv=[]
    for face in body.data.polygons:
        point=body.matrix_world@face.center
        if not (.44<point.z<.81 and abs(point.x)<.33 and -.30<point.y<.23):continue
        coords=[uv[i].uv.copy() for i in face.loop_indices]
        coord=sum(coords,Vector((0,0)))/len(coords)
        r,g,b=pixels[min(int(coord.y*image.size[1]),image.size[1]-1),min(int(coord.x*image.size[0]),image.size[0]-1),:3]
        if r<.36 and g<.36 and b<.27 and g>r*.85 and b<g*.9:
            faces.append(tuple(face.vertices));source_uv.append(coords)
    assert len(faces)>1000
    tree=BVHTree.FromPolygons(points,faces,all_triangles=True)
    around=96;rows=21;vertices=[];colors=[]
    for j in range(rows):
        t=j/(rows-1)
        rx=.13+.175*t;ry=.095+.15*t
        for i in range(around):
            angle=2*math.pi*i/around
            # The tunic hangs lower in front. Tuck the added cloth beneath it
            # instead of letting a high circular waist cover the white fabric.
            top=.725-.035*math.cos(angle)
            z=top*(1-t)+.49*t
            point=Vector((-.016+rx*math.sin(angle),-.025-ry*math.cos(angle),z))
            hit,normal,index,distance=tree.find_nearest(point)
            point.x+=max(-.012,min(.012,(hit.x-point.x)*.4))
            point.y+=max(-.012,min(.012,(hit.y-point.y)*.4))
            vertices.append(point)
            a,b,c=[points[v] for v in faces[index]]
            tex=barycentric_transform(hit,a,b,c,*[Vector((v.x,v.y,0)) for v in source_uv[index]])
            x=max(0,min(image.size[0]-1,int(tex.x*image.size[0])));y=max(0,min(image.size[1]-1,int(tex.y*image.size[1])))
            colors.append(pixels[y,x].copy())
    mesh=bpy.data.meshes.new('SkirtDrape')
    quads=[(j*around+i,j*around+(i+1)%around,(j+1)*around+(i+1)%around,(j+1)*around+i) for j in range(rows-1) for i in range(around)]
    mesh.from_pydata(vertices,[],quads);mesh.update()
    texture=bpy.data.images.new('OriginalSkirtResampled',width=around,height=rows,alpha=True)
    texture.pixels=np.array(colors).reshape(-1).tolist();texture.pack()
    material=bpy.data.materials.new('OriginalSkirtDrape');material.use_nodes=True
    nodes=material.node_tree.nodes;image_node=nodes.new('ShaderNodeTexImage');image_node.image=texture
    material.node_tree.links.new(image_node.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color'])
    mesh.materials.append(material)
    layer=mesh.uv_layers.new()
    for face in mesh.polygons:
        face.use_smooth=True
        for li,vi in zip(face.loop_indices,face.vertices):
            j,i=divmod(vi,around)
            if face.index%around==around-1 and i==0:i=around
            layer.data[li].uv=((i+.5)/around,(j+.5)/rows)
    obj=bpy.data.objects.new('SkirtDrape',mesh);bpy.context.scene.collection.objects.link(obj)
    obj.shape_key_add(name='Basis')
    rest=rig.matrix_world@rig.data.bones['Hips'].matrix_local
    state={'rig':rig,'object':obj,'rest_inverse':rest.inverted(),'vertices':[v.copy() for v in vertices],'around':around,'rows':rows}
    return obj,{'method':'Separate fitted skirt surface, sampled original painted texture, pelvis support and thigh clearance','source_faces':len(faces),'vertices':len(vertices)},state


def update(state,keyframe=None):
    rig=state['rig'];obj=state['object']
    transform=(rig.matrix_world@rig.pose.bones['Hips'].matrix)@state['rest_inverse']
    inverse=transform.inverted();obj.matrix_world=transform
    legs=[]
    for side in ('Left','Right'):
        legs.append((inverse@(rig.matrix_world@rig.pose.bones[side+'UpLeg'].head),inverse@(rig.matrix_world@rig.pose.bones[side+'Leg'].head)))
    coords=[]
    for point in state['vertices']:
        p=point.copy()
        origin=Vector((-.016,-.025,p.z))
        radial=p-origin;radius_at_point=radial.length;direction=radial.normalized()
        for a,b in legs:
            t=max(0,min(1.1,(p.z-a.z)/(b.z-a.z))) if abs(b.z-a.z)>.001 else 0
            center=a+(b-a)*t
            offset=Vector((center.x-origin.x,center.y-origin.y,0))
            along=offset.dot(direction)
            perpendicular_squared=max(0,offset.length_squared-along*along)
            radius=.115
            if perpendicular_squared<radius*radius and b.z-.06<p.z<a.z-.02:
                outside=along+math.sqrt(radius*radius-perpendicular_squared)
                radius_at_point=max(radius_at_point,outside)
        p=origin+direction*radius_at_point
        coords.append(p)
    if keyframe is None:
        if len(obj.data.shape_keys.key_blocks)==1:
            for v,p in zip(obj.data.shape_keys.key_blocks['Basis'].data,coords):v.co=p
    else:
        for v,p in zip(obj.data.shape_keys.key_blocks['Basis'].data,state['vertices']):v.co=p
        key=obj.shape_key_add(name='Drape_%03d'%len(obj.data.shape_keys.key_blocks))
        for v,p in zip(key.data,coords):v.co=p
        start,end=rig.animation_data.action.frame_range
        spacing=(end-start)/64
        for at,value in ((keyframe-spacing,0),(keyframe,1),(keyframe+spacing,0)):
            key.value=value;key.keyframe_insert('value',frame=at)
        action=obj.data.shape_keys.animation_data.action
        for slot in action.slots:
            for layer in action.layers:
                for strip in layer.strips:
                    bag=strip.channelbag(slot)
                    if bag:
                        for curve in bag.fcurves:
                            for point in curve.keyframe_points:point.interpolation='LINEAR'
        for channel in ('location','rotation_euler','scale'):obj.keyframe_insert(channel,frame=keyframe)
    bpy.context.view_layer.update()
