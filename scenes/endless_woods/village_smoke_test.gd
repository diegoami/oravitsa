extends SceneTree

## Aura (#42), feeding (#43), hamlet villagers, chieftains and food gifts (#44).


func _initialize() -> void:
	call_deferred("_run")


func _travel(world: Node2D, absolute: Vector2) -> void:
	world.player_position = world.from_ground(absolute - world.landscape.origin)
	world._rebase_if_needed()
	world.view.position = world.to_world(world.player_position) + world.CAMERA_OFFSET
	world._refresh_visible()
	world._sync_presentation(0.0)
	await process_frame


func _villagers(world: Node2D) -> Array[int]:
	var ids: Array[int] = []
	for id in world._animals.size():
		if world._animals[id]["kind"] == world.VILLAGER and world._animals[id]["alive"]:
			ids.append(id)
	return ids


func _run() -> void:
	var world = load("res://scenes/endless_woods/woods.tscn").instantiate()
	world.save_path = "user://village_smoke_save.json"
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	await process_frame
	var land: Node3D = world.landscape
	# Aura: a HUD icon with the number drawn on top, flashing on change.
	var badge: Control = world._aura_badge
	assert(badge.visible and world.aura == 0 and badge.aura == 0)
	world._add_aura(5, "test")
	assert(world.aura == 5 and badge.aura == 5 and badge._flash > 0.0 and "+5 aura" in world._notice_label.text)
	world._add_aura(-7, "test")
	assert(world.aura == -2 and badge.aura == -2, "Aura can go below zero")
	world.aura = 0
	# Feeding: she grows hungrier steadily and eats a random item per meal.
	assert(world.fed == world.FED_START)
	world.berries_basket = 0
	world.basket = 0
	world.raw_meat = 0
	world.fed = 50.0
	world._meal_timer = 100.0
	world._update_hunger(10.0)
	assert(is_equal_approx(world.fed, 50.0 - 10.0 * world.FED_DECAY) and is_equal_approx(world._meal_timer, 90.0))
	var eaten := {"berries": 0, "mushroom": 0, "raw_meat": 0}
	world._food_rng.seed = 7
	for trial in 40:
		world.berries_basket = 1
		world.basket = 1
		world.raw_meat = 1
		world.fed = 20.0
		world._meal_timer = 0.01
		world._update_hunger(0.02)
		var meal := "berries" if world.berries_basket == 0 else ("mushroom" if world.basket == 0 else "raw_meat")
		assert(world.berries_basket + world.basket + world.raw_meat == 2, "One item per meal")
		assert(is_equal_approx(world.fed, 20.0 - 0.02 * world.FED_DECAY + world.MEAL_VALUE[meal]) and world._meal_timer == world.MEAL_INTERVAL)
		eaten[meal] += 1
	assert(eaten["berries"] > 0 and eaten["mushroom"] > 0 and eaten["raw_meat"] > 0, "Meals are picked at random")
	world.fed = world.FED_FULL + 5.0
	world._meal_timer = 0.01
	world._update_hunger(0.02)
	assert(world.berries_basket + world.basket + world.raw_meat == 2 and world._meal_timer == world.MEAL_INTERVAL, "A full Oravitsa skips a meal")
	world.berries_basket = 0
	world.basket = 0
	world.raw_meat = 0
	world.fed = 0.1
	world._update_hunger(1.0)
	world._update_hud()
	assert(world.is_hungry() and badge.fed == 0.0 and "starving" in world._notice_label.text, "With nothing to eat she starves")
	assert(is_equal_approx(world._move_speed(), world.SPEED * world.HUNGRY_SPEED) and is_equal_approx(world._player_stun_time(1.0), 1.0))
	world.raw_meat = 1
	world._update_hunger(0.0)
	assert(not world.is_hungry() and world.raw_meat == 0 and is_equal_approx(world.fed, world.MEAL_VALUE["raw_meat"]), "Starving, she eats as soon as she has food")
	assert(is_equal_approx(world._move_speed(), world.SPEED), "Half fed is normal speed")
	world.fed = world.FED_MAX
	assert(is_equal_approx(world._move_speed(), world.SPEED * world.FULL_SPEED), "Well fed is faster")
	assert(is_equal_approx(world._player_stun_time(world.CONTACT_STUN_TIME), world.CONTACT_STUN_TIME * world.FULL_STUN), "Well fed shortens stuns")
	world.fed = 25.0
	assert(world._move_speed() < world.SPEED and world._player_stun_time(1.0) > world._player_stun_time(0.9))
	world.fed = world.FED_START
	# Villagers appear at a nearby hamlet, inside its clearing.
	var hamlet: Dictionary = {}
	for by in range(-2, 3):
		for bx in range(-2, 3):
			if hamlet.is_empty():
				hamlet = land.hamlet_at(Vector2i(bx, by))
	assert(not hamlet.is_empty())
	await _travel(world, hamlet["center"] + Vector2(0, 8))
	world._update_villagers()
	var ids := _villagers(world)
	var chiefs := ids.filter(func(id: int) -> bool: return world._animals[id].get("chief", false))
	assert(chiefs.size() == 1, "Each hamlet has one chieftain")
	var chief: int = chiefs[0]
	var post: Vector2 = world._animals[chief]["home"]
	var post_ground: Vector2 = world.absolute_ground(post)
	assert(post_ground.distance_to(hamlet["store"] + Vector2(0, land.STORE_HALF + 0.9)) < 0.01, "The chieftain stands at his store tent's entrance")
	assert(not land.can_walk(hamlet["store"] - land.origin, 0.3), "The store tent is solid")
	ids.erase(chief)
	assert(ids.size() >= world.VILLAGERS_PER_HAMLET.x and ids.size() <= world.VILLAGERS_PER_HAMLET.y, "2–4 villagers per hamlet")
	var looks := []
	var drawn := 0
	for id in ids:
		var data: Dictionary = world._animals[id]
		assert(data["hamlet"] == hamlet["block"] and land.in_settlement(world.to_ground(data["position"])))
		if world._active_animals.has(id):
			drawn += 1
			assert(world._animal_models.has(id), "Active villagers are drawn")
			assert(world._animal_players[id].has_animation("Walk") and world._animal_players[id].has_animation("Idle"), "CC0 clips are aliased")
		looks.append(data["look"])
	assert(drawn >= 1, "Villagers near Oravitsa are drawn")
	# They stroll and stay in their clearing.
	ids = ids.filter(func(id: int) -> bool: return world._active_animals.has(id))
	var start: Dictionary = {}
	for id in ids:
		start[id] = world._animals[id]["position"]
	for frame in 300:
		world._move_animals(1.0 / 30.0)
	var moved := 0
	for id in ids:
		var p: Vector2 = world._animals[id]["position"]
		moved += 1 if p.distance_to(start[id]) > 5.0 else 0
		assert(world.to_ground(p).distance_to(world.to_ground(world._animals[id]["home"])) < land.HAMLET_RADIUS + 2.0, "Villagers keep to their hamlet")
	assert(moved >= 1, "Villagers wander")
	if world._active_animals.has(chief):
		for frame in 300:
			world._move_animals(1.0 / 30.0)
		assert(world._animals[chief]["position"].distance_to(post) < 8.0, "The chieftain keeps to his post")
	# They ignore Oravitsa: she walks through them with no bump either way.
	var villager: int = ids[0]
	world._animals[villager]["position"] = world.player_position + Vector2(20, 0)
	world._animals[villager]["velocity"] = Vector2.ZERO
	world.player_stun = 0.0
	for step in 6:
		assert(world._try_move(Vector2(8, 0)), "A villager never blocks Oravitsa")
	assert(world.player_stun == 0.0 and world._animals[villager]["stun"] == 0.0)
	assert(world._can_animal_move(villager, world.player_position), "Oravitsa never blocks a villager")
	# Shooing or hitting a villager costs aura.
	world.aura = 0
	world.selected_target = villager
	world.shoo_cooldown = 0.0
	world._use_skill(0)
	assert(world.aura == world.AURA["shoo_villager"] and world._animals[villager]["shoo"] > 0.0)
	world.sling_cooldown = 0.0
	world._animals[villager]["position"] = world.player_position + Vector2(200, 0)
	world._use_skill(1)
	for frame in 40:
		world._update_sling(1.0 / 30.0)
	assert(world.aura == world.AURA["shoo_villager"] + world.AURA["hit_villager"] and world._animals[villager]["stun"] > 0.0)
	# Food goes to the chieftain, one random item at a time.
	world.aura = 0
	world.raw_meat = 1
	world.basket = 1
	world.berries_basket = 1
	await _travel(world, hamlet["center"] + Vector2(40, 0))
	assert(not world._offer_ready(), "Food is given only to the chieftain")
	await _travel(world, post_ground + Vector2(0, 1.2))
	world._update_villagers()
	chief = -1
	for id in _villagers(world):
		if world._animals[id].get("chief", false):
			chief = id
	assert(chief >= 0 and world._active_animals.has(chief))
	world._animals[chief]["position"] = world._animals[chief]["home"]
	world._update_hud()
	assert(world._offer_ready() and world._offer_button.visible and "chieftain" in world._offer_button.text)
	var expected := 0
	for gift in 3:
		var before := [world.berries_basket, world.basket, world.raw_meat]
		if gift < 2:
			world._offer_food()
		else:
			var press := InputEventJoypadButton.new()
			press.button_index = JOY_BUTTON_A
			press.pressed = true
			world._unhandled_input(press)
		var given := 2 if world.raw_meat < before[2] else (1 if world.basket < before[1] else 0)
		assert(world.berries_basket + world.basket + world.raw_meat == 2 - gift, "One item per gift (controller A for the last)")
		expected += world.AURA["meat"] if given == 2 else world.AURA["food"]
		assert(world.aura == expected, "Raw meat is worth most")
	assert(world._animals[chief]["thanks"] > 0.0)
	world._sync_presentation(0.0)
	assert(world._animal_players[chief].current_animation == "Wave", "The chieftain waves his thanks")
	assert("chieftain’s store" in world._landmark_label.text)
	world._update_hud()
	assert(not world._offer_ready() and not world._offer_button.visible, "Nothing left to give")
	world.raw_meat = 1
	world._animals[chief]["shoo"] = 2.0
	assert(not world._offer_ready(), "A scared chieftain takes nothing")
	world._animals[chief]["shoo"] = 0.0
	world.raw_meat = 0
	# Far away the villagers leave; on return the same seeded villagers come back.
	await _travel(world, hamlet["center"] + Vector2(3000, 0))
	world._update_villagers()
	assert(_villagers(world).is_empty())
	await _travel(world, hamlet["center"] + Vector2(0, 8))
	world._update_villagers()
	var again := []
	var chief_again := 0
	for id in _villagers(world):
		if world._animals[id].get("chief", false):
			chief_again += 1
			assert(world.absolute_ground(world._animals[id]["home"]).distance_to(post_ground) < 0.01, "The chieftain returns to the same post")
		else:
			again.append(world._animals[id]["look"])
	assert(chief_again == 1 and again.size() == looks.size() and again == looks, "Villagers regenerate from their hamlet's seed")
	# Saves keep aura and feeding, never villagers; version-1 saves still load.
	world.aura = 17
	world.fed = 0.0
	world._meal_timer = 33.0
	var state: Dictionary = world.save_state()
	assert(world.SAVE_GAME.validate(state) == "" and state["version"] == 2)
	for record in state["animals"]:
		assert(record["kind"] != world.VILLAGER, "Villagers are never saved")
	world.aura = 0
	world.fed = 70.0
	world.apply_state(state)
	assert(world.aura == 17 and world.is_hungry() and world._meal_timer == 33.0)
	var old: Dictionary = state.duplicate(true)
	old["version"] = 1
	old.erase("aura")
	old.erase("fed")
	assert(world.SAVE_GAME.validate(old) == "", "Version-1 saves remain valid")
	world.apply_state(old)
	assert(world.aura == 0 and world.fed == world.FED_START)
	var bad: Dictionary = state.duplicate(true)
	bad["aura"] = "lots"
	assert(world.SAVE_GAME.validate(bad) != "")
	bad = state.duplicate(true)
	bad["fed"]["level"] = 400
	assert(world.SAVE_GAME.validate(bad) != "")
	print("Village smoke test passed: aura HUD and notices, feeding decay, random meals, full skips, starving slowdown, fed speed and stun resistance, ", ids.size(), " seeded villagers wandering in their clearing, a chieftain at his post, pass-through, shoo/sling aura loss, random gifts to the chieftain (keys and controller A) with his Wave, leave/return regeneration, save v2 with v1 compatibility")
	quit()
