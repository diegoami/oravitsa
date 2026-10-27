extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world = load("res://scenes/endless_woods/woods.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	await process_frame
	world.selected_target = -1
	world._use_skill(0)
	assert(world.shoo_cooldown == 0, "Shoo without a target must not spend its cooldown")
	assert(world._shoo_button.disabled)
	for sprite in world._active_animals.values():
		sprite.queue_free()
	world._active_animals.clear()
	world._sync_animal_lifecycle()
	world._animals.clear()
	for kind in [world.BOAR, world.WOLF, world.HARE, world.DEER]:
		world._add_animal(kind, world.START + Vector2i(4, 0))
	world._animals[1]["position"] = world.from_ground(Vector2(8, 1))
	world._animals[2]["position"] = world.from_ground(Vector2(8, -1))
	world._animals[3]["position"] = world.from_ground(Vector2(10, -1))
	world._refresh_visible()
	world._sync_presentation(0.0)
	# Out-of-range and dead targets must not cast or spend a cooldown.
	world.selected_target = 0
	var position: Vector2 = world._animals[0]["position"]
	world._animals[0]["position"] = world.player_position + Vector2(world.SHOO_RANGE + 1, 0)
	world._use_skill(0)
	assert(world.shoo_cooldown == 0)
	world._animals[0]["position"] = position
	world._animals[0]["alive"] = false
	world._use_skill(0)
	assert(world.shoo_cooldown == 0)
	world._animals[0]["alive"] = true
	# Fear must interrupt feeding, stun and stale hunt/navigation state.
	var target: Dictionary = world._animals[0]
	target["stun"] = 2.0
	target["feeding"] = 1.5
	target["eat_time"] = 0.5
	target["catch_target"] = 2
	target["catch_time"] = 2.9
	target["route"] = PackedVector2Array([world.player_position])
	world._use_skill(0)
	assert(world.shoo_cooldown == world.SHOO_COOLDOWN)
	assert(target["shoo"] == world.SHOO_FEAR_TIME and target["state"] == "scared")
	assert(target["stun"] == 0 and target["feeding"] == 0 and target["eat_time"] == 0)
	assert(target["catch_target"] == -1 and target["catch_time"] == 0 and target["route"].is_empty())
	assert(world._animals[1]["shoo"] == 0 and world._animals[2]["shoo"] == 0, "Shoo affects only the selected animal")
	assert(target["velocity"].length() > world.SPEED)
	assert(target["velocity"].dot(position - world.player_position) > 0)
	var fear: float = target["shoo"]
	world._use_skill(0)
	assert(target["shoo"] == fear and world.shoo_cooldown == world.SHOO_COOLDOWN)
	world._move_animals(0.1)
	world._sync_presentation(0.0)
	assert(target["position"].distance_to(world.player_position) > position.distance_to(world.player_position) + 25, "Scared animal must quickly run away")
	var marker: Label3D = world._animal_stars[0]
	assert(marker.visible and "SCARED" in marker.text and "4.9" in marker.text)
	assert(target["alive"] and world._animals[1]["alive"] and world._animals[2]["alive"])
	target["shoo"] = 0.01
	world._move_animals(0.02)
	world._sync_presentation(0.0)
	assert(target["shoo"] == 0 and target["state"] != "scared" and not marker.visible)
	# A predator must flee instead of finishing an almost-complete deer catch.
	world.shoo_cooldown = 0.0
	world.selected_target = 1
	world._animals[1]["catch_target"] = -1
	world._animals[1]["catch_time"] = 0.0
	assert(not world._catch_prey(1, 3, 2.9))
	world._use_skill(0)
	assert(world._animals[1]["state"] == "scared" and world._animals[1]["catch_time"] == 0)
	world._sync_presentation(0.0)
	assert("SCARED" in world._animal_stars[1].text)
	assert(world._animal_players[1].current_animation == "Gallop")
	assert(world._animals[3]["alive"])
	print("Targeted Shoo smoke test passed: selection/range/death guards, one target, immediate strong escape, interrupt/reset, cooldown, scared marker/countdown, expiry and predator fear")
	quit()
