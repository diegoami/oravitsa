extends SceneTree

## Karma (#42), hunger (#43), hamlet villagers and food offerings (#44).


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
	# Karma: a HUD icon with the number drawn on top, flashing on change.
	var badge: Control = world._karma_badge
	assert(badge.visible and world.karma == 0 and badge.karma == 0)
	world._add_karma(5, "test")
	assert(world.karma == 5 and badge.karma == 5 and badge._flash > 0.0 and "+5 karma" in world._notice_label.text)
	world._add_karma(-7, "test")
	assert(world.karma == -2 and badge.karma == -2, "Karma can go below zero")
	world.karma = 0
	# Hunger: one item from the bag per interval, berries first.
	world.berries_basket = 1
	world.basket = 1
	world.raw_meat = 0
	world._hunger_timer = 0.01
	world._update_hunger(0.02)
	assert(world.berries_basket == 0 and world.basket == 1 and not world.hungry and world._hunger_timer == world.HUNGER_INTERVAL)
	world._hunger_timer = 0.01
	world._update_hunger(0.02)
	assert(world.basket == 0 and not world.hungry)
	world._hunger_timer = 0.01
	world._update_hunger(0.02)
	assert(world.hungry and badge.hungry, "An empty bag makes her hungry")
	assert(is_equal_approx(world._move_speed(), world.SPEED * world.HUNGRY_SPEED), "Hunger slows her")
	world.raw_meat = 1
	world._update_hunger(0.0)
	assert(not world.hungry and world.raw_meat == 0 and world._move_speed() == world.SPEED, "She eats as soon as she has food again")
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
	# They ignore Oravitsa: she walks through them with no bump either way.
	var villager: int = ids[0]
	world._animals[villager]["position"] = world.player_position + Vector2(20, 0)
	world._animals[villager]["velocity"] = Vector2.ZERO
	world.player_stun = 0.0
	for step in 6:
		assert(world._try_move(Vector2(8, 0)), "A villager never blocks Oravitsa")
	assert(world.player_stun == 0.0 and world._animals[villager]["stun"] == 0.0)
	assert(world._can_animal_move(villager, world.player_position), "Oravitsa never blocks a villager")
	# Shooing or hitting a villager costs karma.
	world.karma = 0
	world.selected_target = villager
	world.shoo_cooldown = 0.0
	world._use_skill(0)
	assert(world.karma == world.KARMA["shoo_villager"] and world._animals[villager]["shoo"] > 0.0)
	world.sling_cooldown = 0.0
	world._animals[villager]["position"] = world.player_position + Vector2(200, 0)
	world._use_skill(1)
	for frame in 40:
		world._update_sling(1.0 / 30.0)
	assert(world.karma == world.KARMA["shoo_villager"] + world.KARMA["hit_villager"] and world._animals[villager]["stun"] > 0.0)
	# Offering food at the village well.
	world.karma = 0
	world.raw_meat = 1
	world.basket = 1
	world.berries_basket = 1
	await _travel(world, hamlet["center"] + Vector2(40, 0))
	assert(not world._offer_ready(), "Offerings only at the village well")
	await _travel(world, hamlet["well"] + Vector2(0, 1.6))
	world._update_hud()
	assert(world._offer_ready() and world._offer_button.visible)
	world._offer_food()
	assert(world.raw_meat == 0 and world.karma == world.KARMA["meat"], "Raw meat is offered first")
	world._offer_food()
	assert(world.basket == 0 and world.karma == world.KARMA["meat"] + world.KARMA["food"])
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	world._unhandled_input(press)
	assert(world.berries_basket == 0 and world.karma == world.KARMA["meat"] + 2 * world.KARMA["food"], "Controller A offers at the well")
	world._update_hud()
	assert(not world._offer_ready() and not world._offer_button.visible, "Nothing left to offer")
	# Far away the villagers leave; on return the same seeded villagers come back.
	await _travel(world, hamlet["center"] + Vector2(3000, 0))
	world._update_villagers()
	assert(_villagers(world).is_empty())
	await _travel(world, hamlet["center"] + Vector2(0, 8))
	world._update_villagers()
	var again := []
	for id in _villagers(world):
		again.append(world._animals[id]["look"])
	assert(again.size() == looks.size() and again == looks, "Villagers regenerate from their hamlet's seed")
	# Saves keep karma and hunger, never villagers; version-1 saves still load.
	world.karma = 17
	world.hungry = true
	var state: Dictionary = world.save_state()
	assert(world.SAVE_GAME.validate(state) == "" and state["version"] == 2)
	for record in state["animals"]:
		assert(record["kind"] != world.VILLAGER, "Villagers are never saved")
	world.karma = 0
	world.hungry = false
	world.apply_state(state)
	assert(world.karma == 17 and world.hungry)
	var old: Dictionary = state.duplicate(true)
	old["version"] = 1
	old.erase("karma")
	old.erase("hunger")
	assert(world.SAVE_GAME.validate(old) == "", "Version-1 saves remain valid")
	world.apply_state(old)
	assert(world.karma == 0 and not world.hungry)
	var bad: Dictionary = state.duplicate(true)
	bad["karma"] = "lots"
	assert(world.SAVE_GAME.validate(bad) != "")
	print("Village smoke test passed: karma HUD and notices, hunger eating order and slowdown, ", ids.size(), " seeded villagers wandering in their clearing, pass-through, shoo/sling karma loss, well offerings (keys and controller A), leave/return regeneration, save v2 with v1 compatibility")
	quit()
