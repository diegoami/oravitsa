extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://prototypes/foraging_2d/game.tscn")
	assert(scene != null)
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	assert(game.patches.size() == 17)
	assert(game.basket == 0)
	assert(game.seconds_left > 0.0)

	var start: Vector2 = game.player_position
	Input.action_press("move_right")
	for i in 12:
		await process_frame
	Input.action_release("move_right")
	assert(game.player_position.x > start.x)

	game.player_position = game.patches[0]
	game._collect_patches()
	assert(game.basket == 1)
	assert(game.patches.size() == 16)

	game.boar_position = game.patches[0]
	game._move_boar(0.0)
	assert(game.boar_taken == 1)
	assert(game.boar_forage_pause > 0.0)
	assert(game.patches.size() == 15)

	game.boar_position = game.player_position + Vector2(40.0, 0.0)
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	game._unhandled_key_input(space)
	assert(game.shoo_left > 0.0)
	assert(game.shoo_ready_in > 0.0)

	game.restart_round()
	assert(game.basket == 0 and game.boar_taken == 0)
	assert(game.patches.size() == 17)
	assert(game.playing)
	print("2D foraging smoke test passed")
	quit()
