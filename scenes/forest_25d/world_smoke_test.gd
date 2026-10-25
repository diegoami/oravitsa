extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _travel(world: Node2D, point: Vector2) -> void:
	world.player_position = world.from_ground(point)
	world.view.position = world.to_world(world.player_position) + world.CAMERA_OFFSET
	world._refresh_visible()
	world._sync_presentation(0.0)
	await process_frame


func _run() -> void:
	var world = load("res://scenes/forest_25d/clearing.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	await process_frame
	assert(world.landscape.EXTENT == 96.0)
	assert(world.landscape.LAKES.size() == 3 and world.landscape.bridges.size() == 4)
	assert(world.landscape.SITES.size() == 5)
	var beside_bridge := Vector2(world.landscape.river_x(5), 6.3)
	assert(world.landscape.is_water(beside_bridge) and not world.landscape.is_bridge(beside_bridge))
	assert(world.landscape.height_at(beside_bridge) < -0.08)
	for cells in world._food_by_chunk.values():
		for cell in cells:
			assert(not world.landscape.is_bridge(world.to_ground(world._cell_center(cell))))
	var counts := [0, 0, 0, 0, 0]
	for animal in world._animals:
		counts[animal["kind"]] += 1
		assert(world._can_stand(animal["position"], world.ANIMAL_RADIUS[animal["kind"]]))
		if animal["kind"] == world.LYNX:
			assert(animal["position"].distance_to(world._cell_center(world.START)) > 1800)
	assert(world._animals.size() >= 100)
	assert(counts[world.HARE] > counts[world.DEER] and counts[world.HARE] > counts[world.FOX])
	assert(counts[world.DEER] > counts[world.BOAR] and counts[world.FOX] > counts[world.BOAR])
	assert(counts[world.BOAR] > counts[world.LYNX])
	assert(counts[world.LYNX] > 0)
	# Collision works before a distant render chunk has ever been loaded.
	assert(not world._can_stand(world.from_ground(Vector2(38, -44))))
	var blocked := Vector3.ZERO
	for b in world.landscape.blockers:
		if Vector2(b.x, b.y).length() > 60 and absf(b.x) < 85 and absf(b.y) < 85:
			blocked = b
			break
	assert(blocked != Vector3.ZERO)
	assert(not world._can_stand(world.from_ground(Vector2(blocked.x, blocked.y))))
	# Gather, stream far away, return: the resource must stay gathered.
	var food_cell: Vector2i = world.START + Vector2i(1, 1)
	world.player_position = world._cell_center(food_cell)
	world._collect_nearby()
	assert(world.basket == 1)
	var original_chunks: Array = world.landscape.chunks.keys()
	var peak_chunks: int = world.landscape.chunks.size()
	var saw_fox := false
	var saw_hare := false
	for point in [Vector2(45, -30), Vector2(-64, 28), Vector2(-55, -45), Vector2(35, 58), Vector2(86, 84), Vector2(-86, -84)]:
		await _travel(world, point)
		peak_chunks = maxi(peak_chunks, world.landscape.chunks.size())
		assert(world.landscape.chunks.size() <= 25)
		assert(world._animal_models.size() == world._active_animals.size())
		assert(world._animal_models.size() < world._animals.size() / 2)
		for id in world._animal_models:
			if world._animals[id]["kind"] == world.FOX:
				saw_fox = true
				assert(world._animal_players[id].has_animation("Walk"))
			elif world._animals[id]["kind"] == world.HARE:
				saw_hare = true
				assert(world._animal_models[id] is AnimatedSprite3D)
	for key in original_chunks:
		assert(not world.landscape.chunks.has(key))
	assert(saw_fox and saw_hare)
	await _travel(world, Vector2.ZERO)
	assert(world.objects[world._index(food_cell)] == world.EMPTY)
	assert(not world._forage_visuals.has(food_cell) and world.basket == 1)
	# A lynx catch removes the visible prey; respawning offscreen must not
	# recreate its model until that area becomes active again.
	var lynx := -1
	var hare := -1
	for id in world._animals.size():
		if world._animals[id]["kind"] == world.LYNX:
			lynx = id
		elif hare < 0 and world._animals[id]["kind"] == world.HARE:
			hare = id
	world._animals[lynx]["position"] = world.from_ground(Vector2(14.5, 5))
	world._animals[hare]["position"] = world.from_ground(Vector2(15, 5))
	world._refresh_visible()
	assert(world._animal_models.has(hare))
	assert(world._catch_prey(lynx, hare, 0.1))
	world._sync_presentation(0.0)
	assert(not world._animal_models.has(hare) and not world._animals[hare]["alive"])
	await _travel(world, Vector2(70, 70))
	world._move_animals(2.0)
	assert(world._animals[lynx]["feeding"] == 0.0 and world._animals[lynx]["state"] == "idle")
	world._update_respawns(world.PREY_RESPAWN_TIME)
	world._sync_presentation(0.0)
	assert(world._animals[hare]["alive"] and not world._animal_models.has(hare))
	await _travel(world, Vector2.ZERO)
	assert(world._animal_models.has(hare))
	# Widening the window while stationary expands streaming coverage.
	root.size = Vector2i(2560, 720)
	world._layout_hud()
	await process_frame
	await process_frame
	world._sync_presentation(0.0)
	var half: Vector2 = world._visible_half()
	for p in [Vector2(-half.x, -half.y), Vector2(half.x, half.y)]:
		var key := Vector2i(floori(p.x / world.landscape.CHUNK), floori(p.y / world.landscape.CHUNK))
		assert(world.landscape.chunks.has(key))
	await _travel(world, Vector2(94, 84))
	for p in [Vector2(94, 84) - half, Vector2(94, 84) + half]:
		var key := Vector2i(floori(p.x / world.landscape.CHUNK), floori(p.y / world.landscape.CHUNK))
		assert(world.landscape.chunks.has(key))
	for tick in 3:
		world._replenish_local_animals()
	world._sync_presentation(0.0)
	assert(world._animal_models.size() == world._active_animals.size())
	assert(world._animals.size() <= 260)
	# Reachability is checked on the actual player-radius collision map. This
	# catches disconnected river banks and decorative bridges that cannot be used.
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	var visited := {Vector2i.ZERO: true}
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = p + offset
			if visited.has(next) or not world.landscape.can_walk(Vector2(next), world.PLAYER_RADIUS / world.METRE):
				continue
			visited[next] = true
			queue.append(next)
	for site in world.landscape.SITES:
		assert(visited.has(Vector2i(site)))
	assert(visited.size() > 22000)
	print("Expanded world test passed: species counts [boar,deer,fox,lynx,hare]=", counts, "; peak nearby chunks=", peak_chunks, "; reachable square-metre cells=", visited.size(), "; persistent pickups, model unloading and stationary resize coverage")
	quit()
