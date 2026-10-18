extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/forest_2d/forest.tscn")
	var forest := scene.instantiate()
	root.add_child(forest)
	current_scene = forest
	assert(forest.terrain.size() == 128 * 128)
	assert(forest.objects.size() == 128 * 128)
	assert(forest._ground.get_used_rect().size == Vector2i(128, 128))
	assert(forest._camera.limit_right == 128 * 114)
	assert(forest._minimap != null)
	assert(forest._can_stand(forest._cell_center(forest.START)))
	assert(forest.terrain[forest._index(forest.START)] == forest.DIRT)
	forest._player.stop()
	assert(not forest._player.is_playing())
	Input.action_press("move_right")
	forest._process(1.0 / 60.0)
	Input.action_release("move_right")
	assert(forest._player.is_playing())
	var found := {}
	var mushroom := Vector2i(-1, -1)
	var grass_count := 0
	var dirt_count := 0
	for y in range(2, 126):
		for x in range(2, 126):
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
	assert(grass_count > 10000 and dirt_count > 500)
	assert(found.has(forest.MUSHROOM))
	assert(forest._can_stand(forest._cell_center(mushroom)))
	forest.player_position = forest._cell_center(mushroom)
	forest._collect_nearby()
	assert(forest.basket >= 1)
	assert(forest.objects[forest._index(mushroom)] == forest.EMPTY)
	assert(forest._in_bounds(Vector2i(127, 127)))
	assert(not forest._in_bounds(Vector2i(128, 127)))
	print("Forest smoke test passed: tiles, bounds, blockers, pickup, minimap")
	quit()
