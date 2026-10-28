extends SceneTree

## Endless foxes eat berries through the shared food/regrowth path (#24).


func _initialize() -> void:
	call_deferred("_run")


func _berry_spot(world, kind: int) -> Vector2i:
	for cell in world._forage_visuals:
		if world.objects[world._index(cell)] != kind:
			continue
		for offset in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(2, 2), Vector2i(-2, -2)]:
			if world._can_stand(world._cell_center(cell + offset), world.ANIMAL_RADIUS[world.FOX]):
				return cell
	return Vector2i(-1, -1)


func _fox_near(world, cell: Vector2i) -> int:
	for offset in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(2, 2), Vector2i(-2, -2)]:
		if world._can_stand(world._cell_center(cell + offset), world.ANIMAL_RADIUS[world.FOX]):
			world._add_animal(world.FOX, cell + offset)
			var id: int = world._animals.size() - 1
			world._active_animals[id] = world._make_animal_sprite(id)
			return id
	return -1


func _run_until(world, id: int, done: Callable, seconds: float) -> bool:
	var t := 0.0
	while t < seconds:
		world._move_animals(1.0 / 30.0)
		t += 1.0 / 30.0
		if done.call():
			return true
	return false


func _run() -> void:
	var world = load("res://scenes/endless_woods/woods.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	await process_frame
	for sprite in world._active_animals.values():
		sprite.queue_free()
	world._active_animals.clear()
	world._sync_animal_lifecycle()
	world._animals.clear()
	assert(world.BERRIES in world._food_kinds(world.FOX) and world.MUSHROOM not in world._food_kinds(world.FOX))
	var berry := _berry_spot(world, world.BERRIES)
	assert(berry.x != -1, "Need a reachable berry patch near arrival")
	# Keep Oravitsa out of the fox's avoidance radius.
	world.player_position = world._cell_center(berry) + Vector2(0, 30 * world.METRE)
	var key: int = world._index(berry)
	var inventory: int = world.basket + world.berries_basket
	var fox := _fox_near(world, berry)
	assert(fox >= 0)
	# Fear interrupts foraging and resets eating progress.
	assert(_run_until(world, fox, func(): return world._animals[fox]["eat_time"] > 0.2, 10.0), "Fox must approach and start eating berries")
	assert(world._animals[fox]["state"] == "forage" and world._animals[fox]["food_cell"] == berry)
	world.selected_target = fox
	world.player_position = world._animals[fox]["position"] + Vector2(300, 0)
	world._use_skill(0)
	assert(world._animals[fox]["eat_time"] == 0.0 and world._animals[fox]["state"] == "scared")
	assert(world.objects[key] == world.BERRIES, "A scared fox must not finish eating")
	world._animals[fox]["shoo"] = 0.0
	world._animals[fox]["state"] = "idle"
	world._animals[fox]["position"] = world._animals[fox]["home"]
	world.player_position = world._cell_center(berry) + Vector2(0, 30 * world.METRE)
	# A stun interrupts eating too.
	assert(_run_until(world, fox, func(): return world._animals[fox]["eat_time"] > 0.2, 10.0))
	world.sling_cooldown = 0.0
	world.player_position = world._animals[fox]["position"] + Vector2(300, 0)
	world._use_skill(1)
	world._update_sling(1.0)
	assert(world._animals[fox]["stun"] > 0 and world._animals[fox]["eat_time"] == 0.0)
	world._animals[fox]["stun"] = 0.0
	world.player_position = world._cell_center(berry) + Vector2(0, 30 * world.METRE)
	# Uninterrupted, the fox consumes the patch exactly once via the regrowth path.
	assert(_run_until(world, fox, func(): return world.objects[key] == world.EMPTY, 10.0), "Fox must finish eating the berries")
	assert(world._harvested.has(key))
	var due: float = world._harvested[key]["ready_at"] - world._food_clock
	assert(due >= world.BERRY_REGROW_SECONDS.x and due <= world.BERRY_REGROW_SECONDS.y, "Fox-eaten berries use the berry regrowth delay")
	assert(world.basket + world.berries_basket == inventory, "Fox foraging grants no player inventory")
	assert(not world._forage_visuals.has(berry))
	var ready: float = world._harvested[key]["ready_at"]
	world._consume_food(berry)
	assert(world._harvested[key]["ready_at"] == ready, "A depleted patch cannot be consumed twice")
	# The fox abandons a depleted patch rather than idling on it.
	world._move_animals(1.0 / 30.0)
	assert(world._animals[fox]["food_cell"] != berry)
	# Hunting a nearby hare takes priority over berries.
	var other := _berry_spot(world, world.BERRIES)
	assert(other.x != -1)
	world._animals[fox]["position"] = world._cell_center(other) + Vector2(world.TILE, 0)
	world._animals[fox]["food_cell"] = Vector2i(-1, -1)
	world._animals[fox]["hunt_rest"] = 0.0
	world._add_animal(world.HARE, world._world_cell(world._animals[fox]["position"]))
	var hare: int = world._animals.size() - 1
	world._animals[hare]["position"] = world._animals[fox]["position"] + Vector2(260, 0)
	world._active_animals[hare] = world._make_animal_sprite(hare)
	world.player_position = world._animals[fox]["position"] + Vector2(0, 30 * world.METRE)
	world._move_animals(1.0 / 30.0)
	assert(world._animals[fox]["state"] == "hunt", "A fox with a hare in reach hunts first")
	# After a missed lunge it rests and forages instead.
	world._animals[fox]["hunt_rest"] = world.FOX_HUNT_REST
	world._move_animals(1.0 / 30.0)
	assert(world._animals[fox]["state"] != "hunt")
	# Foxes never eat mushrooms.
	var mushroom := _berry_spot(world, world.MUSHROOM)
	assert(mushroom.x != -1)
	var mushroom_key: int = world._index(mushroom)
	world._animals[fox]["position"] = world._cell_center(mushroom) + Vector2(world.TILE * 2, 0)
	world._animals[fox]["food_cell"] = Vector2i(-1, -1)
	var target: Vector2i = world._nearest_food(world._animals[fox]["position"], world.FOX)
	assert(target == Vector2i(-1, -1) or world.objects[world._index(target)] == world.BERRIES)
	assert(world.objects[mushroom_key] == world.MUSHROOM)
	print("Fox forage smoke test passed: foxes find and eat berries, fear/stun interrupt eating, shared berry regrowth deadline, no inventory, no double consumption, depleted-patch retargeting, hare hunting priority and no mushrooms")
	quit()
