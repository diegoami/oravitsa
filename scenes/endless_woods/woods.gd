extends "res://scenes/forest_25d/clearing.gd"

const WILDLIFE_WEIGHTS := {HARE: 52, DEER: 18, FOX: 10, BOAR: 8, WOLF: 7, LYNX: 5}
# Owner-tuned sparse ecology: roughly a third of the earlier abundance.
const WILDLIFE_TARGETS := {HARE: 6, DEER: 3, FOX: 1, BOAR: 1, WOLF: 1, LYNX: 1}
const SEEDED_ANIMALS := 33
const FOOD_CHANCE := Vector2(0.043, 0.027) # Birch biome, other biomes.
const WILDLIFE_CHANCE := {HARE: 1.0, DEER: 0.65, FOX: 0.35, BOAR: 0.25, WOLF: 0.32, LYNX: 0.22}
const PREDATOR_HUNGER_LIMIT := 180.0
const PREDATOR_RETURN_DELAY := 45.0
const BERRY_REGROW_SECONDS := Vector2(180, 360)
const MUSHROOM_REGROW_SECONDS := Vector2(300, 540)
var origin_cells := Vector2i.ZERO
var _harvested: Dictionary = {}
var _cached_cells: Dictionary = {}
var _nav_budget := 1
var _nav_frame := -1
var _food_clock := 0.0
var _regrowth_check := 0.0


func _generate_map() -> void:
	objects = {}
	terrain = {}
	_animal_heights[WOLF] = 0.95


func _make_landscape() -> Node3D:
	return load("res://scenes/endless_woods/landscape.gd").new()


func _minimap_script() -> Script:
	return load("res://scenes/endless_woods/map.gd")


func absolute_ground(point: Vector2) -> Vector2:
	return to_ground(point) + Vector2(origin_cells) * TILE / METRE


func _index(cell: Vector2i) -> int:
	var global_cell := cell - START + origin_cells
	var key := (int(global_cell.x) << 32) | (int(global_cell.y) & 0xffffffff)
	if not objects.has(key):
		_cached_cells[key] = global_cell
		var p := to_ground(_cell_center(cell))
		var value := EMPTY
		if not _harvested.has(key) and landscape.random_at(global_cell, 910) < (FOOD_CHANCE.x if landscape.biome_at(p) == 1 else FOOD_CHANCE.y) and not landscape.is_water(p, 0.4) and not landscape.is_bridge(p):
			value = MUSHROOM if landscape.random_at(global_cell, 911) < 0.55 else BERRIES
		if value != EMPTY and not landscape.can_walk(p, 0.2):
			value = EMPTY # Do not lure foragers toward food inside solid scenery.
		objects[key] = value
		terrain[key] = GRASS
	return key


func _in_bounds(cell: Vector2i) -> bool:
	# (-1,-1) remains the shared AI's "no food target" sentinel, not an edge.
	return cell != Vector2i(-1, -1)


func _build_food() -> void:
	pass # Food is generated lazily from absolute cells as chunks arrive.


func _refresh_food() -> void:
	for cell in _forage_visuals.keys():
		var q := absolute_ground(_cell_center(cell))
		if not landscape.chunks.has(Vector2i((q / landscape.CHUNK).floor())):
			_forage_visuals[cell].queue_free()
			_forage_visuals.erase(cell)
	for key in _food_chunks.keys():
		if not landscape.chunks.has(key):
			_food_chunks.erase(key)
	for key in landscape.chunks:
		if _food_chunks.has(key):
			continue
		_food_chunks[key] = true
		var first := Vector2i((Vector2(key) * landscape.CHUNK * METRE / TILE).ceil())
		var end := Vector2i(((Vector2(key) + Vector2.ONE) * landscape.CHUNK * METRE / TILE).ceil())
		for z in range(first.y, end.y):
			for x in range(first.x, end.x):
				var cell := Vector2i(x, z) - origin_cells + START
				if not _forage_visuals.has(cell) and objects[_index(cell)] in [MUSHROOM, BERRIES] and _can_stand(_cell_center(cell), 10):
					_add_food_visual(cell)
	var center := _world_cell(player_position) - START + origin_cells
	for key in _cached_cells.keys():
		var delta: Vector2i = _cached_cells[key] - center
		if absi(delta.x) > 100 or absi(delta.y) > 100:
			_cached_cells.erase(key)
			objects.erase(key)
			terrain.erase(key)


