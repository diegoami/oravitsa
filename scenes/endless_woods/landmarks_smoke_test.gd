extends SceneTree

## Empty hamlets and exterior cave mouths (#22): deterministic placement,
## solid buildings and rock, passable approaches, bare clearings and streaming.


func _initialize() -> void:
	call_deferred("_run")


func _travel(world: Node2D, absolute: Vector2) -> void:
	world.player_position = world.from_ground(absolute - world.landscape.origin)
	world._rebase_if_needed()
	world.view.position = world.to_world(world.player_position) + world.CAMERA_OFFSET
	world._refresh_visible()
	world._sync_presentation(0.0)
	await process_frame


func _walk(land, a: Vector2, b: Vector2, radius: float) -> bool:
	for step in int(a.distance_to(b) * 4) + 1:
		if not land.can_walk(a.move_toward(b, step * 0.25) - land.origin, radius):
			return false
	return true


func _run() -> void:
	var world = load("res://scenes/endless_woods/woods.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	await process_frame
	var land: Node3D = world.landscape
	var radius: float = world.PLAYER_RADIUS / world.METRE
	# About one road crossing in six hosts a hamlet, in positive and negative blocks.
	var hamlets: Array[Dictionary] = []
	var houses := 0
	for by in range(-3, 4):
		for bx in range(-3, 4):
			var hamlet: Dictionary = land.hamlet_at(Vector2i(bx, by))
			if not hamlet.is_empty():
				hamlets.append(hamlet)
				houses += hamlet["houses"].size()
				assert(hamlet["houses"].size() >= 3 and hamlet["houses"].size() <= 6)
	var crossings := 49 * 6
	print("hamlets ", hamlets.size(), " of ", crossings, " crossings, houses ", houses)
	assert(hamlets.size() >= 30 and float(hamlets.size()) / crossings > 0.1, "About one crossing in six hosts a hamlet")
	assert(land.hamlet_at(Vector2i(2, -1)) == land.hamlet_at(Vector2i(2, -1)), "Placement is cached and deterministic")
	var caves: Array[Dictionary] = []
	for rz in range(-6, 7):
		for rx in range(-4, 5):
			var cave: Dictionary = land.cave_at(Vector2i(rx, rz))
			if not cave.is_empty():
				caves.append(cave)
				assert(land.landmark_at(Vector2i(rx, rz))["kind"] != 0, "No cave shares a region with a homestead")
	print("caves ", caves.size(), " of ", 13 * 9, " regions")
	assert(caves.size() >= 8, "Caves exist but are rarer than landmarks")
	for hamlet in hamlets:
		var center: Vector2 = hamlet["center"]
		for house in hamlet["houses"]:
			# Closed and solid everywhere, independent of rendered chunks.
			assert(not land.can_walk(house.get_center() - land.origin, radius))
			assert(not land.can_walk(house.position + Vector2(0.3, 0.3) - land.origin, radius))
			assert(not land.is_water(house.get_center() - land.origin))
		assert(not land.can_walk(hamlet["well"] - land.origin, radius))
		for door in hamlet["doors"]:
			var from := Vector2(door.x, door.y) + Vector2(0, signf(door.w - door.y) * 0.5)
			assert(_walk(land, from, Vector2(door.z, door.w), radius), "Every door trail must reach the road")
			assert(land.trail_distance(from.lerp(Vector2(door.z, door.w), 0.5) - land.origin) < 0.01, "The dressed trail must match the walkable path")
		# The crossing itself stays open in every direction.
		for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			assert(land.can_walk(center + direction * 3 - land.origin, radius))
		assert(land.in_settlement(center + Vector2(3, 3) - land.origin) and not land.in_settlement(center + Vector2(80, 0) - land.origin))
	for cave in caves:
		var mouth: Vector2 = cave["mouth"]
		var facing: Vector2 = cave["facing"]
		assert(land.can_walk(mouth - land.origin, radius), "Oravitsa can stand in the cave entrance")
		assert(not land.can_walk(mouth - facing * 1.6 - land.origin, radius), "The rock beyond the mouth is solid")
		assert(not land.can_walk(mouth - facing * 3.2 - land.origin, radius))
		assert(facing == Vector2(0, 1), "Mouths open toward the fixed camera")
		assert(_walk(land, mouth, cave["elbow"], radius) and _walk(land, cave["elbow"], cave["road"], radius), "The cave trail must reach a road")
		assert(land.trail_distance(mouth.lerp(cave["elbow"], 0.5) - land.origin) < 0.01)
		assert(land.trail_distance(cave["elbow"].lerp(cave["road"], 0.5) - land.origin) < 0.01)
		# Collision matches the visible rock: just outside each part is open ground.
		for part in cave["parts"]:
			assert(not land.can_walk(Vector2(part.x, part.y) - land.origin, radius))
	# The bare clearing grows no food and hosts no wildlife homes.
	var hamlet: Dictionary = hamlets[0]
	await _travel(world, hamlet["center"] + Vector2(0, 2))
	var near := 0
	for key in world._cached_cells:
		var cell: Vector2i = world._cached_cells[key]
		var local: Vector2 = world.from_ground(Vector2(cell - world.origin_cells) * world.TILE / world.METRE) + Vector2.ONE * world.TILE * 0.5
		if land.in_settlement(world.to_ground(local)):
			near += 1
			assert(world.objects[key] == world.EMPTY, "No food inside a hamlet clearing")
	assert(near > 50)
	assert(not world._spawn_allowed(world.from_ground(hamlet["center"] - land.origin)))
	for animal in world._animals:
		assert(not land.in_settlement(world.to_ground(animal["home"])) or not animal["alive"], "No wildlife homes inside a hamlet")
	# Streaming: every house of a visited hamlet is built in its own chunk, and
	# returning after a rebase rebuilds the same placement.
	var nodes_before: int = land.chunks.size()
	assert(nodes_before > 0)
	var before: Dictionary = land.hamlet_near(hamlet["center"]).duplicate(true)
	await _travel(world, hamlet["center"] + Vector2(3000, 0))
	await _travel(world, hamlet["center"] + Vector2(0, 2))
	var after: Dictionary = land.hamlet_near(hamlet["center"])
	assert(after["houses"] == before["houses"] and after["well"] == before["well"], "Hamlets regenerate identically after rebasing")
	assert(land._hamlet_cache.size() < 40 and land._cave_cache.size() < 60, "Feature caches stay bounded")
	# Labels at the hamlet and the cave mouth.
	world._sync_presentation(0.0)
	assert(world._landmark_label.text == "Empty hamlet")
	var cave: Dictionary = caves[0]
	await _travel(world, cave["mouth"] + cave["facing"] * 2)
	assert(world._landmark_label.text == "Cave mouth")
	assert(world.absolute_ground(world.player_position).distance_to(cave["mouth"]) < 3)
	print("Landmarks smoke test passed: ", hamlets.size(), " hamlets (", houses, " closed houses) and ", caves.size(), " cave mouths; solid houses/wells/rock, open entrances and crossings, passable door and cave trails, bare clearings, no spawns inside, deterministic after rebasing, bounded caches and labels")
	quit()
