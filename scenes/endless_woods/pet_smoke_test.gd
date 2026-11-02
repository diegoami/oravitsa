extends SceneTree

## Pets (#65): seeded hamlet cats and dogs who follow Oravitsa with enough
## aura, go underground with her, kill monsters only while they are stunned,
## scared or slowed, get poisoned or wounded by monster bites and are healed
## by her Cure.

const STEP := 1.0 / 30.0

var world


func _initialize() -> void:
	call_deferred("_run")


func _travel(absolute: Vector2) -> void:
	world.player_position = world.from_ground(absolute - world.landscape.origin)
	world._rebase_if_needed()
	world.view.position = world.to_world(world.player_position) + world.CAMERA_OFFSET
	world._refresh_visible()
	world.pets.refresh()
	world.pets.update(0.0)
	world._sync_presentation(0.0)
	await process_frame


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


func _a() -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	return event


func _here() -> Vector2:
	return world.absolute_ground(world.player_position)


func _live(spec: Dictionary) -> Dictionary:
	return world.pets.find(spec["hamlet"])


func _count(spec: Dictionary) -> int:
	var count := 0
	for record in world.pets.pets:
		count += 1 if record["hamlet"] == spec["hamlet"] else 0
	return count


## Walks up to a hamlet's pet (beside it, not on it) with plenty of aura and
## adopts it.
func _adopt(spec: Dictionary) -> Dictionary:
	await _travel(spec["post"] + Vector2(1.2, 0.8))
	world.aura = 100
	var record := _live(spec)
	assert(world.pets.nearest() == record, "She stands by the %s" % spec["kind"])
	world.pets.toggle()
	assert(record["state"] == "following", "The %s follows" % spec["kind"])
	return record


## Every pet back at home.
func _dismiss_all() -> void:
	for record in world.pets.pets:
		if record["state"] != "post":
			world.pets._home(record)


## Absolute metres of a cave cell centre.
func _cell(cell: Vector2i) -> Vector2:
	return world._cave.cell_center(cell) + world.pets._origin()


func _put_monster(id: int, absolute: Vector2, refresh: bool = true) -> void:
	var data: Dictionary = world._animals[id]
	var at: Vector2 = world.from_ground(absolute - world.pets._origin())
	data["position"] = at
	data["target"] = at
	data["velocity"] = Vector2.ZERO
	for timer in ["stun", "shoo", "slow", "held", "bite_cooldown", "attack_time", "burst", "burst_cooldown", "flee", "dart"]:
		data[timer] = 0.0
	data["state"] = "roam"
	if world._active_animals.has(id):
		world._active_animals[id].position = at
	if refresh:
		world._loaded_center = Vector2i(-999, -999)
		world._refresh_cave_creatures()


func _clear_monsters(keep: Array) -> void:
	for id in world._active_animals.keys():
		if id not in keep and world._animals[id]["kind"] in world.MONSTERS:
			_put_monster(id, _here() + Vector2(120, 120), false)


func _monsters(kind: int = -1) -> Array:
	var ids := []
	for id in world._active_animals:
		var data: Dictionary = world._animals[id]
		if data["kind"] in world.MONSTERS and data["alive"] and (kind < 0 or data["kind"] == kind):
			ids.append(id)
	ids.sort()
	return ids


## A floor cell centre and an open spot `low`–`high` metres from it, with a
## wall between them (or none, when `walled` is false), in a stable order.
func _pair(low: float, high: float, walled: bool) -> Array:
	var cells: Array = world._cave.open.keys()
	cells.sort()
	var spots := []
	for cell in cells:
		for dz in [-0.7, 0.0, 0.7]:
			for dx in [-0.7, 0.0, 0.7]:
				var p := _cell(cell) + Vector2(dx, dz)
				if world._cave.can_walk(p - world.pets._origin(), 0.35):
					spots.append(p)
	for a in cells:
		var pa := _cell(a)
		for pb in spots:
			var distance: float = pa.distance_to(pb)
			if distance >= low and distance <= high and world.pets._clear_floor(pa, pb) != walled:
				return [pa, pb]
	return []


## Each follower stands beside her on open ground of the current level.
func _beside(note: String) -> void:
	assert(world.pets.followers().size() == 2, note + ": both pets are with her")
	for record in world.pets.followers():
		var distance: float = record["at"].distance_to(_here())
		assert(distance > 0.5 and distance < 2.6, note + ": beside her (%.2f m)" % distance)
		assert(world.landscape.can_walk(record["at"] - world.pets._origin(), world.pets.RADIUS), note + ": on open ground")


