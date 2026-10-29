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
# Aura is the game's points (#42).
const AURA := {"rat": 5, "spider": 10, "checkpoint": 20, "food": 1, "meat": 3, "shoo_villager": -5, "hit_villager": -10}
# How well fed Oravitsa is (#43), from 0 (starving) to FED_MAX. It falls
# steadily; every MEAL_INTERVAL she eats one random bag item unless she is
# full, and when starving she eats as soon as she has food. Being well fed
# makes her faster and shortens the stuns she suffers.
const FED_MAX := 100.0
const FED_START := 60.0
const FED_DECAY := 0.3 # Per second: from full to starving in about five and a half minutes.
const FED_FULL := 80.0 # She skips a meal at or above this.
const MEAL_INTERVAL := 120.0
const MEAL_VALUE := {"berries": 25.0, "mushroom": 30.0, "raw_meat": 50.0}
const MEAL_NAMES := {"berries": "some berries", "mushroom": "a mushroom", "raw_meat": "some raw meat"}
const HUNGRY_SPEED := 0.6 # Starving; normal speed at half fed.
const FULL_SPEED := 1.2
const FULL_STUN := 0.5 # Share of a stun she suffers when full; starving, the whole stun.
# Hamlet villagers (#44): they wander their clearing and ignore Oravitsa.
const CREATURES := "res://scenes/endless_woods/creatures/"
const VILLAGER_LOOKS := ["farmer", "man", "woman_dress"]
const VILLAGERS_PER_HAMLET := Vector2i(2, 4)
const VILLAGER_APPEAR := 150.0 # Metres from a hamlet centre at which its villagers appear.
const VILLAGER_LEAVE := 230.0
const OFFER_RADIUS := 2.4 # Metres from the chieftain, who stands at his store tent.
const CHIEF_HEIGHT := 1.7
# Caves (#45, #46): a seeded first level behind each mouth, with giant rats
# and spiders that bite (a stun, never an injury).
const CAVE_LEVEL := preload("res://scenes/endless_woods/cave_level.gd")
const CAVE_ENTER_RADIUS := 0.9
const CAVE_REARM := 2.5
const MONSTER_SIGHT := 9.0 # Metres at which a rat or spider notices Oravitsa.
const BITE_STUN := 1.5
const BITE_COOLDOWN := 3.5
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
var aura := 0
var fed := FED_START
var _meal_timer := MEAL_INTERVAL
var _food_rng := RandomNumberGenerator.new() # Picks which bag item is eaten or offered.
var _aura_badge: Control
var _offer_button: Button
var _villager_check := 0.0
var _cave: Node3D = null
var _surface_landscape: Node3D
var _surface_animals: Array[Dictionary] = []
var _cave_key := ""
var _cave_progress: Dictionary = {} # "x,y" region -> {"checkpoints": [...], "killed": [...]}
var _cave_return := Vector2.ZERO
var _cave_armed := true
var _cave_exit_armed := false
var _lantern: OmniLight3D
var _surface_light: Dictionary = {}


func _generate_map() -> void:
	objects = {}
	terrain = {}
	_animal_heights[WOLF] = 0.95
	_animal_heights[RAT] = 0.55
	_animal_heights[SPIDER] = 0.5
	_animal_heights[VILLAGER] = 1.55
	_food_rng.randomize()


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
	_aura_badge = Control.new()
	_aura_badge.set_script(load("res://scenes/endless_woods/aura_badge.gd"))
	_aura_badge.name = "Aura"
	canvas.add_child(_aura_badge)
	_offer_button = _hud_toggle(canvas, _offer_food)
	_offer_button.visible = false
	_layout_hud()


func _layout_hud() -> void:
	super._layout_hud()
	if is_instance_valid(_aura_badge):
		var viewport_size := get_viewport_rect().size
		_aura_badge.position = Vector2(viewport_size.x * 0.5 - _aura_badge.ICON * 0.5, 10)
		_offer_button.size = Vector2(236, 34)
		_offer_button.position = Vector2(viewport_size.x * 0.5 - 118, viewport_size.y - 156)


func _fit_help_panel() -> void:
	super._fit_help_panel()
	if is_instance_valid(_ambience_button):
		_ambience_button.position = _save_button.position + Vector2(0, 40)
		_ambience_button.size = Vector2(124, 32)
		_animal_sound_button.position = _ambience_button.position + Vector2(132, 0)
		_animal_sound_button.size = Vector2(124, 32)


