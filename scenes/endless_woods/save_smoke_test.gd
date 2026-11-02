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
		if FileAccess.file_exists(path + "/blocker"):
			DirAccess.remove_absolute(path + "/blocker")
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
			DirAccess.remove_absolute(path)


## A non-empty directory at a save path makes renames onto it fail for real.
func _block(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	DirAccess.make_dir_absolute(path)
	_write(path + "/blocker", "x")


func _meat(world, path: String) -> int:
	var result: Dictionary = world.SAVE_GAME.read(path)
	return int(result["data"]["inventory"]["raw_meat"]) if result["ok"] else -1


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
	world.slow_cooldown = 3.5
	world.cure_cooldown = 9.0
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
	assert(is_equal_approx(world.player_stun, 0.75) and is_equal_approx(world.slow_cooldown, 3.5) and is_equal_approx(world.cure_cooldown, 9.0))
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
	# The long recovery notice must stay readable on screen (#31).
	await process_frame
	assert(Rect2(Vector2.ZERO, world.get_viewport_rect().size).encloses(world._notice_label.get_rect()), "Recovery notice must stay on screen")
	assert(world._notice_label.get_rect().end.y < world._inventory.position.y)
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
	# Failure injection (#29): no failed save may lose the last readable save.
	_clean()
	for meat in [5, 6]:
		world.raw_meat = meat
		assert(world.SAVE_GAME.write(world.save_state(), PATH).is_empty())
	assert(_meat(world, PATH) == 6 and _meat(world, PATH + ".bak") == 5)
	# A corrupt slot is never rotated over the valid backup.
	_write(PATH, "{corrupt")
	world.raw_meat = 7
	assert(world.SAVE_GAME.write(world.save_state(), PATH).is_empty())
	assert(_meat(world, PATH) == 7 and _meat(world, PATH + ".bak") == 5, "A corrupt slot must not displace the valid backup")
	# The slot cannot be replaced: the backup survives and is offered on load.
	_block(PATH)
	world.raw_meat = 8
	var failed: String = world.SAVE_GAME.write(world.save_state(), PATH)
	assert(not failed.is_empty() and _meat(world, PATH + ".bak") == 5 and not FileAccess.file_exists(PATH + ".tmp"))
	world._save_game()
	assert("previous save is unchanged" in world._notice_label.text and _meat(world, PATH + ".bak") == 5)
	world.raw_meat = 0
	world._load_game()
	assert(world.raw_meat == 5 and "previous save" in world._notice_label.text, "An unusable slot falls back to the backup")
	# A readable slot that cannot be rotated stays exactly as it was.
	_clean()
	world.raw_meat = 9
	assert(world.SAVE_GAME.write(world.save_state(), PATH).is_empty())
	var before := FileAccess.get_file_as_string(PATH)
	_block(PATH + ".bak")
	world.raw_meat = 10
	failed = world.SAVE_GAME.write(world.save_state(), PATH)
	assert(not failed.is_empty() and FileAccess.get_file_as_string(PATH) == before and not FileAccess.file_exists(PATH + ".tmp"))
	# Controller X/B save and load only while Help is open; keys K/L always.
	_clean()
	world.raw_meat = 9
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
	world._toggle_instructions()
	# The explored world map (#66): walking explores absolute cells, coming
	# near a hamlet or cave mouth discovers it by name, and both survive
	# rebasing and saving. M / Select cycles local map, world map and none.
	# Protects: lost or shifted exploration, discoveries without names, and a
	# world map that cannot be opened or closed.
	var land: Node3D = world.landscape
	var hamlet := {}
	var cave := {}
	for by in range(-2, 3):
		for bx in range(-2, 3):
			if hamlet.is_empty():
				hamlet = land.hamlet_at(Vector2i(bx, by))
	for rz in range(-3, 4):
		for rx in range(-3, 4):
			if cave.is_empty():
				cave = land.cave_at(Vector2i(rx, rz))
	assert(not hamlet.is_empty() and not cave.is_empty())
	world.explored = {}
	world.discovered_hamlets = {}
	world.discovered_caves = {}
	await _travel(world, hamlet["center"] + Vector2(0, 8))
	world._explore()
	var hamlet_cell := Vector2i(((hamlet["center"] + Vector2(0, 8)) / world.EXPLORE_CELL).floor())
	assert(world.explored.has(hamlet_cell) and world.explored.size() >= 9, "Walking explores the cells around her")
	assert(world.discovered_hamlets.has(hamlet["block"]) and world.discovered_hamlets[hamlet["block"]]["name"] == world.PLACE_NAMES.hamlet(hamlet["block"]), "A hamlet she reaches is discovered by name")
	await _travel(world, cave["mouth"] + cave["facing"] * 4.0)
	world._explore()
	assert(world.discovered_caves.has(cave["region"]) and world.discovered_caves[cave["region"]]["name"] == world.PLACE_NAMES.cave(cave["region"]))
	# Crossing the discovery radius within one exploration cell still
	# discovers (#96). Protects: discoveries waiting for the next cell.
	world.discovered_caves = {}
	var outside := Vector2.ZERO
	var inside := Vector2.ZERO
	for step in 72:
		var way := Vector2.from_angle(step * TAU / 72.0)
		var a: Vector2 = cave["mouth"] + way * (world.DISCOVER_RADIUS + 2.0)
		var b: Vector2 = cave["mouth"] + way * (world.DISCOVER_RADIUS - 2.0)
		if Vector2i((a / world.EXPLORE_CELL).floor()) == Vector2i((b / world.EXPLORE_CELL).floor()):
			outside = a
			inside = b
			break
	assert(outside != Vector2.ZERO, "Some approach stays inside one cell")
	world.player_position = world.from_ground(outside - world.landscape.origin)
	world._explore()
	assert(not world.discovered_caves.has(cave["region"]))
	world.player_position = world.from_ground(inside - world.landscape.origin)
	world._explore()
	assert(world.discovered_caves.has(cave["region"]), "Crossing the radius inside one cell discovers the cave")
	var explored_count: int = world.explored.size()
	await _travel(world, cave["mouth"] + Vector2(4000, 0))
	await _travel(world, cave["mouth"] + cave["facing"] * 4.0)
	world._explore()
	assert(world.explored.has(hamlet_cell), "Exploration is absolute: rebasing never shifts it")
	var mapped: Dictionary = world.save_state()
	assert(world.SAVE_GAME.validate(mapped) == "")
	world.explored = {}
	world.discovered_hamlets = {}
	world.discovered_caves = {}
	world.apply_state(mapped)
	assert(world.explored.has(hamlet_cell) and world.explored.size() >= explored_count, "Exploration survives saving")
	assert(world.discovered_hamlets.has(hamlet["block"]) and world.discovered_caves.has(cave["region"]), "Discoveries survive saving")
	var old_save := mapped.duplicate(true)
	old_save.erase("explored")
	old_save.erase("discovered")
	assert(world.SAVE_GAME.validate(old_save) == "", "Saves from before the world map still load")
	var bad_map := mapped.duplicate(true)
	bad_map["explored"] = [1, "x"]
	assert(world.SAVE_GAME.validate(bad_map) != "")
	bad_map["explored"] = [1]
	assert(world.SAVE_GAME.validate(bad_map) != "")
	world._map_visible = false
	world._world_map_visible = false
	world._toggle_map()
	assert(world._minimap.visible and not world._world_map.visible and "World map" in world._map_toggle.text)
	world._toggle_map()
	assert(not world._minimap.visible and world._world_map.visible, "The second press opens the world map")
	await process_frame # Draws it.
	# Protects: a world map stuck at one scale, a zoom input that misses one
	# of keyboard / wheel / button / stick, zooming past its limits, and keys
	# or flicks that zoom while the map is closed (#105).
	var atlas: Control = world._world_map
	assert(atlas.metres_per_pixel() == 4.0, "It opens at 4 m per pixel")
	var zoom_press := func(code: Key) -> void:
		var zoom_key := InputEventKey.new()
		zoom_key.keycode = code
		zoom_key.pressed = true
		world._unhandled_input(zoom_key)
	zoom_press.call(KEY_EQUAL)
	assert(atlas.metres_per_pixel() == 2.0, "+ zooms in")
	zoom_press.call(KEY_KP_SUBTRACT)
	zoom_press.call(KEY_MINUS)
	assert(atlas.metres_per_pixel() == 8.0, "− zooms out")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	atlas._gui_input(wheel)
	assert(atlas.metres_per_pixel() == 16.0, "The wheel zooms")
	world._cycle_sling_target(1)
	assert(atlas.metres_per_pixel() == 32.0 and atlas._zoom_out.disabled and not atlas.zoom_by(1), "A flick zooms out, up to the widest scale")
	await process_frame # Draws the widest scale.
	for i in 6:
		atlas._zoom_in.pressed.emit()
	assert(atlas.metres_per_pixel() == 1.0 and atlas._zoom_in.disabled, "The + button zooms in, down to the closest scale")
	var names: Array[Rect2] = []
	var font := ThemeDB.fallback_font
	assert(atlas.claim_label(font, Vector2(100, 100), "Rantala", names) and not atlas.claim_label(font, Vector2(104, 106), "Zmiieva Pechera", names), "A crowded place name is left out")
	assert(atlas.claim_label(font, Vector2(100, 160), "Zmiieva Pechera", names) and names.size() == 2, "Clear names are all drawn")
	await process_frame # Draws the closest scale.
	atlas.zoom_by(atlas.DEFAULT_ZOOM)
	world._world_map_visible = false
	zoom_press.call(KEY_EQUAL)
	world._cycle_sling_target(1)
	assert(atlas.metres_per_pixel() == 4.0, "Closed, keys and flicks leave the zoom alone")
	world._world_map_visible = true
	world._enter_cave(cave, true)
	world._update_hud()
	assert(world.map_center() == world._cave_return)
	await process_frame # Draws it underground, centred on the mouth.
	world._exit_cave(true)
	world._toggle_map()
	assert(not world._minimap.visible and not world._world_map.visible, "The third press closes the maps")
	_clean()
	print("Save smoke test passed: missing-save feedback, long-distance rebased round trip, inventory/cooldowns/stun, harvest deadlines, animal states, paused timers, streaming after load, backup on replace, corrupt/incompatible/foreign/invalid rejection without loss, rename-failure injection keeping the last readable save, controller and HUD access, explored world map and discoveries saved across rebases with a map cycle")
	quit()
