extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


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
	for kind in [world.WOLF, world.LYNX, world.DEER, world.HARE]:
		world._add_animal(kind, world.START + Vector2i(4, 0))
	world._refresh_visible()
	world._sync_presentation(0.0)
	assert(world._animal_players[0].has_animation("Walk") and world._animal_players[0].has_animation("Idle"))
	world._animals[0]["hunger"] = 100.0
	assert(not world._catch_prey(0, 2, 2.9))
	assert(world._catch_prey(0, 2, 0.2) and not world._animals[2]["alive"])
	assert(world._animals[0]["hunger"] == 0)
	world._sync_presentation(0.0)
	assert(world._animal_players[0].current_animation == "Eating")
	assert(world._catch_prey(1, 3) and not world._animals[3]["alive"])
	world.selected_target = 0
	world._use_skill(1)
	world._update_sling(1.0)
	assert(world._animals[0]["alive"] and world._animals[0]["stun"] > 0, "Sling must remain non-lethal to wolves")
	world._sync_presentation(0.0)
	assert(world._animal_stars[0].visible and "STUNNED 4." in world._animal_stars[0].text, "A stun shows its countdown")
	for id in [0, 1]:
		world._animals[id]["hunger"] = world.PREDATOR_HUNGER_LIMIT - 0.01
	world._move_animals(0.02)
	for id in [0, 1]:
		assert(not world._spawn_is_hidden(world._animals[id]["position"], world._animals[id]["kind"]))
		assert(world._animals[id]["alive"] and world._animal_models.has(id), "Hungry predators must not pop out in view")
		assert(world._animals[id]["hunger"] >= world.PREDATOR_HUNGER_LIMIT)
	# Once outside the view they leave, retaining hunger until that point.
	for id in [0, 1]:
		world._animals[id]["position"] = world.from_ground(Vector2(200 + id * 4, 200))
	world._move_animals(0.02)
	for id in [0, 1]:
		assert(not world._animals[id]["alive"] and world._animals[id]["gone"])
		assert(not world._animal_models.has(id))
	world._update_respawns(1000)
	assert(not world._animals[0]["alive"] and not world._animals[1]["alive"], "Starved predators must not use the prey respawn path")
	# Offscreen predators age too.
	world._animals[0]["alive"] = true
	world._animals[0]["gone"] = false
	world._animals[0]["position"] = world.from_ground(Vector2(200, 200))
	world._animals[0]["hunger"] = world.PREDATOR_HUNGER_LIMIT - 0.01
	world._move_animals(0.02)
	assert(world._animals[0]["gone"])
	# Route a wolf from behind the cottage, around a solid side wall and through
	# the front doorway. No teleport, no walking through trunks/walls/water.
	var start: Vector2 = world.from_ground(Vector2(7, -8))
	var target: Vector2 = world.from_ground(Vector2(7, -3))
	var wolf: Dictionary = world._animals[0]
	wolf["alive"] = true
	wolf["gone"] = false
	wolf["hunger"] = 0.0
	wolf["stun"] = 0.0
	wolf["feeding"] = 0.0
	wolf["position"] = start
	wolf["home"] = start
	wolf["target"] = target
	wolf["state"] = "roam"
	wolf["timeout"] = 100.0
	wolf["velocity"] = Vector2.ZERO
	wolf["stuck"] = 1.0
	wolf["nav_cooldown"] = 0.0
	world.player_position = world.from_ground(Vector2(0, 12))
	world.view.position = world.to_world(world.player_position) + world.CAMERA_OFFSET
	world._refresh_visible()
	var route: PackedVector2Array = world._plan_route(0, target)
	assert(route.size() > 3, "Recovery must find a path around the cottage")
	var visited_side := false
	for frame in 900:
		await process_frame
		world._move_animals(1.0 / 60.0)
		assert(world._can_stand(wolf["position"], world.ANIMAL_RADIUS[world.WOLF]))
		if absf(world.to_ground(wolf["position"]).x - 7) > 2.5:
			visited_side = true
		if wolf["position"].distance_to(target) < 40:
			break
	assert(visited_side and wolf["position"].distance_to(target) < 40, "Stuck animal must physically recover and reach the doorway")
	# Chase tuning (#16): endless wolves/lynxes spurt longer and faster than the
	# finite scenes; foxes hunt hares with weak spurts and rare catches.
	assert(world._burst_profile(world.WOLF).x > world.LYNX_BURST_SPEED and world._burst_profile(world.LYNX).y > world.LYNX_BURST_TIME)
	assert(world._burst_profile(world.FOX).x < world._burst_profile(world.WOLF).x)
	assert(world._prey_kinds(world.FOX) == [world.HARE] and world.FOX in world._threat_kinds(world.HARE))
	assert(world.HARE not in world._threat_kinds(world.FOX), "Endless foxes must not flee their prey")
	world._add_animal(world.FOX, world.START + Vector2i(4, 0))
	world._add_animal(world.HARE, world.START + Vector2i(4, 0))
	var fox: int = world._animals.size() - 2
	var hare: int = fox + 1
	var fox_catches := 0
	for attempt in 40:
		world._animals[fox]["hunt_rest"] = 0.0
		world._animals[hare]["alive"] = true
		assert(world._wants_to_hunt(fox))
		if world._catch_prey(fox, hare):
			fox_catches += 1
		else:
			assert(world._animals[hare]["alive"] and world._animals[fox]["hunt_rest"] == world.FOX_HUNT_REST)
			assert(not world._wants_to_hunt(fox), "A fox rests after a missed lunge")
	assert(fox_catches > 0 and fox_catches < 20, "Foxes catch hares rarely but not never")
	assert(not world._catch_prey(fox, 2) and world._animals[2]["kind"] == world.DEER, "Foxes never catch deer")
	world._animals[fox]["hunt_rest"] = 1.0
	world._move_animals(1.1)
	assert(world._animals[fox]["hunt_rest"] == 0.0, "Fox hunt rest recovers even offscreen")
	print("Endless wildlife smoke test passed: rigged wolf, wolf/deer pursuit, lynx/hare catch, non-lethal sling, feeding resets hunger, visible starvation deferral/offscreen removal, no predator auto-respawn, collision-safe stuck recovery, stronger predator spurts and rare fox hare catches")
	quit()
