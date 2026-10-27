extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _travel(world: Node2D, absolute: Vector2) -> void:
	world.player_position = world.from_ground(absolute - world.landscape.origin)
	world._rebase_if_needed()
	world.view.position = world.to_world(world.player_position) + world.CAMERA_OFFSET
	world._refresh_visible()
	world._sync_presentation(0.0)
	await process_frame


func _run() -> void:
	var world = load("res://scenes/endless_woods/woods.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	await process_frame
	var food: Vector2i = world._forage_visuals.keys()[0]
	var absolute: Vector2 = world.absolute_ground(world._cell_center(food))
	await _travel(world, absolute)
	var kind: int = world.objects[world._index(food)]
	world._collect_nearby()
	var inventory: int = world.basket + world.berries_basket
	var key: int = world._index(food)
	var due: float = world._harvested[key]["ready_at"]
	var limits: Vector2 = world.BERRY_REGROW_SECONDS if kind == world.BERRIES else world.MUSHROOM_REGROW_SECONDS
	assert(due >= limits.x and due <= limits.y)
	# Empty-cell requests must not restart the timer or create extra records.
	world._consume_food(food)
	assert(world._harvested[key]["ready_at"] == due)
	await _travel(world, Vector2(4096, 200))
	world._update_food_regrowth(due - 1)
	assert(world._harvested.has(key), "Food must not regrow before its delay")
	await _travel(world, absolute)
	food = world._world_cell(world.from_ground(absolute - world.landscape.origin))
	assert(world.objects[world._index(food)] == world.EMPTY)
	assert(world._harvested[key]["ready_at"] == due, "Unloading/rebasing must not restart the regrowth timer")
	world._update_food_regrowth(2.1)
	assert(world._harvested.has(key) and not world._forage_visuals.has(food), "Due food must not pop into the visible view")
	assert(world.basket + world.berries_basket == inventory, "Regrowth must not grant inventory")
	await _travel(world, Vector2(-4096, -200))
	world._update_food_regrowth(1.1)
	assert(not world._harvested.has(key), "Hidden due patch must regrow")
	assert(not world.objects.has(key), "Unloaded regrowth must stay lazy")
	await _travel(world, absolute)
	food = world._world_cell(world.from_ground(absolute - world.landscape.origin))
	assert(world.objects[world._index(food)] == kind and world._forage_visuals.has(food))
	# Re-dressing a dirty chunk must not duplicate all its other pickup meshes.
	var node: Node3D = world._forage_visuals[food]
	var chunk := Vector2i((absolute / world.landscape.CHUNK).floor())
	world._food_chunks.erase(chunk)
	world._refresh_food()
	assert(world._forage_visuals[food] == node)
	world._collect_nearby()
	assert(world.basket + world.berries_basket == inventory + 1)
	assert(world._harvested[key]["ready_at"] > world._food_clock)
	# Animals use the same depletion/regrowth path as manual collection.
	var another: Vector2i = world._forage_visuals.keys()[0]
	for cell in world._forage_visuals:
		if world.objects[world._index(cell)] != kind:
			another = cell
			break
	var other_key: int = world._index(another)
	var other_kind: int = world.objects[other_key]
	assert(other_kind != kind)
	world._consume_food(another)
	assert(world._harvested.has(other_key) and world.objects[other_key] == world.EMPTY)
	var other_limits: Vector2 = world.BERRY_REGROW_SECONDS if other_kind == world.BERRIES else world.MUSHROOM_REGROW_SECONDS
	var other_delay: float = world._harvested[other_key]["ready_at"] - world._food_clock
	assert(other_delay >= other_limits.x and other_delay <= other_limits.y)
	assert(world._harvested[other_key]["ready_at"] != world._harvested[key]["ready_at"], "Patches should recover at staggered times")
	# A hidden patch can recover while its chunk is still rendered in the margin.
	var ready: float = world._harvested[key]["ready_at"]
	await _travel(world, absolute + Vector2(18, 0))
	assert(world.landscape.chunks.has(chunk))
	world._update_food_regrowth(ready - world._food_clock + 1.1)
	food = world._world_cell(world.from_ground(absolute - world.landscape.origin))
	assert(not world._harvested.has(key) and world._forage_visuals.has(food), "Loaded offscreen patch must regain its visual")
	print("Food regrowth smoke test passed: per-species delays, no early/visible respawn, absolute timers across unloading/rebases, lazy offscreen recovery, no duplicate visuals and recollection")
	quit()
