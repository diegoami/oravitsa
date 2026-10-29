extends SceneTree

## Only a stunned hare in reach can be collected, once, as raw meat (#19).


func _initialize() -> void:
	call_deferred("_run")


func _button(button: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)


func _run() -> void:
	var world = load("res://scenes/endless_woods/woods.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	await process_frame
	for sprite in world._active_animals.values():
		sprite.queue_free()
	world._active_animals.clear()
	world._sync_animal_lifecycle()
	world._animals.clear()
	for kind in [world.HARE, world.DEER, world.HARE]:
		world._add_animal(kind, world.START + Vector2i(4, 0))
	world._refresh_visible()
	world._sync_presentation(0.0)
	var hare: Dictionary = world._animals[0]
	var deer: Dictionary = world._animals[1]
	world._animals[2]["position"] = world.player_position + Vector2(0, 2000)
	# An alert hare in reach cannot be taken.
	hare["position"] = world.player_position + Vector2(60, 0)
	world._collect_nearby()
	assert(world.raw_meat == 0 and hare["alive"])
	# A stunned hare beyond reach cannot be taken either; the prompt guides.
	hare["stun"] = 3.0
	hare["position"] = world.player_position + Vector2(world.HARE_PICKUP_RADIUS + 40, 0)
	world._collect_nearby()
	assert(world.raw_meat == 0 and hare["alive"])
	world._show_controller_hint()
	assert(world._inventory.get("pickup_prompt") == "Get closer to take the hare")
	# A stunned deer in reach is never collectable.
	deer["stun"] = 3.0
	deer["position"] = world.player_position + Vector2(-60, 0)
	world._collect_nearby()
	assert(deer["alive"] and world.raw_meat == 0)
	# Oravitsa walks straight through the stunned deer, and nobody is stunned.
	assert(world._active_animals.has(1))
	var walk_start: Vector2 = world.player_position
	for step in 12:
		assert(world._try_move(Vector2(-10, 0)), "A stunned animal never blocks Oravitsa")
	assert(world.player_stun == 0.0 and deer["stun"] == 3.0)
	# Once it is awake, walking into it is a bump again.
	world.player_position = walk_start
	deer["stun"] = 0.0
	deer["position"] = walk_start + Vector2(-40, 0)
	assert(not world._try_move(Vector2(-10, 0)) and is_equal_approx(world.player_stun, world._player_stun_time(world.CONTACT_STUN_TIME)))
	world.player_stun = 0.0
	deer["position"] = world.player_position + Vector2(0, 1500)
	# Oravitsa cannot take it while she is stunned herself.
	hare["position"] = world.player_position + Vector2(60, 0)
	world._update_hud()
	assert(world._inventory.get("pickup_prompt") == "A / Cross: take stunned hare")
	world.player_stun = 0.5
	world._collect_nearby()
	assert(hare["alive"] and world.raw_meat == 0)
	world.player_stun = 0.0
	# Controller A collects it: the hare is removed and becomes one raw meat.
	world.selected_target = 0
	_button(JOY_BUTTON_A, true)
	await process_frame
	_button(JOY_BUTTON_A, false)
	assert(world.raw_meat == 1 and not hare["alive"])
	assert(not world._active_animals.has(0) and world.selected_target == -1)
	world._sync_presentation(0.0)
	assert(not world._animal_models.has(0), "A collected hare's model must disappear")
	assert(world._inventory.get("meat") == 1)
	assert(world._notice_label.visible and "raw meat" in world._notice_label.text)
	# Exactly once, even if collection is requested again.
	world._collect_hare(0)
	world._collect_nearby()
	assert(world.raw_meat == 1)
	# It leaves the sparse ecology: no prey respawn, not revived by streaming.
	assert(hare["gone"] and hare["respawn"] == world.PREDATOR_RETURN_DELAY)
	world._update_respawns(1000.0)
	world._refresh_visible()
	assert(not hare["alive"] and not world._active_animals.has(0))
	# Keyboard/touch use walk-over pickup like food.
	var other: Dictionary = world._animals[2]
	other["position"] = world.player_position + Vector2(50, 0)
	other["stun"] = 2.0
	world._refresh_visible()
	assert(world._active_animals.has(2))
	var key := InputEventKey.new()
	key.keycode = KEY_H
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	key.pressed = false
	Input.parse_input_event(key)
	assert(world._input_mode == "keyboard")
	world._process(1.0 / 60.0)
	assert(world.raw_meat == 2 and not other["alive"])
	# Collection never touches other inventory.
	assert(world.basket == 0 and world.berries_basket == 0)
	print("Hare meat smoke test passed: alert/out-of-reach/deer/self-stunned rejection, walking through stunned animals, prompts, controller A and walk-over pickup, single removal, raw meat inventory and notice, no respawn or streaming revival")
	quit()
