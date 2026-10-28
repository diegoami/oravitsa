extends SceneTree

## Occasional nonlethal fights between wolves, lynxes and boars (#25).


func _initialize() -> void:
	call_deferred("_run")


func _calm(world, id: int, at: Vector2) -> void:
	var data: Dictionary = world._animals[id]
	data["position"] = at
	data["velocity"] = Vector2.ZERO
	for field in ["stun", "shoo", "feeding", "fight_time", "fight_cooldown", "aggro_cooldown", "provoke"]:
		data[field] = 0.0
	data["fight_with"] = -1
	data["aggro"] = world.AGGRO_NONE
	data["state"] = "idle"
	data["catch_target"] = -1


func _until_fight(world, a: int, b: int, seconds: float) -> bool:
	var t := 0.0
	while t < seconds:
		world._update_fights(0.25)
		t += 0.25
		if world._animals[a]["fight_with"] == b:
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
	for kind in [world.WOLF, world.BOAR, world.WOLF, world.HARE, world.LYNX]:
		world._add_animal(kind, world.START + Vector2i(4, 0))
	var here: Vector2 = world.player_position + Vector2(0, 500)
	for id in 5:
		_calm(world, id, world.player_position + Vector2(-1200 + id * 600, -400))
	world._refresh_visible()
	# Same-species and non-eligible pairs never fight.
	_calm(world, 0, here)
	_calm(world, 2, here + Vector2(70, 0))
	_calm(world, 3, here + Vector2(0, 70))
	world._refresh_visible()
	assert(not _until_fight(world, 0, 2, 120.0) and world._animals[0]["fight_with"] == -1, "Wolves do not fight wolves")
	assert(world._animals[3]["fight_with"] == -1, "Hares never fight")
	_calm(world, 2, world.player_position + Vector2(-1500, 600))
	_calm(world, 3, world.player_position + Vector2(1500, 600))
	# A calm wolf and boar nearby eventually fight; it is not immediate.
	_calm(world, 1, here + Vector2(90, 0))
	world._refresh_visible()
	assert(world._active_animals.has(0) and world._active_animals.has(1))
	world._update_fights(world.FIGHT_CHECK * 0.5)
	assert(world._animals[0]["fight_with"] == -1)
	assert(_until_fight(world, 0, 1, 120.0), "A wolf and boar side by side must eventually fight")
	assert(world._animals[1]["fight_with"] == 0 and world._is_fighting(0) and world._is_fighting(1))
	# Fighting animals hold position, show a marker and ignore Oravitsa.
	var a_position: Vector2 = world._animals[0]["position"]
	world._move_animals(0.5)
	assert(world._animals[0]["position"] == a_position and world._animals[0]["state"] == "fight")
	world._sync_presentation(0.0)
	assert(world._animal_stars[0].visible and "FIGHTING" in world._animal_stars[0].text)
	# Resolution: one loser is stunned, both return to ordinary behaviour.
	for step in 120:
		world._move_animals(0.05)
		if not world._is_fighting(0):
			break
	var loser := 0 if world._animals[0]["stun"] > 0 else 1
	var winner := 1 - loser
	assert(world._animals[loser]["stun"] > world.FIGHT_LOSER_STUN - 1.0 and world._animals[winner]["stun"] == 0)
	assert(world._animals[0]["alive"] and world._animals[1]["alive"], "Fights are nonlethal")
	assert(not world._is_fighting(0) and not world._is_fighting(1))
	assert(world._animals[winner]["state"] != "fight")
	world._sync_presentation(0.0)
	assert("STUNNED" in world._animal_stars[loser].text)
	# Cooldown: they do not immediately fight again (no stun-lock).
	assert(world._animals[0]["fight_cooldown"] > 40 and world._animals[1]["fight_cooldown"] > 40)
	world._animals[loser]["stun"] = 0.0
	_calm(world, 0, here)
	_calm(world, 1, here + Vector2(90, 0))
	world._animals[0]["fight_cooldown"] = world.FIGHT_COOLDOWN
	world._animals[1]["fight_cooldown"] = world.FIGHT_COOLDOWN
	assert(not _until_fight(world, 0, 1, world.FIGHT_COOLDOWN - 2.0), "No new fight during the cooldown")
	# Already stunned, scared, feeding, hunting or provoked animals never start one.
	_calm(world, 0, here)
	_calm(world, 4, here + Vector2(80, 0))
	_calm(world, 1, world.player_position + Vector2(-1500, -600))
	world._refresh_visible()
	for blocker in ["stun", "shoo", "feeding", "hunt", "aggro"]:
		_calm(world, 0, here)
		_calm(world, 4, here + Vector2(80, 0))
		if blocker == "hunt":
			world._animals[4]["state"] = "hunt"
		elif blocker == "aggro":
			world._animals[4]["aggro"] = world.AGGRO_WARN
		else:
			world._animals[4][blocker] = 999.0
		assert(not world._can_start_fight(4) and not _until_fight(world, 0, 4, 60.0), "No fight while " + blocker)
	# Interruption: Shoo or Sling ends a fight for both with no winner.
	for interrupt in ["shoo", "sling"]:
		_calm(world, 0, here)
		_calm(world, 4, here + Vector2(80, 0))
		assert(_until_fight(world, 0, 4, 200.0))
		world.selected_target = 4
		world.shoo_cooldown = 0.0
		world.sling_cooldown = 0.0
		world.player_position = here + Vector2(0, 300)
		if interrupt == "shoo":
			world._use_skill(0)
		else:
			world._use_skill(1)
			world._update_sling(1.0)
		world._move_animals(1.0 / 30.0)
		assert(not world._is_fighting(0) and not world._is_fighting(4), interrupt + " must end the fight")
		assert(world._animals[0]["stun"] == 0, "An interrupted fight has no loser")
		assert(world._animals[0]["fight_cooldown"] > 0)
	# Leaving the active area also ends a fight.
	_calm(world, 0, here)
	_calm(world, 4, here + Vector2(80, 0))
	world._animals[4]["stun"] = 0.0
	assert(_until_fight(world, 0, 4, 200.0))
	world._active_animals[4].queue_free()
	world._active_animals.erase(4)
	world._update_fights(0.1)
	assert(not world._is_fighting(0) and not world._is_fighting(4))
	# A boar actually eating a food patch (#30) is feeding too: no fight starts.
	var cell: Vector2i = world._forage_visuals.keys()[0]
	world.objects[world._index(cell)] = world.BERRIES
	_calm(world, 1, world._cell_center(cell))
	world._animals[1]["target"] = world._cell_center(cell)
	world._animals[1]["food_cell"] = cell
	_calm(world, 0, world._cell_center(cell) + Vector2(90, 0))
	world.player_position = world._cell_center(cell) + Vector2(0, 2000)
	world._refresh_visible()
	for id in [0, 1]:
		if not world._active_animals.has(id):
			world._active_animals[id] = world._make_animal_sprite(id)
	world._move_animals(0.3)
	assert(world._animals[1]["state"] == "forage" and world._animals[1]["eat_time"] > 0, "The boar must really be eating")
	assert(not world._can_start_fight(1), "An eating boar must not start a fight")
	assert(not _until_fight(world, 0, 1, 0.25 * 3), "No fight interrupts the meal")
	print("Fight smoke test passed: cross-species only, occasional start, in-place standoff with marker, nonlethal stunned loser, cooldown, no start while stunned/scared/feeding/hunting/provoked, Shoo/Sling/deactivation interruption")
	quit()