func _update_hud() -> void:
	super._update_hud()
	var keys := _input_mode != "controller" and _input_mode != "touch"
	if in_cave() and player_stun <= 0.0 and _stunned_monster_near(HARE_NOTICE_RADIUS) >= 0:
		var monster: String = ANIMAL_NAMES[_animals[_stunned_monster_near(HARE_NOTICE_RADIUS)]["kind"]].to_lower()
		if _input_mode == "controller":
			_inventory.set("pickup_prompt", ("A / Cross: finish the " + monster) if _stunned_monster_near(HARE_PICKUP_RADIUS) >= 0 else "Get closer to the " + monster)
		else:
			_inventory.set("pickup_prompt", "Walk to the stunned " + monster + " to finish it")
	if is_instance_valid(_aura_badge):
		_aura_badge.aura = aura
		_aura_badge.fed = fed / FED_MAX
		_aura_badge.queue_redraw()
		_offer_button.visible = _offer_ready()
		_offer_button.text = "Give food to the chieftain" + (" [A]" if _input_mode == "controller" else (" [O]" if keys else ""))
	if not is_instance_valid(_ambience_button) or audio == null:
		return
	_ambience_button.visible = _instructions_visible
	_animal_sound_button.visible = _instructions_visible
	_ambience_button.text = "Forest " + audio.level_text(audio.ambience_level) + (" [9]" if keys else "")
	_animal_sound_button.text = "Animals " + audio.level_text(audio.animal_level) + (" [0]" if keys else "")
	if keys:
		_hint_label.text += "\nO: give food to a village chieftain\n9 / 0: forest / animal volume"
	_fit_help_panel()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_O:
		_offer_food()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_9, KEY_0]:
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
		if value != EMPTY and (not landscape.can_walk(p, 0.2) or landscape.in_settlement(p)):
			value = EMPTY # No food inside solid scenery or a hamlet's bare clearing.
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
	if _bump_animal(candidate):
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
	# Both a predator's post-catch meal and a forager's eating count as feeding.
	if data["fight_cooldown"] > 0 or data["stun"] > 0 or data["shoo"] > 0 or data["feeding"] > 0 or data["eat_time"] > 0:
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
					player_stun = _player_stun_time(AGGRO_PLAYER_STUN)
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
			if not _can_stand(spot, ANIMAL_RADIUS[kind]) or not _spawn_allowed(spot):
				continue
			var clear := true
			for animal in _animals:
				if spot.distance_to(animal["position"]) < 110:
					clear = false
			if clear:
				_add_animal(kind, cell)
				break


func _make_animal_sprite(id: int) -> AnimatedSprite2D:
	if _animals[id]["kind"] not in [WOLF, RAT, SPIDER, VILLAGER]:
		return super._make_animal_sprite(id)
	# Invisible animation driver only; the actual visual is a rigged CC0 mesh,
	# never a substitute fox/heroine displayed in the world.
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = PLAYER_WALK
	_world.add_child(sprite)
	sprite.play("s")
	return sprite


func _on_hare_collected(id: int) -> void:
	# The slot leaves the sparse ecology; replenishment brings a new hare later.
	_animals[id]["gone"] = true
	_animals[id]["respawn"] = PREDATOR_RETURN_DELAY


func _spawn_allowed(spot: Vector2) -> bool:
	return not landscape.in_settlement(to_ground(spot))


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


## A save may predate world features added since (such as a hamlet house over
## a saved spot), so loaded positions move to the nearest open ground, clear of
## the `occupied` actor footprints (Vector3: position, radius); homes also
## leave hamlet clearings. Spots that are already valid stay unchanged.
func _open_ground_near(point: Vector2, actor_radius: float, outside_settlements: bool = false, occupied: Array[Vector3] = []) -> Vector2:
	var start := to_ground(point)
	var radius := actor_radius / METRE
	var settled: bool = outside_settlements and landscape.in_settlement(start)
	if not settled and landscape.can_walk(start, radius):
		return point
	if settled:
		var hamlet: Dictionary = landscape.hamlet_near(start + landscape.origin)
		var away: Vector2 = start + landscape.origin - hamlet["center"]
		start = hamlet["center"] - landscape.origin + (away.normalized() if away.length() > 0.01 else Vector2.RIGHT) * (landscape.HAMLET_RADIUS + 1.0)
	for ring in 120:
		var count := maxi(1, ring * 6)
		for i in count:
			var q := start + Vector2.from_angle(i * TAU / count) * ring * 0.25
			if landscape.can_walk(q, radius) and not (outside_settlements and landscape.in_settlement(q)):
				var landing := from_ground(q)
				var clear := true
				for other in occupied:
					clear = clear and landing.distance_to(Vector2(other.x, other.y)) >= actor_radius + other.z
				if clear:
					return landing
	return point


## Bounded game state: absolute positions, timers and depleted food only. The
## world itself regenerates from its seeds; nothing like a world map is stored.
## Underground, the frozen surface is saved with Oravitsa at the cave mouth,
## plus where she and the living monsters are, relative to the way out.
func save_state() -> Dictionary:
	var animals := []
	for data in (_surface_animals if in_cave() else _animals):
		if data["kind"] == VILLAGER:
			continue # Villagers regenerate from their hamlet's seed.
		var record := {"kind": data["kind"], "alive": data["alive"], "gone": data["gone"], "state": data["state"]}
		for field in ["position", "home", "target"]:
			record[field] = _absolute_point(data[field])
		for field in SAVED_ANIMAL_TIMERS + SAVED_ANIMAL_COUNTERS:
			record[field] = data[field]
		animals.append(record)
	var harvested := []
	for record in _harvested.values():
		harvested.append([record["cell"].x, record["cell"].y, record["ready_at"]])
	var ground := [_cave_return.x, _cave_return.y] if in_cave() else _absolute_point(player_position)
	var state := {
		"format": SAVE_GAME.FORMAT,
		"version": SAVE_GAME.VERSION,
		"game": ProjectSettings.get_setting("application/config/version", ""),
		"world": WORLD_ID,
		"player": {"ground": ground, "stun": player_stun, "shoo_cooldown": shoo_cooldown, "sling_cooldown": sling_cooldown, "active_skill": active_skill},
		"inventory": {"mushrooms": basket, "berries": berries_basket, "raw_meat": raw_meat},
		"clock": {"food": _food_clock, "population_tick": _population_tick, "fight_tick": _fight_tick},
		"harvested": harvested,
		"animals": animals,
		"aura": aura,
		"fed": {"level": fed, "meal_timer": _meal_timer},
		"caves": _cave_progress.duplicate(true),
	}
	if in_cave():
		var offset: Vector2 = to_ground(player_position) - _cave.entrance
		var monsters := []
		for data in _animals:
			if data["alive"]:
				var at: Vector2 = to_ground(data["position"]) - _cave.entrance
				monsters.append([data["cave_index"], at.x, at.y, data["stun"]])
		state["underground"] = {"cave": _cave_key, "offset": [offset.x, offset.y], "monsters": monsters}
	return state


