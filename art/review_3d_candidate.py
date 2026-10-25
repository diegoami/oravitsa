"""Render an imported reconstruction from fixed cameras; do not replace game art."""
import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix,Vector


def bounds(objects):
    points=[obj.matrix_world@Vector(corner) for obj in objects for corner in obj.bound_box]
    return Vector(tuple(min(p[i] for p in points) for i in range(3))),Vector(tuple(max(p[i] for p in points) for i in range(3)))


def main():
    root=Path(__file__).resolve().parents[1]
    parser=argparse.ArgumentParser()
    parser.add_argument("--model",type=Path,default=root/"build/fal-tripo-trial/candidate.glb")
    parser.add_argument("--output",type=Path,default=root/"build/fal-tripo-trial/review")
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    output=args.output.resolve();(output/"views").mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(args.model.resolve()))
    meshes=[obj for obj in bpy.context.scene.objects if obj.type=="MESH"]
    if not meshes: raise RuntimeError("The reconstruction contains no meshes.")
    bpy.context.view_layer.update()
    low,high=bounds(meshes)
    height=high.z-low.z
    if height<1e-5: raise RuntimeError("Model has invalid vertical bounds.")
    original_roots=[obj for obj in bpy.context.scene.objects if obj.parent is None]
    group=bpy.data.objects.new("CandidateNormalization",None)
    bpy.context.scene.collection.objects.link(group)
    for obj in original_roots:
        transform=obj.matrix_world.copy();obj.parent=group;obj.matrix_world=transform
    group.matrix_world=Matrix.Scale(1.5/height,4)@Matrix.Translation(Vector((-(low.x+high.x)/2,-(low.y+high.y)/2,-low.z)))
    bpy.context.view_layer.update()
    # Preserve the generated base-color artwork without adding plastic highlights.
    materials=sorted({slot.material for obj in meshes for slot in obj.material_slots if slot.material},key=lambda m:m.name)
    for mat in materials:
        if not mat.use_nodes: continue
        nodes=mat.node_tree.nodes
        principled=next((node for node in nodes if node.type=="BSDF_PRINCIPLED"),None)
        destination=next((node for node in nodes if node.type=="OUTPUT_MATERIAL"),None)
        if principled is None or destination is None: continue
        emission=nodes.new("ShaderNodeEmission")
        source=principled.inputs["Base Color"]
        if source.is_linked:
            mat.node_tree.links.new(source.links[0].from_socket,emission.inputs["Color"])
        else: emission.inputs["Color"].default_value=source.default_value
        mat.node_tree.links.new(emission.outputs["Emission"],destination.inputs["Surface"])
    scene=bpy.context.scene
    scene.render.engine="CYCLES";scene.cycles.device="CPU";scene.cycles.samples=8
    scene.render.resolution_x=320;scene.render.resolution_y=480;scene.render.resolution_percentage=100
    scene.render.film_transparent=True;scene.render.image_settings.file_format="PNG";scene.render.image_settings.color_mode="RGBA"
    scene.view_settings.view_transform="Standard"
    data=bpy.data.cameras.new("LikenessReviewCamera");data.type="ORTHO";data.ortho_scale=1.95
    camera=bpy.data.objects.new(data.name,data);scene.collection.objects.link(camera);scene.camera=camera
    for index in range(8):
        angle=math.radians(index*45)
        camera.location=(6*math.sin(angle),-6*math.cos(angle),.75+6*math.tan(math.radians(35.264)))
        camera.rotation_euler=(Vector((0,0,.75))-camera.location).to_track_quat("-Z","Y").to_euler()
        scene.render.filepath=str(output/"views"/f"angle-{index*45:03d}.png")
        bpy.ops.render.render(write_still=True)
    camera.location=(0,-6,.75+6*math.tan(math.radians(35.264)))
    camera.rotation_euler=(Vector((0,0,.75))-camera.location).to_track_quat("-Z","Y").to_euler()
    for image in bpy.data.images:
        if image.source=="FILE" and not image.packed_file:
            try: image.pack()
            except RuntimeError: pass
    bpy.ops.wm.save_as_mainfile(filepath=str(output/"candidate-review.blend"))
    report={"source":str(args.model.resolve()),"original_bounds":[list(low),list(high)],"normalized_height":1.5,"mesh_count":len(meshes),"polygons":sum(len(obj.data.polygons) for obj in meshes),"material_count":len(materials),"rendering":"Generated base-color textures as emission; no relighting","camera_elevation_degrees":35.264,"angles":list(range(0,360,45)),"purpose":"Static likeness review only; no rigging or game replacement"}
    (output/"review.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
    print("CANDIDATE_REVIEW="+str(output))


if __name__=="__main__": main()
