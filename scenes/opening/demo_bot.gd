extends RefCounted

## A bounded, local player bot. Goals and routes are absolute metres, so
## streaming/rebasing cannot change what she is walking toward.
var world: Node2D
var direction := Vector2.ZERO
var activity := "Looking for woodland food"
var goal := Vector2.INF
var food_cell := Vector2i(1 << 28, 1 << 28)
var route := PackedVector2Array()
var elapsed := 0.0
var goal_age := 0.0
var stuck := 0.0
var replan := 0.0
var previous := Vector2.ZERO
var ignored := {} # Absolute food cells -> expiry, bounded by local searches.
var heading := 0.0
var distance_walked := 0.0
var foods_collected := 0
var reactions := 0
var hares_collected := 0
var goal_kind := "food"
var goals_chosen := 0
var hare := -1
var gift_wait := 0.0
var visited := {}
var progress_origin := Vector2.ZERO
var progress_time := 0.0
var recoveries := 0
var gifts_given := 0
var mushrooms_collected := 0
var caves_explored := 0
var caves_cleared := 0
var companions_adopted := 0
var villages_visited := 0
var _village_dwell := 0.0
var _last_hunt := -30.0
var _last_village := -120.0
var _last_cave := -120.0
var cave_bot: RefCounted
var _adopt_target: Dictionary = {}
var _village_center := Vector2.INF


func _init(forest: Node2D) -> void:
	world = forest
	previous = world.absolute_ground(world.player_position)
	progress_origin = previous
	cave_bot = preload("res://scenes/opening/demo_cave_bot.gd").new(world)


func update(delta: float) -> void:
	elapsed += delta
	goal_age += delta
	replan -= delta
	gift_wait -= delta
	var at: Vector2 = world.absolute_ground(world.player_position)
	var moved := at.distance_to(previous)
	distance_walked += moved
	# Net displacement catches oscillation as well as a motionless bot. Tiny
	# alternating steps must not keep resetting the obstruction timer.
	progress_time += delta
	if progress_time >= 1.0:
		stuck = stuck + progress_time if at.distance_to(progress_origin) < 0.6 else 0.0
		progress_origin = at
		progress_time = 0.0
	previous = at
	if world.in_cave():
		direction = cave_bot.update(delta)
		activity = cave_bot.activity
		return
	if cave_bot.was_underground:
		cave_bot.was_underground = false
		caves_explored += int(cave_bot.completed)
		caves_cleared += int(cave_bot.cleared)
		_last_cave = elapsed
		goal = Vector2.INF
		route.clear()
		progress_origin = at
		stuck = 0.0
	world._use_skill(world.SKILL_CURE)
	if world.player_stun > 0.0 or world.player_fright > 0.0:
		world._use_skill(world.SKILL_CURE)
		activity = "Shaking off a fright"
		direction = Vector2.ZERO
		return
	if stuck >= 2.0:
		_escape(at)
	# Threats have priority, but only real, nearby wildlife is ever shooed.
	var threat: int = world._nearest_animal(world.player_position, world.AGGRO_KINDS, -1, 340.0)
	if threat >= 0:
		var animal: Dictionary = world._animals[threat]
		if animal["stun"] <= 0.0 and animal["shoo"] <= 0.0:
			world.selected_target = threat
			var before: float = world.shoo_cooldown
			world._use_skill(world.SKILL_SHOO)
			if world.shoo_cooldown > before:
				reactions += 1
			activity = "Giving wildlife some space"
			direction = _safe_heading(world.absolute_ground(animal["position"]).direction_to(at))
			return
	if world._offer_ready() and gift_wait <= 0.0:
		world._offer_food()
		gifts_given += 1
		gift_wait = 1.5
		activity = "Sharing food with the village chieftain"
	var pet: Dictionary = world.pets.nearest()
	if world.pets.prompt(pet) == "join" and world.player_stun <= 0.0:
		world.pets.toggle()
		companions_adopted += 1
		_adopt_target = {}
		goal = Vector2.INF
	if goal_kind == "pet" and not _adopt_target.is_empty():
		goal = _adopt_target["at"]
	if goal_kind == "hamlet" and world._offer_chief() >= 0 and _village_dwell < 5.0:
		if _village_dwell == 0.0:
			villages_visited += 1
		_village_dwell += delta
		activity = "Visiting the village and sharing gathered food"
		stuck = 0.0
		progress_origin = at
		direction = Vector2.ZERO
		if _village_dwell >= 5.0:
			goal = Vector2.INF
		return
	if goal_kind == "hare" and hare >= 0 and world._animals[hare]["alive"]:
		goal = world.absolute_ground(world._animals[hare]["position"])
		world.selected_target = hare
		if world._animals[hare]["stun"] <= 0.0:
			world._use_skill(world.SKILL_SLING)
	if goal_kind == "hamlet" and at.distance_to(goal) < 20.0:
		for id in world._active_animals:
			if world._animals[id].get("chief", false) and world.absolute_ground(world._animals[id]["position"]).distance_to(_village_center) < 15.0:
				goal = world.absolute_ground(world._animals[id]["position"])
	var local_cell: Vector2i = food_cell - world.origin_cells + world.START
	var empty: bool = goal_kind == "food" and food_cell.x != 1 << 28 and world.objects[world._index(local_cell)] not in [world.MUSHROOM, world.BERRIES]
	var lost_hare: bool = goal_kind == "hare" and (hare < 0 or not world._animals[hare]["alive"])
	var limit := 12.0 if goal_kind == "hare" else (150.0 if goal_kind in ["hamlet", "cave"] else 16.0)
	if goal == Vector2.INF or at.distance_to(goal) < 0.45 or empty or lost_hare or goal_age > limit or stuck > 2.5:
		if goal != Vector2.INF and (stuck > 2.5 or goal_age > limit):
			ignored[food_cell] = elapsed + 25.0
		_choose_goal(at)
	while not route.is_empty() and at.distance_to(route[0]) < 0.3:
		route.remove_at(0)
	if replan <= 0.0 and (route.is_empty() or stuck > 0.4):
		route = world.plan_detour(at, goal, world.PLAYER_RADIUS / world.METRE + 0.1)
		replan = 1.2
	var aim := goal if route.is_empty() else route[0]
	direction = _safe_heading(at.direction_to(aim))


