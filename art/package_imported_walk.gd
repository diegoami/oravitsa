extends SceneTree

func _initialize() -> void:
    var root_path := "res://build/fal-walk/render/"
    var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root_path+"manifest.json"))
    var directions := ["s","se","e","ne","n","nw","w","sw"]
    var maximum_height := 0
    var checks := []
    var frame_bounds := {}
    for direction in directions:
        var atlas := Image.create(2048,384,false,Image.FORMAT_RGBA8)
        var sheet := Image.create(1024,768,false,Image.FORMAT_RGBA8)
        var hashes := {}
        var bounds := []
        for index in 8:
            var path: String = root_path+str(direction)+"/walk-%02d.png" % (index+1)
            var image := Image.load_from_file(path)
            assert(image != null and image.get_size()==Vector2i(256,384))
            assert(image.detect_alpha()!=Image.ALPHA_NONE)
            maximum_height=maxi(maximum_height,image.get_used_rect().size.y)
            var used := image.get_used_rect()
            bounds.append([used.position.x,used.position.y,used.size.x,used.size.y])
            hashes[FileAccess.get_sha256(path)]=true
            var edges := 0
            for y in 384:
                for x in [0,255]:
                    if image.get_pixel(x,y).a>.01:edges+=1
            for x in 256:
                for y in [0,383]:
                    if image.get_pixel(x,y).a>.01:edges+=1
            assert(edges==0,"Frame touches border")
            atlas.blend_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i(index*256,0))
            sheet.blend_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i((index%4)*256,(index/4)*384))
        assert(hashes.size()==8,"Repeated frame in directional walk")
        atlas.save_png(root_path+direction+"/atlas.png")
        sheet.save_png(root_path+direction+"/contact-sheet.png")
        checks.append({"direction":direction,"frames":8,"unique_images":8,"opaque_border_pixels":0,"transparent":true})
        frame_bounds[direction]=bounds
    manifest["preview_scale"]=132.0/maximum_height
    manifest["maximum_body_height_pixels"]=maximum_height
    manifest["export_checks"]=checks
    manifest["frame_bounds"]=frame_bounds
    var pivot := Vector2(manifest["pivot"][0],manifest["pivot"][1])
    var scale: float = manifest["preview_scale"]
    var layout := Rect2(Vector2.ZERO,Vector2.ZERO)
    for direction in frame_bounds:
        for bound in frame_bounds[direction]:
            layout=layout.merge(Rect2((Vector2(bound[0],bound[1])-pivot)*scale,Vector2(bound[2],bound[3])*scale))
    var references := {"s":"oravitsa_walk_s_v2.png","se":"oravitsa_walk_se.png","e":"oravitsa_walk_side_v2.png","ne":"oravitsa_walk_ne.png","n":"oravitsa_walk_back_v2.png"}
    var reference_bounds := {}
    for direction in references:
        var strip := Image.load_from_file("res://scenes/forest_2d/art/"+references[direction])
        var width := strip.get_width()/4
        var old_pivot := Vector2(width/2.0,strip.get_height()/2.0+290)
        var bounds := []
        for index in 4:
            var used := strip.get_region(Rect2i(index*width,0,width,strip.get_height())).get_used_rect()
            bounds.append([used.position.x,used.position.y,used.size.x,used.size.y])
            var rectangle := Rect2((Vector2(used.position)-old_pivot)*.2,Vector2(used.size)*.2)
            layout=layout.merge(rectangle)
            layout=layout.merge(Rect2(Vector2(-rectangle.end.x,rectangle.position.y),rectangle.size))
        reference_bounds[direction]={"width":strip.get_width(),"height":strip.get_height(),"frames":bounds}
    manifest["reference_bounds"]=reference_bounds
    manifest["layout_bounds"]=[layout.position.x,layout.position.y,layout.end.x,layout.end.y]
    var file := FileAccess.open(root_path+"manifest.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(manifest,"  "))
    print("WALK_EXPORT_VALIDATED: 64 unique directional PNGs, transparent frames, no clipped borders, eight atlases")
    quit()
