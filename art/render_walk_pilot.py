"""Build, rig and render a southeast walk without manual authoring.

blender --background --factory-startup --python art/render_walk_pilot.py -- --still
Omit --still for eight transparent frames. Original .blend/.glb files are untouched.
"""
import argparse
import ast
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT = Path(__file__).resolve().parents[1]
TAU = math.tau
REST = {}
ENDS = {}
RIG = None
SKIRT_KEYS = None


def source_builder():
    source = ROOT / "art/build_oravitsa.py"
    tree = ast.parse(source.read_text(encoding="utf-8"))
    # Reuse the geometry functions, without the source script's save/main call.
    tree.body = [n for n in tree.body if not (
        isinstance(n, ast.Expr) and isinstance(n.value, ast.Call)
        and isinstance(n.value.func, ast.Name) and n.value.func.id == "main")]
    namespace = {"__file__": str(source), "__name__": "pilot_mesh"}
    exec(compile(tree, str(source), "exec"), namespace)
    namespace["PALETTE"]["hair"] = (0.769, 0.675, 0.592)
    namespace["PALETTE"]["leather"] = (0.29, 0.18, 0.12)
    collection = bpy.data.collections.new("Oravitsa")
    bpy.context.scene.collection.children.link(collection)
    for part in ("tunic", "skirt", "belt", "head", "hair", "bandana", "arms", "legs", "basket"):
        namespace["build_" + part](collection)
    # Give the long skirt room for the forward knee, rather than letting it
    # protrude through a narrow static cone during the contact poses.
    for vertex in bpy.data.objects["Skirt"].data.vertices:
        flare=max(0,min(1,(.85-vertex.co.z)/.35))
        vertex.co.x*=1+.35*flare
        vertex.co.y*=1+.95*flare
        vertex.co.z+=.07*max(0,min(1,(.82-vertex.co.z)/.54))
    skirt_mesh=bpy.data.objects["Skirt"].data
    bm=namespace["bmesh"].new();bm.from_mesh(skirt_mesh)
    namespace["bmesh"].ops.subdivide_edges(bm,edges=list(bm.edges),cuts=2,use_grid_fill=True)
    bm.to_mesh(skirt_mesh);bm.free()
    for name in ("Eye_R", "Eye_L"):
        bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)
    return namespace, collection


def sphere(name, at, scale, material, collection):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, location=at)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    collection.objects.link(obj)
    obj.data.materials.append(material)
    for face in obj.data.polygons:
        face.use_smooth = True
    return obj


def material(name, color):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*color, 1)
    result.use_nodes = True
    node = result.node_tree.nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value = (*color, 1)
    node.inputs["Roughness"].default_value = 0.8
    return result


def details(builder, collection):
    white = material("Pilot_eye_white", (0.86, 0.83, 0.75))
    dark = material("Pilot_pupil", (0.015, 0.025, 0.035))
    for side, sign in (("R", 1), ("L", -1)):
        for kind, at, scale, mat in (
            ("White", (sign*.04, .130, 1.309), (.025, .010, .022), white),
            ("Iris", (sign*.04, .140, 1.309), (.014, .005, .016), builder["material"]("eye")),
            ("Pupil", (sign*.04, .145, 1.309), (.006, .003, .010), dark),
            ("Glint", (sign*.04-.004, .148, 1.316), (.004, .002, .004), white),
        ):
            sphere("Face_"+kind+"_"+side, at, scale, mat, collection)
        sphere("Hand_"+side, (sign*.18, 0, .690), (.027, .025, .038), builder["material"]("skin"), collection)
    sphere("Face_Nose", (0, .122, 1.280), (.013, .019, .014), builder["material"]("skin"), collection)
    smile=material("Pilot_smile", (.20,.08,.06))
    for i in range(5):
        x=(i-2)*.007
        sphere("Face_Smile_%d" % i,(x,.106,1.251+.003*abs(i-2)),(.004,.003,.002),smile,collection)
    # Replace the solid yellow headband with a blue band carrying gold motifs.
    bpy.data.objects["BandanaBand"].data.materials[0] = builder["material"]("blue")
    for i in range(14):
        angle = TAU*i/14
        sphere("HeadFlower_%02d" % i,
               (.115*math.cos(angle), .133*math.sin(angle), 1.361),
               (.006, .006, .008), builder["material"]("yellow"), collection)
    for i in range(7):
        a = TAU*i/7
        center = Vector((.07*math.cos(a), -.175+.045*math.sin(a), 1.204+.012*(i%2)))
        for petal in range(5):
            p = center+Vector((math.cos(petal*TAU/5)*.011, math.sin(petal*TAU/5)*.011, 0))
            sphere("Flower_%d_%d" % (i, petal), p, (.008, .008, .004), white, collection)
        sphere("FlowerCenter_%d" % i, center+Vector((0,0,.003)), (.005,.005,.005), builder["material"]("yellow"), collection)
    # Curved vest panels follow the tunic; cream remains visible in the middle.
    for side in (-1, 1):
        vertices, faces = [], []
        rows = [(.943,.145,.104), (1.02,.153,.105), (1.10,.165,.113), (1.145,.176,.117)]
        for z, rx, ry in rows:
            for i in range(7):
                angle = .18+(1.30-.18)*i/6
                vertices.append((side*rx*math.cos(angle), ry*math.sin(angle), z))
        for row in range(3):
            for i in range(6):
                a=row*7+i
                faces.append((a,a+1,a+8,a+7))
        mesh=bpy.data.meshes.new("Vest")
        mesh.from_pydata(vertices, [], faces)
        mesh.materials.append(builder["material"]("leather"))
        obj=bpy.data.objects.new("Vest_%s" % side, mesh)
        collection.objects.link(obj)
        solid=obj.modifiers.new("Thickness", "SOLIDIFY")
        solid.thickness=.004