func _choose_goal(at: Vector2) -> void:
	for cell in ignored.keys():
		if ignored[cell] <= elapsed:
			ignored.erase(cell)
	for point in visited.keys():
		if visited[point] <= elapsed:
			visited.erase(point)
	goal_age = 0.0
	stuck = 0.0
	route.clear()
	replan = 0.0
	food_cell = Vector2i(1 << 28, 1 << 28)
	goals_chosen += 1
	hare = -1
	var food_stock: int = world.basket + world.berries_basket + world.raw_meat
	# Needs and opportunities drive the next decision. No staged loadout,
	# fixed tour, timer reset or special access requirement for cave entry.
	if food_stock >= 2 and elapsed - _last_hunt > 25.0 and world.raw_meat < 3:
		hare = world._nearest_animal(world.player_position, [world.HARE], -1, 550.0)
		if hare >= 0:
			goal_kind = "hare"
			goal = world.absolute_ground(world._animals[hare]["position"])
			activity = "Stunning and collecting a hare"
			_last_hunt = elapsed
			return
	if world.pets.followers().size() < world.pets.MAX_FOLLOWERS:
		var nearest := 100.0
		_adopt_target = {}
		for pet in world.pets.pets:
			var distance: float = at.distance_to(pet["at"])
			if pet["state"] != "following" and world.pets.allowed(pet) and distance < nearest:
				nearest = distance
				_adopt_target = pet
		if not _adopt_target.is_empty():
			goal_kind = "pet"
			goal = _adopt_target["at"]
			activity = "Meeting a village " + world.pets.title(_adopt_target)
			return
	if food_stock >= 12 or (world.fed >= 65.0 and food_stock >= 6):
		var sign := _signpost_near(at)
		var interest := -INF
		var destination := ""
		for arm in sign.get("arms", []):
			if visited.has(arm["target"]):
				continue
			var last: float = _last_cave if arm["kind"] == "cave" else _last_village
			var score: float = minf(300.0, elapsed - last) / 300.0 + 50.0 / (50.0 + float(arm["distance"]))
			if score > interest:
				interest = score
				destination = arm["kind"]
		if destination != "" and seek_landmark(destination, at):
			return
	goal_kind = "food"
	var center: Vector2i = world._world_cell(world.player_position)
	var best := INF
	for y in range(-9, 10):
		for x in range(-9, 10):
			var cell := center + Vector2i(x, y)
			var absolute_cell: Vector2i = cell - world.START + world.origin_cells
			if ignored.has(absolute_cell) or world.objects[world._index(cell)] not in [world.MUSHROOM, world.BERRIES]:
				continue
			var point: Vector2 = world._cell_center(cell)
			var distance: float = world.player_position.distance_squared_to(point) * (0.45 if world.objects[world._index(cell)] == world.MUSHROOM else 1.0)
			if distance < best and world._can_stand(point):
				best = distance
				goal = world.absolute_ground(point)
				food_cell = absolute_cell
	if best < INF:
		activity = "Gathering mushrooms and berries"
		return
	activity = "Exploring the woodland"
	goal_kind = "roam"
	# Keep a bearing out of bare village clearings instead of circling within
	# their food-free radius. Recovery may turn it when the route is blocked.
	goal = at + Vector2.from_angle(heading) * 24.0


