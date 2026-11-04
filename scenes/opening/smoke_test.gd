extends SceneTree

## Protects: an idle/player-driven demo, stuck automation, a skipped splash,
## demo save writes, advancing instructions, and dirty/bot-driven player runs.


func _initialize() -> void:
	call_deferred("_run")


func _key(code: Key, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)


## A long autonomous run need not end beside the same empty tile. Place the
## skill fixture on verified open ground within the bot's reaction radius.
func _place_threat(world: Node2D) -> int:
	for distance in [180.0, 240.0, 300.0, 120.0, 60.0]:
		for angle in 16:
			var point: Vector2 = world.player_position + Vector2.from_angle(angle * TAU / 16.0) * distance
			if world._can_stand(point, world.ANIMAL_RADIUS[world.WOLF]):
				world._animals.append(world._animal_record(world.WOLF, point))
				return world._animals.size() - 1
	assert(false, "Threat fixture needs clear ground within reaction range")
	return -1


func _run() -> void:
	var opening = load("res://scenes/opening/opening.tscn").instantiate()
	root.add_child(opening)
	current_scene = opening
	await process_frame
	var demo: Node2D = opening.world
	demo.set_process(false)
	assert(opening.state == opening.DEMO and "DEMO MODE" in opening.demo_badge.text)
	assert(demo.get_node("HUD").visible and not demo._pause.visible)
	assert(not demo._can_save() and not demo.is_processing_unhandled_input())
	var save_before := ""
	if FileAccess.file_exists(demo.SAVE_GAME.PATH):
		save_before = FileAccess.get_sha256(demo.SAVE_GAME.PATH)
	demo.save_path = "user://opening-save-isolation-test.json"
	var sentinel := FileAccess.open(demo.save_path, FileAccess.WRITE)
	sentinel.store_string("untouched manual save")
	sentinel.close()
	demo._save_game()
	demo._load_game()
	assert(FileAccess.get_file_as_string(demo.save_path) == "untouched manual save")
	DirAccess.remove_absolute(demo.save_path)
	# Directly-polled actions cannot steer or sprint the demo either.
	Input.action_press("move_left")
	Input.action_press("sprint")
	demo._touch_controls.direction = Vector2.RIGHT
	demo.bot.direction = Vector2.DOWN
	assert(demo._movement_direction() == Vector2.DOWN and not demo._sprint_requested())
	Input.action_release("move_left")
	Input.action_release("sprint")
	demo._touch_controls.direction = Vector2.ZERO
	_key(KEY_F, true)
	_key(KEY_F, false)
	_key(KEY_P, true)
	_key(KEY_P, false)
	await process_frame
	assert(demo._stones.is_empty() and not paused, "Player skills and pause cannot hijack demo")
	# Run five simulated minutes with ordinary gameplay updates, including food
	# depletion, wildlife, hunger, streaming and animation. No scripted pickups.
	var progress_at: Vector2 = demo.absolute_ground(demo.player_position)
	var stationary := 0.0
	for frame in 9000:
		demo._process(1.0 / 30.0)
		assert(demo._can_stand(demo.player_position), "Bot never walks through scenery")
		if frame % 90 == 89:
			var at: Vector2 = demo.absolute_ground(demo.player_position)
			stationary = stationary + 3.0 if at.distance_to(progress_at) < 0.5 else 0.0
			assert(stationary < 9.0, "Bot must recover from stalled or oscillating movement")
			progress_at = at
		if frame % 300 == 0:
			await process_frame
	print("Demo observations: walked ", demo.bot.distance_walked, " m; food ", demo.bot.foods_collected, "; hares ", demo.bot.hares_collected, "; gifts ", demo.bot.gifts_given, "; reactions ", demo.bot.reactions)
	assert(demo.bot.distance_walked > 60.0, "Bot makes meaningful unattended progress")
	assert(demo.bot.foods_collected >= 3, "Bot actually gathers food")
	assert(not demo.discovered_hamlets.is_empty() and not demo.discovered_caves.is_empty(), "Bot reaches real villages and cave discoveries")
	assert(demo.bot.gifts_given > 0, "Bot gives food to a chieftain for aura")
	# A nearby threat is handled through the real selected-target skill path.
	assert(demo.bot.hares_collected > 0, "Bot stuns and collects hares through ordinary gameplay")
	for id in demo._active_animals:
		if demo._animals[id]["kind"] in demo.AGGRO_KINDS:
			demo._animals[id]["position"] += Vector2(3000, 3000)
	var wolf := _place_threat(demo)
	assert(demo._can_stand(demo._animals[wolf]["position"], demo.ANIMAL_RADIUS[demo.WOLF]))
	demo._refresh_visible()
	demo.player_stun = 0.0
	demo.player_fright = 0.0
	demo.shoo_cooldown = 0.0
	demo.bot.update(0.05)
	assert(demo._animals[wolf]["shoo"] > 0.0 and demo.shoo_cooldown > 0.0, "Bot Shoos wildlife")
	demo.player_stun = 1.0
	demo.cure_cooldown = 0.0
	demo.bot.update(0.05)
	assert(demo.player_stun == 0.0 and demo.cure_cooldown > 0.0, "Bot recovers with Cure")
	# Explicitly obstruct a goal with the starting cottage. The bot must plan
	# around it, rather than press into its wall or teleport through it.
	demo.player_position = demo._local_point([3.0, -4.0])
	assert(demo._can_stand(demo.player_position))
	assert(not demo._can_stand(demo._local_point([4.5, -4.0])))
	for id in demo._active_animals:
		demo._animals[id]["position"] += Vector2(3000, 3000)
	demo.bot.goal = Vector2(11, -4)
	demo.bot.goal_kind = "roam"
	demo.bot.food_cell = Vector2i(1 << 28, 1 << 28)
	demo.bot.goal_age = 0.0
	demo.bot.stuck = 0.0
	demo.bot.replan = 0.0
	demo.bot.route.clear()
	var went_around := false
	for frame in 420:
		demo._process(1.0 / 30.0)
		assert(demo._can_stand(demo.player_position))
		if demo.absolute_ground(demo.player_position).distance_to(Vector2(11, -4)) < 0.8:
			went_around = true
			break
	assert(went_around, "Bot routes around a cottage blocking the direct path")
	var recoveries: int = demo.bot.recoveries
	var before_escape: Vector2 = demo.player_position
	demo.bot.stuck = 2.0
	demo.bot.update(0.05)
	assert(demo.bot.recoveries == recoveries + 1 and not demo.bot.route.is_empty())
	assert(demo.player_position == before_escape, "Recovery plans ordinary movement, never teleports")
	var old_demo: WeakRef = weakref(demo)
	demo.bot.visited.clear()
	assert(demo.bot.seek_landmark("hamlet", Vector2.ZERO), "Bot seeks a real village")
	assert(demo.bot.goal_kind == "hamlet" and "Visiting" in demo.bot.activity)
	assert(demo.bot.seek_landmark("cave", Vector2.ZERO), "Bot seeks a real cave mouth")
	assert(demo.bot.goal_kind == "cave" and "cave mouth" in demo.bot.activity)
	opening.demo_time = opening.DEMO_SECONDS
	opening._process(0.0)
	assert(old_demo.get_ref() == null and opening.demo_time == 0.0, "Attract loops discard demo state")
	demo = opening.world
	# Start needs a release, repeats cannot skip, and instructions freeze time.
	_key(KEY_ENTER, true)
	await process_frame
	assert(opening.state == opening.DEMO)
	_key(KEY_ENTER, true, true)
	_key(KEY_ENTER, false)
	await process_frame
	assert(opening.state == opening.RULES and opening.rules.visible)
	assert(demo.bot.direction == Vector2.ZERO)
	var before := [demo.player_position, demo.fed, demo._food_clock]
	for frame in 10:
		await process_frame
	assert(before == [demo.player_position, demo.fed, demo._food_clock], "Rules freeze the demo")
	# Responsive instructions leave space for scrolling and confirmation.
	root.content_scale_size = Vector2i(640, 360)
	root.size = Vector2i(640, 360)
	await process_frame
	assert(opening.card.position.x >= 0 and opening.card.position.y >= 0)
	assert(opening.card.get_global_rect().end.y <= root.get_visible_rect().end.y)
	var scroll_before: float = opening.rules.get_v_scroll_bar().value
	_key(KEY_PAGEDOWN, true)
	_key(KEY_PAGEDOWN, false)
	await process_frame
	assert(opening.rules.get_v_scroll_bar().value > scroll_before, "Keyboard can scroll overflowing instructions")
	opening.guard = 0.0
	Input.action_press("move_right")
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	Input.parse_input_event(accept)
	accept = accept.duplicate()
	accept.pressed = false
	Input.parse_input_event(accept)
	await process_frame
	assert(opening.state == opening.STARTING, "Controller confirms instructions")
	opening._process(0.3)
	assert(opening.state == opening.STARTING, "Held controls cannot leak into gameplay")
	Input.action_release("move_right")
	opening._process(0.3)
	assert(opening.state == opening.PLAYING)
	var game: Node2D = opening.world
	game.set_process(false)
	assert(game.get_script() == load("res://scenes/endless_woods/woods.gd"))
	assert(game.player_position == game._cell_center(game.START))
	assert(game.basket == 0 and game.berries_basket == 0 and game.raw_meat == 0)
	assert(game.fed == game.FED_START and game.aura == 0 and game._food_clock == 0.0)
	assert(game._harvested.is_empty() and game.explored.is_empty() and game._stones.is_empty())
	assert(game._can_save() and game.get_node("HUD").visible and game._pause.visible)
	Input.action_press("move_right")
	assert(game._movement_direction().x > 0.0, "Player controls work after confirmation")
	Input.action_release("move_right")
	# Touch buttons also work with the project's mouse emulation disabled.
	var touch_opening = load("res://scenes/opening/opening.tscn").instantiate()
	root.add_child(touch_opening)
	await process_frame
	for stage in 2:
		touch_opening.guard = 0.0
		var finger := InputEventScreenTouch.new()
		finger.index = 0
		finger.position = touch_opening.action.get_global_rect().get_center()
		finger.pressed = true
		touch_opening._input(finger)
		assert(touch_opening.state == stage, "A held touch cannot activate")
		finger = finger.duplicate()
		finger.pressed = false
		touch_opening._input(finger)
		assert(touch_opening.state == stage + 1, "Touch release activates once")
		await process_frame
	touch_opening.free()
	if save_before != "":
		assert(FileAccess.get_sha256(game.SAVE_GAME.PATH) == save_before)
	else:
		assert(not FileAccess.file_exists(game.SAVE_GAME.PATH))
	opening.free()
	await process_frame
	print("Opening smoke test passed: unattended bot gathers, avoids scenery, Shoos, Cures, repeats, isolates inputs and saves, freezes instructions, resizes, and hands a fresh world to the player")
	quit()