## Applies an already validated save. Game-time timers resume where they were:
## nothing advances while the game is closed.
func apply_state(data: Dictionary) -> void:
	if in_cave():
		_exit_cave(true)
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
	_status_peaks.clear()
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
		var radius: float = ANIMAL_RADIUS[animal["kind"]]
		animal["home"] = _open_ground_near(animal["home"], radius, true)
		_animals.append(animal)
	# Actors on valid ground keep their spots and reserve them; displaced actors
	# then land clear of those and of each other, so nobody is stuck in contact.
	player_position = _local_point(ground)
	var occupied: Array[Vector3] = []
	var displaced: Array[Dictionary] = []
	if _can_stand(player_position):
		occupied.append(Vector3(player_position.x, player_position.y, PLAYER_RADIUS))
	for animal in _animals:
		var radius: float = ANIMAL_RADIUS[animal["kind"]]
		if not animal["alive"] or animal["gone"]:
			animal["position"] = _open_ground_near(animal["position"], radius) # Collides with nobody.
		elif _can_stand(animal["position"], radius):
			occupied.append(Vector3(animal["position"].x, animal["position"].y, radius))
		else:
			displaced.append(animal)
	for animal in displaced:
		var radius: float = ANIMAL_RADIUS[animal["kind"]]
		animal["position"] = _open_ground_near(animal["position"], radius, false, occupied)
		occupied.append(Vector3(animal["position"].x, animal["position"].y, radius))
	for animal in _animals:
		if not _can_stand(animal["target"], ANIMAL_RADIUS[animal["kind"]]):
			animal["target"] = animal["position"]
	if not _can_stand(player_position):
		player_position = _open_ground_near(player_position, PLAYER_RADIUS, false, occupied)
	_stones.clear()
	selected_target = -1
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
	# Saves from before aura and feeding (version 1) start at zero, part fed.
	aura = int(data.get("aura", 0))
	var feeding: Dictionary = data.get("fed", {})
	fed = float(feeding.get("level", FED_START))
	_meal_timer = float(feeding.get("meal_timer", MEAL_INTERVAL))
	_cave_progress = {}
	var caves: Dictionary = data.get("caves", {})
	for key in caves:
		_cave_progress[key] = {"checkpoints": caves[key]["checkpoints"].map(func(v): return int(v)), "killed": caves[key]["killed"].map(func(v): return int(v))}
	_villager_check = 0.0
	_regrowth_check = 0.0
	view.position = to_world(player_position) + CAMERA_OFFSET
	_refresh_visible()
	_sync_presentation(0.0)
	var underground: Dictionary = data.get("underground", {})
	if not underground.is_empty():
		_resume_cave(underground)
	_update_hud()


## Re-enters the saved cave and puts Oravitsa and its monsters back where
## they were. A cave that no longer exists at its key leaves her at its mouth.
func _resume_cave(underground: Dictionary) -> void:
	var parts: PackedStringArray = String(underground["cave"]).split(",")
	var cave: Dictionary = landscape.cave_at(Vector2i(int(parts[0]), int(parts[1])))
	if cave.is_empty():
		return
	_enter_cave(cave, true)
	var offset := Vector2(underground["offset"][0], underground["offset"][1])
	if _cave.can_walk(_cave.entrance + offset, PLAYER_RADIUS / METRE):
		player_position = from_ground(_cave.entrance + offset)
	_cave_exit_armed = offset.length() > 3.0
	var saved := {}
	for record in underground["monsters"]:
		saved[int(record[0])] = record
	for data in _animals:
		if not saved.has(data["cave_index"]):
			continue
		var record: Array = saved[data["cave_index"]]
		var spot: Vector2 = _cave.entrance + Vector2(record[1], record[2])
		if _cave.can_walk(spot, ANIMAL_RADIUS[data["kind"]] / METRE):
			data["position"] = from_ground(spot)
			data["target"] = data["position"]
		data["stun"] = float(record[3])
	_loaded_center = Vector2i(-999, -999)
	_refresh_cave_creatures()
	view.position = to_world(player_position) + CAMERA_OFFSET
	_sync_presentation(0.0)


func _save_game() -> void:
	var error: String = SAVE_GAME.write(save_state(), save_path)
	if error.is_empty():
		_show_notice("Game saved")
	else:
		_show_notice("Save failed: " + error + ". The previous save is unchanged.", 5.0)


func _load_game() -> void:
	var result: Dictionary = SAVE_GAME.read(save_path)
	var note := "Game loaded"
	if not result["ok"]:
		# Never discard the slot; offer the previous save if it is intact.
		var backup: Dictionary = SAVE_GAME.read(save_path + ".bak")
		if backup["ok"] and backup["data"]["world"] == WORLD_ID:
			note = "The save was %s; loaded the previous save" % ("missing" if result["missing"] else "unreadable (%s)" % result["error"])
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
	if in_cave():
		_process_cave(delta)
		return
	_rebase_if_needed()
	_update_food_regrowth(delta)
	_update_hunger(delta)
	_villager_check -= delta
	if _villager_check <= 0.0:
		_villager_check = 0.5
		_update_villagers()
	super._process(delta)
	_check_cave_mouth()


func in_cave() -> bool:
	return _cave != null


func _refresh_visible() -> void:
	if in_cave():
		_loaded_center = Vector2i(-999, -999)
		_refresh_cave_creatures()
	else:
		super._refresh_visible()


