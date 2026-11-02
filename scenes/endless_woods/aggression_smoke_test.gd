extends SceneTree

## Lingering near a wolf, lynx or boar can provoke a bounded, stun-only charge (#20).


func _initialize() -> void:
	call_deferred("_run")


func _rolls_for(world, id: int, success: bool) -> int:
	for rolls in 200:
		if (world._hash(id, rolls + 1, 1701) < world.AGGRO_CHANCE) == success:
			return rolls
	return -1


func _reset(world, id: int, offset: Vector2) -> void:
	var data: Dictionary = world._animals[id]
	data["position"] = world.player_position + offset
	data["velocity"] = Vector2.ZERO
	data["stun"] = 0.0
	data["shoo"] = 0.0
	data["feeding"] = 0.0
	data["provoke"] = 0.0
	data["grudge"] = false
	data["aggro"] = world.AGGRO_NONE
	data["aggro_time"] = 0.0
	data["aggro_cooldown"] = 0.0
	data["state"] = "idle"
	world.player_stun = 0.0


func _dwell(world, id: int, seconds: float, offset: Vector2) -> void:
	# Hold the animal where Oravitsa lingers beside it.
	var t := 0.0
	while t < seconds:
		world._animals[id]["position"] = world.player_position + offset
		world._update_aggression(1.0 / 30.0)
		t += 1.0 / 30.0


