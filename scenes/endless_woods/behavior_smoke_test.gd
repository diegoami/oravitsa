extends SceneTree

## Wildlife must not get stuck in behaviour loops (#52).
## Protects: animals flipping between behaviours at a single limit, walking back
## into what just scared them, and pressing forever against what they can't reach.

const DT := 1.0 / 30.0
const RETURN_FLIP_LIMIT := 60 # The unfixed world made about 700 of these per 60 s.
const FROZEN_SECONDS := 10.0


func _initialize() -> void:
	call_deferred("_run")


func _clear(world: Node2D) -> void:
	for sprite in world._active_animals.values():
		sprite.queue_free()
	world._active_animals.clear()
	world._sync_animal_lifecycle()
	world._animals.clear()


func _add(world: Node2D, kind: int, position: Vector2, home: Vector2) -> int:
	world._animals.append(world._animal_record(kind, position))
	var id: int = world._animals.size() - 1
	world._animals[id]["home"] = home
	world._active_animals[id] = world._make_animal_sprite(id)
	return id


## A direction with clear ground for `length` px from `from`, so obstacles don't
## decide what these checks see.
func _clear_direction(world: Node2D, from: Vector2, length: float, radius: float) -> Vector2:
	for turn in 32:
		var direction := Vector2.from_angle(TAU * turn / 32.0)
		var clear := true
		for step in range(0, int(length), 24):
			clear = clear and world._can_stand(from + direction * step, radius + 8.0)
		if clear:
			return direction
	return Vector2.ZERO


## Open ground with clear ground for `length` px in some direction.
func _open_start(world: Node2D, length: float) -> Array:
	for cell in world._forage_visuals:
		for offset in [Vector2i(5, 0), Vector2i(-5, 0), Vector2i(0, 5), Vector2i(0, -5), Vector2i(8, 8), Vector2i(-8, -8)]:
			var from: Vector2 = world._cell_center(cell + offset)
			if world._can_stand(from, 40.0):
				var direction := _clear_direction(world, from, length, world.ANIMAL_RADIUS[world.HARE])
				if direction != Vector2.ZERO:
					return [from, direction]
	return []


## Runs the simulation, returning how often the animal entered each state.
func _entries(world: Node2D, id: int, seconds: float, done: Callable = func(): return false) -> Dictionary:
	var entries := {}
	var state: String = world._animals[id]["state"]
	var elapsed := 0.0
	while elapsed < seconds and not done.call():
		world._move_animals(DT)
		elapsed += DT
		if world._animals[id]["state"] != state:
			state = world._animals[id]["state"]
			entries[state] = entries.get(state, 0) + 1
	return entries