## Walking into a cave mouth enters its level; stepping back out re-arms it.
func _check_cave_mouth() -> void:
	var here := absolute_ground(player_position)
	var cave: Dictionary = landscape.cave_at(Vector2i(floori(here.x / 256), floori(here.y / 128)))
	if cave.is_empty():
		_cave_armed = true
		return
	var distance := here.distance_to(cave["mouth"])
	if distance > CAVE_REARM:
		_cave_armed = true
	elif distance < CAVE_ENTER_RADIUS and _cave_armed and player_stun <= 0.0:
		_enter_cave(cave)


## The surface freezes while Oravitsa is underground: its landscape, food and
## wildlife are hidden and kept as they are, then restored on the way out.
func _enter_cave(cave: Dictionary, quiet: bool = false) -> void:
	var region: Vector2i = cave["region"]
	_cave_key = "%d,%d" % [region.x, region.y]
	if not _cave_progress.has(_cave_key):
		_cave_progress[_cave_key] = {"checkpoints": [], "killed": []}
	var progress: Dictionary = _cave_progress[_cave_key]
	_cave_return = cave["mouth"] + cave["facing"] * 2.2
	var mouth: Vector2 = cave["mouth"] - landscape.origin
	for sprite in _active_animals.values():
		sprite.queue_free()
	_active_animals.clear()
	_sync_animal_lifecycle()
	_surface_animals = _animals
	var creatures: Array[Dictionary] = []
	_animals = creatures
	_stones.clear()
	selected_target = -1
	_status_peaks.clear()
	_surface_landscape = landscape
	landscape.visible = false
	for node in _forage_visuals.values():
		node.visible = false
	var level: Node3D = CAVE_LEVEL.new()
	level.name = "Cave"
	level.setup(region, mouth, RAT, SPIDER)
	stage.add_child(level)
	level.build()
	landscape = level
	_cave = level
	for i in level.spawns.size():
		if i in progress["killed"]:
			continue
		var spot: Vector3 = level.spawns[i]
		var data := _animal_record(int(spot.z), from_ground(Vector2(spot.x, spot.y)))
		data["cave_index"] = i
		data["bite_cooldown"] = 0.0
		data["attack_time"] = 0.0
		data["state"] = "roam"
		_animals.append(data)
	for i in progress["checkpoints"]:
		level.checkpoint_collected(int(i))
	player_position = from_ground(level.entrance)
	_cave_exit_armed = false
	_set_cave_lighting(true)
	_loaded_center = Vector2i(-999, -999)
	_refresh_cave_creatures()
	view.position = to_world(player_position) + CAMERA_OFFSET
	if not quiet:
		_show_notice("Oravitsa enters the cave: find its glowing checkpoints", 3.5)
	_update_hud()


func _exit_cave(quiet: bool = false) -> void:
	for sprite in _active_animals.values():
		sprite.queue_free()
	_active_animals.clear()
	_sync_animal_lifecycle()
	_animals = _surface_animals
	var none: Array[Dictionary] = []
	_surface_animals = none
	_stones.clear()
	selected_target = -1
	_status_peaks.clear()
	_cave.queue_free()
	_cave = null
	landscape = _surface_landscape
	landscape.visible = true
	for node in _forage_visuals.values():
		node.visible = true
	_set_cave_lighting(false)
	player_position = _local_point([_cave_return.x, _cave_return.y])
	_cave_armed = false
	view.position = to_world(player_position) + CAMERA_OFFSET
	_refresh_visible()
	_sync_presentation(0.0)
	if not quiet:
		_show_notice("Back in the woods")
	_update_hud()


func _set_cave_lighting(underground: bool) -> void:
	var environment: Environment = null
	var sun: DirectionalLight3D = null
	for child in stage.get_children():
		if child is WorldEnvironment:
			environment = child.environment
		elif child is DirectionalLight3D:
			sun = child
	if underground:
		_surface_light = {"background": environment.background_color, "ambient": environment.ambient_light_energy, "ambient_color": environment.ambient_light_color, "sun": sun.light_energy}
		environment.background_color = Color("050505")
		environment.ambient_light_color = Color("7a7f8f")
		environment.ambient_light_energy = 0.32
		sun.light_energy = 0.0
		if _lantern == null:
			_lantern = OmniLight3D.new()
			_lantern.name = "Lantern"
			_lantern.light_color = Color("ffd9a0")
			_lantern.light_energy = 2.2
			_lantern.omni_range = 11.0
			stage.add_child(_lantern)
		_lantern.visible = true
		_lantern.position = to_world(player_position) + Vector3.UP * 1.7
	elif not _surface_light.is_empty():
		environment.background_color = _surface_light["background"]
		environment.ambient_light_energy = _surface_light["ambient"]
		environment.ambient_light_color = _surface_light["ambient_color"]
		sun.light_energy = _surface_light["sun"]
		_lantern.visible = false


func _refresh_cave_creatures() -> void:
	var cell := _world_cell(player_position)
	if cell == _loaded_center:
		return
	_loaded_center = cell
	_loaded_half = _stream_half()
	_refresh_animals(cell)
	_sync_animal_lifecycle()


## Underground only Oravitsa, her skills and the cave's monsters run; the
## surface simulation waits, unchanged, for her return.
func _process_cave(delta: float) -> void:
	_update_player(delta)
	if not in_cave():
		return
	_refresh_cave_creatures()
	_move_cave_creatures(delta)
	_update_sling(delta)
	_update_hunger(delta)
	_check_cave_points()
	if not in_cave():
		return
	_update_hud()
	_minimap.queue_redraw()
	_sync_presentation(delta)


