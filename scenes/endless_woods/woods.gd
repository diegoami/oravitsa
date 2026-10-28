extends "res://scenes/forest_25d/clearing.gd"

const WILDLIFE_WEIGHTS := {HARE: 52, DEER: 18, FOX: 10, BOAR: 8, WOLF: 7, LYNX: 5}
# Owner-tuned sparse ecology: roughly a third of the earlier abundance.
const WILDLIFE_TARGETS := {HARE: 6, DEER: 3, FOX: 1, BOAR: 1, WOLF: 1, LYNX: 1}
const SEEDED_ANIMALS := 33
const FOOD_CHANCE := Vector2(0.043, 0.027) # Birch biome, other biomes.
const WILDLIFE_CHANCE := {HARE: 1.0, DEER: 0.65, FOX: 0.35, BOAR: 0.25, WOLF: 0.32, LYNX: 0.22}
# Wolves and lynxes sustain longer, faster spurts than in the finite scenes
# (speed px/s, duration s, recovery from spurt start s). Foxes chase hares in
# short, weak spurts and usually lose them at the last moment.
const PREDATOR_BURST := Vector3(240, 2.2, 3.4)
const FOX_BURST := Vector3(195, 1.4, 4.0)
const FOX_CATCH_CHANCE := 0.3
const FOX_HUNT_REST := 9.0
# Lingering within AGGRO_RADIUS of a wolf, lynx or boar for AGGRO_DWELL seconds
# may provoke it: a visible warning, then a bounded charge that can stun
# Oravitsa. Win or lose, the animal then ignores her for AGGRO_COOLDOWN.
const AGGRO_KINDS := [WOLF, LYNX, BOAR]
const AGGRO_RADIUS := 260.0
const AGGRO_DWELL := 3.0
const AGGRO_CHANCE := 0.6
const AGGRO_RETRY := 8.0
const AGGRO_WARN_TIME := 1.2
const AGGRO_CHARGE_TIME := 4.0
const AGGRO_SPEED := {WOLF: 232.0, LYNX: 228.0, BOAR: 196.0}
const AGGRO_REACH := 12.0
const AGGRO_PLAYER_STUN := 2.0
const AGGRO_COOLDOWN := 25.0
# Nearby calm wolves, lynxes and boars of different species occasionally fight.
# The loser is stunned; neither fights again during FIGHT_COOLDOWN.
const FIGHT_KINDS := [WOLF, LYNX, BOAR]
const FIGHT_RADIUS := 140.0
const FIGHT_CHANCE := 0.12
const FIGHT_CHECK := 1.0
const FIGHT_TIME := 2.5
const FIGHT_STRENGTH := {WOLF: 1.2, LYNX: 1.0, BOAR: 1.0}
const FIGHT_LOSER_STUN := 4.0
const FIGHT_COOLDOWN := 45.0
const FIGHT_INTERRUPT_COOLDOWN := 20.0
const PREDATOR_HUNGER_LIMIT := 180.0
const PREDATOR_RETURN_DELAY := 45.0
# The generated world is fixed by the landscape's seeds; saves name it so a
# save can never be applied to a differently generated world.
const WORLD_ID := "mossbank-27102026"
const SAVE_GAME := preload("res://scenes/endless_woods/save_game.gd")
const SAVED_ANIMAL_TIMERS := ["respawn", "stun", "shoo", "hunger", "feeding", "burst_cooldown", "hunt_rest", "aggro_cooldown", "fight_cooldown", "timeout"]
const SAVED_ANIMAL_COUNTERS := ["turn", "hunt_attempts", "aggro_rolls"]
const BERRY_REGROW_SECONDS := Vector2(180, 360)
const MUSHROOM_REGROW_SECONDS := Vector2(300, 540)
var origin_cells := Vector2i.ZERO
var _harvested: Dictionary = {}
var _cached_cells: Dictionary = {}
var _nav_budget := 1
var _nav_frame := -1
var _food_clock := 0.0
var _regrowth_check := 0.0
var _fight_check := FIGHT_CHECK
var _fight_tick := 0
var save_path: String = SAVE_GAME.PATH
var audio: Node
var _ambience_button: Button
var _animal_sound_button: Button


func _generate_map() -> void:
	objects = {}
	terrain = {}
	_animal_heights[WOLF] = 0.95


func _build_world() -> void:
	super._build_world()
	audio = load("res://scenes/endless_woods/forest_audio.gd").new()
	add_child(audio)
	audio.setup(self)
	var canvas: CanvasLayer = get_node("HUD")
	_ambience_button = _hud_toggle(canvas, func():
		audio.cycle_ambience()
		_update_hud())
	_animal_sound_button = _hud_toggle(canvas, func():
		audio.cycle_animals()
		_update_hud())
	_layout_hud()


