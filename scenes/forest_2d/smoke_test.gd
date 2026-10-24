extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/forest_2d/forest.tscn")
	var forest := scene.instantiate()
	root.add_child(forest)
	current_scene = forest
	# Check the actual generated world before installing close-range AI fixtures.
	var populations := {}
	for kind in forest.SPAWN_WEIGHTS:
		populations[kind] = 0
	for animal in forest._animals:
		populations[animal["kind"]] += 1
	assert(populations[forest.HARE] > populations[forest.DEER])
	assert(populations[forest.HARE] > populations[forest.FOX])
	assert(populations[forest.DEER] > populations[forest.BOAR])
	assert(populations[forest.FOX] > populations[forest.BOAR])
	assert(populations[forest.BOAR] > populations[forest.LYNX])
	assert(forest._local_population(forest.LYNX) == 0)
	for sprite in forest._active_animals.values():
		sprite.queue_free()
	forest._active_animals.clear()
	forest._animals.clear()
	for entry in [
		[forest.BOAR, Vector2i(-3, -2)], [forest.DEER, Vector2i(3, -2)],
		[forest.FOX, Vector2i(-3, 2)], [forest.LYNX, Vector2i(3, 2)],
		[forest.HARE, Vector2i(-4, 0)], [forest.HARE, Vector2i(4, 0)]
	]:
		forest._add_animal(entry[0], forest.START + entry[1])
	forest._refresh_animals(forest.START)
	assert(forest.MAP_SIZE * forest.MAP_SIZE >= 10 * 128 * 128)
	assert(forest.terrain.size() == forest.MAP_SIZE * forest.MAP_SIZE)
	assert(forest.objects.size() == forest.MAP_SIZE * forest.MAP_SIZE)
	assert(forest._ground.get_used_rect().size == Vector2i(21, 15))
	assert(forest._dirt.get_used_rect().size == Vector2i(21, 15))
	assert(forest._blocked_ground != null)
	assert(forest._camera.limit_right == forest.MAP_SIZE * forest.TILE)
	assert(forest._minimap != null)
	assert(forest._active_animals.size() >= 4)
	for direction in ["e", "se", "s", "ne", "n"]:
		assert(forest._player.sprite_frames.get_frame_texture(direction, 0) != null)
		for sprite in forest._active_animals.values():
			assert(sprite.sprite_frames.get_frame_texture(direction, 0) != null)
	assert(forest._direction_name(Vector2.LEFT) == "w")
	assert(forest._direction_name(Vector2(-1, -1)) == "nw")
	assert(forest._direction_name(Vector2(1, 1)) == "se")
	assert(forest._player.sprite_frames.get_frame_count("e") == 4)
	assert(forest._player.sprite_frames.get_frame_count("s") == 4)
	assert(forest._player.sprite_frames.get_frame_count("n") == 4)
	assert(forest._ground.tile_set.get_source(forest.GRASS).texture != null)
	for sprite in forest._active_animals.values():
		assert(sprite != null and is_instance_valid(sprite))
	var animal_kinds := {}
	for animal in forest._animals:
		animal_kinds[animal["kind"]] = true
	for kind in [forest.BOAR, forest.DEER, forest.FOX, forest.LYNX, forest.HARE]:
		assert(animal_kinds.has(kind))
	assert(forest._minimap.ANIMAL_COLORS.size() == 5)
	assert(forest._can_stand(forest._cell_center(forest.START)))
	assert(not forest._can_stand(forest._cell_center(Vector2i(1, forest.START.y))))
	assert(forest.terrain[forest._index(forest.START)] == forest.DIRT)
	forest._player.stop()
	assert(not forest._player.is_playing())
	Input.action_press("move_right")
	forest._process(1.0 / 60.0)
	Input.action_release("move_right")
	assert(forest._player.is_playing())
	assert(forest._player.animation == "e")
	var start: Vector2 = forest._cell_center(forest.START)
	forest.player_position = start
	Input.action_press("move_right")
	Input.action_press("move_forward")
	forest._process(1.0 / 60.0)
	Input.action_release("move_right")
	Input.action_release("move_forward")
	assert(forest.player_position.x > start.x and forest.player_position.y < start.y)
	assert(forest._player.animation == "ne")
	forest.player_position = start
	var right_cell: Vector2i = forest.START + Vector2i(1, 0)
	var previous: int = forest.objects[forest._index(right_cell)]
	forest.objects[forest._index(right_cell)] = forest.TREE
	assert(forest._try_move(Vector2(forest.TILE, -forest.TILE)))
	assert(forest.player_position == forest._cell_center(forest.START + Vector2i(1, -1)))
	forest.objects[forest._index(right_cell)] = previous
	forest.player_position = start
	var left_cell: Vector2i = forest.START + Vector2i(-1, 0)
	var down_cell: Vector2i = forest.START + Vector2i(0, 1)
	var previous_left: int = forest.objects[forest._index(left_cell)]
	var previous_down: int = forest.objects[forest._index(down_cell)]
	forest.objects[forest._index(left_cell)] = forest.BUSH
	forest.objects[forest._index(down_cell)] = forest.BUSH
	assert(forest._try_move(Vector2(-50.0, 50.0)))
	assert(forest.player_position == start + Vector2(-50.0, 50.0))
	assert(not forest._can_stand(forest._cell_center(left_cell) + Vector2(45.0, 0.0)))
	forest.objects[forest._index(left_cell)] = previous_left
	forest.objects[forest._index(down_cell)] = previous_down
	forest.player_position = start
	Input.action_press("move_left")
	Input.action_press("move_back")
	forest._process(1.0 / 60.0)
	Input.action_release("move_left")
	Input.action_release("move_back")
	assert(forest.player_position.x < start.x and forest.player_position.y > start.y)
	assert(forest._player.animation == "se" and forest._player.flip_h)
	forest.player_position = forest._animals[0]["position"] + Vector2(-100.0, 0.0)
	forest._shoo()
	assert(forest.shoo_cooldown > 0.0)
	assert(forest._animals[0]["shoo"] > 0.0)
	# Shooing and touching a hare must never kill it.
	forest.shoo_cooldown = 0.0
	var hare_position: Vector2 = forest._animals[4]["position"]
	forest.player_position = hare_position + Vector2(-100.0, 0.0)
	forest._shoo()
	assert(forest._animals[4]["shoo"] > 0.0)
	assert(forest._animals[4]["alive"])
	forest.player_position = hare_position + Vector2(-forest.PLAYER_RADIUS - forest.ANIMAL_RADIUS[forest.HARE] - 1.0, 0.0)
	forest._try_move(Vector2(3.0, 0.0))
	assert(forest._animals[4]["stun"] > 0.0)
	assert(forest._animals[4]["alive"])
	forest.player_stun = 0.0
	forest._animals[4]["stun"] = 0.0
	forest._animals[4]["shoo"] = 0.0
	forest.shoo_cooldown = 0.0
	var boar_position: Vector2 = forest._animals[0]["position"]
	forest.player_position = boar_position + Vector2(-forest.PLAYER_RADIUS - forest.ANIMAL_RADIUS[forest.BOAR] - 1.0, 0.0)
	forest._try_move(Vector2(3.0, 0.0))
	assert(forest.player_stun > 0.0)
	assert(forest._animals[0]["stun"] > 0.0)
	forest.player_stun = 0.0
	forest._animals[0]["stun"] = 0.0
	forest.player_position = forest._cell_center(forest.START)
	var boar_food: Vector2i = forest.START + Vector2i(-2, -2)
	forest.objects[forest._index(boar_food)] = forest.MUSHROOM
	assert(forest._nearest_food(forest._animals[0]["position"], forest.BOAR) == boar_food)
	forest.objects[forest._index(boar_food)] = forest.EMPTY
	forest._animals[0]["shoo"] = 0.0
	forest._animals[1]["position"] = forest._animals[3]["position"] + Vector2(0.0, -200.0)
	forest._animals[4]["position"] = forest._animals[3]["position"] + Vector2(-200.0, 0.0)
	forest._animals[2]["position"] = forest._animals[0]["position"] + Vector2(0.0, 120.0)
	forest._move_animals(1.0 / 60.0)
	assert(forest._animals[1]["state"] == "flee")
	assert(forest._animals[2]["state"] == "flee")
	assert(forest._animals[3]["state"] == "hunt")
	assert(forest._animals[3]["burst"] > 0.0)
	forest._animals[1]["position"] = forest._animals[3]["position"] + Vector2(-54.0, 0.0)
	forest._catch_prey(3, 1, forest.DEER_CATCH_TIME - 0.1)
	assert(forest._animals[1]["alive"])
	assert(forest._animals[3]["feeding"] == 0.0)
	assert(forest._active_animals.has(1))
	# Losing contact discards progress; a later attempt starts from zero.
	forest._animals[1]["position"] = forest._animals[3]["position"] + Vector2(-200.0, 0.0)
	forest._move_animals(1.0 / 60.0)
	assert(forest._animals[3]["catch_time"] == 0.0)
	for step in 29:
		forest._animals[1]["position"] = forest._animals[3]["position"] + Vector2(-54.0, 0.0)
		forest._animals[1]["stun"] = 0.2
		forest._move_animals(0.1)
	assert(forest._animals[3]["catch_time"] > 2.8)
	assert(forest._animals[1]["alive"])
	forest._animals[1]["position"] = forest._animals[3]["position"] + Vector2(-54.0, 0.0)
	forest._animals[1]["stun"] = 0.2
	forest._move_animals(0.11)
	assert(not forest._animals[1]["alive"])
	assert(forest.deer_caught == 1)
	assert(forest._animals[3]["feeding"] > 0.0)
	assert(not forest._active_animals.has(1))
	forest._animals[4]["position"] = forest._animals[3]["position"] + Vector2(-200.0, 0.0)
	forest._animals[3]["feeding"] = 0.0
	forest._move_animals(1.0 / 60.0)
	assert(forest._animals[4]["state"] == "flee")
	forest._animals[4]["position"] = forest._animals[3]["position"] + Vector2(-45.0, 0.0)
	forest._move_animals(1.0 / 60.0)
	assert(not forest._animals[4]["alive"])
	assert(forest.hares_caught == 1)
	assert(forest._animals[3]["feeding"] > 0.0)
	assert(not forest._active_animals.has(4))
	forest._animals[3]["feeding"] = 0.001
	forest._move_animals(0.01)
	assert(forest._animals[3]["state"] != "feed")
	forest.player_position = forest._cell_center(forest.START + Vector2i(20, 20))
	forest._update_respawns(forest.PREY_RESPAWN_TIME + 0.1)
	assert(forest._animals[4]["alive"])
	assert(forest._animals[1]["alive"])
	forest.player_position = start
	forest._animals[2]["position"] = forest._cell_center(forest.START + Vector2i(-3, 2))
	forest._animals[1]["position"] = forest._cell_center(forest.START + Vector2i(3, -2))
	var before: Vector2 = forest._animals[0]["position"]
	for i in 30:
		forest._move_animals(1.0 / 60.0)
	assert(forest._animals[0]["position"] != before)
	for id in forest._active_animals.keys():
		assert(forest._can_stand(forest._animals[id]["position"]))
	var found := {}
	var mushroom := Vector2i(-1, -1)
	var berries := Vector2i(-1, -1)
	var grass_count := 0
	var dirt_count := 0
	for y in range(2, forest.MAP_SIZE - 2):
		for x in range(2, forest.MAP_SIZE - 2):
			var cell := Vector2i(x, y)
			if forest.terrain[forest._index(cell)] == forest.GRASS:
				grass_count += 1
			else:
				dirt_count += 1
			var kind: int = forest.objects[forest._index(cell)]
			if kind != forest.EMPTY and not found.has(kind):
				found[kind] = cell
			if kind == forest.MUSHROOM and mushroom.x < 0:
				mushroom = cell
			if kind == forest.BERRIES and berries.x < 0:
				berries = cell
	for kind in [forest.TREE, forest.BUSH, forest.STONE, forest.LOG]:
		assert(found.has(kind))
		assert(not forest._can_stand(forest._cell_center(found[kind])))
	assert(found.has(forest.FERN))
	assert(grass_count > 100000 and dirt_count > 5000)
	assert(found.has(forest.MUSHROOM))
	assert(forest._can_stand(forest._cell_center(mushroom)))
	forest.player_position = forest._cell_center(mushroom)
	forest._collect_nearby()
	assert(forest.basket >= 1)
	assert(forest.objects[forest._index(mushroom)] == forest.EMPTY)
	assert(found.has(forest.BERRIES))
	assert(forest._can_stand(forest._cell_center(berries)))
	assert(forest._nearest_food(forest._cell_center(berries), forest.DEER) == berries)
	forest.player_position = forest._cell_center(berries)
	forest._collect_nearby()
	assert(forest.berries_basket >= 1)
	assert(forest.objects[forest._index(berries)] == forest.EMPTY)
	assert(forest._in_bounds(Vector2i(forest.MAP_SIZE - 1, forest.MAP_SIZE - 1)))
	assert(not forest._in_bounds(Vector2i(forest.MAP_SIZE, forest.MAP_SIZE - 1)))
	forest.player_position = forest._cell_center(Vector2i(48, 48))
	forest._refresh_visible()
	assert(forest._ground.get_used_rect().position == Vector2i(38, 41))
	assert(forest._ground.get_used_rect().size == Vector2i(21, 15))
	assert(forest._dirt.get_used_rect().position == Vector2i(38, 41))
	forest.player_position = start
	forest._refresh_visible()
	for id in forest._animals.size():
		if forest._animals[id]["kind"] == forest.HARE:
			forest._animals[id]["position"] = forest._cell_center(Vector2i(45, 45))
	forest._refresh_animals(forest._loaded_center)
	assert(forest._local_population(forest.HARE) == 0)
	forest._replenish_local_animals()
	assert(forest._local_population(forest.HARE) >= 4)
	for animal in forest._animals:
		if animal["kind"] == forest.HARE and animal["position"].distance_to(start) < forest.POPULATION_RADIUS:
			assert(animal["position"].distance_to(start) >= 730.0)
	# Repeated shortages must preserve rarity, rather than guaranteeing a lynx
	# each time Oravitsa reaches a new area. Reuse offscreen animals as in play.
	var arrivals := {}
	for kind in forest.SPAWN_WEIGHTS:
		arrivals[kind] = 0
	for tick in 128:
		for animal in forest._animals:
			animal["position"] = Vector2.ZERO
		forest._refresh_animals(forest.START)
		forest._replenish_local_animals()
		for kind in arrivals:
			arrivals[kind] += forest._local_population(kind)
	assert(arrivals[forest.HARE] > arrivals[forest.DEER])
	assert(arrivals[forest.HARE] > arrivals[forest.FOX])
	assert(arrivals[forest.DEER] > arrivals[forest.BOAR])
	assert(arrivals[forest.FOX] > arrivals[forest.BOAR])
	assert(arrivals[forest.BOAR] > arrivals[forest.LYNX])
	print("Forest smoke test passed: movement, hare flight, local replenishment, lynx catch/respawn, minimap, streaming and pickups")
	quit()
