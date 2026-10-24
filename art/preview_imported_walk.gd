extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var path := "res://build/fal-walk/render/"
    var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path+"manifest.json"))
    var node := AnimatedSprite2D.new()
    var frames := SpriteFrames.new()
    for direction in ["s","se","e","ne","n","nw","w","sw"]:
        frames.add_animation(direction)
        frames.set_animation_speed(direction,8.0/manifest["source_cycle_seconds"])
        for index in 8:
            var image := Image.load_from_file(path+direction+"/walk-%02d.png" % (index+1))
            frames.add_frame(direction,ImageTexture.create_from_image(image))
    node.sprite_frames=frames
    root.add_child(node)
    node.play("se")
    await process_frame
    node.set_frame_and_progress(3,.4)
    var previous_frame := node.frame
    var progress := node.frame_progress
    node.play("ne")
    node.set_frame_and_progress(previous_frame,progress)
    assert(node.frame==3 and is_equal_approx(node.frame_progress,.4))
    assert(node.is_playing())
    print("GODOT_WALK_VALIDATED: eight directions, eight frames each, phase retained across direction change")
    quit()
