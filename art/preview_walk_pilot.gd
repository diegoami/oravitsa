extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var args := OS.get_cmdline_user_args()
    var output := args[0] if not args.is_empty() else ProjectSettings.globalize_path("res://build/blender-walk-pilot")
    var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(output+"/manifest.json"))
    root.size=Vector2i(800,500)
    var background := ColorRect.new()
    background.color=Color("516846")
    background.size=Vector2(800,500)
    root.add_child(background)
    var sprite := AnimatedSprite2D.new()
    var frames := SpriteFrames.new()
    frames.add_animation("southeast")
    frames.set_animation_speed("southeast",10)
    for i in 8:
        var image := Image.load_from_file(output+"/frames/se-%02d.png" % (i+1))
        frames.add_frame("southeast",ImageTexture.create_from_image(image))
    sprite.sprite_frames=frames
    sprite.centered=false
    sprite.offset=-Vector2(manifest["pivot"][0],manifest["pivot"][1])
    sprite.scale=Vector2.ONE*0.55
    sprite.position=Vector2(400,350)
    root.add_child(sprite)
    sprite.play("southeast")
    var label := Label.new()
    label.text="Southeast — fully scripted Blender pilot\nEight frames · 10 FPS · fixed camera\nCurrent game artwork is unchanged"
    label.position=Vector2(30,25)
    root.add_child(label)
    assert(frames.get_frame_count("southeast")==8)
    await process_frame
    assert(sprite.is_playing())
    print("GODOT_PILOT_READY: eight rendered frames playing in AnimatedSprite2D")