func _layout_hud() -> void:
	super._layout_hud()
	if is_instance_valid(_ambience_button):
		_ambience_button.position = _save_button.position + Vector2(0, 40)
		_ambience_button.size = Vector2(124, 32)
		_animal_sound_button.position = _ambience_button.position + Vector2(132, 0)
		_animal_sound_button.size = Vector2(124, 32)


func _update_hud() -> void:
	super._update_hud()
	if not is_instance_valid(_ambience_button) or audio == null:
		return
	_ambience_button.visible = _instructions_visible
	_animal_sound_button.visible = _instructions_visible
	var keys := _input_mode != "controller" and _input_mode != "touch"
	_ambience_button.text = "Forest " + audio.level_text(audio.ambience_level) + (" [9]" if keys else "")
	_animal_sound_button.text = "Animals " + audio.level_text(audio.animal_level) + (" [0]" if keys else "")
	if keys:
		_hint_label.text += "\n9 / 0: forest / animal volume"


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_9, KEY_0]:
		if event.keycode == KEY_9:
			audio.cycle_ambience()
		else:
			audio.cycle_animals()
		_update_hud()
	else:
		super._unhandled_key_input(event)


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
			player_stun = CONTACT_STUN_TIME
			animal["stun"] = maxf(animal["stun"], CONTACT_STUN_TIME)
			animal["velocity"] = Vector2.ZERO
			return false
	player_position = candidate
	return true


func _animal_record(kind: int, position: Vector2) -> Dictionary:
	var data := super._animal_record(kind, position)
	data["hunger"] = 0.0
	data["gone"] = false
	data["stuck"] = 0.0
	data["progress_time"] = 0.0
	data["progress_origin"] = data["position"]
	data["route"] = PackedVector2Array()
	data["route_goal"] = data["position"]
	data["nav_cooldown"] = 0.0
	data["hunt_rest"] = 0.0
	data["hunt_attempts"] = 0
	data["provoke"] = 0.0
	data["aggro"] = AGGRO_NONE
	data["aggro_time"] = 0.0
	data["aggro_cooldown"] = 0.0
	data["aggro_rolls"] = 0
	data["fight_with"] = -1
	data["fight_time"] = 0.0
	data["fight_cooldown"] = 0.0
	return data


func _is_fighting(id: int) -> bool:
	return _animals[id]["fight_with"] >= 0


func _can_start_fight(id: int) -> bool:
	var data := _animals[id]
	if not data["alive"] or not _active_animals.has(id) or data["kind"] not in FIGHT_KINDS or data["fight_with"] >= 0:
		return false
	if data["fight_cooldown"] > 0 or data["stun"] > 0 or data["shoo"] > 0 or data["feeding"] > 0:
		return false
	return data["aggro"] == AGGRO_NONE and data["state"] != "hunt" and data["catch_target"] < 0


func _start_fight(a: int, b: int) -> void:
	for pair in [[a, b], [b, a]]:
		var data := _animals[pair[0]]
		data["fight_with"] = pair[1]
		data["fight_time"] = FIGHT_TIME
		data["velocity"] = Vector2.ZERO
		data["burst"] = 0.0
		data["eat_time"] = 0.0
		data["provoke"] = 0.0
		data["route"] = PackedVector2Array()
		data["facing"] = (_animals[pair[1]]["position"] - data["position"]).normalized()


func _end_fight(id: int, cooldown: float) -> void:
	var data := _animals[id]
	data["fight_with"] = -1
	data["fight_time"] = 0.0
	data["fight_cooldown"] = maxf(data["fight_cooldown"], cooldown)
	if data["state"] == "fight":
		data["state"] = "idle"
		data["timeout"] = 0.0