func _signpost_near(at: Vector2) -> Dictionary:
	# Match the landscape's road-grid inverse, including road_x's +70 m.
	return world.landscape.signpost_at(roundi((at.x - 70.0) / 256.0), roundi((at.y - 5.0) / 128.0))


func seek_landmark(kind: String, at: Vector2) -> bool:
	# The same seeded destinations used by signposts: real villages/caves,
	# never invented points of interest. Lookups and routes stay bounded.
	var sign := _signpost_near(at)
	for arm in sign.get("arms", []):
		if arm["kind"] != kind or float(visited.get(arm["target"], 0.0)) > elapsed:
			continue
		goal_kind = kind
		goal = arm["target"]
		visited[goal] = elapsed + 600.0
		if kind == "hamlet":
			_last_village = elapsed
			_village_dwell = 0.0
			_village_center = goal
		else:
			_last_cave = elapsed
		activity = ("Visiting " if kind == "hamlet" else "Looking for the cave mouth at ") + arm["name"]
		goal_age = 0.0
		route.clear()
		replan = 0.0
		return true
	return false


func _escape(at: Vector2) -> void:
	if goal_kind == "food":
		ignored[food_cell] = elapsed + 30.0
	# Commit to a reachable short escape instead of choosing the same nearest
	# food or reversing direction every frame. Ordinary collision still owns
	# each step; this never teleports the heroine.
	for attempt in 12:
		var candidate := at + Vector2.from_angle(heading + attempt * TAU / 12.0) * 3.0
		var path: PackedVector2Array = world.plan_detour(at, candidate, world.PLAYER_RADIUS / world.METRE)
		if path.is_empty() or path[path.size() - 1].distance_to(candidate) > 0.75:
			continue
		goal = candidate
		goal_kind = "roam"
		food_cell = Vector2i(1 << 28, 1 << 28)
		route = path
		replan = 1.2
		goal_age = 0.0
		stuck = 0.0
		heading += 1.3
		recoveries += 1
		activity = "Finding a clear path around an obstacle"
		return


func _safe_heading(wanted: Vector2) -> Vector2:
	var best := -INF
	var result := Vector2.ZERO
	for turn in [0.0, 0.4, -0.4, 0.8, -0.8, 1.2, -1.2, 1.8, -1.8, PI]:
		var candidate := wanted.rotated(turn)
		var clear := true
		for ahead in [8.0, 16.0, 28.0]:
			if not world._can_stand(world.player_position + candidate * ahead):
				clear = false
				break
		if not clear:
			continue
		var score := candidate.dot(wanted)
		for id in world._active_animals:
			var animal: Dictionary = world._animals[id]
			if not animal["alive"] or animal["stun"] > 0.0 or animal["kind"] == world.VILLAGER:
				continue
			var next: Vector2 = world.player_position + candidate * 70.0
			var distance: float = next.distance_to(animal["position"])
			if distance < 100.0:
				score -= (100.0 - distance) / 20.0
		if score > best:
			best = score
			result = candidate
	return result