func _consume_food(cell: Vector2i) -> void:
	var key := _index(cell)
	var kind: int = objects[key]
	if kind not in [MUSHROOM, BERRIES]:
		return
	var global_cell := cell - START + origin_cells
	var limits := BERRY_REGROW_SECONDS if kind == BERRIES else MUSHROOM_REGROW_SECONDS
	var delay: float = lerpf(limits.x, limits.y, landscape.random_at(global_cell, 1200 + floori(_food_clock)))
	_harvested[key] = {"cell": global_cell, "ready_at": _food_clock + delay}
	super._consume_food(cell)


func _update_food_regrowth(delta: float) -> void:
	_food_clock += maxf(0, delta)
	_regrowth_check -= maxf(0, delta)
	if _regrowth_check > 0 or _harvested.is_empty():
		return
	_regrowth_check = 1.0
	var refresh := false
	for key in _harvested.keys():
		var record: Dictionary = _harvested[key]
		if _food_clock < record["ready_at"]:
			continue
		var global_cell: Vector2i = record["cell"]
		var local_cell := global_cell - origin_cells + START
		# Let the patch recover outside the actual smoothed view, so it cannot
		# visibly pop in beside the player. Unloaded areas need no render nodes.
		if not _spawn_is_hidden(_cell_center(local_cell), HARE):
			continue
		_harvested.erase(key)
		objects.erase(key)
		terrain.erase(key)
		_cached_cells.erase(key)
		var chunk := Vector2i((Vector2(global_cell) * TILE / METRE / landscape.CHUNK).floor())
		_food_chunks.erase(chunk)
		refresh = refresh or landscape.chunks.has(chunk)
	if refresh:
		_refresh_food()


func _try_move(step: Vector2) -> bool:
	if player_stun > 0:
		return false
	var candidate := player_position + step
	if not _can_stand(candidate, PLAYER_RADIUS):
		return false
	for id in _active_animals:
		var animal: Dictionary = _animals[id]
		if animal["alive"] and candidate.distance_to(animal["position"]) < PLAYER_RADIUS + ANIMAL_RADIUS[animal["kind"]]:
			player_stun = 0.85
			animal["stun"] = maxf(animal["stun"], 0.85)
			animal["velocity"] = Vector2.ZERO
			return false
	player_position = candidate
	return true


func _add_animal(kind: int, cell: Vector2i) -> void:
	super._add_animal(kind, cell)
	var data := _animals[-1]
	data["hunger"] = 0.0
	data["gone"] = false
	data["stuck"] = 0.0
	data["progress_time"] = 0.0
	data["progress_origin"] = data["position"]
	data["route"] = PackedVector2Array()
	data["route_goal"] = data["position"]
	data["nav_cooldown"] = 0.0


func _seed_animals() -> void:
	for off in [Vector2i(4, 0), Vector2i(-1, 5)]:
		if _can_stand(_cell_center(START + off)):
			_add_animal(HARE, START + off)
	for i in SEEDED_ANIMALS:
		var roll := _hash(i, 0, 950) * 100
		var kind := HARE
		for species in WILDLIFE_WEIGHTS:
			roll -= WILDLIFE_WEIGHTS[species]
			if roll < 0:
				kind = species
				break
		for attempt in 80:
			var p := Vector2(_hash(i, attempt, 951) * 2 - 1, _hash(i, attempt, 952) * 2 - 1) * 45
			if p.length() < (16 if _is_predator(kind) else 5):
				continue
			var cell := _world_cell(from_ground(p))
			var spot := _cell_center(cell)
			if not _can_stand(spot, ANIMAL_RADIUS[kind]):
				continue
			var clear := true
			for animal in _animals:
				if spot.distance_to(animal["position"]) < 110:
					clear = false
			if clear:
				_add_animal(kind, cell)
				break