func _check_cave_points() -> void:
	var here := to_ground(player_position)
	var progress: Dictionary = _cave_progress[_cave_key]
	for i in _cave.checkpoints.size():
		if i not in progress["checkpoints"] and here.distance_to(_cave.checkpoints[i]) <= _cave.CHECKPOINT_RADIUS:
			progress["checkpoints"].append(i)
			_cave.checkpoint_collected(i)
			_add_aura(AURA["checkpoint"], "cave checkpoint %d of %d" % [progress["checkpoints"].size(), _cave.checkpoints.size()])
	var to_exit := here.distance_to(_cave.entrance)
	if to_exit > 3.0:
		_cave_exit_armed = true
	elif _cave_exit_armed and to_exit < _cave.EXIT_RADIUS:
		_exit_cave()


## Giant rats and spiders roam near where they lair, chase Oravitsa when they
## see her and bite, which only stuns her. Shoo drives one off; Sling stuns
## one so it can be finished for aura.
func _move_cave_creatures(delta: float) -> void:
	for id in _active_animals.keys():
		var data := _animals[id]
		if not data["alive"]:
			continue
		var sprite: AnimatedSprite2D = _active_animals[id]
		for timer in ["stun", "shoo", "bite_cooldown", "attack_time"]:
			data[timer] = maxf(0.0, data[timer] - delta)
		var position: Vector2 = data["position"]
		if data["stun"] > 0.0 or data["attack_time"] > 0.0:
			data["velocity"] = Vector2.ZERO
			continue
		var kind: int = data["kind"]
		var to_player := player_position - position
		var distance := to_player.length()
		var speed: float = ANIMAL_SPEEDS[kind]
		var target: Vector2 = data["target"]
		if data["shoo"] > 0.0:
			target = position - to_player.normalized() * 300.0
			speed *= 1.6
			data["state"] = "scared"
		elif distance < MONSTER_SIGHT * METRE:
			data["state"] = "hunt"
			target = player_position
			if distance <= ANIMAL_RADIUS[kind] + PLAYER_RADIUS + 10.0 and data["bite_cooldown"] <= 0.0 and player_stun <= 0.0:
				player_stun = _player_stun_time(BITE_STUN)
				data["bite_cooldown"] = BITE_COOLDOWN
				data["attack_time"] = 0.6
				data["velocity"] = Vector2.ZERO
				_show_notice("The %s bit Oravitsa!" % ANIMAL_NAMES[kind].to_lower())
				continue
		else:
			data["state"] = "roam"
			speed *= 0.35
			data["timeout"] = float(data["timeout"]) - delta
			if position.distance_to(target) < 12.0 or data["timeout"] <= 0.0:
				data["turn"] += 1
				var home: Vector2 = data["home"]
				var spot: Vector2 = home + Vector2.from_angle(_hash(id, data["turn"], 1801) * TAU) * _hash(id, data["turn"], 1802) * 3.0 * METRE
				target = spot if _can_stand(spot, ANIMAL_RADIUS[kind]) else position
				data["target"] = target
				data["timeout"] = 2.0 + _hash(id, data["turn"], 1803) * 4.0
		var heading := position.direction_to(target) if position.distance_to(target) > 4.0 else Vector2.ZERO
		var velocity: Vector2 = data["velocity"]
		velocity = velocity.move_toward(heading * speed, 600.0 * delta)
		var step := velocity * delta
		var candidate := position
		if _can_animal_move(id, candidate + Vector2(step.x, 0)):
			candidate.x += step.x
		if _can_animal_move(id, candidate + Vector2(0, step.y)):
			candidate.y += step.y
		if candidate.distance_squared_to(position) < 0.01:
			velocity = Vector2.ZERO
		data["velocity"] = velocity
		data["position"] = candidate
		sprite.position = candidate


func _animation_override(id: int, wanted: String, animator: AnimationPlayer) -> String:
	if float(_animals[id].get("attack_time", 0.0)) > 0.0 and animator.has_animation("Attack"):
		return "Attack"
	if float(_animals[id].get("thanks", 0.0)) > 0.0 and animator.has_animation("Wave"):
		return "Wave"
	return wanted


## Nearest stunned giant rat or spider within reach; only those can be killed.
func _stunned_monster_near(radius: float) -> int:
	var nearest := -1
	var best := radius
	for id in _active_animals:
		var data := _animals[id]
		if data["alive"] and data["kind"] in [RAT, SPIDER] and data["stun"] > 0.0:
			var distance := player_position.distance_to(data["position"])
			if distance <= best:
				best = distance
				nearest = id
	return nearest


func _collect_nearby() -> void:
	if not in_cave():
		super._collect_nearby()
		return
	var id := _stunned_monster_near(HARE_PICKUP_RADIUS)
	if id >= 0 and player_stun <= 0.0:
		_kill_monster(id)


## A stunned giant rat or spider is finished off once, for aura; its Death
## clip plays and it stays dead in this cave.
func _kill_monster(id: int) -> void:
	var data := _animals[id]
	if not data["alive"] or data["kind"] not in [RAT, SPIDER] or data["stun"] <= 0.0:
		return
	data["alive"] = false
	data["stun"] = 0.0
	data["velocity"] = Vector2.ZERO
	_cave_progress[_cave_key]["killed"].append(int(data["cave_index"]))
	if _animal_models.has(id):
		var model: Node3D = _animal_models[id]
		var animator: AnimationPlayer = _animal_players.get(id)
		_animal_models.erase(id)
		_animal_players.erase(id)
		_animal_stars[id].queue_free()
		_animal_stars.erase(id)
		_animal_shadows[id].queue_free()
		_animal_shadows.erase(id)
		if animator != null and animator.has_animation("Death"):
			animator.speed_scale = 1.0
			animator.play("Death")
			get_tree().create_timer(2.5).timeout.connect(func():
				if is_instance_valid(model):
					model.queue_free())
		else:
			model.queue_free()
	if _active_animals.has(id):
		_active_animals[id].queue_free()
		_active_animals.erase(id)
	if selected_target == id:
		selected_target = -1
	_add_aura(AURA["rat"] if data["kind"] == RAT else AURA["spider"], "defeated a " + ANIMAL_NAMES[data["kind"]].to_lower())


