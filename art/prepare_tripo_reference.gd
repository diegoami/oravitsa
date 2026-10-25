extends SceneTree

func _initialize() -> void:
    var output := "res://build/tripo-trial"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
    var strip := Image.load_from_file("res://scenes/forest_2d/art/oravitsa_walk_se.png")
    var source := strip.get_region(Rect2i(0,0,strip.get_width()/4,strip.get_height()))
    var input := Image.create(source.get_width(),source.get_height(),false,Image.FORMAT_RGBA8)
    input.fill(Color("f0eee6"))
    input.blend_rect(source,Rect2i(Vector2i.ZERO,source.get_size()),Vector2i.ZERO)
    input.save_png(output+"/source.png")
    print("Prepared one unchanged painted southeast figure on a neutral background")
    quit()
