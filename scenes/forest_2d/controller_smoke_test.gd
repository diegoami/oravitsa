extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _axis(axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)


func _button(button: int, pressed: bool = true) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)


func _run() -> void:
	var forest = load("res://scenes/forest_2d/forest.tscn").instantiate()
	root.add_child(forest)
	current_scene = forest
	forest.set_process(false)
	await process_frame
	# Exercise real input-map bindings rather than calling controller handlers.
	_axis(JOY_AXIS_LEFT_X, 0.1)
	await process_frame
	assert(Input.get_vector("move_left", "move_right", "move_forward", "move_back") == Vector2.ZERO)
	_axis(JOY_AXIS_LEFT_X, 0.6)
	await process_frame
	var direction := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	assert(direction.x > 0.4 and direction.x < 0.6)
	var before: Vector2 = forest.player_position
	forest._process(1.0 / 60.0)
	assert(forest.player_position.x > before.x)
	assert(forest.player_position.x - before.x < forest.SPEED / 60.0 * 0.7)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_button(JOY_BUTTON_DPAD_UP)
	await process_frame
	assert(Input.get_vector("move_left", "move_right", "move_forward", "move_back").y < -0.9)
	_button(JOY_BUTTON_DPAD_UP, false)
	await process_frame
	assert(Input.get_vector("move_left", "move_right", "move_forward", "move_back") == Vector2.ZERO)
	# Make the eligible target order deterministic; hidden, dead and far animals
	# must never steal controller selection.
	for id in forest._active_animals:
		forest._animals[id]["position"] = forest.player_position + Vector2(1000 + id, 0)
	forest._animals[0]["position"] = forest.player_position + Vector2(180, 0)
	forest._animals[1]["position"] = forest.player_position + Vector2(300, 0)
	forest._animals[2]["position"] = forest.player_position + Vector2(100, 0)
	forest._animals[2]["alive"] = false
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	await process_frame
	assert(forest.selected_target == 0)
	_button(JOY_BUTTON_RIGHT_SHOULDER, false)
	await process_frame
	assert(forest.selected_target == 0)
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	await process_frame
	assert(forest.selected_target == 1)
	_button(JOY_BUTTON_RIGHT_SHOULDER, false)
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	await process_frame
	assert(forest.selected_target == 0)
	_button(JOY_BUTTON_RIGHT_SHOULDER, false)
	_button(JOY_BUTTON_LEFT_SHOULDER)
	await process_frame
	assert(forest.selected_target == 1)
	_button(JOY_BUTTON_LEFT_SHOULDER, false)
	_button(JOY_BUTTON_A)
	await process_frame
	assert(forest._stones.size() == 1 and forest.sling_cooldown > 0.0)
	_button(JOY_BUTTON_A, false)
	_button(JOY_BUTTON_A)
	await process_frame
	assert(forest._stones.size() == 1)
	_button(JOY_BUTTON_A, false)
	_button(JOY_BUTTON_B)
	await process_frame
	assert(forest.shoo_cooldown > 0.0)
	_button(JOY_BUTTON_B, false)
	forest._animals[0]["alive"] = false
	forest._animals[1]["alive"] = false
	_button(JOY_BUTTON_RIGHT_SHOULDER)
	await process_frame
	assert(forest.selected_target == -1)
	_button(JOY_BUTTON_RIGHT_SHOULDER, false)
	assert(forest._shoo_button.get("prompt") == "B / Circle")
	assert(forest._sling_button.get("prompt") == "A / Cross")
	assert(is_equal_approx(float(forest._sling_button.get("cooldown")), forest.sling_cooldown))
	_button(JOY_BUTTON_BACK)
	await process_frame
	assert(not forest._minimap.visible and forest._map_toggle.visible)
	_button(JOY_BUTTON_BACK, false)
	_button(JOY_BUTTON_START)
	await process_frame
	assert(not forest._help_panel.visible and not forest._hint_label.visible)
	_button(JOY_BUTTON_START, false)
	# Switching back to keyboard updates prompts and can restore hidden panels.
	var key := InputEventKey.new()
	key.keycode = KEY_M
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	assert(forest._minimap.visible)
	assert(forest._sling_button.get("prompt") == "RMB / F")
	key.pressed = false
	Input.parse_input_event(key)
	key = InputEventKey.new()
	key.keycode = KEY_H
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	assert(forest._help_panel.visible and forest._hint_label.visible)
	key.pressed = false
	Input.parse_input_event(key)
	print("Controller smoke test passed: analog movement/deadzone, D-pad, target filtering/cycling, sling/cooldown and shoo")
	quit()
