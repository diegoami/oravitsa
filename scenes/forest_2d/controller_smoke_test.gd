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
	assert(not forest._minimap.visible and not forest._hint_label.visible)
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
	_axis(JOY_AXIS_RIGHT_X, 0.8)
	await process_frame
	assert(forest.selected_target == 0)
	_axis(JOY_AXIS_RIGHT_X, 0.95)
	await process_frame
	assert(forest.selected_target == 0) # Holding the stick must not race targets.
	_axis(JOY_AXIS_RIGHT_X, 0.0)
	_axis(JOY_AXIS_RIGHT_X, 0.8)
	await process_frame
	assert(forest.selected_target == 1)
	_axis(JOY_AXIS_RIGHT_X, 0.0)
	_axis(JOY_AXIS_RIGHT_X, 0.8)
	await process_frame
	assert(forest.selected_target == 0)
	_axis(JOY_AXIS_RIGHT_X, 0.0)
	_axis(JOY_AXIS_RIGHT_X, -0.8)
	await process_frame
	assert(forest.selected_target == 1)
	_axis(JOY_AXIS_RIGHT_X, 0.0)
	assert(forest.active_skill == 0)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.9)
	await process_frame
	assert(forest.active_skill == 1 and forest._sling_button.get("active"))
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.95)
	await process_frame
	assert(forest.active_skill == 1) # One switch per squeeze.
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	_button(JOY_BUTTON_Y)
	await process_frame
	assert(forest._stones.size() == 1 and forest.sling_cooldown > 0.0)
	_button(JOY_BUTTON_Y, false)
	_button(JOY_BUTTON_Y)
	await process_frame
	assert(forest._stones.size() == 1)
	_button(JOY_BUTTON_Y, false)
	assert(forest._sling_button.get("prompt") == "Y / Triangle")
	assert(forest._shoo_button.get("prompt") == "LT / RT")
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.9)
	await process_frame
	assert(forest.active_skill == 0 and forest._shoo_button.get("active"))
	_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	_button(JOY_BUTTON_Y)
	await process_frame
	assert(forest.shoo_cooldown > 0.0)
	_button(JOY_BUTTON_Y, false)
	# A collects food without casting; walking in controller mode is manual pickup.
	var food_cell: Vector2i = forest.START
	forest.player_position = forest._cell_center(food_cell)
	forest.objects[forest._index(food_cell)] = forest.MUSHROOM
	var old_mushrooms: int = forest.basket
	forest._process(0.0)
	assert(forest.basket == old_mushrooms)
	_button(JOY_BUTTON_A)
	await process_frame
	assert(forest.basket == old_mushrooms + 1 and forest._stones.size() == 1)
	assert(forest._inventory.get("mushrooms") == forest.basket)
	assert(forest.objects[forest._index(food_cell)] == forest.EMPTY)
	_button(JOY_BUTTON_A, false)
	food_cell += Vector2i(2, 0)
	forest.objects[forest._index(food_cell)] = forest.BERRIES
	var old_berries: int = forest.berries_basket
	_button(JOY_BUTTON_A)
	await process_frame
	assert(forest.berries_basket == old_berries) # Too far away.
	_button(JOY_BUTTON_A, false)
	forest.player_position = forest._cell_center(food_cell)
	forest.player_stun = 0.5
	_button(JOY_BUTTON_A)
	await process_frame
	assert(forest.berries_basket == old_berries)
	_button(JOY_BUTTON_A, false)
	forest.player_stun = 0.0
	_button(JOY_BUTTON_A)
	await process_frame
	assert(forest.berries_basket == old_berries + 1)
	assert(forest._inventory.get("berries") == forest.berries_basket)
	_button(JOY_BUTTON_A, false)
	forest._animals[0]["alive"] = false
	forest._animals[1]["alive"] = false
	_axis(JOY_AXIS_RIGHT_X, 0.9)
	await process_frame
	assert(forest.selected_target == -1)
	_axis(JOY_AXIS_RIGHT_X, 0.0)
	assert(is_equal_approx(float(forest._sling_button.get("cooldown")), forest.sling_cooldown))
	_button(JOY_BUTTON_BACK)
	await process_frame
	assert(forest._minimap.visible and forest._map_toggle.visible)
	_button(JOY_BUTTON_BACK, false)
	_button(JOY_BUTTON_START)
	await process_frame
	assert(forest._help_panel.visible and forest._hint_label.visible)
	_button(JOY_BUTTON_START, false)
	# Switching back to keyboard updates prompts and can collapse open panels.
	var key := InputEventKey.new()
	key.keycode = KEY_M
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	assert(not forest._minimap.visible)
	assert(forest._sling_button.get("prompt") == "RMB / F")
	key.pressed = false
	Input.parse_input_event(key)
	key = InputEventKey.new()
	key.keycode = KEY_H
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	assert(not forest._help_panel.visible and not forest._hint_label.visible)
	key.pressed = false
	Input.parse_input_event(key)
	print("Controller smoke test passed: analog movement/deadzone, D-pad, right-stick targeting, trigger skill selection, Y cast, A pickup, inventory and panel toggles")
	quit()
