"""Bake the approved textured character's supplied walk into directional PNGs."""
import argparse,json,math,sys,runpy
from pathlib import Path
import bpy
from mathutils import Matrix,Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT=Path(__file__).resolve().parents[1]
DIRECTIONS={"s":0,"se":315,"e":270,"ne":225,"n":180,"nw":135,"w":90,"sw":45}


def frame_set(scene,at):
    scene.frame_set(math.floor(at),subframe=at-math.floor(at))


def evaluated_bounds(objects):
    graph=bpy.context.evaluated_depsgraph_get()
    points=[]
    for obj in objects:
        posed=obj.evaluated_get(graph)
        points.extend(posed.matrix_world@Vector(corner) for corner in posed.bound_box)
    return points


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--directions",default=",".join(DIRECTIONS))
    parser.add_argument("--foot-skinning",choices=("none","matched"),default="matched")
    parser.add_argument("--output",type=Path,default=ROOT/"build/fal-walk/render")
    parser.add_argument("--skirt-repair",action=argparse.BooleanOptionalAction,default=True)
    parser.add_argument("--arm-clearance",action=argparse.BooleanOptionalAction,default=True)
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    requested=args.directions.split(",")
    assert all(direction in DIRECTIONS for direction in requested)
    output=args.output.resolve()
    output.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/"build/fal-walk/walking.glb"))
    scene=bpy.context.scene
    rig=next(obj for obj in scene.objects if obj.type=="ARMATURE")
    for track in rig.animation_data.nla_tracks:track.mute=True
    action=rig.animation_data.action or next(iter(bpy.data.actions))
    rig.animation_data.action=action
    start,end=map(float,action.frame_range)
    arm_report=runpy.run_path(str(ROOT/'art/arm_clearance.py'))['correct'](rig) if args.arm_clearance else None
    action=rig.animation_data.action
    source_fps=scene.render.fps
    phases=[(.25+i/8)%1 for i in range(8)]
    sample_frames=[start+(end-start)*p for p in phases]
    character=[obj for obj in scene.objects if obj.type=="MESH" and (obj.parent==rig or any(mod.type=="ARMATURE" and mod.object==rig for mod in obj.modifiers))]
    skirt_report=None;skirt_state=None;skirt_update=None
    if args.skirt_repair:
        skirt_module=runpy.run_path(str(ROOT/"art/skirt_drape.py"))
        skirt,skirt_report,skirt_state=skirt_module['create'](rig,character)
        skirt_update=skirt_module['update'];character.append(skirt)
    boot_state=None;boot_update=None
    if args.foot_skinning=="matched":
        boot_module=runpy.run_path(str(ROOT/"art/matched_boots.py"))
        new_boots,foot_report,boot_state=boot_module["create"](rig,character)
        boot_update=boot_module["update"]
        character.extend(new_boots)
    else:foot_report=runpy.run_path(str(ROOT/"art/foot_skinning.py"))["correct"](character,args.foot_skinning)
    (output/"foot-skinning.json").write_text(json.dumps(foot_report,indent=2),encoding="utf-8")
    for obj in scene.objects:
        if obj.type=="MESH" and obj not in character:obj.hide_render=True
    frame_set(scene,start)
    hips_start=rig.matrix_world@rig.pose.bones["Hips"].head
    frame_set(scene,end)
    hips_end=rig.matrix_world@rig.pose.bones["Hips"].head
    travel=hips_end-hips_start
    all_points=[]
    for at in sample_frames:
        frame_set(scene,at)
        if boot_state:boot_update(boot_state)
        if skirt_state:skirt_update(skirt_state)
        all_points.extend(evaluated_bounds(character))
    low=Vector(tuple(min(p[i] for p in all_points) for i in range(3)))
    high=Vector(tuple(max(p[i] for p in all_points) for i in range(3)))
    scale=1.5/(high.z-low.z)
    original_roots=[obj for obj in scene.objects if obj.parent is None]
    group=bpy.data.objects.new("InPlaceNormalization",None);scene.collection.objects.link(group)
    for obj in original_roots:
        transform=obj.matrix_world.copy();obj.parent=group;obj.matrix_world=transform
    base=Matrix.Scale(scale,4)@Matrix.Translation(Vector((-hips_start.x,-hips_start.y,-low.z)))
    def set_pose(index):
        frame_set(scene,sample_frames[index])
        group.matrix_world=Matrix.Translation(Vector((-travel.x*scale*phases[index],-travel.y*scale*phases[index],0)))@base
        bpy.context.view_layer.update()
        if boot_state:boot_update(boot_state)
        if skirt_state:skirt_update(skirt_state)
    if boot_state or skirt_state:
        for step in range(65):
            phase=step/64
            at=start+(end-start)*phase
            frame_set(scene,at)
            group.matrix_world=Matrix.Translation(Vector((-travel.x*scale*phase,-travel.y*scale*phase,0)))@base
            bpy.context.view_layer.update()
            if boot_state:boot_update(boot_state,keyframe=at)
            if skirt_state:skirt_update(skirt_state,keyframe=at)
    # Keep the generated painted color, rather than relighting the character.
    materials={slot.material for obj in character for slot in obj.material_slots if slot.material}
    for mat in materials:
        if not mat.use_nodes:continue
        principled=next((n for n in mat.node_tree.nodes if n.type=="BSDF_PRINCIPLED"),None)
        destination=next((n for n in mat.node_tree.nodes if n.type=="OUTPUT_MATERIAL"),None)
        if not principled or not destination:continue
        emission=mat.node_tree.nodes.new("ShaderNodeEmission")
        color=principled.inputs["Base Color"]
        if color.is_linked:mat.node_tree.links.new(color.links[0].from_socket,emission.inputs["Color"])
        else:emission.inputs["Color"].default_value=color.default_value
        mat.node_tree.links.new(emission.outputs["Emission"],destination.inputs["Surface"])
    scene.render.engine="CYCLES";scene.cycles.device="CPU";scene.cycles.samples=8
    scene.render.resolution_x=256;scene.render.resolution_y=384;scene.render.resolution_percentage=100
    scene.render.film_transparent=True;scene.render.image_settings.file_format="PNG";scene.render.image_settings.color_mode="RGBA"
    scene.view_settings.view_transform="Standard"
    data=bpy.data.cameras.new("DirectionalWalkCamera");data.type="ORTHO";data.ortho_scale=1.95
    camera=bpy.data.objects.new(data.name,data);scene.collection.objects.link(camera);scene.camera=camera
    def set_camera(direction):
        angle=math.radians(DIRECTIONS[direction])
        camera.location=(6*math.sin(angle),-6*math.cos(angle),.75+6*math.tan(math.radians(35.264)))
        camera.rotation_euler=(Vector((0,0,.75))-camera.location).to_track_quat("-Z","Y").to_euler()
        bpy.context.view_layer.update()
    # Fit every pose and direction together, using one camera scale and origin.
    fit=0.0
    for direction in DIRECTIONS:
        set_camera(direction)
        for i in range(8):
            set_pose(i)
            for point in evaluated_bounds(character):
                uv=world_to_camera_view(scene,camera,point)
                fit=max(fit,abs(uv.x-.5)/.43,abs(uv.y-.5)/.44)
    data.ortho_scale*=max(1.0,fit)
    set_camera("se");set_pose(0)
    pivot=world_to_camera_view(scene,camera,Vector((0,0,0)))
    metadata={"source":"Meshy walking clip on the approved Tripo character","foot_repair":foot_report,"foot_mode":args.foot_skinning,"action":action.name,"source_frame_range":[start,end],"source_cycle_seconds":(end-start)/source_fps,"sample_frames":sample_frames,"sample_phases":phases,"frames_per_direction":8,"frame_size":[256,384],"directions":DIRECTIONS,"pivot":[pivot.x*256,(1-pivot.y)*384],"camera_scale":data.ortho_scale,"root_motion_removed":list(travel),"bone_count":len(rig.data.bones),"geometry":"Original textured body; matched boot geometry repaired locally without new generation","rendering":"Base-color emission, transparent PNG","phase_note":"Same pose phase in every direction; first phase chosen near opposing-foot contact","status":"Review export, not integrated into gameplay","limitations":["Automatic skirt deformation still needs visual review","Earlier garment/IK corrective experiments were rejected and are not applied"]}
    (output/"manifest.json").write_text(json.dumps(metadata,indent=2),encoding="utf-8")
    if skirt_report:
        metadata['skirt_repair']=skirt_report
        metadata['limitations']=['Fitted skirt surface resamples the original painted fabric; inspect the drape visually before game integration']
        (output/"manifest.json").write_text(json.dumps(metadata,indent=2),encoding="utf-8")
    if arm_report:
        metadata['arm_clearance']=arm_report
        (output/"manifest.json").write_text(json.dumps(metadata,indent=2),encoding="utf-8")
    for direction in requested:
        (output/direction).mkdir(exist_ok=True)
        set_camera(direction)
        for index in range(8):
            set_pose(index)
            scene.render.filepath=str(output/direction/f"walk-{index+1:02d}.png")
            bpy.ops.render.render(write_still=True)
    set_camera("se");set_pose(0)
    bpy.ops.wm.save_as_mainfile(filepath=str(output/"oravitsa-walk.blend"))
    print("DIRECTIONAL_WALK_RENDERED="+str(output))


if __name__=="__main__":main()
