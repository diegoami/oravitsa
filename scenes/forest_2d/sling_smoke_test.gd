extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _touch(controls: Control, id: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = point
	event.pressed = pressed
	controls._input(event)


func _run() -> void:
	var forest = load("res://scenes/forest_2d/forest.tscn").instantiate()
	root.add_child(forest)
	current_scene = forest
	forest.set_process(false)
	await process_frame
	var target: Dictionary = forest._animals[0]
	var sprite: AnimatedSprite2D = forest._active_animals[0]
	target["position"] = forest.player_position + Vector2(180, 40)
	sprite.position = target["position"]
	forest._camera.force_update_scroll()
	var point := sprite.get_global_transform_with_canvas() * sprite.offset
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = point
	root.push_input(click, true)
	await process_frame
	assert(forest.selected_target == 0)
	assert(forest._sling_ready())
	forest._select_sling_target(forest._hud_panel.position + Vector2(5, 5))
	assert(forest.selected_target == 0)
	var key := InputEventKey.new()
	key.keycode = KEY_F
	key.pressed = true
	root.push_input(key, true)
	await process_frame
	key.pressed = false
	root.push_input(key, true)
	assert(forest._stones.size() == 1)
	assert(target["stun"] == 0.0)
	forest._fire_sling()
	assert(forest._stones.size() == 1)
	for frame in 20:
		forest._update_sling(0.05)
	assert(forest._stones.is_empty())
	assert(target["alive"])
	assert(target["stun"] == forest.SLING_STUN_TIME)
	assert(target["velocity"] == Vector2.ZERO)
	var before: Vector2 = target["position"]
	forest._move_animals(0.1)
	assert(target["position"] == before)
	assert(target["stun"] > 0.0)
	forest._move_animals(forest.SLING_STUN_TIME)
	assert(target["stun"] == 0.0)
	assert(sprite.modulate == Color.WHITE)
	forest._update_sling(forest.SLING_COOLDOWN)
	target["position"] = forest.player_position + Vector2(forest.SLING_RANGE + 1.0, 0)
	forest._fire_sling()
	assert(forest._stones.is_empty() and forest.sling_cooldown == 0.0)
	target["position"] = forest.player_position + Vector2(180, 40)
	forest.player_stun = 0.5
	forest._fire_sling()
	assert(forest._stones.is_empty())
	forest.player_stun = 0.0
	forest._fire_sling()
	assert(forest._stones.size() == 1)
	target["alive"] = false
	forest._update_sling(0.05)
	assert(forest._stones.is_empty() and forest.selected_target == -1)
	target["alive"] = true
	forest.sling_cooldown = 0.0
	var controls: Control = forest._touch_controls
	controls._enable_touch()
	root.size = Vector2i(390, 844)
	forest._layout_hud()
	await process_frame
	await process_frame
	target["position"] = forest.player_position + Vector2(120, 0)
	sprite.position = target["position"]
	forest._camera.force_update_scroll()
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	tap.index = 5
	tap.position = sprite.get_global_transform_with_canvas() * sprite.offset
	forest._unhandled_input(tap)
	assert(forest.selected_target == 0)
	_touch(controls, 4, controls._stick_center + Vector2(controls._radius, 0), true)
	_touch(controls, 6, controls._sling_center, true)
	assert(forest._stones.size() == 1)
	assert(controls.direction.x > 0.9)
	assert(not controls.sling_available)
	_touch(controls, 6, controls._sling_center, false)
	assert(controls.direction.x > 0.9)
	controls._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(controls.direction == Vector2.ZERO and controls._sling_finger == -1)
	print("Sling smoke test passed: mouse/touch selection, F/touch fire, projectile hit, stun/recovery, range/cooldown, disappearing target, independent multitouch")
	quit()
