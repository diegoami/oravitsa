extends SceneTree

## Save, quit and reload after long travel; reject bad saves without loss (#17).

const PATH := "user://smoke_test_save.json"


func _initialize() -> void:
	call_deferred("_run")


func _new_world():
	var world = load("res://scenes/endless_woods/woods.tscn").instantiate()
	world.save_path = PATH
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	await process_frame
	return world


func _travel(world, absolute: Vector2) -> void:
	world.player_position = world.from_ground(absolute - world.landscape.origin)
	world._rebase_if_needed()
	world.view.position = world.to_world(world.player_position) + world.CAMERA_OFFSET
	world._refresh_visible()
	world._sync_presentation(0.0)
	await process_frame


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _clean() -> void:
	for path in [PATH, PATH + ".bak", PATH + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _run() -> void:
	_clean()
	var world = await _new_world()
	# Loading without a save reports it and changes nothing.
	var start: Vector2 = world.absolute_ground(world.player_position)
	world._load_game()
	assert(world._notice_label.text.begins_with("Cannot load") and "no saved game" in world._notice_label.text)
	assert(world.absolute_ground(world.player_position).distance_to(start) < 0.01)
	# Travel far east (forcing several origin rebases), then harvest there.
	var far := Vector2(3100, world.landscape.road_z(3100, 0))
	await _travel(world, far)
	assert(world.origin_cells != Vector2i.ZERO, "The journey must rebase the origin")
	var food: Vector2i = world._forage_visuals.keys()[0]
	var food_absolute: Vector2 = world.absolute_ground(world._cell_center(food))
	var key: int = world._index(food)
	world.player_position = world._cell_center(food)
	world._collect_nearby()
	assert(world._harvested.has(key))
	var due: float = world._harvested[key]["ready_at"]
	world._update_food_regrowth(12.5)
	var clock: float = world._food_clock
	var position: Vector2 = world.absolute_ground(world.player_position)
	world.raw_meat = 3
	var bag: int = world.basket + world.berries_basket
	world.shoo_cooldown = 4.25
	world.sling_cooldown = 1.5
	world.player_stun = 0.75
	world.active_skill = 1
	# Animal statuses, a gone slot and an encounter in progress.
	assert(world._animals.size() >= 3)
	world._animals[0]["stun"] = 3.25
	world._animals[0]["shoo"] = 2.0
	world._animals[1]["alive"] = false
	world._animals[1]["gone"] = true
	world._animals[1]["respawn"] = 30.0
	world._animals[2]["aggro"] = world.AGGRO_CHARGE
	world._animals[2]["state"] = "charge"
	world._animals[2]["aggro_cooldown"] = 12.0
	world._animals[2]["hunger"] = 77.0
	var animals: Array = []
	for data in world._animals:
		animals.append({"kind": data["kind"], "position": world.absolute_ground(data["position"]), "alive": data["alive"]})
	world._save_game()
	assert(world._notice_label.text == "Game saved")
	assert(FileAccess.file_exists(PATH) and not FileAccess.file_exists(PATH + ".tmp"))
	# Quit: a fresh session starts at arrival with nothing collected.
	world.queue_free()
	await process_frame
	world = await _new_world()
	assert(world.raw_meat == 0 and world.origin_cells == Vector2i.ZERO)
	world._load_game()
	assert(world._notice_label.text == "Game loaded")
	assert(world.absolute_ground(world.player_position).distance_to(position) < 0.01, "Absolute location must be restored")
	assert(world.to_ground(world.player_position).length() < 645, "Loading must rebase near the restored location")
	assert(world.raw_meat == 3 and world.basket + world.berries_basket == bag)
	assert(is_equal_approx(world.shoo_cooldown, 4.25) and is_equal_approx(world.sling_cooldown, 1.5))
	assert(is_equal_approx(world.player_stun, 0.75) and world.active_skill == 1)
	assert(is_equal_approx(world._food_clock, clock), "Timers do not advance while the game is closed")
	assert(world._harvested.has(key) and is_equal_approx(world._harvested[key]["ready_at"], due), "Regrowth deadlines survive loading")
	var restored_food: Vector2i = world._world_cell(world.from_ground(food_absolute - world.landscape.origin))
	assert(world._index(restored_food) == key)
	assert(world.objects[key] == world.EMPTY and not world._forage_visuals.has(restored_food), "Harvested food stays harvested")
	assert(world._animals.size() == animals.size())
	for id in animals.size():
		assert(world._animals[id]["kind"] == animals[id]["kind"] and world._animals[id]["alive"] == animals[id]["alive"])
		assert(world.absolute_ground(world._animals[id]["position"]).distance_to(animals[id]["position"]) < 0.01)
	assert(is_equal_approx(world._animals[0]["stun"], 3.25) and is_equal_approx(world._animals[0]["shoo"], 2.0))
	assert(world._animals[1]["gone"] and is_equal_approx(world._animals[1]["respawn"], 30.0))
	assert(world._animals[2]["aggro"] == world.AGGRO_NONE and world._animals[2]["state"] == "idle", "An encounter in progress restarts calm")
	assert(is_equal_approx(world._animals[2]["aggro_cooldown"], 12.0) and is_equal_approx(world._animals[2]["hunger"], 77.0))
	# Streaming after the load keeps the restored harvest.
	await _travel(world, far + Vector2(-2200, 0))
	await _travel(world, food_absolute)
	restored_food = world._world_cell(world.from_ground(food_absolute - world.landscape.origin))
	assert(world.objects[world._index(restored_food)] == world.EMPTY)
	# A second save keeps the first as a backup.
	world.raw_meat = 4
	world._save_game()
	assert(FileAccess.file_exists(PATH + ".bak"))
	# A corrupt slot is never deleted; the intact backup is offered instead.
	_write(PATH, "{not json")
	world.raw_meat = 0
	world._load_game()
	assert(world.raw_meat == 3 and "previous save" in world._notice_label.text)
	assert(FileAccess.get_file_as_string(PATH) == "{not json", "A corrupt save must not be deleted or rewritten")
	# Incompatible or foreign saves are rejected without changing the game.
	DirAccess.remove_absolute(PATH + ".bak")
	var valid: Dictionary = world.save_state()
	var future := valid.duplicate(true)
	future["version"] = 99
	_write(PATH, JSON.stringify(future))
	world.raw_meat = 9
	world._load_game()
	assert(world.raw_meat == 9 and "incompatible" in world._notice_label.text)
	assert(JSON.parse_string(FileAccess.get_file_as_string(PATH))["version"] == 99)
	var foreign := valid.duplicate(true)
	foreign["world"] = "elsewhere"
	_write(PATH, JSON.stringify(foreign))
	world._load_game()
	assert(world.raw_meat == 9 and "different world" in world._notice_label.text)
	var broken := valid.duplicate(true)
	broken["animals"][0]["position"] = ["x", 1]
	_write(PATH, JSON.stringify(broken))
	world._load_game()
	assert(world.raw_meat == 9 and world._notice_label.text.begins_with("Cannot load"), "Invalid fields are rejected before anything is applied")
	# Controller X/B save and load only while Help is open; keys K/L always.
	_clean()
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_X
	press.pressed = true
	world._unhandled_input(press)
	assert(not FileAccess.file_exists(PATH), "X must not save while Help is closed")
	world._toggle_instructions()
	assert(world._save_button.visible and world._load_button.visible)
	world._unhandled_input(press)
	assert(FileAccess.file_exists(PATH))
	world.raw_meat = 0
	press.button_index = JOY_BUTTON_B
	world._unhandled_input(press)
	assert(world.raw_meat == 9)
	_clean()
	print("Save smoke test passed: missing-save feedback, long-distance rebased round trip, inventory/cooldowns/stun, harvest deadlines, animal states, paused timers, streaming after load, backup on replace, corrupt/incompatible/foreign/invalid rejection without loss, controller and HUD access")
	quit()