func _update_fights(delta: float) -> void:
	for id in _animals.size():
		var data := _animals[id]
		data["fight_cooldown"] = maxf(0, data["fight_cooldown"] - delta)
		var other: int = data["fight_with"]
		if other < 0 or other < id and _animals[other]["fight_with"] == id:
			continue # Each pair resolves once, from its lower id.
		var rival := _animals[other] if other < _animals.size() else {}
		var valid: bool = not rival.is_empty() and rival["fight_with"] == id
		for fighter in [data, rival]:
			valid = valid and fighter["alive"] and fighter["stun"] <= 0 and fighter["shoo"] <= 0
		valid = valid and _active_animals.has(id) and _active_animals.has(other)
		if not valid:
			# Fear, a stun or leaving the active area ends it with no winner.
			_end_fight(id, FIGHT_INTERRUPT_COOLDOWN)
			if not rival.is_empty() and rival["fight_with"] == id:
				_end_fight(other, FIGHT_INTERRUPT_COOLDOWN)
			continue
		data["fight_time"] -= delta
		rival["fight_time"] = data["fight_time"]
		if data["fight_time"] > 0:
			continue
		_fight_tick += 1
		var odds: float = FIGHT_STRENGTH[data["kind"]] / (FIGHT_STRENGTH[data["kind"]] + FIGHT_STRENGTH[rival["kind"]])
		var loser := other if _hash(id + other, _fight_tick, 1801) < odds else id
		_end_fight(id, FIGHT_COOLDOWN)
		_end_fight(other, FIGHT_COOLDOWN)
		_animals[loser]["stun"] = maxf(_animals[loser]["stun"], FIGHT_LOSER_STUN)
		_animals[loser]["velocity"] = Vector2.ZERO
	_fight_check -= delta
	if _fight_check > 0:
		return
	_fight_check = FIGHT_CHECK
	var calm: Array[int] = []
	for id in _active_animals:
		if _can_start_fight(id):
			calm.append(id)
	for i in calm.size():
		for j in range(i + 1, calm.size()):
			var a := calm[i]
			var b := calm[j]
			if _animals[a]["kind"] == _animals[b]["kind"] or _animals[a]["fight_with"] >= 0 or _animals[b]["fight_with"] >= 0:
				continue
			if _animals[a]["position"].distance_to(_animals[b]["position"]) > FIGHT_RADIUS:
				continue
			_fight_tick += 1
			if _hash(a * 977 + b, _fight_tick, 1802) < FIGHT_CHANCE:
				_start_fight(a, b)
				if audio != null:
					audio.call_now(a)


func _aggression(id: int) -> int:
	return _animals[id]["aggro"]


func _charge_speed(kind: int) -> float:
	return AGGRO_SPEED.get(kind, ANIMAL_SPEEDS[kind])


func _end_aggression(id: int, cooldown: float) -> void:
	var data := _animals[id]
	data["aggro"] = AGGRO_NONE
	data["aggro_time"] = 0.0
	data["aggro_cooldown"] = maxf(data["aggro_cooldown"], cooldown)
	data["provoke"] = 0.0
	if data["state"] in ["warn", "charge"]:
		data["state"] = "idle"
		data["timeout"] = 0.0


func _update_aggression(delta: float) -> void:
	for id in _animals.size():
		var data := _animals[id]
		data["aggro_cooldown"] = maxf(0, data["aggro_cooldown"] - delta)
		if data["kind"] not in AGGRO_KINDS:
			continue
		# Fear, any stun, feeding, a fight or leaving the active area ends an encounter.
		if not data["alive"] or not _active_animals.has(id) or data["stun"] > 0 or data["shoo"] > 0 or data["feeding"] > 0 or data["fight_with"] >= 0:
			if data["aggro"] != AGGRO_NONE:
				_end_aggression(id, AGGRO_COOLDOWN)
			data["provoke"] = 0.0
			continue
		var distance: float = data["position"].distance_to(player_position)
		if data["aggro"] == AGGRO_NONE:
			if data["aggro_cooldown"] > 0 or distance > AGGRO_RADIUS:
				data["provoke"] = maxf(0, data["provoke"] - delta * 2)
				continue
			data["provoke"] += delta
			if data["provoke"] < AGGRO_DWELL:
				continue
			data["provoke"] = 0.0
			data["aggro_rolls"] += 1
			if _hash(id, data["aggro_rolls"], 1701) >= AGGRO_CHANCE:
				data["aggro_cooldown"] = AGGRO_RETRY
				continue
			data["aggro"] = AGGRO_WARN
			data["aggro_time"] = AGGRO_WARN_TIME
			data["catch_target"] = -1
			data["catch_time"] = 0.0
			data["burst"] = 0.0
			_show_notice("The %s is angry — back away!" % ANIMAL_NAMES[data["kind"]].to_lower())
			if audio != null:
				audio.call_now(id)
		elif data["aggro"] == AGGRO_WARN:
			data["aggro_time"] -= delta
			if data["aggro_time"] <= 0:
				data["aggro"] = AGGRO_CHARGE
				data["aggro_time"] = AGGRO_CHARGE_TIME
		else:
			data["aggro_time"] -= delta
			if distance <= ANIMAL_RADIUS[data["kind"]] + PLAYER_RADIUS + AGGRO_REACH:
				# An already stunned Oravitsa is not stunned again by a second animal.
				if player_stun <= 0:
					player_stun = AGGRO_PLAYER_STUN
					_show_notice("The %s knocked Oravitsa down!" % ANIMAL_NAMES[data["kind"]].to_lower())
				data["velocity"] = Vector2.ZERO
				_end_aggression(id, AGGRO_COOLDOWN)
			elif data["aggro_time"] <= 0 or distance > AGGRO_RADIUS * 3:
				_end_aggression(id, AGGRO_COOLDOWN)


