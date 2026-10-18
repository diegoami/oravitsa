extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/forest_2d/forest.tscn")
	var forest := scene.instantiate()
	root.add_child(forest)
	current_scene = forest
	assert(forest.MAP_SIZE * forest.MAP_SIZE >= 10 * 128 * 128)
	assert(forest.terrain.size() == forest.MAP_SIZE * forest.MAP_SIZE)
	assert(forest.objects.size() == forest.MAP_SIZE * forest.MAP_SIZE)
	assert(forest._ground.get_used_rect().size == Vector2i(21, 15))
	assert(forest._dirt.get_used_rect().size == Vector2i(21, 15))
	assert(forest._camera.limit_right == forest.MAP_SIZE * forest.TILE)
	assert(forest._minimap != null)
	assert(forest._active_animals.size() >= 4)
	assert(forest._player.sprite_frames.get_frame_texture("side", 0) != null)
	assert(forest._ground.tile_set.get_source(forest.GRASS).texture != null)
	for sprite in forest._active_animals.values():
		assert(sprite != null and is_instance_valid(sprite))
	var animal_kinds := {}
	for animal in forest._animals:
		animal_kinds[animal["kind"]] = true
	for kind in [forest.BOAR, forest.DEER, forest.FOX, forest.LYNX]:
		assert(animal_kinds.has(kind))
	assert(forest._can_stand(forest._cell_center(forest.START)))
	assert(forest.terrain[forest._index(forest.START)] == forest.DIRT)
	forest._player.stop()
	assert(not forest._player.is_playing())
	Input.action_press("move_right")
	forest._process(1.0 / 60.0)
	Input.action_release("move_right")
	assert(forest._player.is_playing())
	assert(forest._player.animation == "side")
	var before: Vector2 = forest._animals[0]["position"]
	for i in 30:
		forest._move_animals(1.0 / 60.0)
	assert(forest._animals[0]["position"] != before)
	for id in forest._active_animals.keys():
		assert(forest._can_stand(forest._animals[id]["position"]))
	var found := {}
	var mushroom := Vector2i(-1, -1)
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
	assert(forest._in_bounds(Vector2i(forest.MAP_SIZE - 1, forest.MAP_SIZE - 1)))
	assert(not forest._in_bounds(Vector2i(forest.MAP_SIZE, forest.MAP_SIZE - 1)))
	forest.player_position = forest._cell_center(Vector2i(48, 48))
	forest._refresh_visible()
	assert(forest._ground.get_used_rect().position == Vector2i(38, 41))
	assert(forest._ground.get_used_rect().size == Vector2i(21, 15))
	assert(forest._dirt.get_used_rect().position == Vector2i(38, 41))
	print("Forest smoke test passed: 10x world, tile streaming, blockers, pickup, four roaming species, side walk")
	quit()
