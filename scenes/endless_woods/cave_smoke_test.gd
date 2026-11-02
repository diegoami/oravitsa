extends SceneTree

## Cave interiors (#45) and their giant rats and spiders (#46).


func _initialize() -> void:
	call_deferred("_run")


func _travel(world: Node2D, absolute: Vector2) -> void:
	world.player_position = world.from_ground(absolute - world.landscape.origin)
	world._rebase_if_needed()
	world.view.position = world.to_world(world.player_position) + world.CAMERA_OFFSET
	world._refresh_visible()
	world._sync_presentation(0.0)
	await process_frame


func _level(world: Node2D, region: Vector2i) -> Node3D:
	var level: Node3D = world.CAVE_LEVEL.new()
	level.setup(region, Vector2(5, 7), world.RAT, world.SPIDER)
	return level


func _put(world: Node2D, id: int, offset: Vector2) -> void:
	world._animals[id]["position"] = world.player_position + offset
	world._animals[id]["velocity"] = Vector2.ZERO
	world._active_animals[id].position = world._animals[id]["position"]


func _creature(world: Node2D, kind: int) -> int:
	for id in world._active_animals:
		if world._animals[id]["kind"] == kind and world._animals[id]["alive"]:
			return id
	return -1


func _reset_monster(world: Node2D, id: int, offset: Vector2) -> void:
	_put(world, id, offset)
	for timer in ["stun", "shoo", "bite_cooldown", "attack_time", "burst", "burst_cooldown"]:
		world._animals[id][timer] = 0.0


## Runs the monsters while her stun wears off, up to `seconds` or until `done`.
func _run_cave(world: Node2D, seconds: float, done: Callable, each: Callable = func(): pass) -> bool:
	var elapsed := 0.0
	while elapsed < seconds:
		world._move_cave_creatures(1.0 / 30.0)
		world.player_stun = maxf(0.0, world.player_stun - 1.0 / 30.0)
		each.call()
		elapsed += 1.0 / 30.0
		if done.call():
			return true
	return false


