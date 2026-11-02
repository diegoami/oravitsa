extends SceneTree

## Pause (#57): the Pause button, P / Esc and the controller's right-stick click
## freeze the whole game on the surface and in caves; Resume carries on.
## Protects: animals, monsters, hunger or timers running on while paused, and a
## pause that cannot be undone from the keyboard, a controller or the overlay.


func _initialize() -> void:
	call_deferred("_run")


func _frames(count: int) -> void:
	for frame in count:
		await process_frame


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


## A snapshot of everything pausing must hold still.
func _state(world: Node2D) -> Array:
	var positions := []
	for id in world._active_animals:
		positions.append(world._animals[id]["position"])
	return [world.fed, world._food_clock, world._meal_timer, world.player_position, positions, world.aura, world._aura_decay]


func _run() -> void:
	var world = load("res://scenes/endless_woods/woods.tscn").instantiate()
	world.fright_chance = 0.0
	world.aura = 50 # So aura decay (#64) is running and must stop while paused.
	root.add_child(world)
	current_scene = world
	await _frames(3)
	var pause: CanvasLayer = world._pause
	assert(not paused and pause.button.visible and pause.button.text.begins_with("Pause"))
	# P pauses: the overlay replaces the button and nothing moves, even while
	# she is told to walk.
	pause._unhandled_input(_key(KEY_P))
	assert(paused and pause.is_paused() and not pause.button.visible, "P pauses")
	Input.action_press("move_right")
	var before := _state(world)
	await _frames(20)
	assert(_state(world) == before, "Nothing runs on the surface while paused")
	# Resume carries on from where it stopped.
	pause._resume.pressed.emit()
	assert(not paused and pause.button.visible, "Resume unpauses")
	await _frames(20)
	Input.action_release("move_right")
	var after := _state(world)
	assert(after[1] > before[1] and after[0] < before[0] and after[3] != before[3], "The game runs again after Resume")
	# Esc and the HUD button pause; the right-stick click resumes.
	pause._unhandled_input(_key(KEY_ESCAPE))
	assert(paused, "Esc pauses")
	pause._unhandled_input(_key(KEY_ESCAPE))
	assert(not paused, "Esc resumes")
	pause.button.pressed.emit()
	assert(paused, "The Pause button pauses")
	var stick := InputEventJoypadButton.new()
	stick.button_index = JOY_BUTTON_RIGHT_STICK
	stick.pressed = true
	pause._unhandled_input(stick)
	assert(not paused, "The right-stick click resumes")
	world._input_mode = "controller"
	world._update_hud()
	assert(pause.button.text == "Pause [R3]" and "R3" in world._hint_label.text)
	# In a cave the monsters and her hunger hold still as well.
	var land: Node3D = world.landscape
	var cave: Dictionary = {}
	for rz in range(-3, 4):
		for rx in range(-3, 4):
			if cave.is_empty():
				cave = land.cave_at(Vector2i(rx, rz))
	assert(not cave.is_empty())
	world._enter_cave(cave, true)
	assert(world.in_cave())
	await _frames(5)
	pause.set_paused(true)
	before = _state(world)
	await _frames(20)
	assert(_state(world) == before, "Nothing runs in a cave while paused")
	pause.set_paused(false)
	await _frames(20)
	assert(world.fed < before[0], "Hunger resumes underground")
	# Leaving the scene while paused never leaves the tree frozen.
	pause.set_paused(true)
	world.queue_free()
	await process_frame
	assert(not paused, "Freeing the world unpauses the tree")
	print("Pause smoke test passed: P, Esc, the HUD button and R3 pause, Resume, Esc and R3 resume, and nothing moves or gets hungrier on the surface or in caves while paused")
	quit()