func _make_animal_sprite(id: int) -> AnimatedSprite2D:
	if _animals[id]["kind"] != WOLF:
		return super._make_animal_sprite(id)
	# Invisible animation driver only; the wolf's actual visual is its rigged
	# CC0 wolf mesh, never a substitute fox/heroine displayed in the world.
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = PLAYER_WALK
	_world.add_child(sprite)
	sprite.play("s")
	return sprite


func _should_respawn(id: int) -> bool:
	return not _animals[id].get("gone", false)


func _catch_prey(predator: int, prey: int, delta: float = 0.0) -> bool:
	var caught := super._catch_prey(predator, prey, delta)
	if caught:
		_animals[predator]["hunger"] = 0.0
	return caught


func _replenish_local_animals() -> void:
	_population_tick += 1
	for kind in WILDLIFE_TARGETS:
		if _hash(_population_tick, kind, 803) >= WILDLIFE_CHANCE[kind]:
			continue
		for missing in maxi(0, WILDLIFE_TARGETS[kind] - _local_population(kind)):
			var cell := _find_local_spawn(kind)
			if cell == Vector2i(-1, -1):
				break
			var donor := -1
			for id in _animals.size():
				var data := _animals[id]
				if _active_animals.has(id) or data["gone"] and data["respawn"] > 0:
					continue
				if data["gone"] or data["position"].distance_to(player_position) > _population_radius() * 1.8:
					donor = id
					break
			if donor < 0:
				if _animals.size() >= 208:
					break
				_add_animal(kind, cell)
			else:
				# Recycle slots instead of growing history with every new region.
				_add_animal(kind, cell)
				_animals[donor] = _animals.pop_back()
	_refresh_animals(_loaded_center)
	_sync_animal_lifecycle()


func _move_animals(delta: float) -> void:
	if _nav_frame != Engine.get_process_frames():
		_nav_frame = Engine.get_process_frames()
		_nav_budget = 1
	super._move_animals(delta)
	for id in _animals.size():
		var data := _animals[id]
		data["nav_cooldown"] = maxf(0, data["nav_cooldown"] - delta)
		if data["gone"]:
			data["respawn"] = maxf(0, data["respawn"] - delta)
		elif data["alive"] and _is_predator(data["kind"]):
			data["hunger"] += delta
			# Keep aging in view, but only remove a hungry predator once hidden.
			if data["hunger"] >= PREDATOR_HUNGER_LIMIT and _spawn_is_hidden(data["position"], data["kind"]):
				data["alive"] = false
				data["gone"] = true
				data["respawn"] = PREDATOR_RETURN_DELAY
				data["velocity"] = Vector2.ZERO
				if _active_animals.has(id):
					_active_animals[id].queue_free()
					_active_animals.erase(id)
		if not _active_animals.has(id) or data["state"] == "idle" or data["stun"] > 0 or data["feeding"] > 0 or data["eat_time"] > 0:
			data["progress_time"] = 0.0
			data["progress_origin"] = data["position"]
			continue
		data["progress_time"] += delta
		if data["progress_time"] >= 0.8:
			data["stuck"] = 1.0 if data["position"].distance_to(data["progress_origin"]) < 24 else 0.0
			data["progress_origin"] = data["position"]
			data["progress_time"] = 0.0
	_sync_animal_lifecycle()