## Active monsters (#50) at their reduced size (#51): they find their way to
## her, leave her room after a bite and never push against walls.
## Protects: monsters stuck on walls, noticing her through them, and stun-locks.
func _monster_behaviour(world: Node2D, level: Node3D, rat: int, spider: int) -> void:
	assert(world._animal_heights[world.RAT] < world._animal_heights[world.FOX], "A giant rat is smaller than a fox")
	assert(world.ANIMAL_RADIUS[world.RAT] < world.ANIMAL_RADIUS[world.SPIDER] and world.ANIMAL_SPEEDS[world.RAT] > world.ANIMAL_SPEEDS[world.SPIDER])
	assert(world.ANIMAL_SPEEDS[world.RAT] < world.SPEED, "A half-fed Oravitsa can outrun them")
	var here: Vector2 = world.to_ground(world.player_position)
	var flow: Dictionary = level.distances_to(level.cell_at(here))
	assert(not flow.is_empty() and flow[level.cell_at(here)] == 0)
	# A rat with a wall in the straight line still reaches her.
	var around := Vector2i(-1, -1)
	for cell in flow:
		if flow[cell] * level.CELL > world.MONSTER_SIGHT[world.RAT] or flow[cell] < 4:
			continue
		var blocked := false
		for part in 20:
			blocked = blocked or not level.is_open(level.cell_center(cell).lerp(here, part / 20.0))
		if blocked:
			around = cell
	assert(around.x >= 0, "This level has a corner to test")
	_reset_monster(world, rat, world.from_ground(level.cell_center(around)) - world.player_position)
	var on_floor := func(): assert(world._can_stand(world._animals[rat]["position"], world.ANIMAL_RADIUS[world.RAT]), "Monsters stay on the floor")
	assert(_run_cave(world, 15.0, func(): return world.player_stun > 0.0, on_floor), "A rat finds its way around the wall")
	world.player_stun = 0.0
	world._bite_grace = 0.0
	# Beyond walking reach it does not notice her, however close in a straight line.
	var limit: float = world.MONSTER_SIGHT[world.RAT] * world.MONSTER_LOSE
	var pair: Array[Vector2i] = []
	var cells: Array = level.open.keys()
	cells.sort()
	for from in cells:
		var walking: Dictionary = level.distances_to(from)
		for cell in walking:
			if pair.is_empty() and walking[cell] * level.CELL > limit and level.cell_center(cell).distance_to(level.cell_center(from)) < world.MONSTER_SIGHT[world.RAT]:
				pair = [from, cell]
	assert(pair.size() == 2, "This level has cells near in a line but far on foot")
	world.player_position = world.from_ground(level.cell_center(pair[0]))
	_reset_monster(world, rat, world.from_ground(level.cell_center(pair[1])) - world.player_position)
	world._animals[rat]["state"] = "roam"
	world._move_cave_creatures(1.0 / 30.0)
	assert(world._animals[rat]["state"] == "roam", "Out of walking reach it only roams")
	# Calm monsters scurry about their lair on the floor.
	var far_flow: Dictionary = level.distances_to(pair[0])
	var far_cell: Vector2i = pair[1]
	for cell in far_flow:
		if far_flow[cell] > far_flow[far_cell]:
			far_cell = cell
	_reset_monster(world, rat, world.from_ground(level.cell_center(far_cell)) - world.player_position)
	world._animals[rat]["home"] = world._animals[rat]["position"]
	world._animals[rat]["roam_from"] = far_cell
	world._animals[rat]["timeout"] = 0.0
	var lair: Vector2 = world._animals[rat]["position"]
	var strayed := {"most": 0.0}
	_run_cave(world, 15.0, func(): return false, func():
		strayed["most"] = maxf(strayed["most"], world._animals[rat]["position"].distance_to(lair))
		on_floor.call())
	var reach: float = (world.MONSTER_ROAM[world.RAT] + 1) * level.CELL * world.METRE * sqrt(2.0)
	assert(strayed["most"] > level.CELL * world.METRE and strayed["most"] <= reach, "It scurries around its lair: %.0f px" % strayed["most"])
	# Spiders lunge once she is close.
	world.player_position = world.from_ground(here)
	_reset_monster(world, rat, Vector2(5000, 5000))
	_reset_monster(world, spider, Vector2(150, 0))
	world._animals[spider]["state"] = "roam"
	assert(world.fed_speed() > 0.0)
	world._move_cave_creatures(1.0 / 30.0)
	assert(world._animals[spider]["burst"] > 0.0 and world._animals[spider]["burst_cooldown"] > 0.0, "A close spider lunges")
	var fastest := 0.0
	for frame in 20:
		world._move_cave_creatures(1.0 / 30.0)
		fastest = maxf(fastest, world._animals[spider]["velocity"].length())
	assert(fastest > world.ANIMAL_SPEEDS[world.SPIDER] * 1.1, "It lunges faster than it walks: %.0f" % fastest)
	# After a bite the pack backs off and she has time to get away.
	world.player_stun = 0.0
	world._bite_grace = 0.0
	world.fed = world.FED_MAX
	_reset_monster(world, rat, Vector2(50, 0))
	_reset_monster(world, spider, Vector2(-60, 0))
	assert(_run_cave(world, 3.0, func(): return world.player_stun > 0.0), "One of them bites")
	var first_stun: float = world.player_stun
	assert(absf(world._bite_grace - first_stun - world.BITE_GRACE) < 0.1, "A bite starts the grace time")
	var free := {"time": 0.0, "closest": INF}
	_run_cave(world, first_stun + world.BITE_GRACE - 0.1, func(): return false, func():
		assert(world.player_stun < first_stun, "No second bite during the grace time")
		if world.player_stun <= 0.0:
			free["time"] += 1.0 / 30.0
			free["closest"] = minf(world._animals[rat]["position"].distance_to(world.player_position), world._animals[spider]["position"].distance_to(world.player_position)))
	assert(free["time"] >= 1.8, "She always gets two free seconds: %.1f" % free["time"])
	assert(free["closest"] > world.ANIMAL_RADIUS[world.RAT] + world.PLAYER_RADIUS + 10.0, "The pack has backed off out of reach")
	assert(_run_cave(world, 5.0, func(): return world.player_stun > 0.0), "Then they come for her again")
	# Shoo drives a monster away along the floor.
	world.player_stun = 0.0
	world._bite_grace = 0.0
	_reset_monster(world, spider, Vector2(5000, 5000))
	_reset_monster(world, rat, Vector2(80, 0))
	world._animals[rat]["shoo"] = 2.0
	var near: float = world._animals[rat]["position"].distance_to(world.player_position)
	_run_cave(world, 1.0, func(): return false, on_floor)
	assert(world._animals[rat]["position"].distance_to(world.player_position) > near and world._animals[rat]["state"] == "scared", "Shoo drives it off")
	_reset_monster(world, rat, Vector2(90, 0))
	world._animals[rat]["state"] = "roam"
	world.player_stun = 0.0
	world._bite_grace = 0.0
	await process_frame