func is_hungry() -> bool:
	return fed <= 0.0


## Starving she walks at HUNGRY_SPEED, half fed at normal speed, and full at
## FULL_SPEED.
func fed_speed() -> float:
	var level := fed / FED_MAX
	return lerpf(HUNGRY_SPEED, 1.0, level * 2.0) if level < 0.5 else lerpf(1.0, FULL_SPEED, level * 2.0 - 1.0)


func _move_speed() -> float:
	return SPEED * fed_speed()


func _player_stun_time(seconds: float) -> float:
	return seconds * lerpf(1.0, FULL_STUN, fed / FED_MAX)


## Aura, the game's points: every gain or loss shows a notice and flashes the
## HUD badge.
func _add_aura(amount: int, reason: String) -> void:
	aura += amount
	_show_notice("%+d aura · %s" % [amount, reason])
	if is_instance_valid(_aura_badge):
		_aura_badge.show_change(amount)
	_update_hud()


## One item picked at random from the bag (each item equally likely), removed
## from it; "" when the bag is empty.
func _take_random_food() -> String:
	var total := berries_basket + basket + raw_meat
	if total <= 0:
		return ""
	var pick := _food_rng.randi_range(0, total - 1)
	if pick < berries_basket:
		berries_basket -= 1
		return "berries"
	if pick < berries_basket + basket:
		basket -= 1
		return "mushroom"
	raw_meat -= 1
	return "raw_meat"


## She grows hungrier steadily and eats a random bag item each MEAL_INTERVAL
## unless she is full. A due meal waits for food, and once she is starving
## she eats whatever she finds at once.
func _update_hunger(delta: float) -> void:
	var was_hungry := is_hungry()
	fed = maxf(0.0, fed - FED_DECAY * delta)
	_meal_timer = maxf(0.0, _meal_timer - delta)
	if _meal_timer > 0.0 and fed > 0.0:
		return
	if fed >= FED_FULL:
		_meal_timer = MEAL_INTERVAL
		return
	var meal := _take_random_food()
	if meal.is_empty():
		if is_hungry() and not was_hungry:
			_show_notice("Oravitsa is starving and slower: find food", 3.0)
			_update_hud()
		return
	fed = minf(FED_MAX, fed + MEAL_VALUE[meal])
	_meal_timer = MEAL_INTERVAL
	_show_notice("Oravitsa ate " + MEAL_NAMES[meal] + ("; she is no longer starving" if was_hungry else ""))
	_update_hud()


## The hamlet chieftain Oravitsa can give food to: close by, awake and calm.
func _offer_chief() -> int:
	for id in _active_animals:
		var data := _animals[id]
		if data.get("chief", false) and data["alive"] and data["stun"] <= 0.0 and data["shoo"] <= 0.0 and player_position.distance_to(data["position"]) <= OFFER_RADIUS * METRE:
			return id
	return -1


func _offer_ready() -> bool:
	return not in_cave() and player_stun <= 0.0 and basket + berries_basket + raw_meat > 0 and _offer_chief() >= 0


## Gives one random bag item to the chieftain for aura; raw meat is worth
## most. He waves his thanks.
func _offer_food() -> void:
	if not _offer_ready():
		return
	var chief := _offer_chief()
	var meal := _take_random_food()
	_animals[chief]["thanks"] = 1.8
	_animals[chief]["velocity"] = Vector2.ZERO
	_add_aura(AURA["meat"] if meal == "raw_meat" else AURA["food"], "gave " + MEAL_NAMES[meal] + " to the chieftain")


func _unhandled_input(event: InputEvent) -> void:
	# Beside a chieftain, A gives him food instead of picking up.
	if event is InputEventJoypadButton and event.pressed and event.is_action_pressed("pick_up") and _offer_ready():
		_offer_food()
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(event)


func _on_shooed(id: int) -> void:
	if _animals[id]["kind"] == VILLAGER:
		_add_aura(AURA["shoo_villager"], "never shoo villagers")


func _on_sling_hit(id: int) -> void:
	if _animals[id]["kind"] == VILLAGER:
		_add_aura(AURA["hit_villager"], "never hit villagers")


func _passes_through(id: int) -> bool:
	return _animals[id]["kind"] == VILLAGER


func _moves_itself(id: int, delta: float) -> bool:
	if _animals[id]["kind"] != VILLAGER:
		return false
	_move_villager(id, delta)
	return true


