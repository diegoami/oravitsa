extends SceneTree

## Repeatable ecology samples for tuning the endless world (not a CI gate):
## initial population, food patches in a 200 m square, local population over
## a 1.5 km walk, and isolated catch trials from 6 m over 20 seconds.
## godot --headless --path . --script res://scenes/endless_woods/ecology_sample.gd


func _initialize() -> void:
	call_deferred("_run")


func _fresh():
	var world = load("res://scenes/endless_woods/woods.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	await process_frame
	return world


func _stand(w, cell: Vector2i, kind: int) -> Vector2i:
	for r in 8:
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if w._can_stand(w._cell_center(cell + Vector2i(dx, dz)), w.ANIMAL_RADIUS[kind]):
					return cell + Vector2i(dx, dz)
	return cell


func _run() -> void:
	var world = await _fresh()
	var counts := {}
	for animal in world._animals:
		counts[world.ANIMAL_NAMES[animal["kind"]]] = counts.get(world.ANIMAL_NAMES[animal["kind"]], 0) + 1
	print("initial animals ", world._animals.size(), " ", counts)
	# Food over a fixed 200 x 200 m absolute area around the start.
	var food := {"mushroom": 0, "berries": 0}
	var radius := int(100 * world.METRE / world.TILE)
	for z in range(-radius, radius + 1, 1):
		for x in range(-radius, radius + 1, 1):
			var cell: Vector2i = world.START + Vector2i(x, z)
			var kind: int = world.objects[world._index(cell)]
			if kind == world.MUSHROOM:
				food["mushroom"] += 1
			elif kind == world.BERRIES:
				food["berries"] += 1
		if z % 40 == 0:
			world._refresh_food() # trims the cell cache
	print("food in 200m square ", food)
	# Travel session: walk east 1.5 km and sample live local population.
	world.set_process(true)
	var samples := []
	for step in 60:
		world.player_position += Vector2(25 * world.METRE, 0)
		for frame in 30:
			await process_frame
		world._replenish_local_animals()
		var alive := 0
		for animal in world._animals:
			if animal["alive"] and animal["position"].distance_to(world.player_position) <= world._population_radius():
				alive += 1
		samples.append(alive)
	var total := 0
	for s in samples:
		total += s
	print("travel local population mean ", float(total) / samples.size(), " last ", samples.slice(-5))
	world.queue_free()
	await process_frame
	# Catch trials: one predator chasing one prey from 6 m, 20 simulated seconds.
	for pair in [["WOLF", "HARE"], ["LYNX", "HARE"], ["WOLF", "DEER"], ["LYNX", "DEER"], ["FOX", "HARE"]]:
		var caught := 0
		var trials := 24
		var times := []
		for trial in trials:
			var w = await _fresh()
			for sprite in w._active_animals.values():
				sprite.queue_free()
			w._active_animals.clear()
			w._sync_animal_lifecycle()
			w._animals.clear()
			var angle := TAU * trial / trials
			var center: Vector2 = w.from_ground(Vector2(-30, 30))
			w.player_position = center + Vector2(0, 40 * w.METRE)
			var a: Vector2i = _stand(w, w._world_cell(center), w.get(pair[0]))
			var b: Vector2i = _stand(w, w._world_cell(center + Vector2(cos(angle), sin(angle)) * 6 * w.METRE), w.get(pair[1]))
			w._add_animal(w.get(pair[0]), a)
			w._add_animal(w.get(pair[1]), b)
			w._animals[0]["home"] = w._animals[0]["position"]
			w.view.position = w.to_world(center) + w.CAMERA_OFFSET
			w._refresh_visible()
			# Force both into the active set regardless of the view.
			for id in 2:
				if not w._active_animals.has(id):
					w._active_animals[id] = w._make_animal_sprite(id)
			var t := 0.0
			while t < 20.0:
				w._move_animals(1.0 / 30.0)
				t += 1.0 / 30.0
				if not w._animals[1]["alive"]:
					caught += 1
					times.append(snappedf(t, 0.1))
					break
			w.queue_free()
			await process_frame
		print(pair, " catches ", caught, "/", trials, " times ", times)
	quit()