## A stun may become panic, which breaks chains of stuns.
## Protects: stun-locks, being stunned while panicking and pinned panic runs.
func _panic(world: Node2D, level: Node3D, rat: int, spider: int) -> void:
	var start: Vector2 = world.from_ground(level.checkpoints[0])
	world.player_position = start
	world.player_stun = 0.0
	world._bite_grace = 0.0
	world.fed = 50.0
	var walking: float = world._move_speed()
	_reset_monster(world, spider, Vector2(5000, 5000))
	_reset_monster(world, rat, Vector2(50, 0))
	world.fright_chance = 1.0
	assert(_run_cave(world, 3.0, func(): return world.player_fright > 0.0), "A bite can scare her")
	assert(world.player_stun == 0.0 and world._animals[rat]["attack_time"] > 0.0, "Instead of stunning her")
	assert(world._move_speed() > walking * 1.15, "She runs faster")
	world._sync_presentation(0.0)
	assert(world._player_marker.visible and world._player_marker.icons == ["scared"] and world._player_marker.fractions[0] > 0.9, "Her fear shows as an icon with a time bar")
	# While scared nothing can stun her, and animals neither stop nor bump her.
	world.fright_chance = 0.0
	assert(not world._stun_player(1.0, world._animals[rat]["position"]) and world.player_stun == 0.0, "No stun while scared")
	world.fright_chance = 1.0
	assert(world._passes_through(rat), "She runs through animals")
	_reset_monster(world, rat, Vector2(30, 0))
	world._animals[rat]["bite_cooldown"] = 0.0
	world._bite_grace = 0.0
	world._move_cave_creatures(1.0 / 30.0)
	assert(world.player_stun == 0.0 and world._animals[rat]["attack_time"] == 0.0, "Nothing bites her while scared")
	assert(world._try_move(Vector2(10, 0)) and world.player_stun == 0.0, "No bump while scared")
	# She runs away from what hit her, by herself and on the floor.
	world.player_position = start
	world.player_fright = world.FRIGHT_TIME
	world._fright_to_exit = false
	world._fright_away = Vector2.RIGHT
	for frame in 15:
		world._update_player(1.0 / 30.0)
		assert(world._can_stand(world.player_position, world.PLAYER_RADIUS), "Panic stays on the floor")
	assert((world.player_position - start).x > 30.0, "She runs without any input")
	# Or for the way out, walking the tunnels rather than into walls.
	world.player_position = start
	world.player_fright = world.FRIGHT_TIME
	world._fright_to_exit = true
	var steps_before: int = world._cave_exit_flow[level.cell_at(world.to_ground(start))]
	assert(steps_before > 3)
	for frame in int((world.FRIGHT_TIME - 0.1) * 30.0):
		world._update_player(1.0 / 30.0)
		assert(world._can_stand(world.player_position, world.PLAYER_RADIUS), "Panic stays on the floor")
	assert(world._cave_exit_flow[level.cell_at(world.to_ground(world.player_position))] < steps_before - 2, "She heads for the way out")
	# It wears off, and she can be stunned again.
	world._update_player(0.2)
	assert(world.player_fright == 0.0)
	world._sync_presentation(0.0)
	assert(not world._player_marker.visible, "The icon goes with it")
	world.fright_chance = 0.0
	assert(world._stun_player(1.0, start) and world.player_stun > 0.0, "Stuns return after panic")
	world.player_stun = 0.0
	# Over many stuns about a third become panic, half of those for the way out.
	world._fright_rng.seed = 7
	world.fright_chance = world.FRIGHT_CHANCE
	var scares := 0
	var exits := 0
	for roll in 1000:
		world.player_fright = 0.0
		world.player_stun = 0.0
		world._stun_player(1.0, start)
		if world.player_fright > 0.0:
			scares += 1
			exits += 1 if world._fright_to_exit else 0
		else:
			assert(world.player_stun > 0.0, "Every roll is a stun or panic")
	assert(scares > 290 and scares < 410 and exits > scares * 0.35 and exits < scares * 0.65, "Odds: %d scares, %d for the exit" % [scares, exits])
	world.fright_chance = 0.0
	world.player_fright = 0.0
	world.player_stun = 0.0
	world.fed = world.FED_MAX
	world.player_position = start
	_reset_monster(world, rat, Vector2(90, 0))
	world._animals[rat]["state"] = "roam"


