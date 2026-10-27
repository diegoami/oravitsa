extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _travel(world: Node2D, absolute: Vector2) -> void:
	world.player_position = world.from_ground(absolute - world.landscape.origin)
	world._rebase_if_needed()
	world.view.position = world.to_world(world.player_position) + world.CAMERA_OFFSET
	world._refresh_visible()
	world._sync_presentation(0.0)
	await process_frame


func _run() -> void:
	var world = load("res://scenes/endless_woods/woods.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	await process_frame
	assert(not world._map_visible and not world._instructions_visible)
	assert(world.objects is Dictionary and world.terrain is Dictionary)
	var counts := [0, 0, 0, 0, 0, 0]
	for animal in world._animals:
		counts[animal["kind"]] += 1
	assert(counts[world.WOLF] > 1 and counts[world.LYNX] > 1)
	assert(counts[world.HARE] > counts[world.WOLF] + counts[world.LYNX])
	var land: Node3D = world.landscape
	assert(absf(land.road_z(64, 0) - lerpf(land.road_z(0, 0), land.road_z(128, 0), 0.5)) > 1, "Road must curve between endpoints")
	var biomes := {}
	var landmarks := {}
	for x in range(-4, 5):
		for z in range(-4, 5):
			biomes[land.biome_at(Vector2(x * 90, z * 90))] = true
			landmarks[land.landmark_at(Vector2i(x, z))["kind"]] = true
	assert(biomes.size() == 4 and landmarks.size() == 4)
	# Both road families stay passable, including river crossings, outside the
	# original map in positive/negative coordinates and across chunk seams.
	for row in [-4, 0, 3]:
		for x in range(-512, 513, 8):
			assert(land.can_walk(Vector2(x, land.road_z(x, row)), world.PLAYER_RADIUS / world.METRE), "East/west route must stay connected")
	for col in [-2, 0, 2]:
		for z in range(-512, 513, 8):
			assert(land.can_walk(Vector2(land.road_x(z, col), z), world.PLAYER_RADIUS / world.METRE), "North/south route must stay connected")
	var food: Vector2i = world._forage_visuals.keys()[0]
	var food_world: Vector2 = world.absolute_ground(world._cell_center(food))
	var key: int = world._index(food)
	world.player_position = world._cell_center(food)
	world._collect_nearby()
	assert(world._harvested.has(key))
	var basket: int = world.basket + world.berries_basket
	var reference := Vector2(20, 20)
	var reference_height: float = land.height_at(reference)
	var reference_trees: Array = land._ensure_nature(Vector2i(1, 1))["trees"].duplicate()
	for p in [Vector2(4096, land.road_z(4096, 2)), Vector2(-4096, land.road_z(-4096, -2)), Vector2(land.road_x(4096, 2), 4096), Vector2(land.road_x(-4096, -2), -4096)]:
		await _travel(world, p)
		assert(world.absolute_ground(world.player_position).distance_to(p) < 0.02)
		assert(world.to_ground(world.player_position).length() < 645, "Render coordinates must rebase rather than accumulating distance")
		var before: Vector2 = world.player_position
		assert(world._try_move(Vector2(2, 0)))
		assert(world.player_position.distance_to(before + Vector2(2, 0)) < 0.01, "Movement must not clamp to the finite map")
		for tick in 3:
			world._replenish_local_animals()
		world._sync_presentation(0.0)
		assert(land.chunks.size() <= 25 and land._nature.size() <= 256)
		assert(world._animals.size() <= 208 and world.objects.size() < 45000)
		assert(is_equal_approx(land.height_at(reference - land.origin), reference_height))
	await _travel(world, food_world)
	var restored_cell: Vector2i = world._world_cell(world.from_ground(food_world - land.origin))
	assert(world.objects[world._index(restored_cell)] == world.EMPTY)
	assert(not world._forage_visuals.has(restored_cell))
	assert(world.basket + world.berries_basket == basket)
	assert(land._ensure_nature(Vector2i(1, 1))["trees"] == reference_trees, "Unloaded nature must regenerate deterministically")
	# The water plane must not flood declared dry land on a low rolling hill.
	for x in range(-300, 301, 20):
		for z in range(-300, 301, 20):
			var p: Vector2 = Vector2(x, z) - land.origin
			if land.water_edge(p) > 1.7:
				assert(land.terrain_height_at(p) > -0.08)
	print("Endless world smoke test passed: six species ", counts, ", four biomes/landmarks, winding connected routes, four-direction 4 km travel, rebasing, bounded caches and persistent harvests")
	quit()
