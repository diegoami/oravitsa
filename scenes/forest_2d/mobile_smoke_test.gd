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
	var scene: PackedScene = load("res://scenes/forest_2d/forest.tscn")
	var forest = scene.instantiate()
	root.add_child(forest)
	current_scene = forest
	forest.set_process(false)
	var controls: Control = forest._touch_controls
	assert(not controls.touch_enabled)
	controls._enable_touch()
	await process_frame
	await process_frame
	assert(controls.visible)
	_touch(controls, 2, controls._stick_center + Vector2(controls._radius, 0), true)
	assert(controls.direction.x > 0.9)
	var before: Vector2 = forest.player_position
	forest._process(1.0 / 60.0)
	assert(forest.player_position.x > before.x)
	_touch(controls, 7, controls._shoo_center, true)
	assert(forest.shoo_cooldown > 0.0)
	assert(controls.direction.x > 0.9)
	_touch(controls, 9, Vector2.ZERO, false)
	assert(controls.direction.x > 0.9)
	Input.action_press("move_forward")
	_touch(controls, 2, Vector2.ZERO, false)
	assert(controls.direction == Vector2.ZERO)
	assert(Input.is_action_pressed("move_forward"))
	before = forest.player_position
	forest._process(1.0 / 60.0)
	assert(forest.player_position.y < before.y)
	Input.action_release("move_forward")
	_touch(controls, 7, controls._shoo_center, false)
	_touch(controls, 3, controls._stick_center + Vector2(controls._radius, 0), true)
	controls._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(controls.direction == Vector2.ZERO)
	for window_size in [Vector2i(390, 844), Vector2i(844, 390), Vector2i(1280, 720)]:
		root.size = window_size
		forest._layout_hud()
		await process_frame
		await process_frame
		var viewport_size: Vector2 = forest.get_viewport_rect().size
		assert(forest._minimap.position.x >= forest._hud_panel.position.x + forest._hud_panel.size.x)
		assert(forest._minimap.position.x + forest._minimap.size.x * forest._minimap.scale.x <= viewport_size.x)
		assert(controls._stick_center.y + controls._radius <= viewport_size.y)
		assert(controls._shoo_center.x + controls._radius * 0.72 <= viewport_size.x)
		var skills := Rect2(forest._skill_bar.position, forest._skill_bar.size)
		assert(Rect2(Vector2.ZERO, viewport_size).encloses(skills))
		assert(skills.end.x < controls._stick_center.x - controls._radius)
		assert(forest._shoo_button.get("prompt") == "TAP")
		assert(forest._sling_button.get("prompt") == "TAP")
		assert(forest._hint_label.position.y + forest._hint_label.size.y <= forest._help_panel.position.y + forest._help_panel.size.y)
		assert(controls.direction == Vector2.ZERO)
	# Visible toggle buttons remain usable after collapsing both panels.
	for button in [forest._map_toggle, forest._instructions_toggle]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = button.get_global_rect().get_center()
		click.pressed = true
		root.push_input(click, true)
		click.pressed = false
		root.push_input(click, true)
		await process_frame
	assert(not forest._minimap.visible and not forest._hint_label.visible)
	forest._layout_hud()
	await process_frame
	assert(not forest._minimap.visible and not forest._hint_label.visible)
	assert(forest._map_toggle.visible and forest._instructions_toggle.visible)
	print("Mobile smoke test passed: multitouch movement/shoo, independent keyboard input, focus reset, portrait/landscape HUD")
	quit()
