extends RefCounted

## The autonomous player's cave navigation. Entry/checkpoints/exit, skills
## and pet kills all use the game's existing rules; no companion is needed
## to explore. First-level stairs are avoided so she completes this visit.
var world: Node2D
var activity := "Exploring the cave"
var was_underground := false
var completed := false
var cleared := false
var _level := 0
var _route := PackedVector2Array()
var _goal_cell := Vector2i(1 << 28, 1 << 28)
var _decision := 0.0
var _goal := Vector2.ZERO
var _enemy := -1
var _hunt := false


func _init(forest: Node2D) -> void:
	world = forest


func update(delta: float) -> Vector2:
	was_underground = true
	var cave: Node3D = world._cave
	if _level != cave.get_instance_id():
		_level = cave.get_instance_id()
		completed = false
		cleared = false
		_route.clear()
		_goal_cell = Vector2i(1 << 28, 1 << 28)
		_decision = 0.0
	world._use_skill(world.SKILL_CURE) # Also heals nearby afflicted followers.
	if world.player_stun > 0.0 or world.player_fright > 0.0:
		activity = "Recovering, then continuing through the cave"
		return Vector2.ZERO
	_decision -= delta
	if _decision <= 0.0:
		_decision = 0.35
		_choose_goal()
	# Hinder nearby threats even without a pet: this lets her walk through
	# them to checkpoints. A following pet may finish them by its normal bite.
	var nearest := -1
	var reach := 360.0
	for id in world._active_animals:
		var animal: Dictionary = world._animals[id]
		if not animal["alive"] or animal["kind"] not in world.MONSTERS or world.pets.hindered(animal):
			continue
		var distance: float = world.player_position.distance_to(animal["position"])
		if distance < reach:
			nearest = id
			reach = distance
	if nearest >= 0:
		world.selected_target = nearest
		if world.sling_cooldown <= 0.0:
			world._use_skill(world.SKILL_SLING)
		elif world.shoo_cooldown <= 0.0:
			world._use_skill(world.SKILL_SHOO)
		elif world.slow_cooldown <= 0.0:
			world._use_skill(world.SKILL_SLOW)
	if _hunt and _enemy >= 0 and world._animals[_enemy]["alive"]:
		var animal: Dictionary = world._animals[_enemy]
		world.selected_target = _enemy
		if not world.pets.hindered(animal):
			if world.sling_cooldown <= 0.0:
				world._use_skill(world.SKILL_SLING)
			elif world.slow_cooldown <= 0.0:
				world._use_skill(world.SKILL_SLOW)
		# Stand close enough for the companion to hunt, without bumping prey.
		if world.player_position.distance_to(animal["position"]) < 190.0 and world.pets._clear_floor(world.absolute_ground(world.player_position), world.absolute_ground(animal["position"])):
			return Vector2.ZERO
	return _toward(_goal)


func _choose_goal() -> void:
	var cave: Node3D = world._cave
	var here: Vector2 = world.to_ground(world.player_position)
	var flow: Dictionary = cave.distances_to(cave.cell_at(here))
	var taken: Array = world._cave_progress[world._cave_key]["checkpoints" if world._cave_depth == 1 else "deep"]
	var best := INF
	_hunt = false
	_goal = cave.entrance
	for i in cave.checkpoints.size():
		var steps: float = flow.get(cave.cell_at(cave.checkpoints[i]), INF)
		if i not in taken and steps < best:
			best = steps
			_goal = cave.checkpoints[i]
	completed = taken.size() == cave.checkpoints.size()
	# Prefer completing the level with a healthy companion once exploration
	# has collected its checkpoints. Without one, simply walk back outside.
	var can_hunt := false
	for pet in world.pets.followers():
		can_hunt = can_hunt or not world.pets.afflicted(pet)
	var living := 0
	_enemy = -1
	var nearest := INF
	for id in world._animals.size():
		var animal: Dictionary = world._animals[id]
		if not animal["alive"] or animal["kind"] not in world.MONSTERS:
			continue
		living += 1
		var allowed := false
		for pet in world.pets.followers():
			allowed = allowed or (not world.pets.afflicted(pet) and world.pets.can_kill(pet, animal["kind"]))
		var steps: float = flow.get(cave.cell_at(world.to_ground(animal["position"])), INF)
		if allowed and steps < nearest:
			nearest = steps
			_enemy = id
	cleared = completed and living == 0
	if can_hunt and _enemy >= 0 and (completed or nearest <= 3.0):
		_hunt = true
		_goal = world.to_ground(world._animals[_enemy]["position"])
		activity = "Helping her companion clear the cave"
	elif completed:
		activity = "Cave explored — finding the way back to the woods"
		if not world._cave_exit_armed:
			# Revisiting a completed cave still starts with its exit disarmed.
			# Step into the level before returning, just as a player must.
			var entrance_flow: Dictionary = cave.distances_to(cave.cell_at(cave.entrance))
			var closest := INF
			for cell in entrance_flow:
				var point: Vector2 = cave.cell_center(cell)
				var distance: float = here.distance_squared_to(point)
				if point.distance_to(cave.entrance) > 3.2 and distance < closest:
					closest = distance
					_goal = point
	else:
		activity = "Exploring the cave and collecting aura checkpoints"


func _toward(target: Vector2) -> Vector2:
	var cave: Node3D = world._cave
	var here: Vector2 = world.to_ground(world.player_position)
	var target_cell: Vector2i = cave.cell_at(target)
	if not _route.is_empty() and here.distance_to(_route[0]) > 3.0:
		_route.clear()
	if target_cell != _goal_cell or _route.is_empty():
		_goal_cell = target_cell
		_route.clear()
		var flow := _distances(target_cell)
		var cell: Vector2i = cave.cell_at(here)
		# Centre in the current floor cell before turning through a narrow
		# corner; never cut diagonally through a cave wall.
		if here.distance_to(cave.cell_center(cell)) > 0.2:
			_route.append(cave.cell_center(cell))
		for step_count in cave.open.size():
			var steps: int = flow.get(cell, 0)
			if steps <= 0:
				break
			for offset in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
				if flow.get(cell + offset, -1) == steps - 1:
					cell += offset
					_route.append(cave.cell_center(cell))
					break
	while not _route.is_empty() and here.distance_to(_route[0]) < 0.2:
		_route.remove_at(0)
	var aim := target if _route.is_empty() else _route[0]
	return here.direction_to(aim)


func _distances(goal: Vector2i) -> Dictionary:
	var cave: Node3D = world._cave
	var stairs: Vector2i = cave.cell_at(cave.way_down) if world._cave_depth == 1 else Vector2i(-1, -1)
	if goal == stairs:
		for step in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
			if cave.open.has(goal + step):
				goal += step
				break
	var flow := {goal: 0}
	var frontier: Array[Vector2i] = [goal]
	var head := 0
	while head < frontier.size():
		var cell := frontier[head]
		head += 1
		for step in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
			var next: Vector2i = cell + step
			if next != stairs and cave.open.has(next) and not flow.has(next):
				flow[next] = int(flow[cell]) + 1
				frontier.append(next)
	return flow