func _stand(absolute: Vector2) -> void:
	world.player_position = world.from_ground(absolute - world.pets._origin())
	world.view.position = world.to_world(world.player_position) + world.CAMERA_OFFSET


## Runs one pet's hunt until monster `id` dies or `seconds` pass; `move` lets
## the monsters move too. Returns whether it died.
func _hunt_until_dead(record: Dictionary, id: int, seconds: float, move: bool = false) -> bool:
	var waited := 0.0
	while waited < seconds:
		if move:
			world._move_cave_creatures(STEP)
		world.pets._hunt(record, STEP)
		waited += STEP
		if not world._animals[id]["alive"]:
			return true
	return false


func _killed(level: int) -> Array:
	return world._cave_progress[world._cave_key]["killed" if level == 1 else "killed_deep"]


func _occurrences(list: Array, value: int) -> int:
	var count := 0
	for item in list:
		count += 1 if int(item) == value else 0
	return count


func _indices() -> Array:
	var result := []
	for data in world._animals:
		result.append(int(data["cave_index"]))
	return result


func _icons(record: Dictionary) -> String:
	return ",".join(record["marker"].icons)


func _run() -> void:
	world = load("res://scenes/endless_woods/woods.tscn").instantiate()
	world.save_path = "user://pet_smoke_save.json"
	world.fright_chance = 0.0
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	await process_frame
	var land: Node3D = world.landscape
	var pets: Node = world.pets
	var kinds: Dictionary = pets.KINDS

	# Protects: hamlets that all or never have a pet, missing kinds, huskies as
	# common as cats, thresholds outside their kind's band or a stronger kind
	# needing less aura, homes on solid ground or outside the clearing, and pets
	# that change between visits.
	assert(kinds["cat"]["band"] == Vector2i(20, 40) and kinds["shiba"]["band"] == Vector2i(40, 65) and kinds["husky"]["band"] == Vector2i(65, 90))
	assert(kinds["cat"]["band"].y <= kinds["shiba"]["band"].x and kinds["shiba"]["band"].y <= kinds["husky"]["band"].x, "Stronger kinds need more aura")
	assert(kinds["husky"]["reach"] > kinds["shiba"]["reach"] and kinds["shiba"]["reach"] > kinds["cat"]["reach"], "The husky reaches farthest")
	assert(kinds["husky"]["bite"] < kinds["shiba"]["bite"] and kinds["shiba"]["bite"] < kinds["cat"]["bite"], "The husky bites fastest")
	assert(kinds["husky"]["height"] > kinds["shiba"]["height"] and kinds["shiba"]["height"] > kinds["cat"]["height"], "The cat is smallest, the husky largest")
	var found := {}
	var tally := {"cat": 0, "shiba": 0, "husky": 0}
	var hamlets := 0
	var with_pet := 0
	for by in range(-6, 7):
		for bx in range(-6, 7):
			var hamlet: Dictionary = land.hamlet_at(Vector2i(bx, by))
			if hamlet.is_empty():
				continue
			hamlets += 1
			var spec: Dictionary = pets.hamlet_pet(hamlet)
			assert(pets.hamlet_pet(hamlet) == spec, "Seeded identically")
			if spec.is_empty():
				continue
			with_pet += 1
			tally[spec["kind"]] += 1
			var band: Vector2i = kinds[spec["kind"]]["band"]
			assert(spec["threshold"] >= band.x and spec["threshold"] <= band.y, "Threshold %d inside the %s band" % [spec["threshold"], spec["kind"]])
			assert(land.can_walk(spec["post"] - land.origin, pets.RADIUS), "The home is on open ground")
			var from_centre: float = spec["post"].distance_to(hamlet["center"])
			assert(from_centre > 20.0 and from_centre < land.HAMLET_RADIUS, "Near the clearing's edge")
			if not found.has(spec["kind"]) or spec["post"].distance_to(Vector2.ZERO) < found[spec["kind"]]["post"].distance_to(Vector2.ZERO):
				found[spec["kind"]] = spec
	var share := float(with_pet) / hamlets
	assert(hamlets > 20 and share > 0.45 and share < 0.75, "About 60%% of hamlets have a pet: %.2f" % share)
	assert(tally["cat"] > tally["shiba"] and tally["shiba"] > tally["husky"] and tally["husky"] > 0, "Cats most common, huskies rarest: %s" % tally)
	var cat: Dictionary = found["cat"]
	var shiba: Dictionary = found["shiba"]
	var husky: Dictionary = found["husky"]
	var shiba_home: Dictionary = land.hamlet_at(shiba["hamlet"])
	await _travel(shiba_home["center"] + Vector2(0, 6))
	var first := _live(shiba)
	assert(not first.is_empty() and first["state"] == "post" and first["at"] == shiba["post"] and first["threshold"] == shiba["threshold"])
	await _travel(shiba_home["center"] + Vector2(3000, 0))
	assert(_live(shiba).is_empty(), "Hamlet pets leave with their hamlet")
	await _travel(shiba_home["center"] + Vector2(0, 6))
	assert(_count(shiba) == 1 and _live(shiba)["kind"] == "shiba" and _live(shiba)["threshold"] == shiba["threshold"] and _live(shiba)["at"] == shiba["post"], "The same pet on revisit")

	# Protects: a pet joining below its threshold, a refusal that does not say
	# what is needed, and a prompt or label hiding the threshold.
	await _travel(shiba["post"] + Vector2(1.2, 0.8))
	var dog := _live(shiba)
	var needed: int = shiba["threshold"]
	world.aura = needed - 17
	world._input_mode = "keyboard"
	world._update_hud()
	assert(world._pet_button.visible and world._pet_button.disabled, "The prompt shows, disabled")
	assert(world._pet_button.text == "The Shiba Inu follows only at %d aura (you have %d)" % [needed, needed - 17], world._pet_button.text)
	world._sync_presentation(0.0)
	assert(dog["label"].visible and dog["label"].text == "Shiba Inu · %d aura" % needed, dog["label"].text)
	assert(dog["node"].get_child_count() > 0, "The dog model is shown")
	world._unhandled_key_input(_key(KEY_G))
	assert(dog["state"] == "post" and "follows only at %d aura" % needed in world._notice_label.text)
	world._input_mode = "controller"
	world._update_hud()
	world._unhandled_input(_a())
	world._pet_button.pressed.emit()
	assert(dog["state"] == "post" and pets.followers().is_empty(), "Too little aura never adopts")

	# Protects: G, controller A or the button doing nothing, a follower that
	# cannot be sent home, and A adopting a pet when that is impossible.
	world.aura = needed
	world._input_mode = "keyboard"
	world._update_hud()
	assert(world._pet_button.text == "Adopt the Shiba Inu (%d aura) [G]" % needed and not world._pet_button.disabled, world._pet_button.text)
	world._unhandled_key_input(_key(KEY_G))
	assert(dog["state"] == "following" and "Shiba Inu follows Oravitsa" in world._notice_label.text)
	world._sync_presentation(0.0)
	assert(not dog["label"].visible, "Followers need no threshold label")
	world.player_position += Vector2(0.4 * world.METRE, 0)
	dog["at"] = _here() + Vector2(0.6, 0)
	world._update_hud()
	assert(world._pet_button.text == "Send the Shiba Inu home [G]", world._pet_button.text)
	world._unhandled_key_input(_key(KEY_G))
	assert(dog["state"] == "returning" and "goes back to" in world._notice_label.text)
	await _travel(shiba["post"] + Vector2(1.2, 0.8))
	world._input_mode = "controller"
	world._update_hud()
	assert(world._pet_button.text.ends_with("[A]") and "A beside a cat or dog" in world._hint_label.text)
	world._unhandled_input(_a())
	assert(dog["state"] == "following", "Controller A adopts")
	dog["at"] = _here() + Vector2(0.6, 0)
	world._unhandled_input(_a())
	assert(dog["state"] == "returning", "Controller A sends it home")
	await _travel(shiba["post"] + Vector2(1.2, 0.8))
	world._input_mode = "touch"
	world._update_hud()
	assert(world._pet_button.text == "Adopt the Shiba Inu (%d aura)" % needed)
	world._pet_button.pressed.emit()
	assert(dog["state"] == "following", "The touch button adopts")
	world._input_mode = "keyboard"
	world._update_hud()
	assert("G: adopt a cat or dog" in world._hint_label.text)
	world.aura = needed - 1
	await _travel(_here() + Vector2(40, 0))
	assert(not pets.can_ask(), "Nothing to adopt out here: A picks up as before")

	# Protects: a third follower, and a refusal that does not explain itself.
	_dismiss_all()
	var kitty := await _adopt(cat)
	var big := await _adopt(husky)
	await _travel(shiba["post"] + Vector2(1.2, 0.8))
	world.aura = 100
	world._update_hud()
	assert(world._pet_button.disabled and world._pet_button.text == "Two pets already follow Oravitsa")
	world._unhandled_key_input(_key(KEY_G))
	assert(_live(shiba)["state"] == "post" and pets.followers().size() == 2 and "Two pets already follow" in world._notice_label.text)

	# Protects: a follower left behind or stuck to her, one that jitters at a
	# single distance, and one that never catches up.
	var lane := Vector2.ZERO
	var start := _here()
	for direction in [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]:
		var open := true
		for i in 60:
			open = open and land.can_walk(start + direction * i * 0.5 - land.origin, 0.8)
		if open:
			lane = direction
			break
	assert(lane != Vector2.ZERO, "An open lane to walk")
	world.fed = world.FED_MAX
	var speed: float = world._move_speed() / world.METRE
	var farthest := 0.0
	for i in 150:
		world.player_position += lane * speed * STEP * world.METRE
		world.view.position = world.to_world(world.player_position) + world.CAMERA_OFFSET
		pets.update(STEP)
		if i > 30:
			for record in pets.followers():
				farthest = maxf(farthest, record["at"].distance_to(_here()))
	assert(farthest < 5.5, "Followers keep up at her full speed: %.2f m" % farthest)
	for i in 90:
		pets.update(STEP)
	var rest := []
	for record in pets.followers():
		var distance: float = record["at"].distance_to(_here())
		assert(distance >= pets.FOLLOW_STOP - 0.3 and distance <= pets.FOLLOW_START + 0.1, "They wait a few metres off: %.2f" % distance)
		assert(not record["moving"])
		rest.append(record["at"])
	assert(rest[0].distance_to(rest[1]) > 0.5, "Two followers keep apart")
	world.player_position += lane * 0.3 * world.METRE
	pets.update(STEP)
	for i in 2:
		assert(pets.followers()[i]["at"] == rest[i], "A small step of hers does not set them walking")

	# Protects: a poisoned or wounded pet that keeps its full pace.
	var paces := []
	for hurt in [false, true]:
		kitty["wounded"] = hurt
		kitty["at"] = _here() - lane * 4.0
		kitty["moving"] = true
		pets._follow(kitty, 0, STEP)
		paces.append(kitty["pace"])
	kitty["wounded"] = false
	assert(paces[0] > 0.0 and absf(paces[1] / paces[0] - pets.AFFLICTED_PACE) < 0.05, "A hurt pet follows at 60%% pace: %s" % [paces])
	world.player_position += lane * 40.0 * world.METRE
	world.view.position = world.to_world(world.player_position) + world.CAMERA_OFFSET
	pets.update(STEP)
	for record in pets.followers():
		assert(record["at"].distance_to(_here()) < 3.0, "Left far behind, it appears just behind her")

	# Protects: pets that block or bump her, become Sling/Shoo/Slow targets,
	# or touch wildlife or villagers on the surface.
	for data in world._animals:
		assert(not data.has("threshold"), "Pets are not wildlife")
	await _travel(start + lane * 10.0)
	world.player_stun = 0.0
	var step: Vector2 = lane * 0.3 * world.METRE
	big["at"] = world.absolute_ground(world.player_position + step)
	assert(world._try_move(step) and world.player_stun == 0.0, "She walks through a pet")
	var wild := -1
	for id in world._active_animals:
		if world._animals[id]["alive"]:
			wild = id
	if wild >= 0:
		world._animals[wild]["stun"] = 2.0
		world._animals[wild]["position"] = world.from_ground(big["at"] - land.origin + Vector2(0.5, 0))
		for i in 10:
			pets.update(STEP)
		assert(world._animals[wild]["alive"] and world._animals[wild]["stun"] == 2.0, "No hunting on the surface")
		world._animals[wild]["stun"] = 0.0

	# Protects: a pet staying after her aura falls below its threshold (decay
	# #64), leaving without a notice, vanishing or never going home.
	world.aura = big["threshold"]
	world._aura_decay = world.AURA_DECAY_SECONDS - 0.1
	world._update_aura_decay(0.2)
	assert(world.aura == big["threshold"] - 1)
	var left_at: Vector2 = big["at"]
	pets.update(0.0)
	assert(big["state"] == "returning" and kitty["state"] == "following", "Only the pet above her aura leaves")
	assert("leaves: Oravitsa's aura fell below %d" % big["threshold"] in world._notice_label.text, world._notice_label.text)
	assert(big["at"] == left_at, "It leaves from where it was")
	await _travel(husky["post"] + Vector2(4, 4))
	for i in 600:
		pets.update(0.1)
	assert(big["state"] == "post" and big["at"].distance_to(husky["post"]) < 3.0, "Back at home")

	# Protects: a following pet also appearing at its own hamlet.
	_dismiss_all()
	kitty = await _adopt(cat)
	big = await _adopt(husky)
	await _travel(land.hamlet_at(cat["hamlet"])["center"] + Vector2(2500, 1800))
	await _travel(land.hamlet_at(cat["hamlet"])["center"] + Vector2(0, 5))
	assert(_count(cat) == 1 and _live(cat)["state"] == "following", "No second cat at its hamlet")
	world._sync_presentation(0.0)
	var drawn := 0
	for node in pets._root.get_children():
		drawn += 1 if node.name.begins_with("Pet_%d_%d" % [cat["hamlet"].x, cat["hamlet"].y]) else 0
	assert(drawn == 1, "Drawn once")
	kitty["poisoned"] = true
	var surface_save: Dictionary = world.save_state()
	kitty["poisoned"] = false
	assert(world.SAVE_GAME.validate(surface_save) == "" and surface_save["pets"].size() == 2 and not surface_save.has("hunters"))

	# Protects: followers left outside the cave, lost between levels or left
	# below, standing in walls, and hamlet pets underground.
	var cave: Dictionary = {}
	for rz in range(-6, 7):
		for rx in range(-4, 5):
			if cave.is_empty():
				cave = land.cave_at(Vector2i(rx, rz))
	assert(not cave.is_empty())
	await _travel(cave["mouth"] + cave["facing"] * 3.0)
	world.player_position = world.from_ground(cave["mouth"] - world.landscape.origin)
	world._cave_armed = true
	world._check_cave_mouth()
	assert(world.in_cave())
	_beside("Entering the cave")
	world._sync_presentation(0.0)
	var visible := 0
	for record in pets.pets:
		visible += 1 if record.has("node") else 0
	assert(visible == 2, "Underground only her followers are there")
	world._change_level(2, true)
	assert(world._cave_depth == 2)
	_beside("On the second level")
	world._change_level(1, true)
	_beside("Back on the first level")

	# Protects: a follower that walks into walls or teleports instead of
	# finding its way around them underground.
	var her_spot := Vector2.INF
	var detour := []
	var floor_cells: Array = world._cave.open.keys()
	floor_cells.sort()
	for her_cell in floor_cells:
		if not detour.is_empty():
			break
		var walk_flow: Dictionary = world._cave.distances_to(her_cell)
		for cell in floor_cells:
			var p := _cell(cell)
			var straight: float = p.distance_to(_cell(her_cell))
			if straight > 4.0 and straight < 7.5 and walk_flow.get(cell, 0) * world._cave.CELL >= straight + 4.0 and not pets._clear_floor(p, _cell(her_cell)):
				her_spot = _cell(her_cell)
				detour = [p]
				break
	assert(not detour.is_empty(), "A spot around a wall from her")
	_stand(her_spot)
	_clear_monsters([])
	big["at"] = detour[0]
	kitty["at"] = her_spot + Vector2(0.5, 0)
	var biggest := 0.0
	var reached := false
	for i in 600:
		var was: Vector2 = big["at"]
		pets._follow(big, 0, STEP)
		biggest = maxf(biggest, was.distance_to(big["at"]))
		if big["at"].distance_to(her_spot) <= pets.FOLLOW_START + 0.05:
			reached = true
			break
	assert(reached and biggest < 0.5, "It walks around the wall to her (largest step %.2f m)" % biggest)

	# Protects: a pet that attacks an awake, unhindered monster, Oravitsa
	# killing a monster herself (walk-over or A), and pets earning aura.
	var lane_pair := _pair(3.5, 5.0, false)
	assert(not lane_pair.is_empty())
	var a: Vector2 = lane_pair[0]
	var toward: Vector2 = a.direction_to(lane_pair[1])
	var rats: Array = _monsters(world.RAT)
	var spiders: Array = _monsters(world.SPIDER)
	assert(rats.size() >= 4 and spiders.size() >= 1)
	_clear_monsters([])
	_stand(a)
	kitty["at"] = a + Vector2(30, 30)
	big["at"] = a + Vector2(30, 31)
	var cat_hunt: Dictionary = pets._record(cat, "following", a)
	_put_monster(rats[0], a + toward * 0.6)
	var aura_before: int = world.aura
	for i in 60:
		pets._hunt(cat_hunt, STEP)
	assert(world._animals[rats[0]]["alive"] and cat_hunt["bite"] == 0.0 and cat_hunt["at"] == a, "No attack on an awake, unhindered monster")
	world._animals[rats[0]]["stun"] = 3.0
	_stand(world.absolute_ground(world._animals[rats[0]]["position"]))
	world._input_mode = "keyboard"
	world._collect_nearby()
	world._input_mode = "controller"
	world._update_player(STEP)
	world._unhandled_input(_a())
	world._collect_nearby()
	assert(world._animals[rats[0]]["alive"] and _killed(1).is_empty(), "Oravitsa never kills a monster, walking over it or with A")
	assert(pets.followers().size() == 2, "A did nothing to the pets")

	# Protects: pets that fail to kill a stunned, a scared or a slowed monster,
	# kill one more than once, give aura, skip its Death clip or forget it.
	_stand(a)
	var hindrances := [["stun", 3.0], ["shoo", 5.0], ["slow", 6.0]]
	for i in 3:
		var id: int = rats[i]
		var hunter: Dictionary = pets._record(husky if i == 1 else cat, "following", a)
		_clear_monsters([])
		_put_monster(id, lane_pair[1])
		world._animals[id][hindrances[i][0]] = hindrances[i][1]
		world._loaded_center = Vector2i(-999, -999)
		world._refresh_cave_creatures()
		assert(world._animal_models.has(id), "The rat is drawn")
		var model: Node3D = world._animal_models[id]
		var dying_before: int = world._dying_models.size()
		var index: int = world._animals[id]["cave_index"]
		assert(_hunt_until_dead(hunter, id, 4.0, i == 1), "A pet kills a monster hindered by %s" % hindrances[i][0])
		var reach: float = kinds[hunter["kind"]]["reach"]
		assert(hunter["at"].distance_to(world.absolute_ground(world._animals[id]["position"])) <= reach + 0.6, "It ran to it and bit")
		assert(world._dying_models.size() == dying_before + 1 and model in world._dying_models, "Its Death clip plays")
		var animator: AnimationPlayer = world._find_animator(model)
		assert(animator.current_animation == "Death")
		assert(not world._active_animals.has(id) and not world._animal_models.has(id))
		assert(_occurrences(_killed(1), index) == 1, "Recorded once in the cave's killed list")
		for j in 30:
			pets._hunt(hunter, STEP)
		assert(not world.pet_kill_monster(id, "cat") and _occurrences(_killed(1), index) == 1, "Killed exactly once")
		assert(world.aura == aura_before, "Pet kills give no aura")
	var killed_index: int = world._animals[rats[0]]["cave_index"]

	# Protects: a cat attacking a goblin, a dog sparing one, and a hurt pet
	# that still attacks.
	world._change_level(2, true)
	_clear_monsters([])
	var goblins: Array = _monsters(world.GOBLIN)
	var kobolds: Array = _monsters(world.KOBOLD)
	assert(goblins.size() >= 2 and kobolds.size() >= 2)
	var deep_pair := _pair(2.0, 3.0, false)
	_stand(deep_pair[0])
	kitty["at"] = deep_pair[0] + Vector2(30, 30)
	big["at"] = deep_pair[0] + Vector2(30, 31)
	var cat_deep: Dictionary = pets._record(cat, "following", deep_pair[0])
	_put_monster(goblins[0], deep_pair[1])
	world._animals[goblins[0]]["stun"] = 3.0
	for i in 90:
		pets._hunt(cat_deep, STEP)
	assert(world._animals[goblins[0]]["alive"] and cat_deep["bite"] == 0.0, "Cats never take goblins")
	var shiba_deep: Dictionary = pets._record(shiba, "following", deep_pair[0])
	shiba_deep["wounded"] = true
	for i in 60:
		assert(not pets._hunt(shiba_deep, STEP))
	assert(world._animals[goblins[0]]["alive"], "A wounded dog never attacks")
	shiba_deep["wounded"] = false
	var goblin_index: int = world._animals[goblins[0]]["cave_index"]
	assert(_hunt_until_dead(shiba_deep, goblins[0], 3.0), "Dogs take goblins")
	assert(_occurrences(_killed(2), goblin_index) == 1, "Second-level kills are recorded too")
	_put_monster(kobolds[0], deep_pair[1])
	world._animals[kobolds[0]]["slow"] = 6.0
	cat_deep["cooldown"] = 0.0
	assert(_hunt_until_dead(cat_deep, kobolds[0], 3.0), "Cats take kobolds")

	# Protects: monster bites that do not poison or wound a pet, a kobold that
	# harms one, and a stunned or scared monster that bites.
	_clear_monsters([])
	_stand(deep_pair[0])
	kitty["at"] = deep_pair[0] + Vector2(0.4, 0)
	_put_monster(kobolds[1], kitty["at"])
	pets._monster_bites()
	assert(not kitty["poisoned"] and not kitty["wounded"], "Kobolds never harm a pet")
	_clear_monsters([])
	_put_monster(goblins[1], kitty["at"])
	world._animals[goblins[1]]["stun"] = 1.0
	pets._monster_bites()
	world._animals[goblins[1]]["stun"] = 0.0
	world._animals[goblins[1]]["shoo"] = 1.0
	pets._monster_bites()
	assert(not kitty["wounded"], "Stunned or scared monsters do not bite")
	world._animals[goblins[1]]["shoo"] = 0.0
	pets._monster_bites()
	assert(kitty["wounded"] and not kitty["poisoned"] and world._animals[goblins[1]]["bite_cooldown"] > 0.0, "A goblin wounds a pet")
	assert("goblin clubbed the cat" in world._notice_label.text, world._notice_label.text)
	world._sync_presentation(0.0)
	assert(kitty["marker"].visible and _icons(kitty) == "wounded", "The wound shows as an icon: " + _icons(kitty))

	# Protects: afflictions lost when saving below.
	var deep_save: Dictionary = world.save_state()
	assert(world.SAVE_GAME.validate(deep_save) == "" and deep_save["pets"].size() == 2 and deep_save["underground"]["level"] == 2)
	world._change_level(1, true)
	_clear_monsters([])
	_stand(lane_pair[0])
	kitty["wounded"] = false
	big["at"] = lane_pair[0] + Vector2(0.4, 0)
	kitty["at"] = lane_pair[0] + Vector2(30, 30)
	_put_monster(spiders[0], big["at"])
	pets._monster_bites()
	assert(big["poisoned"] and not big["wounded"], "A spider poisons a pet")
	_clear_monsters([])
	_put_monster(rats[3], big["at"])
	pets._monster_bites()
	assert(big["poisoned"] and big["wounded"], "A rat wounds a pet")
	world._sync_presentation(0.0)
	assert(_icons(big) == "poisoned,wounded", "Both icons show: " + _icons(big))

	# Protects: a Cure that misses a hurt pet within 6 m, heals one farther
	# away, leaves her stun, is spent with nothing to cure, or names nothing.
	_clear_monsters([])
	world.player_stun = 0.0
	world.player_fright = 0.0
	world.cure_cooldown = 0.0
	big["poisoned"] = false
	big["wounded"] = false
	kitty["wounded"] = false
	world._cure()
	assert(world.cure_cooldown == 0.0, "Nothing to cure: not spent")
	big["at"] = _here() + Vector2(5.5, 0)
	kitty["at"] = _here() + Vector2(0, 6.5)
	big["poisoned"] = true
	kitty["wounded"] = true
	world.player_stun = 1.0
	world._cure()
	assert(world.player_stun == 0.0 and not big["poisoned"] and kitty["wounded"], "Cure heals her and pets within 6 m only")
	assert(world.cure_cooldown == world.CURE_COOLDOWN)
	assert("Oravitsa shakes it off and cures the husky's poison" in world._notice_label.text, world._notice_label.text)
	world.cure_cooldown = 0.0
	assert(not world._cure_ready(), "A hurt pet beyond 6 m gives Cure nothing to do")
	kitty["at"] = _here() + Vector2(0, 2.0)
	assert(world._cure_ready())
	world._cure()
	assert(not kitty["wounded"] and "Oravitsa cures the cat's wounds" in world._notice_label.text, world._notice_label.text)

	# Protects: a dying monster's model that outlives the cave, and killed
	# monsters coming back on a revisit or after loading.
	_clear_monsters([])
	_put_monster(rats[3], lane_pair[1])
	world._animals[rats[3]]["stun"] = 3.0
	_stand(lane_pair[0])
	world._loaded_center = Vector2i(-999, -999)
	world._refresh_cave_creatures()
	var last_model: Node3D = world._animal_models[rats[3]]
	assert(_hunt_until_dead(pets._record(husky, "following", lane_pair[0]), rats[3], 3.0))
	assert(last_model in world._dying_models)
	world._exit_cave(true)
	assert(world._dying_models.is_empty() and (not is_instance_valid(last_model) or last_model.is_queued_for_deletion()), "No Death clip outlives the cave")
	_beside("Out of the cave")
	world._enter_cave(cave, true)
	assert(killed_index not in _indices() and _killed(1).size() == 4, "Killed monsters stay dead on a revisit: %s" % [_killed(1)])
	world._change_level(2, true)
	assert(goblin_index not in _indices(), "Second-level kills stay dead too")
	var deep_after: Dictionary = world.save_state()
	world._change_level(1, true)
	world._exit_cave(true)

	# Protects: lost or duplicated followers or afflictions after loading on
	# the surface or on the second level, killed monsters back after loading,
	# old saves that no longer load, and bad records.
	_dismiss_all()
	await _travel(cave["mouth"] + Vector2(900, 300))
	world.apply_state(surface_save)
	_beside("Loaded on the surface")
	assert(_count(cat) == 1 and _count(husky) == 1)
	assert(_live(cat)["poisoned"] and not _live(husky)["poisoned"], "Afflictions load on the surface")
	world.apply_state(deep_save)
	assert(world.in_cave() and world._cave_depth == 2)
	_beside("Loaded on the second level")
	assert(_live(cat)["wounded"] and not _live(husky)["wounded"], "Afflictions load below")
	world.apply_state(deep_after)
	assert(world._cave_depth == 2 and goblin_index not in _indices(), "Second-level kills survive loading")
	world._change_level(1, true)
	assert(killed_index not in _indices(), "First-level kills survive loading")
	world._exit_cave(true)
	var old: Dictionary = surface_save.duplicate(true)
	old.erase("pets")
	for key in old["caves"]:
		old["caves"][key].erase("killed_deep")
	assert(world.SAVE_GAME.validate(old) == "", "Saves from before pets remain valid")
	world.apply_state(old)
	assert(not world.in_cave() and pets.followers().is_empty(), "Older saves load with no followers")
	var mismatch: Dictionary = surface_save.duplicate(true)
	mismatch["pets"][0]["threshold"] = 99
	world.apply_state(mismatch)
	assert(pets.followers().size() == 1, "A record that no longer matches its hamlet is dropped")
	for broken in [{"kind": "spear"}, {"threshold": "x"}, {"threshold": 400}, {"hamlet": [1]}, {"poisoned": "yes"}]:
		var bad: Dictionary = surface_save.duplicate(true)
		bad["pets"][0].merge(broken, true)
		assert(world.SAVE_GAME.validate(bad) != "", "Rejects %s" % broken)
	var three: Dictionary = surface_save.duplicate(true)
	three["pets"].append(three["pets"][0].duplicate(true))
	assert(world.SAVE_GAME.validate(three) != "", "At most two followers")
	var bad_kills: Dictionary = deep_after.duplicate(true)
	bad_kills["caves"][deep_after["underground"]["cave"]]["killed_deep"] = [99]
	assert(world.SAVE_GAME.validate(bad_kills) != "", "Rejects a bad second-level kill")
	print("Pet smoke test passed: ", hamlets, " hamlets, ", with_pet, " with a pet ", tally, ", thresholds inside 20-40 / 40-65 / 65-90, identical revisits, threshold prompt and label, refusal below the threshold, G / controller A / touch adopt and dismiss, at most two, keeping up and waiting with hysteresis, catch-up, hurt pets at 60% pace, pass-through, nothing on the surface, leaving on aura decay and walking home, no hamlet duplicate, cave entry / level 2 / back / exit beside her, walking around walls, no attack on unhindered monsters, Oravitsa never kills, stunned / scared / slowed monsters killed once with Death clip and no aura, cats spare goblins and dogs do not, hurt pets never attack, spider poisons, rat and goblin wound, kobold harmless, icons, Cure within 6 m with her stun and not spent idle, Death clips freed on leaving, kills persist on revisit and load on both levels, save/load of pets and afflictions, older and invalid saves")
	quit()
