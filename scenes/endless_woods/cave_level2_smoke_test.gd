extends SceneTree

## The second cave level (#62): its way down and way up, goblins that club and
## kobolds that steal, its checkpoints and saving there.

const STEP := 1.0 / 30.0


func _initialize() -> void:
	call_deferred("_run")


func _travel(world: Node2D, absolute: Vector2) -> void:
	world.player_position = world.from_ground(absolute - world.landscape.origin)
	world._rebase_if_needed()
	world.view.position = world.to_world(world.player_position) + world.CAMERA_OFFSET
	world._refresh_visible()
	world._sync_presentation(0.0)
	await process_frame


func _level(world: Node2D, region: Vector2i, depth: int) -> Node3D:
	var level: Node3D = world.CAVE_LEVEL.new()
	if depth == 1:
		level.setup(region, Vector2(5, 7), world.RAT, world.SPIDER)
	else:
		level.setup(region, Vector2(5, 7), world.GOBLIN, world.KOBOLD, 2)
	return level


func _connected(level: Node3D) -> bool:
	return level.distances_to(level.cell_at(level.entrance)).size() == level.open.size()


func _put(world: Node2D, id: int, at: Vector2) -> void:
	var data: Dictionary = world._animals[id]
	data["position"] = at
	data["target"] = at
	data["velocity"] = Vector2.ZERO
	for timer in ["stun", "shoo", "bite_cooldown", "attack_time", "burst", "burst_cooldown", "flee", "dart"]:
		data[timer] = 0.0
	data["state"] = "roam"
	if world._active_animals.has(id):
		world._active_animals[id].position = at


## Moves every monster but `keep` far out of the way.
func _clear_others(world: Node2D, keep: Array) -> void:
	for id in world._active_animals:
		if id not in keep:
			_put(world, id, world.player_position + Vector2(5000, 5000))


func _of_kind(world: Node2D, kind: int) -> Array:
	var ids := []
	for id in world._active_animals:
		if world._animals[id]["kind"] == kind and world._animals[id]["alive"]:
			ids.append(id)
	return ids


func _run_cave(world: Node2D, seconds: float, done: Callable, each: Callable = func(): pass) -> bool:
	var elapsed := 0.0
	while elapsed < seconds:
		world._move_cave_creatures(STEP)
		world.player_stun = maxf(0.0, world.player_stun - STEP)
		each.call()
		elapsed += STEP
		if done.call():
			return true
	return false


func _bag(world: Node2D) -> int:
	return world.basket + world.berries_basket + world.raw_meat


## Floor cells `steps` walking cells from her, in a stable order.
func _ring(level: Node3D, here: Vector2, steps: int) -> Array:
	var flow: Dictionary = level.distances_to(level.cell_at(here))
	var cells := []
	for cell in flow:
		if flow[cell] == steps:
			cells.append(cell)
	cells.sort()
	return cells