func _prey_kinds(kind: int) -> Array:
	return [HARE] if kind == FOX else super._prey_kinds(kind)


func _food_kinds(kind: int) -> Array:
	# Foxes also eat berries when no hare is in reach or after a missed lunge.
	return [BERRIES] if kind == FOX else super._food_kinds(kind)


func _threat_kinds(kind: int) -> Array:
	# Endless foxes hunt hares, so they only flee larger animals; hares watch
	# for foxes as well as wolves and lynxes.
	if kind == FOX:
		return [BOAR, WOLF, LYNX]
	return [LYNX, WOLF, FOX] if kind == HARE else super._threat_kinds(kind)


func _wants_to_hunt(id: int) -> bool:
	return super._wants_to_hunt(id) and _animals[id]["hunt_rest"] <= 0


func _burst_profile(kind: int) -> Vector3:
	return FOX_BURST if kind == FOX else PREDATOR_BURST


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


func _on_hare_collected(id: int) -> void:
	# The slot leaves the sparse ecology; replenishment brings a new hare later.
	_animals[id]["gone"] = true
	_animals[id]["respawn"] = PREDATOR_RETURN_DELAY


func _should_respawn(id: int) -> bool:
	return not _animals[id].get("gone", false)


func _catch_prey(predator: int, prey: int, delta: float = 0.0) -> bool:
	var hunter := _animals[predator]
	if hunter["kind"] == FOX and _animals[prey]["alive"] and _animals[prey]["kind"] == HARE:
		# Most fox lunges miss; the fox then rests before hunting again.
		hunter["hunt_attempts"] += 1
		if _hash(predator, hunter["hunt_attempts"], 1601) >= FOX_CATCH_CHANCE:
			hunter["hunt_rest"] = FOX_HUNT_REST
			hunter["burst"] = 0.0
			hunter["state"] = "idle"
			hunter["timeout"] = 0.0
			return false
	var caught := super._catch_prey(predator, prey, delta)
	if caught:
		hunter["hunger"] = 0.0
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
	_update_aggression(delta)
	_update_fights(delta)
	for id in _animals.size():
		var data := _animals[id]
		data["nav_cooldown"] = maxf(0, data["nav_cooldown"] - delta)
		data["hunt_rest"] = maxf(0, data["hunt_rest"] - delta)
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
	_shift_origin(Vector2i(roundi(p.x / 912.0), roundi(p.y / 912.0)) * 512)


func _shift_origin(shift_cells: Vector2i) -> void:
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


func _can_save() -> bool:
	return true


func _absolute_point(point: Vector2) -> Array:
	var p := absolute_ground(point)
	return [p.x, p.y]


func _local_point(value: Array) -> Vector2:
	return from_ground(Vector2(value[0], value[1]) - Vector2(origin_cells) * TILE / METRE)


## Bounded game state: absolute positions, timers and depleted food only. The
## world itself regenerates from its seeds; nothing like a world map is stored.
func save_state() -> Dictionary:
	var animals := []
	for data in _animals:
		var record := {"kind": data["kind"], "alive": data["alive"], "gone": data["gone"], "state": data["state"]}
		for field in ["position", "home", "target"]:
			record[field] = _absolute_point(data[field])
		for field in SAVED_ANIMAL_TIMERS + SAVED_ANIMAL_COUNTERS:
			record[field] = data[field]
		animals.append(record)
	var harvested := []
	for record in _harvested.values():
		harvested.append([record["cell"].x, record["cell"].y, record["ready_at"]])
	return {
		"format": SAVE_GAME.FORMAT,
		"version": SAVE_GAME.VERSION,
		"game": ProjectSettings.get_setting("application/config/version", ""),
		"world": WORLD_ID,
		"player": {"ground": _absolute_point(player_position), "stun": player_stun, "shoo_cooldown": shoo_cooldown, "sling_cooldown": sling_cooldown, "active_skill": active_skill},
		"inventory": {"mushrooms": basket, "berries": berries_basket, "raw_meat": raw_meat},
		"clock": {"food": _food_clock, "population_tick": _population_tick, "fight_tick": _fight_tick},
		"harvested": harvested,
		"animals": animals,
	}