func _run() -> void:
	var world = load("res://scenes/endless_woods/woods.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	world.fright_chance = 0.0 # Panic has its own check below.
	await process_frame
	for sprite in world._active_animals.values():
		sprite.queue_free()
	world._active_animals.clear()
	world._sync_animal_lifecycle()
	world._animals.clear()
	for kind in [world.WOLF, world.HARE, world.BOAR, world.LYNX]:
		world._add_animal(kind, world.START + Vector2i(4, 0))
	world._animals[1]["position"] = world.player_position + Vector2(0, 1800)
	world._animals[2]["position"] = world.player_position + Vector2(-1800, 0)
	world._animals[3]["position"] = world.player_position + Vector2(1800, 0)
	world._refresh_visible()
	world._sync_presentation(0.0)
	var wolf: Dictionary = world._animals[0]
	var near := Vector2(180, 0)
	# Approach: no aggression before the dwell time.
	_reset(world, 0, near)
	wolf["aggro_rolls"] = _rolls_for(world, 0, true)
	_dwell(world, 0, world.AGGRO_DWELL - 0.3, near)
	assert(wolf["aggro"] == world.AGGRO_NONE and wolf["provoke"] > 2.0)
	# Retreat: provocation decays when Oravitsa backs off.
	_dwell(world, 0, 1.5, Vector2(world.AGGRO_RADIUS + 50, 0))
	assert(wolf["provoke"] == 0.0 and wolf["aggro"] == world.AGGRO_NONE)
	# A failed chance leaves it calm and waits before rolling again.
	wolf["aggro_rolls"] = _rolls_for(world, 0, false)
	_dwell(world, 0, world.AGGRO_DWELL + 0.1, near)
	assert(wolf["aggro"] == world.AGGRO_NONE and wolf["aggro_cooldown"] > world.AGGRO_RETRY - 0.2)
	_dwell(world, 0, world.AGGRO_DWELL + 0.1, near)
	assert(wolf["aggro"] == world.AGGRO_NONE, "No re-roll during the retry delay")
	# Success: a visible warning, then a charge that physically reaches her.
	_reset(world, 0, near)
	wolf["aggro_rolls"] = _rolls_for(world, 0, true)
	_dwell(world, 0, world.AGGRO_DWELL + 0.05, near)
	assert(wolf["aggro"] == world.AGGRO_WARN)
	assert(world._notice_label.text.contains("angry"))
	world._sync_presentation(0.0)
	assert(world._animal_stars[0].visible and world._animal_stars[0].icons == ["angry"])
	var warn_left: float = world._animal_stars[0].fractions[0]
	assert(warn_left > 0.9, "The warning shows a nearly full time-left bar")
	var standing: Vector2 = wolf["position"]
	world._move_animals(0.5)
	assert(wolf["position"] == standing and wolf["state"] == "warn", "The warning is a pause, not an attack")
	world._sync_presentation(0.0)
	assert(absf(world._animal_stars[0].fractions[0] - wolf["aggro_time"] / world.AGGRO_WARN_TIME) < 0.001 and world._animal_stars[0].fractions[0] < warn_left - 0.3, "The warning bar empties")
	# Place a hare between them: charging overrides hunting.
	world._animals[1]["position"] = wolf["position"] + Vector2(0, 120)
	world._refresh_visible()
	var hit := false
	var charge_bars: Array[float] = []
	for frame in 240:
		world._move_animals(1.0 / 30.0)
		assert(world._can_stand(wolf["position"], world.ANIMAL_RADIUS[world.WOLF]))
		if wolf["state"] == "charge":
			world._sync_presentation(0.0)
			assert(world._animal_stars[0].icons == ["charging"])
			var left: float = world._animal_stars[0].fractions[0]
			assert(absf(left - wolf["aggro_time"] / world.AGGRO_CHARGE_TIME) < 0.001, "The charge bar shows the charge time left")
			assert(charge_bars.is_empty() or left < charge_bars[-1], "The charge bar empties")
			charge_bars.append(left)
		if world.player_stun > 0:
			hit = true
			break
	assert(hit and is_equal_approx(world.player_stun, world._player_stun_time(world.AGGRO_PLAYER_STUN)), "A charge that reaches Oravitsa stuns her")
	assert(charge_bars.size() >= 2 and world._animal_stars[0].visible)
	assert(world._animals[1]["alive"], "A charging wolf ignores prey")
	assert(wolf["aggro"] == world.AGGRO_NONE and wolf["aggro_cooldown"] >= world.AGGRO_COOLDOWN - 0.1, "It loses interest after the attack")
	assert(world.player_stun < world.SLING_STUN_TIME + world.AGGRO_PLAYER_STUN)
	# No immediate repeat even while she stays beside it.
	world.player_stun = 0.0
	_dwell(world, 0, world.AGGRO_DWELL * 2, Vector2(70, 0))
	assert(wolf["aggro"] == world.AGGRO_NONE and world.player_stun == 0.0, "No repeated stun during the cooldown")
	# Miss: the charge ends when Oravitsa stays out of reach for its duration.
	_reset(world, 0, near)
	wolf["aggro"] = world.AGGRO_CHARGE
	wolf["aggro_time"] = world.AGGRO_CHARGE_TIME
	var t := 0.0
	while t < world.AGGRO_CHARGE_TIME + 0.2:
		wolf["position"] = world.player_position + near
		world._update_aggression(0.1)
		t += 0.1
	assert(wolf["aggro"] == world.AGGRO_NONE and world.player_stun == 0.0 and wolf["aggro_cooldown"] >= world.AGGRO_COOLDOWN - 0.5)
	# Interruption: Shoo or a stun ends the encounter immediately.
	_reset(world, 0, near)
	wolf["aggro"] = world.AGGRO_CHARGE
	wolf["aggro_time"] = world.AGGRO_CHARGE_TIME
	world.selected_target = 0
	world._use_skill(0)
	world._move_animals(1.0 / 30.0)
	assert(wolf["aggro"] == world.AGGRO_NONE and wolf["state"] == "scared" and world.player_stun == 0.0)
	world.shoo_cooldown = 0.0
	_reset(world, 0, near)
	wolf["aggro"] = world.AGGRO_WARN
	wolf["aggro_time"] = world.AGGRO_WARN_TIME
	world.sling_cooldown = 0.0
	world._use_skill(1)
	world._update_sling(1.0)
	world._move_animals(1.0 / 30.0)
	assert(wolf["stun"] > 0 and wolf["aggro"] == world.AGGRO_NONE)
	# A sling hit leaves a grudge (#63): no attack while it is stunned, even if
	# hit again, then a warning and a charge as soon as the stun ends, ignoring
	# dwell, chance and cooldown. Shoo settles it; far away it is forgotten.
	# Protects: predators shrugging off a sling hit, attacking while stunned,
	# and grudges that Shoo cannot stop or that reach across the woods.
	for case in ["grudge", "shoo", "far"]:
		_reset(world, 0, Vector2(300, 0))
		wolf["aggro_cooldown"] = world.AGGRO_COOLDOWN
		wolf["aggro_rolls"] = _rolls_for(world, 0, false)
		world.selected_target = 0
		world.sling_cooldown = 0.0
		world._use_skill(world.SKILL_SLING)
		world._update_sling(1.0)
		assert(wolf["stun"] > 0.0 and wolf["grudge"], "A sling hit leaves a grudge")
		var frames := 0
		while wolf["stun"] > 0.0:
			if frames == 20:
				world.sling_cooldown = 0.0
				world._use_skill(world.SKILL_SLING)
				world._update_sling(1.0) # Hit again while still stunned.
			if frames == 25 and case == "shoo":
				world.shoo_cooldown = 0.0
				world._use_skill(world.SKILL_SHOO)
				world._update_aggression(1.0 / 30.0)
				wolf["shoo"] = 0.0 # Its fear runs out sooner than in play.
			if frames == 25 and case == "far":
				wolf["position"] = world.player_position + Vector2(world.GRUDGE_RADIUS + 50, 0)
			wolf["stun"] = maxf(0.0, wolf["stun"] - 1.0 / 30.0)
			world._update_aggression(1.0 / 30.0)
			if wolf["stun"] > 0.0:
				assert(wolf["aggro"] == world.AGGRO_NONE and world.player_stun == 0.0, "No attack while it is stunned")
			frames += 1
		world._update_aggression(1.0 / 30.0)
		if case == "grudge":
			assert(wolf["aggro"] == world.AGGRO_WARN, "It warns as soon as its stun ends")
			assert(wolf["aggro_time"] > world.AGGRO_WARN_TIME - 0.1, "with the full warning to react")
			for frame in 40:
				world._update_aggression(1.0 / 30.0)
			assert(wolf["aggro"] == world.AGGRO_CHARGE, "then charges")
		else:
			assert(wolf["aggro"] == world.AGGRO_NONE and not wolf["grudge"], "Shoo or distance settles the grudge (%s)" % case)
		world._end_aggression(0, 0.0)
	world.shoo_cooldown = 0.0
	world.sling_cooldown = 0.0
	# Boars and lynxes can be provoked; hares never are.
	for id in [2, 3]:
		_reset(world, id, Vector2(-150, 60))
		world._refresh_visible()
		assert(world._active_animals.has(id))
		world._animals[id]["aggro_rolls"] = _rolls_for(world, id, true)
		_dwell(world, id, world.AGGRO_DWELL + 0.05, Vector2(-150, 60))
		assert(world._animals[id]["aggro"] == world.AGGRO_WARN)
		world._end_aggression(id, world.AGGRO_COOLDOWN)
		world._animals[id]["position"] = world.player_position + Vector2(0, 2500 + id * 100)
	# A boar actually eating a food patch (#48) is feeding too: lingering can't
	# provoke it, even after nearly enough dwell, and its meal goes on.
	var cell: Vector2i = world._forage_visuals.keys()[0]
	world.objects[world._index(cell)] = world.BERRIES
	_reset(world, 2, Vector2.ZERO)
	world._animals[2]["position"] = world._cell_center(cell)
	world._animals[2]["target"] = world._cell_center(cell)
	world._animals[2]["food_cell"] = cell
	world.player_position = world._cell_center(cell) + near
	world._refresh_visible()
	assert(world._active_animals.has(2))
	world._animals[2]["provoke"] = world.AGGRO_DWELL - 0.2
	world._animals[2]["aggro_rolls"] = _rolls_for(world, 2, true)
	world._move_animals(0.3)
	assert(world._animals[2]["state"] == "forage" and world._animals[2]["eat_time"] > 0, "The boar must really be eating")
	world._move_animals(0.1)
	assert(world._animals[2]["aggro"] == world.AGGRO_NONE and world._animals[2]["state"] == "forage", "An eating boar must not turn angry")
	assert(world._animals[2]["eat_time"] > 0.3, "The meal goes on")
	world._animals[2]["position"] = world.player_position + Vector2(0, 2700)
	_reset(world, 1, near)
	_dwell(world, 1, 10.0, near)
	assert(world._animals[1]["aggro"] == world.AGGRO_NONE and world._animals[1]["provoke"] == 0.0)
	assert(world._charge_speed(world.BOAR) < world.SPEED, "Oravitsa can outrun a charging boar")
	# A charge can scare her instead: she runs from it, and it still ends.
	world.fright_chance = 1.0
	_reset(world, 0, Vector2(40, 0))
	world._refresh_visible()
	assert(world._active_animals.has(0))
	wolf["aggro"] = world.AGGRO_CHARGE
	wolf["aggro_time"] = world.AGGRO_CHARGE_TIME
	world._update_aggression(1.0 / 30.0)
	assert(world.player_fright > 0.0 and world.player_stun == 0.0 and not world._fright_to_exit, "A charge can panic her")
	assert(wolf["aggro"] == world.AGGRO_NONE and wolf["aggro_cooldown"] >= world.AGGRO_COOLDOWN - 0.5, "The attack is over either way")
	var gap: float = wolf["position"].distance_to(world.player_position)
	for frame in 15:
		world._update_player(1.0 / 30.0)
		assert(world._can_stand(world.player_position, world.PLAYER_RADIUS), "Panic stays on open ground")
	assert(wolf["position"].distance_to(world.player_position) > gap + 30.0, "She runs from what hit her")
	world.player_fright = 0.0
	# Walking into an animal can scare her too; the animal is still stunned.
	_reset(world, 1, Vector2(50, 0))
	world._refresh_visible()
	assert(world._active_animals.has(1))
	assert(not world._try_move(Vector2(10, 0)) and world.player_fright > 0.0 and world.player_stun == 0.0, "A bump can panic her")
	assert(world._animals[1]["stun"] > 0.0, "What she bumped is still stunned")
	world.player_fright = 0.0
	world.fright_chance = 0.0
	print("Aggression smoke test passed: dwell approach/retreat, failed chance retry delay, warning pause, collision-safe charge, hit stun, hunting override, disengagement cooldown, miss timeout, Shoo/stun interruption, no provocation while eating, sling grudges that charge once the stun ends (not while stunned, not after Shoo or far away), three species only, and charges and bumps that panic her instead")
	quit()
