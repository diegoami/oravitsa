extends SceneTree

## Protects: treating caves as pet-gated, killing monsters without a pet,
## getting trapped at a disarmed exit on revisit, or failing to help a pet
## finish hindered monsters while using normal cooldowns and movement.


func _initialize() -> void:
	call_deferred("_run")


func _cave(world: Node2D) -> Dictionary:
	for y in range(-2, 3):
		for x in range(-2, 3):
			var cave: Dictionary = world.landscape.cave_at(Vector2i(x, y))
			if not cave.is_empty():
				return cave
	return {}


func _walk_out(world: Node2D, seconds: float) -> void:
	for frame in int(seconds * 20):
		world._process(0.05)
		assert(world._can_stand(world.player_position), "Cave bot stays on walkable floor")
		if not world.in_cave():
			world.bot.update(0.01)
			return
		if frame % 100 == 0:
			await process_frame
	assert(false, "Autonomous cave visit must return to the woods")


func _run() -> void:
	for with_pet in [false, true]:
		var world = load("res://scenes/opening/demo_world.gd").new()
		world.fright_chance = 0.0
		root.add_child(world)
		world.set_process(false)
		var cave := _cave(world)
		assert(not cave.is_empty())
		if with_pet:
			# A normal seeded follower in a controlled test fixture. The actual
			# demo starts fresh and may adopt only through its regular prompt.
			var spec := {}
			for y in range(-2, 3):
				for x in range(-2, 3):
					var hamlet: Dictionary = world.landscape.hamlet_at(Vector2i(x, y))
					if spec.is_empty() and not hamlet.is_empty():
						spec = world.pets.hamlet_pet(hamlet)
			assert(not spec.is_empty())
			world.aura = int(spec["threshold"]) + 25
			world.pets.pets.append(world.pets._record(spec, "following", world.absolute_ground(world.player_position)))
		world._enter_cave(cave, true)
		var key: String = world._cave_key
		var checkpoints: int = world._cave.checkpoints.size()
		var monsters: int = world._animals.size()
		assert(world.in_cave() and monsters > 0)
		await _walk_out(world, 240.0)
		assert(world.bot.caves_explored == 1)
		assert(world._cave_progress[key]["checkpoints"].size() == checkpoints)
		if with_pet:
			assert(world._cave_progress[key]["killed"].size() == monsters, "Only the pet clears every cave monster")
			assert(world.bot.caves_cleared == 1)
		else:
			assert(world.pets.followers().is_empty())
			assert(world._cave_progress[key]["killed"].is_empty(), "Without a pet, exploration never kills monsters")
			assert(world.bot.caves_cleared == 0)
			# Checkpoints persist, but entry disarms the exit again. The bot
			# must step away to rearm it instead of waiting at the entrance.
			world._enter_cave(cave, true)
			await _walk_out(world, 30.0)
			assert(world.bot.caves_explored == 2)
		world.free()
		await process_frame
	print("Demo cave smoke test passed: pet-free checkpoint exploration and exit, safe completed-cave revisit, companion-assisted full clear, and normal cave rules")
	quit()