def make_rig(collection):
    global RIG
    arm=bpy.data.armatures.new("OravitsaWalkSkeleton")
    RIG=bpy.data.objects.new("OravitsaWalkRig",arm)
    collection.objects.link(RIG)
    bpy.context.view_layer.objects.active=RIG
    RIG.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    def bone(name, head, tail, parent=None):
        result=arm.edit_bones.new(name)
        result.head=head; result.tail=tail
        if parent: result.parent=arm.edit_bones[parent]
        ENDS[name]=(Vector(head),Vector(tail))
    bone("root",(0,0,0),(0,0,.2))
    bone("pelvis",(0,0,.84),(0,0,.96),"root")
    bone("spine",(0,0,.94),(0,0,1.14),"pelvis")
    bone("head",(0,0,1.14),(0,0,1.50),"spine")
    bone("basket",(0,-.17,.95),(0,-.17,1.17),"spine")
    for side, sign in (("R",1),("L",-1)):
        x=sign*.066
        bone("thigh_"+side,(x,0,.84),(x,0,.46),"pelvis")
        bone("shin_"+side,(x,0,.46),(x,0,.12),"thigh_"+side)
        bone("foot_"+side,(x,0,.12),(x,.18,.12),"shin_"+side)
        bone("upperarm_"+side,(sign*.15,0,1.14),(sign*.17,0,.955),"spine")
        bone("forearm_"+side,(sign*.17,0,.955),(sign*.18,0,.68),"upperarm_"+side)
        bone("tail_"+side,(sign*.052,-.132,1.352),(sign*.162,-.194,1.14),"head")
        bone("braid_"+side,(sign*.092,.05,1.245),(sign*.107,.08,.965),"head")
    bpy.ops.object.mode_set(mode="OBJECT")
    for bone in arm.bones:
        REST[bone.name]=bone.matrix_local.copy()
    for obj in list(collection.objects):
        if obj.type != "MESH": continue
        obj.data.transform(obj.matrix_world)
        obj.matrix_world=Matrix.Identity(4)
        name=obj.name
        side=name[-1] if name.endswith(("_R","_L")) else None
        if name.startswith("Boot_"): group="foot_"+side
        elif name.startswith("Sock_"): group="shin_"+side
        elif name.startswith("Sleeve_"): group="upperarm_"+side
        elif name.startswith(("Forearm_","Hand_")): group="forearm_"+side
        elif name.startswith("BandanaTail_"): group="tail_"+side
        elif name.startswith(("Braid_","Bead_")): group="braid_"+side
        elif name.startswith(("Basket","Greens_","Flower")): group="basket"
        elif name.startswith(("Head","Hair","Bandana","Eye_","Face_")): group="head"
        elif name.startswith(("Belt","Buckle","Pouch","Skirt")): group="pelvis"
        else: group="spine"
        vg=obj.vertex_groups.new(name=group)
        vg.add(list(range(len(obj.data.vertices))),1.0,"REPLACE")
        modifier=obj.modifiers.new("WalkSkeleton","ARMATURE")
        modifier.object=RIG
    return RIG


def transform_bone(name, head, rotation):
    return Matrix.Translation(head) @ rotation.to_matrix().to_4x4() @ REST[name].to_3x3().to_4x4()


def aim(name, head, tail):
    start,end=ENDS[name]
    return transform_bone(name,head,(end-start).rotation_difference(tail-head))


