extends SceneTree

## Hunter companions (#65): seeded hamlet hunters who follow Oravitsa with
## enough aura, go underground with her and stun monsters there.

const STEP := 1.0 / 30.0

var world


func _initialize() -> void:
	call_deferred("_run")


func _travel(absolute: Vector2) -> void:
	world.player_position = world.from_ground(absolute - world.landscape.origin)
	world._rebase_if_needed()
	world.view.position = world.to_world(world.player_position) + world.CAMERA_OFFSET
	world._refresh_visible()
	world.hunters.refresh()
	world.hunters.update(0.0)
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
	return world.hunters.find(spec["hamlet"])


func _count(spec: Dictionary) -> int:
	var count := 0
	for record in world.hunters.hunters:
		count += 1 if record["hamlet"] == spec["hamlet"] else 0
	return count


## Walks up to a hamlet's hunter (beside it, not on it) with plenty of aura
## and asks it to follow.
func _recruit(spec: Dictionary) -> Dictionary:
	await _travel(spec["post"] + Vector2(1.2, 0.8))
	world.aura = 100
	var record := _live(spec)
	assert(world.hunters.nearest() == record, "She stands by the %s" % spec["kind"])
	world.hunters.toggle()
	assert(record["state"] == "following", "The %s follows" % spec["kind"])
	return record


## Every hunter back at its post.
func _dismiss_all() -> void:
	for record in world.hunters.hunters:
		if record["state"] != "post":
			world.hunters._home(record)


## Absolute metres of a cave cell centre.
func _cell(cell: Vector2i) -> Vector2:
	return world._cave.cell_center(cell) + world.hunters._origin()


func _put_monster(id: int, absolute: Vector2) -> void:
	var data: Dictionary = world._animals[id]
	var at: Vector2 = world.from_ground(absolute - world.hunters._origin())
	data["position"] = at
	data["target"] = at
	data["velocity"] = Vector2.ZERO
	for timer in ["stun", "shoo", "bite_cooldown", "attack_time", "burst", "burst_cooldown", "flee", "dart"]:
		data[timer] = 0.0
	data["state"] = "roam"
	if world._active_animals.has(id):
		world._active_animals[id].position = at


func _clear_monsters(keep: Array) -> void:
	for id in world._active_animals:
		if id not in keep and world._animals[id]["kind"] in world.MONSTERS:
			_put_monster(id, _here() + Vector2(500, 500))


func _monsters() -> Array:
	var ids := []
	for id in world._active_animals:
		if world._animals[id]["kind"] in world.MONSTERS and world._animals[id]["alive"]:
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
				if world._cave.can_walk(p - world.hunters._origin(), world.hunters.RADIUS):
					spots.append(p)
	for a in cells:
		var pa := _cell(a)
		for pb in spots:
			var distance: float = pa.distance_to(pb)
			if distance >= low and distance <= high and world.hunters._clear_floor(pa, pb) != walled:
				return [pa, pb]
	return []


## Each follower stands beside her on open ground of the current level.
func _beside(note: String) -> void:
	assert(world.hunters.followers().size() == 2, note + ": both hunters are with her")
	for record in world.hunters.followers():
		var distance: float = record["at"].distance_to(_here())
		assert(distance > 0.5 and distance < 2.6, note + ": beside her (%.2f m)" % distance)
		assert(world.landscape.can_walk(record["at"] - world.hunters._origin(), world.hunters.RADIUS), note + ": on open ground")


