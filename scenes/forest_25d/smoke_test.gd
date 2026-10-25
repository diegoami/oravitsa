extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var clearing = load("res://scenes/forest_25d/clearing.tscn").instantiate()
	root.add_child(clearing)
	current_scene = clearing
	clearing.set_process(false)
	await process_frame
	clearing._sync_presentation(1.0)
	assert(clearing.view.current and not clearing._camera.enabled)
	assert(clearing.heroine.sprite_frames == clearing.PLAYER_WALK)
	assert(clearing.heroine.billboard == BaseMaterial3D.BILLBOARD_ENABLED)
	assert(not clearing.heroine.no_depth_test)
	assert(not clearing._map_visible and not clearing._instructions_visible)
	var point := Vector2(3.25, -6.75)
	assert(clearing.to_ground(clearing.from_ground(point)).distance_to(point) < 0.001)
	assert(not clearing._can_stand(clearing.from_ground(Vector2(-9, -5))))
	assert(not clearing._can_stand(clearing.from_ground(Vector2(clearing.landscape.EXTENT + 1, 0))))
	var bridge_x: float = clearing.landscape.river_x(5)
	for dx in [-1.5, 0.0, 1.5]:
		var crossing := Vector2(bridge_x + dx, 5)
		assert(clearing._can_stand(clearing.from_ground(crossing)))
		assert(is_equal_approx(clearing.landscape.height_at(crossing), 0.27))
	assert(not clearing._can_stand(clearing.from_ground(Vector2(4.55, -4))))
	assert(clearing._can_stand(clearing.from_ground(Vector2(7, -1.7))))
	clearing.player_position = clearing.from_ground(Vector2(7, -3))
	clearing._sync_presentation(0.1)
	assert(is_equal_approx(clearing.heroine.position.y, 0.57))
	for roof in clearing.landscape.roofs:
		assert(not roof.visible)
	clearing.player_position = clearing.from_ground(Vector2.ZERO)
	Input.action_press("move_right")
	var before: Vector2 = clearing.player_position
	clearing._process(0.1)
	Input.action_release("move_right")
	assert(clearing.player_position.x > before.x)
	assert(clearing.heroine.position.distance_to(clearing.to_world(clearing.player_position) + Vector3.UP * 0.02) < 0.001)
	assert(clearing.heroine.frame == clearing._player.frame)
	for roof in clearing.landscape.roofs:
		assert(roof.visible)
	# The deer is genuinely rigged and uses its source animation clips.
	assert(clearing._animal_models.size() == clearing._active_animals.size())
	var animator: AnimationPlayer = clearing._animal_players[0]
	assert(animator.has_animation("Walk") and animator.has_animation("Idle"))
	clearing._animals[0]["eat_time"] = 0.0
	clearing._animals[0]["velocity"] = Vector2(50, 0)
	clearing._sync_presentation(0.1)
	assert(animator.current_animation == "Walk")
	clearing._animals[0]["state"] = "forage"
	clearing._animals[0]["eat_time"] = 0.2
	clearing._animals[0]["velocity"] = Vector2.ZERO
	clearing._sync_presentation(0.1)
	assert(animator.current_animation == "Eating")
	clearing._animals[0]["state"] = "flee"
	clearing._animals[0]["velocity"] = Vector2(50, 0)
	clearing._sync_presentation(0.1)
	assert(animator.current_animation == "Walk")
	clearing.view.position = clearing.to_world(clearing.player_position) + clearing.CAMERA_OFFSET
	var target: Vector3 = clearing.to_world(clearing._animals[0]["position"]) + Vector3.UP * 0.8
	clearing._select_sling_target(clearing.view.unproject_position(target))
	assert(clearing.selected_target == 0)
	clearing._use_skill(1)
	assert(clearing._stones.size() == 1)
	clearing._update_sling(1.0)
	clearing._sync_presentation(0.1)
	assert(clearing._animals[0]["alive"] and clearing._animals[0]["stun"] > 0)
	assert(clearing._animal_stars[0].visible and animator.speed_scale == 0.0)
	# Pickups remove the visible 3D object as well as updating the shared bag.
	var cell: Vector2i = clearing.START + Vector2i(1, 1)
	assert(clearing._forage_visuals.has(cell))
	clearing.player_position = clearing._cell_center(cell)
	clearing._collect_nearby()
	assert(clearing.basket == 1 and not clearing._forage_visuals.has(cell))
	assert(clearing._inventory.get("mushrooms") == 1)
	# Exercise the controller actions in the new scene, not just its 2D parent.
	var shoulder := InputEventJoypadButton.new()
	shoulder.button_index = JOY_BUTTON_LEFT_SHOULDER
	shoulder.pressed = true
	Input.parse_input_event(shoulder)
	await process_frame
	assert(clearing.active_skill == 0)
	shoulder.pressed = false
	Input.parse_input_event(shoulder)
	var cast := InputEventJoypadButton.new()
	cast.button_index = JOY_BUTTON_Y
	cast.pressed = true
	Input.parse_input_event(cast)
	await process_frame
	assert(clearing.shoo_cooldown > 0)
	cast.pressed = false
	Input.parse_input_event(cast)
	print("2.5D smoke test passed: shared controller/HUD, sprite depth and gait, terrain height, water/bridge/walls/doorway, roof cutaway, rigged deer, screen targeting, non-lethal sling and 3D pickup removal")
	quit()