def evaluate(phase, keyframe=None):
    phase=phase%1.0
    offset=Vector((.004*math.sin(TAU*phase),0,-.032-.008*math.sin(2*TAU*phase)))
    desired={"root":Matrix.Translation(offset)@REST["root"]}
    pelvis_q=Quaternion((0,0,1),.025*math.sin(TAU*phase))
    desired["pelvis"]=transform_bone("pelvis",ENDS["pelvis"][0]+offset,pelvis_q)
    torso_q=Quaternion((0,0,1),-.035*math.sin(TAU*phase))
    desired["spine"]=transform_bone("spine",ENDS["spine"][0]+offset,torso_q)
    desired["head"]=transform_bone("head",ENDS["head"][0]+offset,Quaternion((0,0,1),-.012*math.sin(TAU*phase)))
    desired["basket"]=transform_bone("basket",ENDS["basket"][0]+offset,Quaternion((1,0,0),.025*math.sin(2*TAU*phase-.4)))
    trace={}
    for side,delta in (("R",0),("L",.5)):
        p=(phase+delta)%1
        if p<.6:
            travel=.17-.34*p/.6
            lift=0.0
        else:
            t=(p-.6)/.4
            travel=-.17+.34*(t*t*(3-2*t))
            lift=.095*math.sin(math.pi*t)
        hip=ENDS["thigh_"+side][0]+offset
        ankle=Vector((ENDS["foot_"+side][0].x,travel,.12+lift))
        axis=(ankle-hip).normalized()
        distance=(ankle-hip).length
        assert .04<distance<.72, ("unreachable foot",side,p,distance)
        along=(.38**2-.34**2+distance**2)/(2*distance)
        bend=Vector((0,1,0))-axis*axis.y
        knee=hip+axis*along+bend.normalized()*math.sqrt(max(0,.38**2-along**2))
        desired["thigh_"+side]=aim("thigh_"+side,hip,knee)
        desired["shin_"+side]=aim("shin_"+side,knee,ankle)
        desired["foot_"+side]=transform_bone("foot_"+side,ankle,Quaternion())
        swing=-.40*math.cos(TAU*p)
        upper_q=Quaternion((1,0,0),swing)
        shoulder=ENDS["upperarm_"+side][0]+offset
        elbow=shoulder+upper_q@(ENDS["upperarm_"+side][1]-ENDS["upperarm_"+side][0])
        desired["upperarm_"+side]=transform_bone("upperarm_"+side,shoulder,upper_q)
        desired["forearm_"+side]=transform_bone("forearm_"+side,elbow,Quaternion((1,0,0),swing+.14))
        for kind in ("tail","braid"):
            name=kind+"_"+side
            desired[name]=transform_bone(name,ENDS[name][0]+offset,Quaternion((1,0,0),.055*math.sin(TAU*p-.5)))
        trace[side]={"ankle":list(ankle),"knee":list(knee),"support":p<.6,"phase":p}
    for bone in RIG.pose.bones:
        matrix=desired[bone.name]
        if bone.parent:
            basis=REST[bone.name].inverted()@REST[bone.parent.name]@desired[bone.parent.name].inverted()@matrix
        else: basis=REST[bone.name].inverted()@matrix
        bone.rotation_mode="QUATERNION"
        bone.matrix_basis=basis
        if keyframe is not None:
            for channel in ("location","rotation_quaternion","scale"):
                bone.keyframe_insert(channel,frame=keyframe,group=bone.name)
    if SKIRT_KEYS:
        SKIRT_KEYS[0].value=math.sin(TAU*phase)
        SKIRT_KEYS[1].value=(1-math.cos(2*TAU*phase))*.5
        if keyframe is not None:
            for key in SKIRT_KEYS: key.keyframe_insert("value",frame=keyframe)
            # Bake a smooth, repeatable cloth clearance correction around the
            # posed legs. This avoids both mesh penetration and a nondeterministic
            # cloth simulation at the loop boundary.
            skirt=bpy.data.objects["Skirt"]
            correction=skirt.shape_key_add(name="Drape_%02d" % keyframe)
            to_local=(desired["pelvis"]@REST["pelvis"].inverted()).inverted()
            segments=[]
            for side in ("R","L"):
                points=[to_local@(ENDS["thigh_"+side][0]+offset),to_local@Vector(trace[side]["knee"]),to_local@Vector(trace[side]["ankle"])]
                segments.extend(zip(points,points[1:]))
            for i,vertex in enumerate(skirt.data.vertices):
                if vertex.co.y<=0: continue
                sway=SKIRT_KEYS[0].data[i].co.y-vertex.co.y
                needed=vertex.co.y+sway*SKIRT_KEYS[0].value
                for a,b in segments:
                    if not min(a.z,b.z)-.03<=vertex.co.z<=max(a.z,b.z)+.03: continue
                    t=max(0,min(1,(vertex.co.z-a.z)/(b.z-a.z)))
                    center=a.lerp(b,t)
                    dx=abs(vertex.co.x-center.x)
                    if dx<.095:
                        needed=max(needed,center.y+math.sqrt(.095**2-dx**2)+.012)
                correction.data[i].co.y+=max(0,needed-(vertex.co.y+sway*SKIRT_KEYS[0].value))
            for at,value in ((keyframe-1,0),(keyframe,1),(keyframe+1,0)):
                correction.value=value;correction.keyframe_insert("value",frame=at)
    bpy.context.view_layer.update()
    return trace


