extends SceneTree

func _initialize() -> void:
    var args := OS.get_cmdline_user_args()
    var output := args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://build/blender-walk-pilot")
    var atlas := Image.create(2048,384,false,Image.FORMAT_RGBA8)
    var sheet := Image.create(1024,768,false,Image.FORMAT_RGBA8)
    var checks := []
    for i in 8:
        var path := output + "/frames/se-%02d.png" % (i+1)
        var frame := Image.load_from_file(path)
        assert(frame != null and frame.get_size() == Vector2i(256,384))
        assert(frame.detect_alpha() != Image.ALPHA_NONE)
        var edge_pixels := 0
        for y in frame.get_height():
            for x in [0,255]:
                if frame.get_pixel(x,y).a > 0.01: edge_pixels += 1
        for x in frame.get_width():
            for y in [0,383]:
                if frame.get_pixel(x,y).a > 0.01: edge_pixels += 1
        assert(edge_pixels == 0)
        atlas.blend_rect(frame,Rect2i(Vector2i.ZERO,frame.get_size()),Vector2i(i*256,0))
        sheet.blend_rect(frame,Rect2i(Vector2i.ZERO,frame.get_size()),Vector2i((i%4)*256,(i/4)*384))
        checks.append({"frame":i+1,"opaque_edge_pixels":edge_pixels,"bounds":str(frame.get_used_rect())})
    atlas.save_png(output+"/southeast-atlas.png")
    sheet.save_png(output+"/contact-sheet.png")
    var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output+"/manifest.json"))
    manifest["pilot"]={"pivot":manifest["pivot"],"preview_scale":0.55,"phases":["Contact A","Weight transfer A","Passing B","Rise / transfer","Contact B","Weight transfer B","Passing A","Rise / transfer"]}
    manifest["review_note"]="Fully scripted Blender pilot: eight poses from one rig and fixed camera, exported as transparent PNGs. No manual drawing or rigging. The stylized 3D appearance differs from the painted artwork. Game sprites are unchanged."
    manifest["pixel_checks"]=checks
    var file := FileAccess.open(output+"/manifest.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(manifest,"  "))
    print("PACKAGED: eight transparent frames, zero opaque border pixels, PNG atlas and contact sheet")
    quit()