func _run() -> void:
	var world = load("res://scenes/endless_woods/woods.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	await process_frame
	await _whole_world(world)
	_clear(world)
	var far := Vector2(0, 60 * world.METRE)

	# Food just past the animal's range is left alone, with no flipping at the line.
	var food := Vector2i(-1, -1)
	for cell in world._forage_visuals:
		if world.objects[world._index(cell)] in world._food_kinds(world.HARE):
			var candidate: Vector2 = world._cell_center(cell)
			if _clear_direction(world, candidate, 120.0, world.ANIMAL_RADIUS[world.HARE]) != Vector2.ZERO:
				food = cell
				break
	assert(food.x >= 0, "Need reachable food near arrival")
	var food_at: Vector2 = world._cell_center(food)
	var side := _clear_direction(world, food_at, 120.0, world.ANIMAL_RADIUS[world.HARE])
	world.player_position = food_at + far
	var hare := _add(world, world.HARE, food_at + side * 96.0, food_at + side * (world.HOME_LEASH + 50.0))
	assert(world._nearest_food(world._animals[hare]["position"], world.HARE) == food, "The food is the nearest")
	assert(world._nearest_food(world._animals[hare]["position"], world.HARE, hare) != food, "It is not worth setting out for")
	var seen := _entries(world, hare, 20.0)
	assert(seen.get("return", 0) == 0 and seen.get("forage", 0) <= 1, "No flipping at the limit of its range: %s" % seen)
	assert(world.objects[world._index(food)] in world._food_kinds(world.HARE), "Out-of-range food stays")
	_clear(world)

	# Past its range an animal walks well back, once, instead of stopping at the line.
	var start: Array = _open_start(world, world.HOME_LEASH + 120.0)
	assert(not start.is_empty(), "Need a long clear line for the walk home")
	var from: Vector2 = start[0]
	var along: Vector2 = start[1]
	world.player_position = from + far
	hare = _add(world, world.HARE, from + along * (world.HOME_LEASH + 30.0), from)
	world._move_animals(DT)
	assert(world._animals[hare]["state"] == "return")
	seen = _entries(world, hare, 30.0, func(): return world._animals[hare]["state"] != "return")
	assert(world._animals[hare]["state"] != "return", "It arrives")
	assert(world._animals[hare]["position"].distance_to(from) <= world.HOME_LEASH - 150.0, "It comes well inside its range")
	_clear(world)

	# A scared animal runs clear of her and does not wander straight back.
	world.player_position = from
	hare = _add(world, world.HARE, from + along * 200.0, from + along * 200.0)
	seen = _entries(world, hare, 20.0)
	assert(seen.get("flee", 0) + (1 if world._animals[hare]["state"] == "flee" else 0) <= 2, "It flees once: %s" % seen)
	assert(world._animals[hare]["position"].distance_to(from) >= 235.0, "It stays away from her")
	for attempt in 24:
		world._choose_animal_target(hare)
		if world._animals[hare]["state"] == "roam":
			assert(world._animals[hare]["target"].distance_to(from) >= 235.0 * world.CALM_MARGIN, "Calm walks avoid her")
	_clear(world)

	# Driven out of its range, it settles there rather than walking back at her.
	world.player_position = from
	var out: Vector2 = from + along * (world.HOME_LEASH + 60.0)
	hare = _add(world, world.HARE, out, from)
	world._animals[hare]["state"] = "flee"
	world._move_animals(DT)
	assert(world._animals[hare]["state"] != "return" and world._animals[hare]["home"].distance_to(out) < 8.0, "A chased animal resettles")
	world._animals[hare]["position"] = out
	world._animals[hare]["home"] = from
	world._animals[hare]["state"] = "scared"
	world._animals[hare]["shoo"] = DT * 0.5
	world._move_animals(DT)
	assert(world._animals[hare]["state"] != "return" and world._animals[hare]["home"].distance_to(out) < 8.0, "A shooed animal resettles")
	_clear(world)

	# Penned in, it gives up on the food instead of pressing against the pen.
	world.player_position = food_at + far
	hare = _add(world, world.HARE, food_at + side * 96.0, food_at + side * 96.0)
	var pen: Vector2 = world._animals[hare]["position"]
	for offset in [Vector2(46, 0), Vector2(-46, 0), Vector2(0, 46), Vector2(0, -46), Vector2(34, 34), Vector2(-34, 34), Vector2(34, -34), Vector2(-34, -34)]:
		var guard := _add(world, world.BOAR, pen + offset, pen + offset)
		world._animals[guard]["stun"] = 60.0
	world._animals[hare]["food_cell"] = food
	world._animals[hare]["state"] = "forage"
	seen = _entries(world, hare, 5.0, func(): return world._animals[hare]["give_up"] > 0.0)
	assert(world._animals[hare]["give_up"] > 0.0 and world._animals[hare]["food_cell"] == Vector2i(-1, -1), "It gives up")
	world._move_animals(DT)
	assert(world._animals[hare]["state"] != "forage" and world._animals[hare]["food_cell"] == Vector2i(-1, -1), "It stays given up")
	# A way home it can't take is given up too: it settles where it is.
	world._animals[hare]["give_up"] = 0.0
	world._animals[hare]["home"] = pen + along * (world.HOME_LEASH + 100.0)
	seen = _entries(world, hare, 5.0, func(): return world._animals[hare]["home"].distance_to(pen) < 8.0)
	assert(world._animals[hare]["home"].distance_to(pen) < 8.0, "An unreachable home is replaced")
	# Normal walking never counts as blocked.
	_clear(world)
	world.player_position = from + far
	hare = _add(world, world.HARE, from, from)
	world._animals[hare]["state"] = "return"
	world._animals[hare]["home"] = from + along * 800.0
	_entries(world, hare, 5.0)
	assert(world._animals[hare]["give_up"] == 0.0 and world._animals[hare]["blocked"] == 0, "Walking is progress")
	# The progress check follows a rebased world.
	var before: Vector2 = world._animals[hare]["blocked_from"]
	world._shift_origin(Vector2i(8, 0))
	assert(world._animals[hare]["blocked_from"].distance_to(before - Vector2(8, 0) * world.TILE) < 0.01, "The check is rebased")
	print("Behaviour loop smoke test passed: no flipping at the home range, full walk home, no wandering back after fear, resettling after being chased or shooed, giving up on blocked food and unreachable homes, no false give-ups, rebased progress check and a whole-world run free of return flips and frozen animals")
	quit()


## The real ecology with Oravitsa standing still, as it reproduced the loops.
func _whole_world(world: Node2D) -> void:
	world.player_position = world.from_ground(Vector2(-90, 70))
	world.view.position = world.to_world(world.player_position) + world.CAMERA_OFFSET
	world._refresh_visible()
	await process_frame
	var state := {}
	var frozen := {}
	var return_flips := 0
	for tick in int(60.0 / DT):
		world._move_animals(DT)
		world._update_respawns(DT)
		if tick % 150 == 0:
			world._refresh_visible()
			world._replenish_local_animals()
		for id in world._active_animals.keys():
			var data: Dictionary = world._animals[id]
			if not data["alive"]:
				continue
			if state.has(id) and state[id] != data["state"] and "return" in [state[id], data["state"]]:
				return_flips += 1
			state[id] = data["state"]
			var mark: Array = frozen.get(id, [data["position"], 0.0])
			if data["state"] == "idle" or data["stun"] > 0 or data["feeding"] > 0 or data["eat_time"] > 0 or data["position"].distance_to(mark[0]) >= 48.0:
				mark = [data["position"], 0.0]
			else:
				mark[1] += DT
			frozen[id] = mark
			assert(mark[1] < FROZEN_SECONDS, "%s frozen in state %s" % [world.ANIMAL_NAMES[data["kind"]], data["state"]])
	assert(return_flips <= RETURN_FLIP_LIMIT, "Animals flip at the home limit: %d" % return_flips)