def scene_setup(output):
    scene=bpy.context.scene
    scene.render.engine="CYCLES"
    scene.cycles.device="CPU"
    scene.cycles.samples=24
    scene.cycles.use_denoising=True
    scene.render.resolution_x=256;scene.render.resolution_y=384;scene.render.resolution_percentage=100
    scene.render.film_transparent=True
    scene.render.image_settings.file_format="PNG"
    scene.render.image_settings.color_mode="RGBA"
    scene.view_settings.view_transform="Standard"
    scene.world=bpy.data.worlds.new("PilotWorld")
    scene.world.use_nodes=True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value=(.65,.73,.86,1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value=.65
    for name,at,power,size in (("Key",(3,4,6),420,4),("Fill",(-3,1,3),150,3),("Rim",(0,-4,4),220,3)):
        light=bpy.data.lights.new(name,"AREA");light.energy=power;light.shape="DISK";light.size=size
        obj=bpy.data.objects.new(name,light);scene.collection.objects.link(obj);obj.location=at
        obj.rotation_euler=(Vector((0,0,.8))-obj.location).to_track_quat("-Z","Y").to_euler()
    data=bpy.data.cameras.new("SoutheastOrthographic")
    camera=bpy.data.objects.new(data.name,data);scene.collection.objects.link(camera)
    camera.location=(4,6,5.85)
    camera.rotation_euler=(Vector((0,0,.75))-camera.location).to_track_quat("-Z","Y").to_euler()
    data.type="ORTHO";data.ortho_scale=1.95
    scene.camera=camera
    scene.render.fps=60;scene.frame_start=1;scene.frame_end=48
    return scene,camera


def main():
    global SKIRT_KEYS
    parser=argparse.ArgumentParser()
    parser.add_argument("--output",default=str(ROOT/"build/blender-walk-pilot"))
    parser.add_argument("--still",action="store_true")
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    output=Path(args.output).resolve();(output/"frames").mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    builder,collection=source_builder()
    details(builder,collection)
    make_rig(collection)
    skirt=bpy.data.objects["Skirt"]
    skirt.shape_key_add(name="Basis")
    sway=skirt.shape_key_add(name="WalkSway");sway.slider_min=-1
    lift=skirt.shape_key_add(name="HemLift")
    for i,v in enumerate(skirt.data.vertices):
        weight=max(0,min(1,(.82-v.co.z)/.54))**1.5
        sway.data[i].co.y+=.035*weight*v.co.x/.186
        lift.data[i].co.z+=.009*weight
    SKIRT_KEYS=(sway,lift)
    scene,camera=scene_setup(output)
    traces=[]
    for frame in range(1,50):
        traces.append(evaluate((frame-1)/48,keyframe=frame))
    evaluate(0)
    beginning={b.name:b.matrix.copy() for b in RIG.pose.bones}
    evaluate(1)
    closure=max(abs(beginning[b.name][i][j]-b.matrix[i][j]) for b in RIG.pose.bones for i in range(4) for j in range(4))
    assert closure<1e-6
    pivot=world_to_camera_view(scene,camera,Vector((0,0,0)))
    manifest={"method":"Fully scripted Blender geometry, armature and analytic two-bone gait", "direction":"southeast","frame_count":8,"frame_size":[256,384],"pivot":[pivot.x*256,(1-pivot.y)*384],"cycle_seconds":.8,"preview_fps":10,"loop_matrix_error":closure,"bone_count":len(RIG.pose.bones),"source_builder":"art/build_oravitsa.py","manual_steps":0,"poses":[traces[i*6] for i in range(8)]}
    (output/"manifest.json").write_text(json.dumps(manifest,indent=2),encoding="utf-8")
    scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=str(output/"oravitsa-walk-pilot.blend"))
    for i in range(1 if args.still else 8):
        scene.frame_set(1+i*6)
        scene.render.filepath=str(output/"frames"/f"se-{i+1:02}.png")
        bpy.ops.render.render(write_still=True)
    print("PILOT_OUTPUT="+str(output))


if __name__=="__main__":
    main()
