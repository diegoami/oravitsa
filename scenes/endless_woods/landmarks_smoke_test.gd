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


## Loaded meshes centred on an absolute ground point that satisfy `matches`.
func _rendered_at(land, absolute: Vector2, matches: Callable) -> int:
	var count := 0
	for chunk in land.chunks.values():
		for node in chunk.get_children():
			var p: Vector3 = chunk.position + node.position
			if node is MeshInstance3D and Vector2(p.x, p.z).distance_to(absolute - land.origin) < 0.01 and matches.call(node):
				count += 1
	return count


## Visiting each element, the drawn hamlet and cave match their collision
## exactly once: house walls, the square well wall, every rock part and opening.
func _assert_rendered(world: Node2D, hamlet: Dictionary, cave: Dictionary) -> void:
	var land: Node3D = world.landscape
	if not hamlet.is_empty():
		for house in hamlet["houses"]:
			await _travel(world, house.get_center() + Vector2(0, 4))
			assert(_rendered_at(land, house.get_center(), func(n: MeshInstance3D) -> bool: return n.mesh is BoxMesh and n.mesh.size.is_equal_approx(Vector3(house.size.x, 2.5, house.size.y))) == 1, "Every solid house is drawn once at its collision size")
		await _travel(world, hamlet["well"] + Vector2(0, 2))
		var footprint := Rect2()
		var stones := 0
		for chunk in land.chunks.values():
			for node in chunk.get_children():
				if node is MeshInstance3D and node.mesh is BoxMesh and is_equal_approx(node.mesh.size.y, 0.7):
					var box: AABB = node.transform * node.get_aabb()
					var rect := Rect2(Vector2(box.position.x, box.position.z) + Vector2(chunk.position.x, chunk.position.z), Vector2(box.size.x, box.size.z))
					if rect.get_center().distance_to(hamlet["well"] - land.origin) < 1.0:
						footprint = rect if stones == 0 else footprint.merge(rect)
						stones += 1
		var expected := Rect2(hamlet["well"] - land.origin - Vector2.ONE * land.WELL_HALF, Vector2.ONE * land.WELL_HALF * 2)
		assert(stones == 4 and footprint.position.distance_to(expected.position) < 0.01 and footprint.size.distance_to(expected.size) < 0.01, "The drawn well wall is the well's collision square")
	if not cave.is_empty():
		await _travel(world, cave["mouth"] + cave["facing"] * 2)
		for part in cave["parts"]:
			assert(_rendered_at(land, Vector2(part.x, part.y), func(n: MeshInstance3D) -> bool: return n.mesh is SphereMesh and absf(n.mesh.radius * n.scale.x - part.z) < 0.01 and absf(n.mesh.radius * n.scale.z - part.z) < 0.01 and absf(n.mesh.height * 0.5 * n.scale.y - part.w) < 0.01) == 1, "Every solid rock part is drawn once at its collision radius")
		assert(_rendered_at(land, cave["mouth"] - cave["facing"] * 0.85, func(n: MeshInstance3D) -> bool: return n.mesh is BoxMesh and n.mesh.size.is_equal_approx(Vector3(1.8, 1.5, 0.5))) == 1, "The dark cave opening is drawn")


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
		# The square well wall is solid at its corners and open just beyond each side.
		var well: Vector2 = hamlet["well"]
		var reach: float = land.WELL_HALF + radius
		for corner in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			assert(not land.can_walk(well + corner * (reach - 0.05) - land.origin, radius), "No clipping into the well's corners")
		for side in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			assert(not land.can_walk(well + side * (reach - 0.05) - land.origin, radius))
			assert(land.can_walk(well + side * (reach + 0.05) - land.origin, radius), "No invisible wall around the well")
		for door in hamlet["doors"]:
			var from := Vector2(door.x, door.y) + Vector2(0, signf(door.w - door.y) * 0.5)
			assert(_walk(land, from, Vector2(door.z, door.w), radius), "Every door trail must reach the road")
			assert(land.trail_distance(from.lerp(Vector2(door.z, door.w), 0.5) - land.origin) < 0.01, "The dressed trail must match the walkable path")
		# The crossing itself stays open in every direction.
		for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			assert(land.can_walk(center + direction * 3 - land.origin, radius))
		assert(land.in_settlement(center + Vector2(3, 3) - land.origin) and not land.in_settlement(center + Vector2(80, 0) - land.origin))
	var open_samples := 0
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
		# Collision matches the drawn rock (see _assert_rendered): just inside each
		# part's surface is solid, and just outside it is open unless another part,
		# water or the unreserved woods beyond the outcrop are there.
		for part in cave["parts"]:
			var at := Vector2(part.x, part.y)
			assert(not land.can_walk(at - land.origin, radius))
			for i in 16:
				var direction := Vector2.from_angle(i * TAU / 16)
				assert(not land.can_walk(at + direction * (part.z + radius - 0.05) - land.origin, radius))
				var q: Vector2 = at + direction * (part.z + radius + 0.05)
				var covered: bool = q.distance_to(mouth - facing * 2.0) > 6.5 or land.is_water(q - land.origin, radius)
				for other in cave["parts"]:
					covered = covered or q.distance_to(Vector2(other.x, other.y)) < other.z + radius + 0.01
				if not covered:
					assert(land.can_walk(q - land.origin, radius), "No invisible rock wall short of the drawn surface")
					open_samples += 1
	assert(open_samples > caves.size() * 10, "Enough open ground beside the rock is sampled")
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
		assert(animal["kind"] == world.VILLAGER or not land.in_settlement(world.to_ground(animal["home"])) or not animal["alive"], "No wildlife homes inside a hamlet")
	await _assert_rendered(world, hamlet, {})
	# Streaming: every house of a visited hamlet is built in its own chunk, and
	# returning after a rebase rebuilds the same placement.
	var nodes_before: int = land.chunks.size()
	assert(nodes_before > 0)
	var before: Dictionary = land.hamlet_near(hamlet["center"]).duplicate(true)
	await _travel(world, hamlet["center"] + Vector2(3000, 0))
	assert(_rendered_at(land, hamlet["houses"][0].get_center(), func(_n: MeshInstance3D) -> bool: return true) == 0, "Far away, the hamlet's chunks are unloaded")
	await _travel(world, hamlet["center"] + Vector2(0, 2))
	var after: Dictionary = land.hamlet_near(hamlet["center"])
	assert(after["houses"] == before["houses"] and after["well"] == before["well"], "Hamlets regenerate identically after rebasing")
	assert(land._hamlet_cache.size() < 40 and land._cave_cache.size() < 60, "Feature caches stay bounded")
	# Labels at the hamlet and the cave mouth.
	world._sync_presentation(0.0)
	assert(world._landmark_label.text == "Hamlet")
	await _assert_rendered(world, after, {})
	var cave: Dictionary = caves[0]
	await _travel(world, cave["mouth"] + cave["facing"] * 2)
	assert(world._landmark_label.text == "Cave mouth")
	assert(world.absolute_ground(world.player_position).distance_to(cave["mouth"]) < 3)
	await _assert_rendered(world, {}, cave)
	# A save from before hamlets existed can put Oravitsa or an animal where a
	# house now stands, or a home in a clearing: loading moves them to the
	# nearest open ground, and leaves already valid positions exactly as saved.
	var house: Rect2 = hamlet["houses"][0]
	var save: Dictionary = world.save_state()
	save["player"]["ground"] = [house.get_center().x, house.get_center().y]
	save["player"]["stun"] = 0.0
	var other: Vector2 = hamlet["houses"][1].get_center()
	save["animals"][0].merge({"alive": true, "gone": false, "position": [other.x, other.y]}, true)
	save["animals"][0]["home"] = [hamlet["center"].x, hamlet["center"].y]
	var untouched: Array = save["animals"][1]["position"]
	world.apply_state(save)
	assert(world._can_stand(world.player_position), "A saved spot inside a new house is moved to open ground")
	assert(world.absolute_ground(world.player_position).distance_to(house.get_center()) < 4)
	var moves := 0
	for i in 8:
		var start: Vector2 = world.player_position
		if world._try_move(Vector2.from_angle(i * TAU / 8) * 3.5):
			moves += 1
		world.player_position = start
	assert(moves >= 3, "Oravitsa can walk away after loading")
	var moved: Dictionary = world._animals[0]
	assert(world._can_stand(moved["position"], world.ANIMAL_RADIUS[moved["kind"]]))
	assert(not land.in_settlement(world.to_ground(moved["home"])), "A saved home leaves the hamlet clearing")
	var kept: Vector2 = world.absolute_ground(world._animals[1]["position"])
	assert(kept.distance_to(Vector2(untouched[0], untouched[1])) < 0.001, "Valid saved positions are unchanged")
	# A living boar saved, validly, right where Oravitsa would otherwise land:
	# it keeps its spot and Oravitsa lands clear of it, free to move.
	var landing: Vector2 = world.absolute_ground(world.player_position)
	var boar_at := Vector2.INF
	for step in 40:
		var spot: Vector2 = landing + Vector2.from_angle(step * TAU / 8) * (0.2 + step / 8 * 0.15)
		if world._can_stand(world._local_point([spot.x, spot.y]), world.ANIMAL_RADIUS[world.BOAR]):
			boar_at = spot
			break
	assert(boar_at != Vector2.INF, "A valid boar spot overlaps the first landing")
	var boar: Dictionary = save["animals"][2]
	boar.merge({"kind": world.BOAR, "alive": true, "gone": false, "state": "idle", "position": [boar_at.x, boar_at.y], "home": [boar_at.x, boar_at.y], "target": [boar_at.x, boar_at.y]}, true)
	world.apply_state(save)
	var resting: Dictionary = world._animals[2]
	assert(world.absolute_ground(resting["position"]).distance_to(boar_at) < 0.001, "The validly saved boar keeps its spot")
	assert(world.player_position.distance_to(resting["position"]) >= world.PLAYER_RADIUS + world.ANIMAL_RADIUS[world.BOAR], "Oravitsa never lands in contact with an animal")
	var displaced: Dictionary = world._animals[0]
	for i in range(1, world._animals.size()):
		var data: Dictionary = world._animals[i]
		if data["alive"] and not data["gone"]:
			assert(displaced["position"].distance_to(data["position"]) >= world.ANIMAL_RADIUS[displaced["kind"]] + world.ANIMAL_RADIUS[data["kind"]], "A displaced animal lands clear of the others")
	moves = 0
	for i in 8:
		var start: Vector2 = world.player_position
		world.player_stun = 0.0
		if world._try_move(Vector2.from_angle(i * TAU / 8) * 3.5):
			moves += 1
		world.player_position = start
	assert(moves >= 3, "Oravitsa can walk away beside the boar")
	print("Landmarks smoke test passed: ", hamlets.size(), " hamlets (", houses, " closed houses) and ", caves.size(), " cave mouths; solid houses/wells/rock matching their drawn meshes (", open_samples, " open samples beside rock), open entrances and crossings, passable door and cave trails, bare clearings, no spawns inside, deterministic after rebasing, bounded caches, labels and old saves moved out of new houses")
	quit()
