extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _on_screen(world: Node2D, spot: Vector2, kind: int) -> bool:
	var ground: Vector3 = world.to_world(spot)
	# Camera projection uses logical viewport pixels, not physical window pixels
	# when canvas stretch scales an ultrawide/portrait window.
	var viewport := world.get_viewport_rect()
	for h in [0.0, float(world._animal_heights[kind])]:
		if viewport.has_point(world.view.unproject_position(ground + Vector3.UP * h)):
			return true
	return false


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var world = load("res://scenes/forest_25d/clearing.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	await process_frame
	var hare := -1
	for id in world._animals.size():
		if world._animals[id]["kind"] == world.HARE:
			hare = id
			break
	var saved: Dictionary = world._animals[hare].duplicate(true)
	world.player_position = world.from_ground(Vector2(20, 10))
	world.view.position = world.to_world(world.player_position) + world.CAMERA_OFFSET
	world._refresh_visible()
	var home: Vector2 = world.from_ground(Vector2(28, 10))
	assert(_on_screen(world, home, world.HARE) and world._can_stand(home))
	world._animals[hare]["home"] = home
	world._animals[hare]["alive"] = false
	world._animals[hare]["respawn"] = 0.0
	world._update_respawns(0.016)
	assert(not world._animals[hare]["alive"], "Prey must wait while its home is on screen")
	world.player_position = world.from_ground(Vector2(70, 70))
	world.view.position = world.to_world(world.player_position) + world.CAMERA_OFFSET
	world._refresh_visible()
	world._update_respawns(3.1)
	assert(world._animals[hare]["alive"], "Hidden prey home must eventually respawn")
	world._animals[hare] = saved
	var found := 0
	for size in [Vector2i(1280, 720), Vector2i(2560, 1080), Vector2i(720, 1280)]:
		root.size = size
		await process_frame
		await process_frame
		world.player_position = world.from_ground(Vector2(20, 10))
		# Keep the camera behind the player to exercise smoothing lag as well.
		world.view.position = world.to_world(world.player_position) + world.CAMERA_OFFSET + Vector3(-2, 0, 1)
		world._refresh_visible()
		var valid := 0
		for tick in 200:
			world._population_tick = tick
			for kind in [world.HARE, world.DEER, world.FOX, world.BOAR]:
				var cell: Vector2i = world._find_local_spawn(kind)
				if cell.x < 0:
					continue
				valid += 1
				var spot: Vector2 = world._cell_center(cell)
				assert(not _on_screen(world, spot, kind), "Replenished animal must not appear in the visible viewport")
		assert(valid > 0, "Offscreen spawning must still find valid entries")
		found += valid
	print("Spawn smoke test passed: visible-home respawn deferral, hidden recovery and ", found, " offscreen entries across three viewports with camera lag")
	quit()