func _run() -> void:
	var world = load("res://scenes/endless_woods/woods.tscn").instantiate()
	world.save_path = "user://cave_smoke_save.json"
	world.fright_chance = 0.0 # Panic is checked separately.
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	await process_frame
	var land: Node3D = world.landscape
	var cave: Dictionary = {}
	for rz in range(-3, 4):
		for rx in range(-3, 4):
			if cave.is_empty():
				cave = land.cave_at(Vector2i(rx, rz))
	assert(not cave.is_empty())
	# Levels are seeded per region: identical on revisits, varied between caves.
	var a := _level(world, cave["region"])
	var b := _level(world, cave["region"])
	var c := _level(world, cave["region"] + Vector2i(1, 0))
	assert(a.open == b.open and a.checkpoints == b.checkpoints and a.spawns == b.spawns, "A cave regenerates identically")
	assert(a.open != c.open, "Different caves have different levels")
	# Every floor cell, checkpoint and lair is reachable from the way out.
	var start: Vector2i = a.cell_at(a.entrance)
	var seen := {start: true}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if a.open.has(cell + step) and not seen.has(cell + step):
				seen[cell + step] = true
				frontier.append(cell + step)
	assert(seen.size() == a.open.size(), "The level is connected")
	assert(a.checkpoints.size() >= a.CHECKPOINTS.x and a.checkpoints.size() <= a.CHECKPOINTS.y)
	var rats := 0
	var spiders := 0
	for spot in a.spawns:
		assert(seen.has(a.cell_at(Vector2(spot.x, spot.y))) and Vector2(spot.x, spot.y).distance_to(a.entrance) >= 10.0, "Lairs are inside and away from the way out")
		rats += 1 if int(spot.z) == world.RAT else 0
		spiders += 1 if int(spot.z) == world.SPIDER else 0
	assert(rats >= a.RATS.x and rats <= a.RATS.y and spiders >= a.SPIDERS.x and spiders <= a.SPIDERS.y)
	assert(a.can_walk(a.entrance, 0.375) and not a.can_walk(a.cell_center(Vector2i(0, 0)), 0.375), "Collision comes from the grid")
	var cells: int = a.open.size()
	var checkpoint_count: int = a.checkpoints.size()
	for level in [a, b, c]:
		level.free()
	# Walking into the mouth enters the level; the surface freezes meanwhile.
	await _travel(world, cave["mouth"] + cave["facing"] * 2.0)
	world._check_cave_mouth()
	assert(not world.in_cave(), "Standing in front of the mouth is not entering")
	var surface_count: int = world._animals.size()
	var surface_first: Vector2 = world._animals[0]["position"]
	var aura_before: int = world.aura
	world.player_position = world.from_ground(cave["mouth"] - world.landscape.origin)
	world._check_cave_mouth()
	assert(world.in_cave() and world.landscape == world._cave and not world._surface_landscape.visible)
	assert(world._can_save(), "Saving works underground")
	var level: Node3D = world._cave
	assert(world.to_ground(world.player_position).distance_to(level.entrance) < 0.01)
	assert(world._lantern.visible and is_equal_approx(world._lantern.light_energy, 2.2))
	for child in world.stage.get_children():
		if child is DirectionalLight3D:
			assert(child.light_energy == 0.0, "The cave is dark apart from the lantern and its glows")
	assert(world._animals.size() == rats + spiders and world._surface_animals.size() == surface_count)
	world._map_visible = true
	world._update_hud()
	world._minimap.queue_redraw()
	await process_frame
	# Monsters near Oravitsa chase her and bite: a stun, never an injury.
	world.player_position = world.from_ground(level.checkpoints[0] + Vector2(0, 0.0))
	world._loaded_center = Vector2i(-999, -999)
	world._refresh_cave_creatures()
	var rat := _creature(world, world.RAT)
	var spider := _creature(world, world.SPIDER)
	if rat < 0 or spider < 0:
		world.player_position = world.from_ground(Vector2(level.spawns[0].x, level.spawns[0].y) + Vector2(0, 0.0))
		world._loaded_center = Vector2i(-999, -999)
		world._refresh_cave_creatures()
		rat = _creature(world, world.RAT)
		spider = _creature(world, world.SPIDER)
	assert(rat >= 0 and spider >= 0, "Nearby monsters are active")
	world._sync_presentation(0.0)
	assert(world._animal_models.has(rat) and world._animal_players[rat].has_animation("Death") and world._animal_players[rat].has_animation("Attack"))
	for id in world._active_animals:
		if id != rat:
			_put(world, id, Vector2(5000, 5000))
	_put(world, rat, Vector2(90, 0))
	world.player_stun = 0.0
	world.fed = world.FED_MAX
	var bitten := false
	for frame in 90:
		world._move_cave_creatures(1.0 / 30.0)
		if world.player_stun > 0.0:
			bitten = true
			break
	assert(bitten and is_equal_approx(world.player_stun, world.BITE_STUN * world.FULL_STUN) and world._animals[rat]["attack_time"] > 0.0, "A rat that reaches her bites")
	world._sync_presentation(0.0)
	assert(world._animal_players[rat].current_animation == "Attack")
	world.player_stun = 0.0
	await _monster_behaviour(world, level, rat, spider)
	_panic(world, level, rat, spider)
	# Awake monsters cannot be finished; Sling stuns, then walk-over kills.
	world._input_mode = "keyboard"
	_put(world, rat, Vector2(40, 0))
	world._collect_nearby()
	assert(world._animals[rat]["alive"], "Only a stunned monster can be killed")
	world.selected_target = rat
	world.sling_cooldown = 0.0
	_put(world, rat, Vector2(220, 0))
	world._use_skill(1)
	for frame in 40:
		world._update_sling(1.0 / 30.0)
	assert(world._animals[rat]["stun"] > 0.0)
	world.aura = 0
	_put(world, rat, Vector2(50, 0))
	var rat_model: Node3D = world._animal_models[rat]
	var rat_animator: AnimationPlayer = world._animal_players[rat]
	var rat_index: int = world._animals[rat]["cave_index"]
	world._collect_nearby()
	assert(not world._animals[rat]["alive"] and world.aura == world.AURA["rat"], "A stunned rat is finished for aura")
	assert(rat_index in world._cave_progress[world._cave_key]["killed"])
	assert(is_instance_valid(rat_model) and rat_animator.current_animation == "Death", "Its Death clip plays")
	world._collect_nearby()
	assert(world.aura == world.AURA["rat"], "Killed once")
	# With a controller, walking over a stunned monster finishes it too (#72).
	# Protects: controller players passing through stunned monsters unharmed.
	var walk_rat := _creature(world, world.RAT)
	assert(walk_rat >= 0, "The level has a second rat")
	_put(world, walk_rat, Vector2(50, 0))
	world._animals[walk_rat]["stun"] = 3.0
	world._input_mode = "controller"
	world._update_player(1.0 / 30.0)
	assert(not world._animals[walk_rat]["alive"] and world.aura == world.AURA["rat"] * 2, "Walking over a stunned rat with a controller finishes it")
	assert(world._dying_models.size() == 2, "The cave keeps its Death clips")
	var dying_models: Array[Node3D] = world._dying_models.duplicate()
	# A stunned spider never blocks her and A finishes it as well.
	_put(world, spider, Vector2(0, 0))
	world._animals[spider]["stun"] = 3.0
	world.player_position += Vector2(-60, 0)
	for step in 4:
		assert(world._try_move(Vector2(15, 0)), "Stunned monsters never block her")
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	world._unhandled_input(press)
	assert(not world._animals[spider]["alive"] and world.aura == world.AURA["rat"] * 2 + world.AURA["spider"], "Controller A finishes a stunned spider")
	# Checkpoints collect aura once each.
	world.aura = 0
	world.player_position = world.from_ground(level.checkpoints[0])
	world._check_cave_points()
	assert(world.aura == world.AURA["checkpoint"] and 0 in world._cave_progress[world._cave_key]["checkpoints"])
	world._check_cave_points()
	assert(world.aura == world.AURA["checkpoint"], "A checkpoint pays once")
	# The way out returns her to the mouth, with the surface exactly as it was.
	world.player_position = world.from_ground(level.entrance + Vector2(0, -4))
	world._check_cave_points()
	world.player_position = world.from_ground(level.entrance)
	world._check_cave_points()
	assert(not world.in_cave() and world.landscape.visible and not world._lantern.visible)
	# Protects: a Death clip still playing on the surface after she leaves (#71).
	for model in dying_models:
		assert(not is_instance_valid(model) or model.is_queued_for_deletion(), "Death clips do not follow her out of the cave")
	assert(world._dying_models.is_empty())
	assert(world._animals.size() == surface_count and world._animals[0]["position"] == surface_first, "The surface waited unchanged")
	var here: Vector2 = world.absolute_ground(world.player_position)
	assert(here.distance_to(cave["mouth"]) > world.CAVE_ENTER_RADIUS and here.distance_to(cave["mouth"]) < 3.0)
	world._check_cave_mouth()
	assert(not world.in_cave(), "Leaving does not immediately re-enter")
	assert(world._can_save())
	# Progress persists: on return the dead stay dead and checkpoints stay taken.
	await _travel(world, cave["mouth"] + cave["facing"] * 4.0)
	world._check_cave_mouth()
	world.player_position = world.from_ground(cave["mouth"] - world.landscape.origin)
	world._check_cave_mouth()
	assert(world.in_cave() and world._animals.size() == rats + spiders - 3, "Killed monsters stay dead")
	world.player_position = world.from_ground(world._cave.checkpoints[0])
	world.aura = 0
	world._check_cave_points()
	assert(world.aura == 0)
	world.player_position = world.from_ground(world._cave.entrance + Vector2(0, -4))
	world._check_cave_points()
	world.player_position = world.from_ground(world._cave.entrance)
	world._check_cave_points()
	assert(not world.in_cave())
	# Saves carry cave progress and validate it.
	var state: Dictionary = world.save_state()
	assert(world.SAVE_GAME.validate(state) == "")
	var key: String = world._cave_key
	assert(state["caves"][key]["killed"].size() == 3 and state["caves"][key]["checkpoints"] == [0])
	world._cave_progress = {}
	world.apply_state(state)
	assert(world._cave_progress[key]["killed"].size() == 3)
	var bad: Dictionary = state.duplicate(true)
	bad["caves"][key]["killed"] = ["many"]
	assert(world.SAVE_GAME.validate(bad) != "")
	assert(aura_before == 0)
	# Saving underground keeps the waiting surface, and loading puts Oravitsa
	# and the monsters back where they were in the cave.
	await _travel(world, cave["mouth"] + cave["facing"] * 4.0)
	world._check_cave_mouth()
	world.player_position = world.from_ground(cave["mouth"] - world.landscape.origin)
	world._check_cave_mouth()
	assert(world.in_cave())
	var spot: Vector2 = world._cave.checkpoints[0]
	world.player_position = world.from_ground(spot)
	world._loaded_center = Vector2i(-999, -999)
	world._refresh_cave_creatures()
	var living := -1
	for id in world._animals.size():
		if world._animals[id]["alive"] and living < 0:
			living = id
	var living_index: int = world._animals[living]["cave_index"]
	var lair: Vector2 = Vector2(world._cave.spawns[living_index].x, world._cave.spawns[living_index].y)
	world._animals[living]["position"] = world.from_ground(spot + Vector2(1.0, 0))
	world._animals[living]["stun"] = 2.0
	var below: Dictionary = world.save_state()
	assert(world.SAVE_GAME.validate(below) == "" and below["underground"]["cave"] == key and below["underground"]["monsters"].size() == rats + spiders - 3)
	assert(Vector2(below["player"]["ground"][0], below["player"]["ground"][1]).distance_to(world._cave_return) < 0.01, "The surface is saved with her at the mouth")
	world._exit_cave()
	assert(not world.in_cave())
	world.apply_state(below)
	assert(world.in_cave() and world.to_ground(world.player_position).distance_to(world._cave.checkpoints[0]) < 0.01, "Loading resumes underground")
	var restored := -1
	for id in world._animals.size():
		if world._animals[id]["cave_index"] == living_index:
			restored = id
	assert(world.to_ground(world._animals[restored]["position"]).distance_to(world._cave.checkpoints[0] + Vector2(1.0, 0)) < 0.01 and world._animals[restored]["stun"] == 2.0, "Monsters resume where they were")
	assert(lair.distance_to(world._cave.checkpoints[0] + Vector2(1.0, 0)) > 0.01)
	assert(world._animals.size() == rats + spiders - 3 and world._surface_animals.size() == state["animals"].size())
	world.apply_state(below)
	assert(world.in_cave(), "Loading underground from underground")
	# Panic is not saved, ends on leaving and never carries her into a cave.
	world.player_fright = 1.0
	world._exit_cave(true)
	assert(world.player_fright == 0.0, "Leaving ends panic")
	world.player_fright = 1.0
	world.apply_state(state)
	assert(not world.in_cave() and world.player_fright == 0.0, "Loading on the surface ends panic")
	world.player_position = world.from_ground(cave["mouth"] - world.landscape.origin)
	world._cave_armed = true
	world.player_fright = 1.0
	world._check_cave_mouth()
	assert(not world.in_cave(), "A panicking Oravitsa runs past cave mouths")
	world.player_fright = 0.0
	world._check_cave_mouth()
	assert(world.in_cave(), "Calm again, the mouth works")
	world.apply_state(state)
	assert(not world.in_cave() and world.landscape.visible and not world._lantern.visible, "Loading a surface save leaves the cave")
	bad = below.duplicate(true)
	bad["underground"]["offset"] = [9000, 0]
	assert(world.SAVE_GAME.validate(bad) != "")
	bad = below.duplicate(true)
	bad["underground"]["cave"] = "no,cave"
	assert(world.SAVE_GAME.validate(bad) != "")
	print("Cave smoke test passed: seeded connected level (", cells, " cells, ", rats, " rats, ", spiders, " spiders, ", checkpoint_count, " checkpoints), entry/exit through the mouth, frozen surface, dark lantern lighting, monsters that find their way around walls by walking distance, scurry, lunge and leave her room after a bite, panic instead of stuns, bites only stun (shorter when well fed), Sling then walk-over/controller-A kills for aura with Death clips, once-only checkpoints, persistence across visits and saves, saving and loading underground")
	quit()