## Applies an already validated save. Game-time timers resume where they were:
## nothing advances while the game is closed.
func apply_state(data: Dictionary) -> void:
	var ground: Array = data["player"]["ground"]
	var target := Vector2(ground[0], ground[1])
	_shift_origin(Vector2i(roundi(target.x / 912.0), roundi(target.y / 912.0)) * 512 - origin_cells)
	for node in _forage_visuals.values():
		node.queue_free()
	_forage_visuals.clear()
	_food_chunks.clear()
	objects.clear()
	terrain.clear()
	_cached_cells.clear()
	_harvested.clear()
	for record in data["harvested"]:
		var cell := Vector2i(int(record[0]), int(record[1]))
		_harvested[(int(cell.x) << 32) | (int(cell.y) & 0xffffffff)] = {"cell": cell, "ready_at": float(record[2])}
	for sprite in _active_animals.values():
		sprite.queue_free()
	_active_animals.clear()
	_sync_animal_lifecycle()
	_animals.clear()
	for record in data["animals"]:
		var animal := _animal_record(int(record["kind"]), _local_point(record["position"]))
		animal["home"] = _local_point(record["home"])
		animal["target"] = _local_point(record["target"])
		animal["alive"] = record["alive"]
		animal["gone"] = record["gone"]
		for field in SAVED_ANIMAL_TIMERS:
			animal[field] = float(record[field])
		for field in SAVED_ANIMAL_COUNTERS:
			animal[field] = int(record[field])
		# Encounters in progress restart from calm; their cooldowns persist.
		animal["state"] = "idle" if record["state"] in ["warn", "charge", "fight", "hunt", "flee"] else record["state"]
		_animals.append(animal)
	_stones.clear()
	selected_target = -1
	player_position = _local_point(ground)
	player_stun = float(data["player"]["stun"])
	shoo_cooldown = float(data["player"]["shoo_cooldown"])
	sling_cooldown = float(data["player"]["sling_cooldown"])
	active_skill = int(data["player"]["active_skill"])
	basket = int(data["inventory"]["mushrooms"])
	berries_basket = int(data["inventory"]["berries"])
	raw_meat = int(data["inventory"]["raw_meat"])
	_food_clock = float(data["clock"]["food"])
	_population_tick = int(data["clock"]["population_tick"])
	_fight_tick = int(data["clock"]["fight_tick"])
	_regrowth_check = 0.0
	view.position = to_world(player_position) + CAMERA_OFFSET
	_refresh_visible()
	_sync_presentation(0.0)
	_update_hud()


func _save_game() -> void:
	var error: String = SAVE_GAME.write(save_state(), save_path)
	if error.is_empty():
		_show_notice("Game saved")
	else:
		_show_notice("Save failed: " + error + ". The previous save is unchanged.", 5.0)


func _load_game() -> void:
	var result: Dictionary = SAVE_GAME.read(save_path)
	var note := "Game loaded"
	if not result["ok"] and not result["missing"]:
		# Never discard the slot; offer the previous save if it is intact.
		var backup: Dictionary = SAVE_GAME.read(save_path + ".bak")
		if backup["ok"] and backup["data"]["world"] == WORLD_ID:
			note = "The save was unreadable (%s); loaded the previous save" % result["error"]
			result = backup
	if not result["ok"]:
		_show_notice("Cannot load: " + result["error"], 5.0)
		return
	if result["data"]["world"] != WORLD_ID:
		_show_notice("Cannot load: the save belongs to a different world", 5.0)
		return
	apply_state(result["data"])
	_show_notice(note, 4.0 if note != "Game loaded" else 2.5)


func _process(delta: float) -> void:
	_rebase_if_needed()
	_update_food_regrowth(delta)
	super._process(delta)


func _sync_presentation(delta: float) -> void:
	super._sync_presentation(delta)
	if audio != null:
		audio.update(delta)
	for id in _animal_stars:
		var data: Dictionary = _animals[id]
		if data["fight_with"] >= 0:
			_animal_stars[id].visible = true
			_animal_stars[id].no_depth_test = true
			_animal_stars[id].modulate = Color("ffb35c")
			_animal_stars[id].text = "!! FIGHTING"
			continue
		if data["aggro"] == AGGRO_NONE:
			continue
		var marker: Label3D = _animal_stars[id]
		marker.visible = true
		marker.no_depth_test = true
		marker.modulate = Color("ff7a5c")
		marker.text = "!! ANGRY" if data["aggro"] == AGGRO_WARN else "!! CHARGING"
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