## Villagers stroll around their clearing, pause, and ignore Oravitsa: she
## walks through them and they through her. Shoo makes one run off; Sling
## stuns one. Both cost aura. The chieftain keeps to his post at the store tent.
func _move_villager(id: int, delta: float) -> void:
	var data := _animals[id]
	var sprite: AnimatedSprite2D = _active_animals[id]
	data["stun"] = maxf(0.0, data["stun"] - delta)
	data["shoo"] = maxf(0.0, data["shoo"] - delta)
	data["thanks"] = maxf(0.0, data.get("thanks", 0.0) - delta)
	var position: Vector2 = data["position"]
	if data["stun"] > 0.0 or data["thanks"] > 0.0:
		data["velocity"] = Vector2.ZERO
		return
	var speed: float = ANIMAL_SPEEDS[VILLAGER]
	var target: Vector2 = data["target"]
	if data["shoo"] > 0.0:
		var away: Vector2 = (position - player_position).normalized()
		if away.length_squared() < 0.01:
			away = Vector2.DOWN
		target = position + away * 300.0
		speed *= 3.0
		data["state"] = "scared"
	else:
		if data["state"] == "scared":
			data["state"] = "roam"
			data["timeout"] = 0.0
		data["timeout"] = float(data["timeout"]) - delta
		if data.get("chief", false):
			target = data["home"]
			data["target"] = target
		elif position.distance_to(target) < 10.0 or data["timeout"] <= 0.0:
			data["turn"] += 1
			var home: Vector2 = data["home"]
			target = position # Pauses are part of strolling.
			if _hash(id, data["turn"], 1701) >= 0.35:
				var reach: float = (4.0 + _hash(id, data["turn"], 1702) * (landscape.HAMLET_RADIUS - 9.0)) * METRE
				var spot: Vector2 = home + Vector2.from_angle(_hash(id, data["turn"], 1703) * TAU) * reach
				if _can_stand(spot, ANIMAL_RADIUS[VILLAGER]):
					target = spot
			data["target"] = target
			data["timeout"] = 3.0 + _hash(id, data["turn"], 1704) * 6.0
			data["state"] = "roam"
	var heading := position.direction_to(target) if position.distance_to(target) > 6.0 else Vector2.ZERO
	var velocity: Vector2 = data["velocity"]
	velocity = velocity.move_toward(heading * speed, 220.0 * delta)
	var step := velocity * delta
	var candidate := position
	if _can_animal_move(id, candidate + Vector2(step.x, 0)):
		candidate.x += step.x
	if _can_animal_move(id, candidate + Vector2(0, step.y)):
		candidate.y += step.y
	if candidate.distance_squared_to(position) < 0.01:
		velocity = Vector2.ZERO
	data["velocity"] = velocity
	data["position"] = candidate
	sprite.position = candidate


## Villagers appear at hamlets near Oravitsa and leave once she is far away.
## They are not wildlife and are never saved: each hamlet regenerates its
## own seeded villagers.
func _update_villagers() -> void:
	var here := absolute_ground(player_position)
	var block := Vector2i(floori(here.x / landscape.HAMLET_BLOCK.x), floori(here.y / landscape.HAMLET_BLOCK.y))
	var wanted := {}
	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var hamlet: Dictionary = landscape.hamlet_at(block + Vector2i(dx, dz))
			if not hamlet.is_empty() and here.distance_to(hamlet["center"]) < VILLAGER_APPEAR:
				wanted[hamlet["block"]] = hamlet
	var present := {}
	var changed := false
	for id in _animals.size():
		var data := _animals[id]
		if data["kind"] != VILLAGER or not data["alive"]:
			continue
		var home: Dictionary = landscape.hamlet_at(data["hamlet"])
		if home.is_empty() or here.distance_to(home["center"]) > VILLAGER_LEAVE:
			data["alive"] = false
			data["gone"] = true
			data["respawn"] = 0.0
			if _active_animals.has(id):
				_active_animals[id].queue_free()
				_active_animals.erase(id)
			if selected_target == id:
				selected_target = -1
			changed = true
		else:
			present[data["hamlet"]] = true
	for key in wanted:
		if not present.has(key):
			_spawn_villagers(wanted[key])
			changed = true
	if changed:
		_refresh_animals(_loaded_center)
		_sync_animal_lifecycle()


## Each hamlet has its chieftain, at his post before the entrance of his store
## tent, and two to four villagers.
func _spawn_villagers(hamlet: Dictionary) -> void:
	var block: Vector2i = hamlet["block"]
	var span := VILLAGERS_PER_HAMLET.y - VILLAGERS_PER_HAMLET.x + 1
	var count := VILLAGERS_PER_HAMLET.x + mini(span - 1, int(landscape.random_at(block, 140) * span))
	var center: Vector2 = hamlet["center"]
	var store: Vector2 = hamlet["store"]
	for attempt in 8:
		var q: Vector2 = store + Vector2.from_angle(PI * 0.5 + attempt * TAU / 8.0) * (landscape.STORE_HALF + 0.9)
		var post := _local_point([q.x, q.y])
		if _can_stand(post, ANIMAL_RADIUS[VILLAGER]):
			var chief := _animal_record(VILLAGER, post)
			chief["home"] = post
			chief["target"] = post
			chief["state"] = "roam"
			chief["hamlet"] = block
			chief["chief"] = true
			_add_villager(chief)
			break
	for i in count:
		for attempt in 30:
			var angle: float = landscape.random_at(block + Vector2i(i, attempt), 141) * TAU
			var reach: float = 5.0 + landscape.random_at(block + Vector2i(attempt, i), 142) * (landscape.HAMLET_RADIUS - 11.0)
			var q: Vector2 = center + Vector2.from_angle(angle) * reach
			var spot := _local_point([q.x, q.y])
			if not _can_stand(spot, ANIMAL_RADIUS[VILLAGER]):
				continue
			var data := _animal_record(VILLAGER, spot)
			data["home"] = _local_point([center.x, center.y])
			data["target"] = spot
			data["state"] = "roam"
			data["hamlet"] = block
			data["look"] = (int(landscape.random_at(block, 143) * VILLAGER_LOOKS.size()) + i) % VILLAGER_LOOKS.size()
			_add_villager(data)
			break


func _add_villager(data: Dictionary) -> void:
	for id in _animals.size():
		if _animals[id]["kind"] == VILLAGER and _animals[id]["gone"] and not _active_animals.has(id):
			_animals[id] = data
			return
	_animals.append(data)