func _run() -> void:
	var world = load("res://scenes/endless_woods/woods.tscn").instantiate()
	world.save_path = "user://cave_level2_smoke_save.json"
	world.fright_chance = 0.0 # Panic is covered by the cave smoke test.
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	await process_frame
	var land: Node3D = world.landscape
	var caves: Array[Dictionary] = []
	for rz in range(-4, 5):
		for rx in range(-4, 5):
			var found: Dictionary = land.cave_at(Vector2i(rx, rz))
			if not found.is_empty():
				caves.append(found)
	assert(caves.size() >= 5, "Enough caves to sample")
	var cave: Dictionary = caves[0]

	# Protects: a way down missing, in a wall, on a checkpoint or beside the
	# way out; a second level that differs on revisits, copies the first, is
	# disconnected or puts lairs at the way up; packs missing.
	for sample in caves:
		var top := _level(world, sample["region"], 1)
		var deep := _level(world, sample["region"], 2)
		var again := _level(world, sample["region"], 2)
		assert(top.way_down != Vector2.INF and top.can_walk(top.way_down, world.PLAYER_RADIUS / world.METRE), "The way down is on open floor")
		var walk: Dictionary = top.distances_to(top.cell_at(top.entrance))
		assert(walk[top.cell_at(top.way_down)] * top.CELL >= 12.0, "The way down is deep inside")
		for p in top.checkpoints:
			assert(p.distance_to(top.way_down) >= 4.0, "The way down is clear of checkpoints")
		assert(deep.open == again.open and deep.checkpoints == again.checkpoints and deep.spawns == again.spawns, "The second level regenerates identically")
		assert(deep.open != top.open and deep.grid.x * deep.grid.y > top.grid.x * top.grid.y, "It is its own, larger level")
		assert(_connected(deep) and _connected(top), "Both levels are connected")
		assert(deep.way_down == Vector2.INF and deep.can_walk(deep.entrance, world.PLAYER_RADIUS / world.METRE))
		assert(deep.checkpoints.size() >= deep.CHECKPOINTS.x and deep.checkpoints.size() <= deep.CHECKPOINTS.y)
		var goblins := 0
		var kobolds := 0
		for spot in deep.spawns:
			var at := Vector2(spot.x, spot.y)
			assert(deep.is_open(at) and at.distance_to(deep.entrance) >= 10.0, "Lairs are on the floor and away from the way up")
			assert(int(spot.z) in [world.GOBLIN, world.KOBOLD], "Only goblins and kobolds live below")
			goblins += 1 if int(spot.z) == world.GOBLIN else 0
			kobolds += 1 if int(spot.z) == world.KOBOLD else 0
		assert(goblins >= deep.GOBLIN_PACKS.x * deep.PACK_SIZE.x - 2 and kobolds >= deep.KOBOLD_PACKS.x * deep.PACK_SIZE.x - 1, "Packs of goblins and kobolds: %d, %d" % [goblins, kobolds])
		for level in [top, deep, again]:
			level.free()

	# Enter the cave and keep the first level's monsters in view.
	await _travel(world, cave["mouth"] + cave["facing"] * 2.0)
	var surface_count: int = world._animals.size()
	world.player_position = world.from_ground(cave["mouth"] - world.landscape.origin)
	world._check_cave_mouth()
	assert(world.in_cave() and world._cave_depth == 1)
	var top: Node3D = world._cave
	var key: String = world._cave_key
	var first_count: int = world._animals.size()
	var moved: Dictionary = world._animals[0]
	moved["position"] = world.from_ground(Vector2(top.spawns[0].x, top.spawns[0].y) + Vector2(0.4, 0))
	moved["stun"] = 2.5
	var moved_at: Vector2 = moved["position"]

	# Protects: bouncing between levels, a panicking or stunned Oravitsa falling
	# down, and the first level's monsters being revived, duplicated or reset.
	assert(world._way_down_armed, "Coming in from the mouth, the way down is ready")
	world.player_position = world.from_ground(top.way_down)
	world.player_stun = 1.0
	world._check_cave_points()
	assert(world._cave_depth == 1, "Not while stunned")
	world.player_stun = 0.0
	world.player_fright = 1.0
	world._check_cave_points()
	assert(world._cave_depth == 1, "Not while panicking")
	world.player_fright = 0.0
	world._check_cave_points()
	assert(world._cave_depth == 2 and world.in_cave(), "The way down leads to the second level")
	var deep: Node3D = world._cave
	assert(not is_instance_valid(top) or top.is_queued_for_deletion(), "The first level is gone from the stage")
	assert(world.landscape == deep and not world._surface_landscape.visible and world._surface_animals.size() == surface_count, "The surface stays frozen")
	assert(world.to_ground(world.player_position).distance_to(deep.entrance) < 0.01, "She arrives at the way up")
	assert(world._upper_animals.size() == first_count and world._animals.size() == deep.spawns.size())
	world._sync_presentation(0.0)
	assert(world._landmark_label.text == "Way up")
	for frame in 5:
		world._check_cave_points()
	assert(world._cave_depth == 2, "Arriving does not bounce her straight back up")
	world.player_position = world.from_ground(deep.checkpoints[0])
	world._sync_presentation(0.0)
	assert(world._landmark_label.text == world._cave_name() + " · second level")
	var deep_open: Dictionary = deep.open.duplicate()
	var deep_spawns: Array = deep.spawns.duplicate()
	# The way up returns her to the way down, which does not take her straight back.
	world.player_position = world.from_ground(deep.entrance + Vector2(0, -4))
	world._check_cave_points()
	world.player_position = world.from_ground(deep.entrance)
	world._check_cave_points()
	assert(world._cave_depth == 1, "The way up leads back")
	top = world._cave
	assert(world.to_ground(world.player_position).distance_to(top.way_down) < 0.01, "She is back at the way down")
	assert(world._animals.size() == first_count and world._animals[0]["position"] == moved_at and world._animals[0]["stun"] == 2.5, "The first level's monsters waited as they were")
	world._sync_presentation(0.0)
	assert(world._landmark_label.text == "Way down")
	for frame in 5:
		world._check_cave_points()
	assert(world._cave_depth == 1, "Arriving does not bounce her straight back down")
	var away: Vector2 = Vector2.INF
	for cell in top.open:
		var p: Vector2 = top.cell_center(cell)
		if p.distance_to(top.way_down) > 3.2 and p.distance_to(top.way_down) < 6.0 and away == Vector2.INF:
			away = p
	world.player_position = world.from_ground(away)
	world._check_cave_points()
	world.player_position = world.from_ground(top.way_down)
	world._check_cave_points()
	assert(world._cave_depth == 2, "Once she has stepped away, the way down works again")
	deep = world._cave
	assert(deep.open == deep_open and deep.spawns == deep_spawns, "The second level is the same on a revisit")

	# Goblins chase her by walking distance and club her: a stun only.
	# Protects: goblin injuries or kills, stuns over 1.5 s, stun-locks, and
	# goblins that never reach her around walls.
	assert(world.ANIMAL_SPEEDS[world.GOBLIN] < world.ANIMAL_SPEEDS[world.RAT] and world.MONSTER_SIGHT[world.GOBLIN] > world.MONSTER_SIGHT[world.RAT])
	assert(world.ANIMAL_SPEEDS[world.KOBOLD] < world.SPEED, "A half-fed Oravitsa outruns even kobolds")
	var here: Vector2 = deep.checkpoints[0]
	world.player_position = world.from_ground(here)
	for data in world._animals:
		data["position"] = world.player_position # Brought close, so all are active.
	world._loaded_center = Vector2i(-999, -999)
	world._refresh_cave_creatures()
	var goblins := _of_kind(world, world.GOBLIN)
	var kobolds := _of_kind(world, world.KOBOLD)
	assert(goblins.size() >= 1 and kobolds.size() >= 3, "Goblins and a pack of kobolds are active: %d, %d" % [goblins.size(), kobolds.size()])
	world._sync_presentation(0.0)
	var goblin: int = goblins[0]
	assert(world._animal_models.has(goblin) and world._animal_players[goblin].has_animation("Attack") and world._animal_players[goblin].has_animation("Walk"))
	assert(world._animal_players[kobolds[0]].has_animation("Attack") and world._animal_players[kobolds[0]].has_animation("Idle"), "The kobold's Punch is its snatch")
	_clear_others(world, [goblin])
	var start: Array = _ring(deep, here, 6)
	assert(not start.is_empty())
	_put(world, goblin, world.from_ground(deep.cell_center(start[0])))
	world.fed = world.FED_MAX
	world.player_stun = 0.0
	world._bite_grace = 0.0
	var floor_check := func(): assert(world._can_stand(world._animals[goblin]["position"], world.ANIMAL_RADIUS[world.GOBLIN]), "Goblins stay on the floor")
	assert(_run_cave(world, 12.0, func(): return world.player_stun > 0.0, floor_check), "A goblin finds its way to her")
	assert(is_equal_approx(world.player_stun + STEP, world.BITE_STUN * world.FULL_STUN) and world._animals[goblin]["attack_time"] > 0.0, "Its club only stuns her, shorter when well fed")
	assert(world._notice_label.text == "The goblin clubbed Oravitsa!")
	world._sync_presentation(0.0)
	assert(world._animal_players[goblin].current_animation == "Attack")
	var first_stun: float = world.player_stun
	var free := {"time": 0.0}
	_run_cave(world, first_stun + world.BITE_GRACE - 0.1, func(): return false, func():
		assert(world.player_stun < first_stun, "No second club during the grace time")
		if world.player_stun <= 0.0:
			free["time"] += STEP)
	assert(free["time"] >= 1.8, "She gets two free seconds: %.1f" % free["time"])
	assert(world._animals[goblin]["position"].distance_to(world.player_position) > world.ANIMAL_RADIUS[world.GOBLIN] + world.PLAYER_RADIUS + 10.0, "It backed off")
	# Sling and Shoo work on goblins; a stunned or scared one neither clubs nor blocks her, and cannot be killed.
	for field in ["stun", "shoo"]:
		_put(world, goblin, world.player_position + Vector2(40, 0))
		world._animals[goblin][field] = 3.0
		world.player_stun = 0.0
		world._bite_grace = 0.0
		_run_cave(world, 1.0, func(): return false)
		assert(world.player_stun == 0.0 and world._animals[goblin]["attack_time"] == 0.0, "A %s goblin does not club" % field)
		assert(world._passes_through(goblin))
	world._collect_nearby()
	assert(world._animals[goblin]["alive"] and world._active_animals.has(goblin), "No monster can be killed")
	_put(world, goblin, world.player_position + Vector2(5000, 5000))

	# Kobolds keep their distance alone and steal only as a pack.
	# Protects: lone kobolds rushing her or pressing into walls, thieves that
	# stun her, take more than one item or keep stealing, and stunned or scared
	# kobolds stealing.
	world.player_stun = 0.0
	world._bite_grace = 0.0
	world._theft_grace = 0.0
	world.basket = 1
	world.berries_basket = 2
	world.raw_meat = 1
	var lone: int = kobolds[0]
	_clear_others(world, [lone])
	var far: Array = _ring(deep, here, 4)
	_put(world, lone, world.from_ground(deep.cell_center(far[0])))
	var lone_floor := func(): assert(world._can_stand(world._animals[lone]["position"], world.ANIMAL_RADIUS[world.KOBOLD]), "Kobolds stay on the floor")
	var closest := {"d": INF}
	_run_cave(world, 6.0, func(): return false, func():
		lone_floor.call()
		closest["d"] = minf(closest["d"], world._animals[lone]["position"].distance_to(world.player_position)))
	var settled: float = world._animals[lone]["position"].distance_to(world.player_position) / world.METRE
	assert(_bag(world) == 4 and world.player_stun == 0.0, "A lone kobold steals nothing")
	assert(closest["d"] > world.KOBOLD_KEEP.x * world.METRE * 0.8 and settled < world.KOBOLD_KEEP.y + 0.6, "It creeps up but keeps its distance: closest %.1f m, settled %.1f m" % [closest["d"] / world.METRE, settled])
	assert(world._animals[lone]["dart"] == 0.0)
	# Walking into an awake kobold never stuns her or it (#90).
	# Protects: kobolds stunning her through an ordinary bump.
	_put(world, lone, world.player_position + Vector2(30, 0))
	world.player_stun = 0.0
	world._try_move(Vector2(15, 0))
	assert(world.player_stun == 0.0 and world.player_fright == 0.0 and world._animals[lone]["stun"] == 0.0, "Bumping a kobold stuns nobody")
	# She walks up to it: it backs away.
	var toward: Vector2 = world.player_position.direction_to(world._animals[lone]["position"])
	_put(world, lone, world.player_position + toward * world.METRE * 1.4)
	var near: float = world._animals[lone]["position"].distance_to(world.player_position)
	_run_cave(world, 1.0, func(): return false, lone_floor)
	assert(world._animals[lone]["position"].distance_to(world.player_position) > near, "It backs off when she is close")
	# A pack of three darts in; one snatches exactly one item and runs off.
	var pack: Array = kobolds.slice(0, 3)
	var close: Array = _ring(deep, here, 2)
	assert(close.size() >= 3)
	for i in 3:
		_put(world, pack[i], world.from_ground(deep.cell_center(close[i])))
	_clear_others(world, pack)
	assert(world._kobolds_near() == 3)
	assert(_run_cave(world, 4.0, func(): return _bag(world) < 4), "A pack of kobolds steals")
	assert(_bag(world) == 3 and world.player_stun == 0.0 and world.player_fright == 0.0, "Exactly one item, and no stun")
	assert(world._notice_label.text.begins_with("A kobold snatched "))
	var thief := -1
	for id in pack:
		if world._animals[id]["flee"] > 0.0:
			thief = id
	assert(thief >= 0 and world._animals[thief]["attack_time"] > 0.0, "The thief snatches, then flees")
	world._move_cave_creatures(STEP)
	assert(world._theft_grace > 0.0 and pack.all(func(id): return world._animals[id]["dart"] == 0.0), "After a theft the others stop darting")
	# Saving straight after a theft keeps the hang-back and the thief's flight (#92).
	# Protects: a save and load that lets the pack steal again at once.
	var robbed: Dictionary = world.save_state()
	assert(world.SAVE_GAME.validate(robbed) == "")
	world.apply_state(robbed)
	deep = world._cave
	assert(world._theft_grace > 0.0 and world._animals[thief]["flee"] > 0.0, "Loading keeps the hang-back and the flight")
	_run_cave(world, world.THEFT_GRACE - 0.2, func(): return false, func():
		assert(_bag(world) == 3, "No second theft straight after"))
	assert(world._animals[thief]["state"] == "flee" and world._animals[thief]["position"].distance_to(world.player_position) > world.KOBOLD_KEEP.y * world.METRE, "The thief ran off, farther than a waiting kobold")
	# Stunned or scared kobolds steal nothing.
	for field in ["stun", "shoo"]:
		for i in 3:
			_put(world, pack[i], world.from_ground(deep.cell_center(close[i])))
			world._animals[pack[i]][field] = 3.0
		world._theft_grace = 0.0
		_run_cave(world, 2.5, func(): return false)
		assert(_bag(world) == 3, "%s kobolds steal nothing" % ("Stunned" if field == "stun" else "Scared"))
		assert(world._passes_through(pack[0]))
	# With an empty bag they just run off.
	world.basket = 0
	world.berries_basket = 0
	world.raw_meat = 0
	for i in 3:
		_put(world, pack[i], world.from_ground(deep.cell_center(close[i])))
	world._theft_grace = 0.0
	assert(_run_cave(world, 4.0, func(): return pack.any(func(id): return world._animals[id]["flee"] > 0.0)), "They still dart in")
	assert(_bag(world) == 0 and world.player_stun == 0.0 and world._theft_grace == 0.0)
	for id in pack:
		_put(world, id, world.player_position + Vector2(5000, 5000))

	# Second-level checkpoints pay +30 once each and persist.
	# Protects: paying twice, paying the first level's +20, and progress lost on
	# a revisit or a save.
	world.aura = 0
	world.player_position = world.from_ground(deep.checkpoints[0])
	world._check_cave_points()
	assert(world.aura == world.AURA["deep_checkpoint"] and world.AURA["deep_checkpoint"] == 30)
	world._check_cave_points()
	assert(world.aura == 30, "A deep checkpoint pays once")
	assert(world._cave_progress[key]["deep"] == [0] and 0 not in world._cave_progress[key]["checkpoints"], "Kept apart from the first level's")

	# Saving on the second level keeps the level, her spot and its monsters.
	# Protects: loading on the wrong level, at the wrong spot, with monsters
	# reset or duplicated, and older saves failing to load.
	world.player_position = world.from_ground(deep.checkpoints[0] + Vector2(0.5, 0))
	world._loaded_center = Vector2i(-999, -999)
	world._refresh_cave_creatures()
	var living: int = goblins[0]
	var index: int = world._animals[living]["cave_index"]
	_put(world, living, world.from_ground(deep.checkpoints[0] + Vector2(-1.0, 0)))
	world._animals[living]["stun"] = 2.0
	var below: Dictionary = world.save_state()
	assert(world.SAVE_GAME.validate(below) == "" and below["underground"]["level"] == 2 and below["caves"][key]["deep"] == [0])
	assert(below["underground"]["monsters"].size() == deep.spawns.size())
	assert(world.SAVE_GAME.write(below, world.save_path) == "")
	world._exit_cave(true)
	assert(not world.in_cave() and world._cave_depth == 0)
	world._cave_progress = {}
	world._load_game()
	assert(world.in_cave() and world._cave_depth == 2, "Loading resumes on the second level")
	deep = world._cave
	assert(world.to_ground(world.player_position).distance_to(deep.checkpoints[0] + Vector2(0.5, 0)) < 0.01, "At her spot")
	assert(world._animals.size() == deep.spawns.size() and world._upper_animals.size() == first_count, "No monster revived or duplicated")
	var restored := -1
	for id in world._animals.size():
		if world._animals[id]["cave_index"] == index:
			restored = id
	assert(world.to_ground(world._animals[restored]["position"]).distance_to(deep.checkpoints[0] + Vector2(-1.0, 0)) < 0.01 and world._animals[restored]["stun"] == 2.0, "Monsters resume where they were")
	world.aura = 0
	world.player_position = world.from_ground(deep.checkpoints[0])
	world._check_cave_points()
	assert(world.aura == 0 and world._cave_progress[key]["deep"] == [0], "Collected checkpoints stay collected")
	# A save from before the second level: no level, no deep checkpoints.
	var old: Dictionary = below.duplicate(true)
	old["underground"].erase("level")
	old["underground"]["offset"] = [0, -2]
	old["underground"]["monsters"] = []
	for cave_key in old["caves"]:
		old["caves"][cave_key].erase("deep")
	assert(world.SAVE_GAME.validate(old) == "", "Older saves stay valid")
	world.apply_state(old)
	assert(world.in_cave() and world._cave_depth == 1 and world._cave_progress[key]["deep"].is_empty(), "Older saves load on the first level")
	var bad: Dictionary = below.duplicate(true)
	bad["underground"]["level"] = 3
	assert(world.SAVE_GAME.validate(bad) != "")
	bad["underground"]["level"] = 1.5
	assert(world.SAVE_GAME.validate(bad) != "")
	bad = below.duplicate(true)
	bad["caves"][key]["deep"] = ["x"]
	assert(world.SAVE_GAME.validate(bad) != "")
	bad["caves"][key]["deep"] = range(17)
	assert(world.SAVE_GAME.validate(bad) != "")
	# Leaving from below never strands her: loading a surface save leaves the cave.
	world.apply_state(below)
	assert(world._cave_depth == 2)
	# Saving straight after a club keeps her escape grace (#91).
	# Protects: a save and load that lets a goblin club her again at once.
	deep = world._cave
	world._loaded_center = Vector2i(-999, -999)
	world._refresh_cave_creatures()
	var clubber: int = _of_kind(world, world.GOBLIN)[0]
	_clear_others(world, [clubber])
	var spots: Array = _ring(deep, world.to_ground(world.player_position), 4)
	_put(world, clubber, world.from_ground(deep.cell_center(spots[0])))
	world.player_stun = 0.0
	world.player_fright = 0.0
	world._bite_grace = 0.0
	assert(_run_cave(world, 12.0, func(): return world.player_stun > 0.0), "The goblin clubs her")
	var clubbed: Dictionary = world.save_state()
	assert(world.SAVE_GAME.validate(clubbed) == "")
	world.apply_state(clubbed)
	assert(world.player_stun > 0.0 and world._bite_grace > world.player_stun, "The grace survives loading")
	var stunned_for: float = world.player_stun
	var after_load := {"free": 0.0}
	_run_cave(world, stunned_for + world.BITE_GRACE - 0.1, func(): return false, func():
		assert(world.player_stun < stunned_for, "No second club after loading")
		if world.player_stun <= 0.0:
			after_load["free"] += STEP)
	assert(after_load["free"] >= 1.8, "Two free seconds after loading too: %.1f" % after_load["free"])
	world._exit_cave(true)
	assert(not world.in_cave() and world._upper_animals.is_empty() and world._animals.size() == surface_count)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(world.save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(world.save_path + ".bak"))
	print("Cave level 2 smoke test passed: ", caves.size(), " caves sampled with a way down on open floor and an identical, connected, larger second level; way down and way up without bouncing; first-level monsters wait; goblins chase and club (stun only) then back off; a lone kobold keeps its distance, a pack steals exactly one item and flees, none while stunned or scared; deep checkpoints pay +30 once; saving and loading on the second level; older saves load on the first")
	quit()