func _run() -> void:
	world = load("res://scenes/endless_woods/woods.tscn").instantiate()
	world.save_path = "user://hunter_smoke_save.json"
	world.fright_chance = 0.0
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	await process_frame
	var land: Node3D = world.landscape
	var hunters: Node = world.hunters
	var kinds: Dictionary = hunters.KINDS

	# Protects: hamlets that all or never have a hunter, missing kinds, veterans
	# as common as spear hunters, thresholds outside their kind's band or a
	# stronger kind needing less aura, posts on solid ground or outside the
	# clearing, and hunters that change between visits.
	assert(kinds["spear"]["band"] == Vector2i(20, 40) and kinds["bow"]["band"] == Vector2i(45, 70) and kinds["veteran"]["band"] == Vector2i(75, 100))
	assert(kinds["spear"]["band"].y < kinds["bow"]["band"].x and kinds["bow"]["band"].y < kinds["veteran"]["band"].x, "Stronger kinds need more aura")
	var found := {}
	var tally := {"spear": 0, "bow": 0, "veteran": 0}
	var hamlets := 0
	var with_hunter := 0
	for by in range(-6, 7):
		for bx in range(-6, 7):
			var hamlet: Dictionary = land.hamlet_at(Vector2i(bx, by))
			if hamlet.is_empty():
				continue
			hamlets += 1
			var spec: Dictionary = hunters.hamlet_hunter(hamlet)
			assert(hunters.hamlet_hunter(hamlet) == spec, "Seeded identically")
			if spec.is_empty():
				continue
			with_hunter += 1
			tally[spec["kind"]] += 1
			var band: Vector2i = kinds[spec["kind"]]["band"]
			assert(spec["threshold"] >= band.x and spec["threshold"] <= band.y, "Threshold %d inside the %s band" % [spec["threshold"], spec["kind"]])
			assert(land.can_walk(spec["post"] - land.origin, hunters.RADIUS), "The post is on open ground")
			var from_centre: float = spec["post"].distance_to(hamlet["center"])
			assert(from_centre > 20.0 and from_centre < land.HAMLET_RADIUS, "Near the clearing's edge")
			if not found.has(spec["kind"]) or spec["post"].distance_to(Vector2.ZERO) < found[spec["kind"]]["post"].distance_to(Vector2.ZERO):
				found[spec["kind"]] = spec
	var share := float(with_hunter) / hamlets
	assert(hamlets > 20 and share > 0.45 and share < 0.75, "About 60%% of hamlets have a hunter: %.2f" % share)
	assert(tally["spear"] > tally["bow"] and tally["bow"] > tally["veteran"] and tally["veteran"] > 0, "Spear hunters most common, veterans rarest: %s" % tally)
	var bow: Dictionary = found["bow"]
	var spear: Dictionary = found["spear"]
	var veteran: Dictionary = found["veteran"]
	var bow_home: Dictionary = land.hamlet_at(bow["hamlet"])
	await _travel(bow_home["center"] + Vector2(0, 6))
	var first := _live(bow)
	assert(not first.is_empty() and first["state"] == "post" and first["at"] == bow["post"] and first["threshold"] == bow["threshold"])
	await _travel(bow_home["center"] + Vector2(3000, 0))
	assert(_live(bow).is_empty(), "Hamlet hunters leave with their hamlet")
	await _travel(bow_home["center"] + Vector2(0, 6))
	assert(_count(bow) == 1 and _live(bow)["kind"] == "bow" and _live(bow)["threshold"] == bow["threshold"] and _live(bow)["at"] == bow["post"], "The same hunter on revisit")
	assert(not _live(bow).has("node") or _live(bow)["node"].visible)

	# Protects: a hunter joining below its threshold, a refusal that does not
	# say what is needed, and a prompt or label hiding the threshold.
	await _travel(bow["post"] + Vector2(1.2, 0.8))
	var archer := _live(bow)
	var needed: int = bow["threshold"]
	world.aura = needed - 17
	world._input_mode = "keyboard"
	world._update_hud()
	assert(world._hunter_button.visible and world._hunter_button.disabled, "The prompt shows, disabled")
	assert(world._hunter_button.text == "The bow hunter follows only at %d aura (you have %d)" % [needed, needed - 17], world._hunter_button.text)
	world._sync_presentation(0.0)
	assert(archer["label"].visible and archer["label"].text == "Bow hunter · %d aura" % needed, archer["label"].text)
	world._unhandled_key_input(_key(KEY_G))
	assert(archer["state"] == "post" and "follows only at %d aura" % needed in world._notice_label.text)
	world._input_mode = "controller"
	world._update_hud()
	world._unhandled_input(_a())
	world._hunter_button.pressed.emit()
	assert(archer["state"] == "post" and hunters.followers().is_empty(), "Too little aura never recruits")

	# Protects: G, controller A or the button doing nothing, a follower that
	# cannot be sent home, and A asking a hunter when that is impossible.
	world.aura = needed
	world._input_mode = "keyboard"
	world._update_hud()
	assert(world._hunter_button.text == "Ask the bow hunter to join (%d aura) [G]" % needed and not world._hunter_button.disabled)
	world._unhandled_key_input(_key(KEY_G))
	assert(archer["state"] == "following" and "bow hunter follows Oravitsa" in world._notice_label.text)
	world._sync_presentation(0.0)
	assert(not archer["label"].visible, "Followers need no threshold label")
	world.player_position += Vector2(0.4 * world.METRE, 0)
	archer["at"] = _here() + Vector2(0.6, 0)
	world._update_hud()
	assert(world._hunter_button.text == "Send the bow hunter home [G]", world._hunter_button.text)
	world._unhandled_key_input(_key(KEY_G))
	assert(archer["state"] == "returning" and "goes back to" in world._notice_label.text)
	await _travel(bow["post"] + Vector2(1.2, 0.8))
	world._input_mode = "controller"
	world._update_hud()
	assert(world._hunter_button.text.ends_with("[A]") and "A beside a hunter" in world._hint_label.text)
	world._unhandled_input(_a())
	assert(archer["state"] == "following", "Controller A recruits")
	archer["at"] = _here() + Vector2(0.6, 0)
	world._unhandled_input(_a())
	assert(archer["state"] == "returning", "Controller A sends it home")
	await _travel(bow["post"] + Vector2(1.2, 0.8))
	world._input_mode = "touch"
	world._update_hud()
	assert(world._hunter_button.text == "Ask the bow hunter to join (%d aura)" % needed)
	world._hunter_button.pressed.emit()
	assert(archer["state"] == "following", "The touch button recruits")
	world._input_mode = "keyboard"
	world._update_hud()
	assert("G: ask a hunter" in world._hint_label.text)
	world.aura = needed - 1
	await _travel(_here() + Vector2(40, 0))
	assert(not hunters.can_ask(), "Nothing to ask out here: A picks up as before")

	# Protects: a third follower, and a refusal that does not explain itself.
	_dismiss_all()
	var spearman := await _recruit(spear)
	archer = await _recruit(bow)
	await _travel(veteran["post"] + Vector2(1.2, 0.8))
	world.aura = 100
	world._update_hud()
	assert(world._hunter_button.disabled and world._hunter_button.text == "Two hunters already follow Oravitsa")
	world._unhandled_key_input(_key(KEY_G))
	assert(_live(veteran)["state"] == "post" and hunters.followers().size() == 2 and "Two hunters already follow" in world._notice_label.text)

	# Protects: a follower left behind or stuck to her, one that jitters at a
	# single distance, and one that never catches up.
	assert(spearman["state"] == "following" and archer["state"] == "following")
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
		hunters.update(STEP)
		if i > 30:
			for record in hunters.followers():
				farthest = maxf(farthest, record["at"].distance_to(_here()))
	assert(farthest < 5.5, "Followers keep up at her full speed: %.2f m" % farthest)
	for i in 90:
		hunters.update(STEP)
	var rest := []
	for record in hunters.followers():
		var distance: float = record["at"].distance_to(_here())
		assert(distance >= hunters.FOLLOW_STOP - 0.3 and distance <= hunters.FOLLOW_START + 0.1, "They wait a few metres off: %.2f" % distance)
		assert(not record["moving"])
		rest.append(record["at"])
	assert(rest[0].distance_to(rest[1]) > 0.5, "Two followers keep apart")
	world.player_position += lane * 0.3 * world.METRE
	hunters.update(STEP)
	for i in 2:
		assert(hunters.followers()[i]["at"] == rest[i], "A small step of hers does not set them walking")
	world.player_position += lane * 40.0 * world.METRE
	world.view.position = world.to_world(world.player_position) + world.CAMERA_OFFSET
	hunters.update(STEP)
	for record in hunters.followers():
		assert(record["at"].distance_to(_here()) < 3.0, "Left far behind, it appears just behind her")

	# Protects: hunters that block or bump her, become Sling/Shoo targets, or
	# fight wildlife on the surface.
	for data in world._animals:
		assert(not data.has("threshold"), "Hunters are not wildlife")
	world.player_stun = 0.0
	var step: Vector2 = lane * 0.3 * world.METRE
	archer["at"] = world.absolute_ground(world.player_position + step)
	assert(world._try_move(step) and world.player_stun == 0.0, "She walks through a hunter")
	var wild := -1
	for id in world._active_animals:
		if world._animals[id]["alive"] and world._animals[id]["kind"] != world.VILLAGER:
			wild = id
	if wild >= 0:
		world._animals[wild]["stun"] = 0.0
		world._animals[wild]["position"] = world.from_ground(archer["at"] - land.origin + Vector2(1.0, 0))
		spearman["cooldown"] = 0.0
		hunters.update(STEP)
		assert(world._animals[wild]["stun"] == 0.0, "No fighting wildlife on the surface")

	# Protects: a hunter staying after her aura falls below its threshold
	# (decay #64), leaving without a notice, vanishing or never going home.
	var low: Dictionary = spearman if spearman["threshold"] < archer["threshold"] else archer
	var high: Dictionary = archer if low == spearman else spearman
	world.aura = high["threshold"]
	world._aura_decay = world.AURA_DECAY_SECONDS - 0.1
	world._update_aura_decay(0.2)
	assert(world.aura == high["threshold"] - 1)
	var left_at: Vector2 = high["at"]
	hunters.update(0.0)
	assert(high["state"] == "returning" and low["state"] == "following", "Only the hunter above her aura leaves")
	assert("leaves: Oravitsa's aura fell below %d" % high["threshold"] in world._notice_label.text, world._notice_label.text)
	assert(high["at"] == left_at, "It leaves from where it was")
	var high_spec: Dictionary = spear if high == spearman else bow
	await _travel(high_spec["post"] + Vector2(4, 4))
	for i in 600:
		hunters.update(0.1)
	assert(high["state"] == "post" and high["at"].distance_to(high_spec["post"]) < 3.0, "Back at its post")

	# Protects: a following hunter also appearing at its own hamlet.
	_dismiss_all()
	spearman = await _recruit(spear)
	archer = await _recruit(bow)
	await _travel(land.hamlet_at(spear["hamlet"])["center"] + Vector2(2500, 1800))
	await _travel(land.hamlet_at(spear["hamlet"])["center"] + Vector2(0, 5))
	assert(_count(spear) == 1 and _live(spear)["state"] == "following", "No second spear hunter at its hamlet")
	world._sync_presentation(0.0)
	var drawn := 0
	for node in hunters._root.get_children():
		drawn += 1 if node.name.begins_with("Hunter_%d_%d" % [spear["hamlet"].x, spear["hamlet"].y]) else 0
	assert(drawn == 1, "Drawn once")
	var surface_save: Dictionary = world.save_state()
	assert(world.SAVE_GAME.validate(surface_save) == "" and surface_save["hunters"].size() == 2)

	# Protects: followers left outside the cave, lost between levels or left
	# below, standing in walls, and hamlet hunters underground.
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
	for record in hunters.hunters:
		visible += 1 if record.has("node") else 0
	assert(visible == 2, "Underground only her followers are there")
	world._change_level(2, true)
	assert(world._cave_depth == 2)
	_beside("On the second level")
	var deep_save: Dictionary = world.save_state()
	assert(world.SAVE_GAME.validate(deep_save) == "" and deep_save["hunters"].size() == 2 and deep_save["underground"]["level"] == 2)
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
			if straight > 4.0 and straight < 7.5 and walk_flow.get(cell, 0) * world._cave.CELL >= straight + 4.0 and not hunters._clear_floor(p, _cell(her_cell)):
				her_spot = _cell(her_cell)
				detour = [p]
				break
	assert(not detour.is_empty(), "A spot around a wall from her")
	world.player_position = world.from_ground(her_spot - hunters._origin())
	world.view.position = world.to_world(world.player_position) + world.CAMERA_OFFSET
	_clear_monsters([])
	archer["at"] = detour[0]
	spearman["at"] = her_spot + Vector2(0.5, 0)
	var biggest := 0.0
	var reached := false
	for i in 600:
		var was: Vector2 = archer["at"]
		hunters._follow(archer, 0, STEP)
		biggest = maxf(biggest, was.distance_to(archer["at"]))
		if archer["at"].distance_to(her_spot) <= hunters.FOLLOW_START + 0.05:
			reached = true
			break
	assert(reached and biggest < 0.5, "It walks around the wall to her (largest step %.2f m)" % biggest)

	# Protects: hunters that kill monsters, strike out of reach, through walls,
	# while cooling down, at stunned or scared monsters, give aura, or prefer
	# a monster other than the one nearest to Oravitsa.
	for kind in ["spear", "bow", "veteran"]:
		var spec: Dictionary = {"spear": spear, "bow": bow, "veteran": veteran}[kind]
		var record: Dictionary = hunters._record(spec, "following", _here())
		var reach: float = kinds[kind]["reach"]
		var lane_pair := _pair(reach + 0.5, reach + 2.0, false)
		var a: Vector2 = lane_pair[0]
		var direction: Vector2 = a.direction_to(lane_pair[1])
		var ids := _monsters()
		var target: int = ids[0]
		_clear_monsters([])
		record["at"] = a
		record["cooldown"] = 0.0
		world.player_position = world.from_ground(a - hunters._origin())
		var aura_before: int = world.aura
		_put_monster(target, a + direction * (reach + 0.3))
		hunters._fight(record, STEP)
		assert(world._animals[target]["stun"] == 0.0, "%s: nothing out of reach" % kind)
		_put_monster(target, a + direction * (reach - 0.2))
		hunters._fight(record, STEP)
		assert(is_equal_approx(world._animals[target]["stun"], kinds[kind]["stun"]), "%s: stuns for %.1f s" % [kind, kinds[kind]["stun"]])
		assert(is_equal_approx(record["cooldown"], kinds[kind]["cooldown"]) and record["attack"] > 0.0)
		assert(world._animals[target]["alive"] and world.aura == aura_before, "%s: never kills, no aura" % kind)
		var second: int = ids[1]
		_put_monster(second, a + direction * (reach * 0.5))
		var waited := 0.0
		while world._animals[second]["stun"] == 0.0 and waited < 10.0:
			hunters._fight(record, STEP)
			waited += STEP
		assert(absf(waited - kinds[kind]["cooldown"]) < STEP * 2.5, "%s: strikes again after %.1f s (%.2f)" % [kind, kinds[kind]["cooldown"], waited])
		# Stunned and scared monsters are left alone.
		_put_monster(target, a + direction * (reach * 0.5))
		world._animals[target]["stun"] = 0.4
		_put_monster(second, a + direction * (reach * 0.4))
		world._animals[second]["shoo"] = 3.0
		record["cooldown"] = 0.0
		hunters._fight(record, STEP)
		assert(record["cooldown"] == 0.0 and world._animals[second]["stun"] == 0.0, "%s: not at stunned or scared monsters" % kind)
		# The monster nearest to Oravitsa first.
		_put_monster(target, a + direction * (reach * 0.8))
		_put_monster(second, a + direction * 0.4)
		world.player_position = world.from_ground(a + direction * reach - hunters._origin())
		hunters._fight(record, STEP)
		assert(world._animals[target]["stun"] > 0.0 and world._animals[second]["stun"] == 0.0, "%s: the monster nearest to her first" % kind)
		# Never through a wall. Walls are whole 2 m cells, so only a bow can
		# reach across one; the spear uses the same clear-floor check.
		if kind != "spear":
			var walled := _pair(3.0, reach - 0.2, true)
			assert(not walled.is_empty(), "%s: a pair across a wall" % kind)
			_clear_monsters([])
			record["at"] = walled[0]
			record["cooldown"] = 0.0
			_put_monster(target, walled[1])
			world.player_position = world.from_ground(walled[0] - hunters._origin())
			for i in 30:
				hunters._fight(record, STEP)
			assert(world._animals[target]["stun"] == 0.0, "%s: never through a wall" % kind)
		assert(_monsters().size() == ids.size(), "%s: no monster removed" % kind)
	assert(kinds["veteran"]["reach"] > kinds["bow"]["reach"] and kinds["bow"]["reach"] > kinds["spear"]["reach"])

	# Protects: a goblin clubbing her though a hunter beside her stuns it first,
	# and a stunned monster biting.
	world._change_level(2, true)
	_clear_monsters([])
	var goblin := -1
	for id in _monsters():
		if world._animals[id]["kind"] == world.GOBLIN:
			goblin = id
	var side_pair := _pair(1.3, 1.5, false)
	world.player_position = world.from_ground(side_pair[0] - hunters._origin())
	world.view.position = world.to_world(world.player_position) + world.CAMERA_OFFSET
	var toward: Vector2 = side_pair[0].direction_to(side_pair[1])
	spearman["at"] = side_pair[0] + toward * 0.4
	archer["at"] = side_pair[0] - toward * 0.5
	spearman["cooldown"] = 0.0
	archer["cooldown"] = 0.0
	_put_monster(goblin, side_pair[1])
	world.player_stun = 0.0
	world._bite_grace = 0.0
	for i in 60:
		world._process_cave(STEP)
	assert(world.player_stun == 0.0, "The goblin never reaches her")
	assert(world._animals[goblin]["alive"], "And is never killed")
	world._change_level(1, true)
	world._exit_cave()
	assert(not world.in_cave())
	_beside("Out of the cave")

	# Protects: lost or duplicated followers after loading on the surface or
	# on the second level, old saves that no longer load, and bad records.
	_dismiss_all()
	await _travel(cave["mouth"] + Vector2(900, 300))
	world.apply_state(surface_save)
	_beside("Loaded on the surface")
	assert(_count(spear) == 1 and _count(bow) == 1)
	world.apply_state(deep_save)
	assert(world.in_cave() and world._cave_depth == 2)
	_beside("Loaded on the second level")
	assert(hunters.followers()[0]["kind"] in ["spear", "bow"] and hunters.followers()[1]["kind"] in ["spear", "bow"])
	var old: Dictionary = surface_save.duplicate(true)
	old.erase("hunters")
	assert(world.SAVE_GAME.validate(old) == "", "Saves from before hunters remain valid")
	world.apply_state(old)
	assert(not world.in_cave() and hunters.followers().is_empty(), "Older saves load with no followers")
	var mismatch: Dictionary = surface_save.duplicate(true)
	mismatch["hunters"][0]["threshold"] = 99 if mismatch["hunters"][0]["kind"] != "veteran" else 80
	world.apply_state(mismatch)
	assert(hunters.followers().size() == 1, "A record that no longer matches its hamlet is dropped")
	for broken in [{"kind": "archer"}, {"threshold": "x"}, {"threshold": 400}, {"hamlet": [1]}]:
		var bad: Dictionary = surface_save.duplicate(true)
		bad["hunters"][0].merge(broken, true)
		assert(world.SAVE_GAME.validate(bad) != "", "Rejects %s" % broken)
	var three: Dictionary = surface_save.duplicate(true)
	three["hunters"].append(three["hunters"][0].duplicate(true))
	assert(world.SAVE_GAME.validate(three) != "", "At most two followers")
	print("Hunter smoke test passed: ", hamlets, " hamlets, ", with_hunter, " with a hunter ", tally, ", thresholds inside 20-40 / 45-70 / 75-100, identical revisits, threshold prompt and label, refusal below the threshold, G / controller A / touch recruit and dismiss, at most two, keeping up and waiting with hysteresis, catch-up, pass-through, no surface fighting, leaving on aura decay and walking home, no hamlet duplicate, cave entry / level 2 / back / exit beside her, walking around walls, spear / bow / veteran reach, stun, cooldown, nearest-to-her, never through walls or killing, goblin stopped before it clubs, save/load on the surface and level 2, older and invalid saves")
	quit()
