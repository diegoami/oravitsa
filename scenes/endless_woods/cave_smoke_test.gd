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


func _run() -> void:
	var world = load("res://scenes/endless_woods/woods.tscn").instantiate()
	world.save_path = "user://cave_smoke_save.json"
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
	var karma_before: int = world.karma
	world.player_position = world.from_ground(cave["mouth"] - world.landscape.origin)
	world._check_cave_mouth()
	assert(world.in_cave() and world.landscape == world._cave and not world._surface_landscape.visible)
	assert(not world._can_save(), "No saving underground")
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
	var bitten := false
	for frame in 90:
		world._move_cave_creatures(1.0 / 30.0)
		if world.player_stun > 0.0:
			bitten = true
			break
	assert(bitten and is_equal_approx(world.player_stun, world.BITE_STUN) and world._animals[rat]["attack_time"] > 0.0, "A rat that reaches her bites")
	world._sync_presentation(0.0)
	assert(world._animal_players[rat].current_animation == "Attack")
	world.player_stun = 0.0
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
	world.karma = 0
	_put(world, rat, Vector2(50, 0))
	var rat_model: Node3D = world._animal_models[rat]
	var rat_animator: AnimationPlayer = world._animal_players[rat]
	var rat_index: int = world._animals[rat]["cave_index"]
	world._collect_nearby()
	assert(not world._animals[rat]["alive"] and world.karma == world.KARMA["rat"], "A stunned rat is finished for karma")
	assert(rat_index in world._cave_progress[world._cave_key]["killed"])
	assert(is_instance_valid(rat_model) and rat_animator.current_animation == "Death", "Its Death clip plays")
	world._collect_nearby()
	assert(world.karma == world.KARMA["rat"], "Killed once")
	# A stunned spider is passed through, then finished with controller A.
	_put(world, spider, Vector2(0, 0))
	world._animals[spider]["stun"] = 3.0
	world.player_position += Vector2(-60, 0)
	for step in 4:
		assert(world._try_move(Vector2(15, 0)), "Stunned monsters never block her")
	world._input_mode = "controller"
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	world._unhandled_input(press)
	assert(not world._animals[spider]["alive"] and world.karma == world.KARMA["rat"] + world.KARMA["spider"], "Controller A finishes a stunned spider")
	# Checkpoints collect karma once each.
	world.karma = 0
	world.player_position = world.from_ground(level.checkpoints[0])
	world._check_cave_points()
	assert(world.karma == world.KARMA["checkpoint"] and 0 in world._cave_progress[world._cave_key]["checkpoints"])
	world._check_cave_points()
	assert(world.karma == world.KARMA["checkpoint"], "A checkpoint pays once")
	# The way out returns her to the mouth, with the surface exactly as it was.
	world.player_position = world.from_ground(level.entrance + Vector2(0, -4))
	world._check_cave_points()
	world.player_position = world.from_ground(level.entrance)
	world._check_cave_points()
	assert(not world.in_cave() and world.landscape.visible and not world._lantern.visible)
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
	assert(world.in_cave() and world._animals.size() == rats + spiders - 2, "Killed monsters stay dead")
	world.player_position = world.from_ground(world._cave.checkpoints[0])
	world.karma = 0
	world._check_cave_points()
	assert(world.karma == 0)
	world.player_position = world.from_ground(world._cave.entrance + Vector2(0, -4))
	world._check_cave_points()
	world.player_position = world.from_ground(world._cave.entrance)
	world._check_cave_points()
	assert(not world.in_cave())
	# Saves carry cave progress and validate it.
	var state: Dictionary = world.save_state()
	assert(world.SAVE_GAME.validate(state) == "")
	var key: String = world._cave_key
	assert(state["caves"][key]["killed"].size() == 2 and state["caves"][key]["checkpoints"] == [0])
	world._cave_progress = {}
	world.apply_state(state)
	assert(world._cave_progress[key]["killed"].size() == 2)
	var bad: Dictionary = state.duplicate(true)
	bad["caves"][key]["killed"] = ["many"]
	assert(world.SAVE_GAME.validate(bad) != "")
	assert(karma_before == 0)
	print("Cave smoke test passed: seeded connected level (", cells, " cells, ", rats, " rats, ", spiders, " spiders, ", checkpoint_count, " checkpoints), entry/exit through the mouth, frozen surface, dark lantern lighting, no saving underground, bites only stun, Sling then walk-over/controller-A kills for karma with Death clips, once-only checkpoints, persistence across visits and saves")
	quit()
