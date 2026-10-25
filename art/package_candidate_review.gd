extends SceneTree

func _initialize() -> void:
    var output := "res://build/fal-tripo-trial/review/"
    var images := []
    var used := Rect2i()
    for angle in range(0,360,45):
        var image := Image.load_from_file(output+"views/angle-%03d.png" % angle)
        assert(image != null)
        images.append(image)
        used=used.merge(image.get_used_rect()) if used.size != Vector2i.ZERO else image.get_used_rect()
    used=used.grow(10).intersection(Rect2i(Vector2i.ZERO,images[0].get_size()))
    var sheet := Image.create(used.size.x*4,used.size.y*2,false,Image.FORMAT_RGBA8)
    for index in 8:
        var cropped: Image = images[index].get_region(used)
        cropped.save_png(output+"views/angle-%03d.png" % (index*45))
        sheet.blend_rect(cropped,Rect2i(Vector2i.ZERO,cropped.get_size()),Vector2i((index%4)*used.size.x,(index/4)*used.size.y))
    sheet.save_png(output+"contact-sheet.png")
    var strip := Image.load_from_file("res://scenes/forest_2d/art/oravitsa_walk_se.png")
    var source := strip.get_region(Rect2i(0,0,strip.get_width()/4,strip.get_height()))
    source=source.get_region(source.get_used_rect().grow(10).intersection(Rect2i(Vector2i.ZERO,source.get_size())))
    source.save_png(output+"reference.png")
    print("Prepared eight consistent camera views and the unchanged painted reference")
    quit()