## Villagers, giant rats and giant spiders use CC0 Quaternius models; their
## clips are aliased to the Idle/Walk/Attack/Death names the stage plays.
func _animal_model(id: int) -> Node3D:
	var kind: int = _animals[id]["kind"]
	if kind not in [RAT, SPIDER, VILLAGER]:
		return super._animal_model(id)
	var file: String = {RAT: "rat", SPIDER: "spider"}.get(kind, VILLAGER_LOOKS[int(_animals[id].get("look", 0)) % VILLAGER_LOOKS.size()])
	var height: float = _animal_heights[kind]
	if _animals[id].get("chief", false):
		file = "chieftain"
		height = CHIEF_HEIGHT
	var model: Node3D = load(CREATURES + file + ".glb").instantiate()
	stage.add_child(model)
	var bounds := _model_bounds(model)
	model.scale = Vector3.ONE * height / maxf(bounds.size.y, 0.01)
	var animator := _find_animator(model)
	if animator != null:
		_alias_clips(animator)
		animator.play("Idle")
		_animal_players[id] = animator
	return model


func _alias_clips(animator: AnimationPlayer) -> void:
	var library := animator.get_animation_library(animator.get_animation_library_list()[0])
	for clip in ["Idle", "Walk", "Attack", "Death", "Wave"]:
		if library.has_animation(clip):
			continue
		for clip_name in animator.get_animation_list():
			if clip_name.ends_with("|" + clip) or clip_name.ends_with("_" + clip):
				var animation: Animation = animator.get_animation(clip_name)
				animation.loop_mode = Animation.LOOP_NONE if clip in ["Attack", "Death", "Wave"] else Animation.LOOP_LINEAR
				library.add_animation(clip, animation)
				break


## Fights and provocation take precedence over stun and fear icons; each is
## timed, so its bar shows the time left of that phase.
func _status_states(id: int) -> Array:
	var data: Dictionary = _animals[id]
	if data["alive"] and data["fight_with"] >= 0:
		return [["fighting", clampf(data["fight_time"] / FIGHT_TIME, 0.0, 1.0)]]
	if data["alive"] and data["aggro"] == AGGRO_WARN:
		return [["angry", clampf(data["aggro_time"] / AGGRO_WARN_TIME, 0.0, 1.0)]]
	if data["alive"] and data["aggro"] == AGGRO_CHARGE:
		return [["charging", clampf(data["aggro_time"] / AGGRO_CHARGE_TIME, 0.0, 1.0)]]
	return super._status_states(id)


func _sync_presentation(delta: float) -> void:
	super._sync_presentation(delta)
	if in_cave():
		if is_instance_valid(_lantern):
			_lantern.position = heroine.position + Vector3.UP * 1.7
		for id in _animal_stars:
			_animal_stars[id].set_on_top(true) # Readable against the monsters' dark bodies.
		var near_exit: bool = to_ground(player_position).distance_to(_cave.entrance) < 3.0
		_landmark_label.text = "Way out to the woods" if near_exit else "Cave · first level"
		return
	if audio != null:
		audio.update(delta)
	var near_chief := false
	for id in _animal_models:
		var data: Dictionary = _animals[id]
		if data.get("chief", false) and data["velocity"].length_squared() < 1:
			# At his post he turns to Oravitsa when she comes close.
			var to_her: Vector2 = player_position - data["position"]
			if to_her.length() < 7.0 * METRE:
				near_chief = true
				var facing: Vector3 = to_world(player_position) - _animal_models[id].position
				_animal_models[id].rotation.y = atan2(facing.x, facing.z)
	for id in _animal_stars:
		var data: Dictionary = _animals[id]
		var marker: Node3D = _animal_stars[id]
		if data["fight_with"] >= 0:
			# One icon centred over the pair, so the two never overlap.
			var other: int = data["fight_with"]
			marker.visible = id < other or not _animal_models.has(other)
			marker.set_on_top(true)
			if _animal_models.has(other):
				var top := maxf(_animal_heights[data["kind"]], _animal_heights[_animals[other]["kind"]])
				marker.position = (_animal_models[id].position + _animal_models[other].position) * 0.5 + Vector3.UP * (top + 0.4)
		elif data["aggro"] != AGGRO_NONE:
			marker.set_on_top(true)
	var absolute := absolute_ground(player_position)
	_landmark_label.text = landscape.biome_name(to_ground(player_position))
	if absolute.distance_to(Vector2(7, -4)) < 9:
		_landmark_label.text = "Forester’s cottage"
	if absolute.distance_to(landscape.WELL_POSITION) < 3:
		_landmark_label.text = "The forester’s old well"
	var site: Dictionary = landscape.landmark_at(Vector2i(floori(absolute.x / 256), floori(absolute.y / 128)))
	if absolute.distance_to(site["position"]) < 7:
		_landmark_label.text = ["Forgotten homestead", "Old standing stones", "Abandoned woodcutters’ camp", "Mossy cairns"][site["kind"]]
	var hamlet: Dictionary = landscape.hamlet_near(absolute)
	if not hamlet.is_empty() and absolute.distance_to(hamlet["center"]) < landscape.HAMLET_RADIUS:
		_landmark_label.text = "Hamlet · the chieftain’s store" if near_chief else "Hamlet"
	var cave: Dictionary = landscape.cave_at(Vector2i(floori(absolute.x / 256), floori(absolute.y / 128)))
	if not cave.is_empty() and absolute.distance_to(cave["mouth"]) < 8:
		_landmark_label.text = "Cave mouth"
	var inside := Rect2(4.7, -5.8, 4.6, 3.8).has_point(absolute)
	for roof in landscape.roofs:
		roof.visible = not inside