func _plan_route(id: int, target: Vector2) -> PackedVector2Array:
	var data := _animals[id]
	var start: Vector2 = data["position"]
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(-9, -9, 19, 19)
	grid.cell_size = Vector2.ONE * 48
	grid.offset = start
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for z in range(-9, 10):
		for x in range(-9, 10):
			grid.set_point_solid(Vector2i(x, z), not _can_stand(start + Vector2(x, z) * 48, ANIMAL_RADIUS[data["kind"]] + 4))
	grid.set_point_solid(Vector2i.ZERO, false)
	var goal := Vector2i(((target - start) / 48).round()).clamp(Vector2i(-9, -9), Vector2i(9, 9))
	if grid.is_point_solid(goal):
		var best := INF
		for z in range(-9, 10):
			for x in range(-9, 10):
				var point := Vector2i(x, z)
				var distance := (start + Vector2(point) * 48).distance_squared_to(target)
				if not grid.is_point_solid(point) and distance < best:
					goal = point
					best = distance
	var route := grid.get_point_path(Vector2i.ZERO, goal, true)
	if not route.is_empty():
		route.remove_at(0)
	return route


func _steer_animal(id: int, heading: Vector2, target: Vector2, _delta: float) -> Vector2:
	var data := _animals[id]
	if data["shoo"] <= 0 and data["route_goal"].distance_to(target) > 150:
		data["route"] = PackedVector2Array()
	if data["stuck"] > 0 and data["nav_cooldown"] <= 0 and _nav_budget > 0:
		_nav_budget -= 1
		data["route"] = _plan_route(id, target)
		data["route_goal"] = target
		data["nav_cooldown"] = 2.0
		data["stuck"] = 0.0
	var route: PackedVector2Array = data["route"]
	while not route.is_empty() and data["position"].distance_to(route[0]) < 20:
		route.remove_at(0)
	data["route"] = route
	return heading if route.is_empty() else data["position"].direction_to(route[0])


func _rebase_if_needed() -> void:
	var p := to_ground(player_position)
	if maxf(absf(p.x), absf(p.y)) < 456:
		return
	var shift_cells := Vector2i(roundi(p.x / 912.0), roundi(p.y / 912.0)) * 512
	if shift_cells == Vector2i.ZERO:
		return
	var shift := Vector2(shift_cells) * TILE
	var meters := shift / METRE
	origin_cells += shift_cells
	player_position -= shift
	for data in _animals:
		for field in ["position", "home", "target", "progress_origin", "route_goal"]:
			data[field] -= shift
		if data["food_cell"] != Vector2i(-1, -1):
			data["food_cell"] -= shift_cells
		var route: PackedVector2Array = data["route"]
		for i in route.size():
			route[i] -= shift
		data["route"] = route
	for stone in _stones:
		stone["position"] -= shift
	var food := {}
	for cell in _forage_visuals:
		var node: Node3D = _forage_visuals[cell]
		node.position -= Vector3(meters.x, 0, meters.y)
		food[cell - shift_cells] = node
	_forage_visuals = food
	view.position -= Vector3(meters.x, 0, meters.y)
	landscape.rebase(meters)
	_loaded_center -= shift_cells


func _process(delta: float) -> void:
	_rebase_if_needed()
	_update_food_regrowth(delta)
	super._process(delta)


func _sync_presentation(delta: float) -> void:
	super._sync_presentation(delta)
	var absolute := absolute_ground(player_position)
	_landmark_label.text = landscape.biome_name(to_ground(player_position))
	if absolute.distance_to(Vector2(7, -4)) < 9:
		_landmark_label.text = "Forester’s cottage"
	if absolute.distance_to(landscape.WELL_POSITION) < 3:
		_landmark_label.text = "The forester’s old well"
	var site: Dictionary = landscape.landmark_at(Vector2i(floori(absolute.x / 256), floori(absolute.y / 128)))
	if absolute.distance_to(site["position"]) < 7:
		_landmark_label.text = ["Forgotten homestead", "Old standing stones", "Abandoned woodcutters’ camp", "Mossy cairns"][site["kind"]]
	var inside := Rect2(4.7, -5.8, 4.6, 3.8).has_point(absolute)
	for roof in landscape.roofs:
		roof.visible = not inside
