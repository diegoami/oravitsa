extends Node2D

## A finite, seeded forest made of connected painted ground tiles. Ground,
## props, and animals are streamed around the camera; map data drives collision.

const TILE := 114
const MAP_SIZE := 416
const ART := "res://scenes/forest_2d/art/"
const CHARACTER_ART := "res://prototypes/foraging_2d/art/"
const PLAYER_WALK: SpriteFrames = preload("res://scenes/forest_2d/art/oravitsa/walk.tres")
const SPEED := 210.0
const PICKUP_RADIUS := 40.0
# Bodies touch at 43 px, so a stunned hare is reachable before a bump.
const HARE_PICKUP_RADIUS := 75.0
const HARE_NOTICE_RADIUS := 260.0
const START := Vector2i(208, 208)
const GRASS := 0
const DIRT := 1
const EMPTY := 0
const TREE := 1
const BUSH := 2
const STONE := 3
const MUSHROOM := 4
const FERN := 5
const LOG := 6
const BERRIES := 7
const BLOCKED := [TREE, BUSH, STONE, LOG]
const BLOCKER_RADIUS := {TREE: 32.0, BUSH: 31.0, STONE: 25.0, LOG: 33.0}
const PROP_NAMES := {TREE: "tree", BUSH: "bush", STONE: "stone", MUSHROOM: "mushroom", FERN: "fern", LOG: "log", BERRIES: "berries"}
const BOAR := 0
const DEER := 1
const FOX := 2
const LYNX := 3
const HARE := 4
const WOLF := 5
const ANIMAL_NAMES := {BOAR: "Boar", DEER: "Deer", FOX: "Fox", LYNX: "Lynx", HARE: "Hare", WOLF: "Wolf"}
const ANIMAL_SPEEDS := {BOAR: 52.0, DEER: 96.0, FOX: 112.0, LYNX: 91.0, HARE: 108.0, WOLF: 120.0}
const ANIMAL_RADIUS := {BOAR: 30.0, DEER: 25.0, FOX: 22.0, LYNX: 25.0, HARE: 19.0, WOLF: 30.0}
const LYNX_BURST_SPEED := 220.0
const LYNX_BURST_TIME := 1.5
const LYNX_BURST_RECOVERY := 3.4
const PREY_RESPAWN_TIME := 25.0
const DEER_CATCH_TIME := 3.0
const SPAWN_WEIGHTS := {HARE: 60, DEER: 17, FOX: 17, BOAR: 5, LYNX: 1}
const LOCAL_POPULATION := {HARE: 4, DEER: 2, FOX: 2, BOAR: 1, LYNX: 1}
const REPLENISH_CHANCE := {HARE: 1.0, DEER: 0.35, FOX: 0.35, BOAR: 0.12, LYNX: 0.02}
# One cell covers the player moving within a cell before streaming refreshes;
# the second covers camera smoothing lag.
const STREAM_MARGIN := 2
const POPULATION_RADIUS := 1150.0
const POPULATION_INTERVAL := 7.0
const PLAYER_RADIUS := 24.0
const SHOO_RANGE := 600.0
const SHOO_COOLDOWN := 7.0
const SHOO_FEAR_TIME := 5.0
const SHOO_FLEE_SPEED := SPEED * 1.8
const SLING_RANGE := 600.0
const SLING_COOLDOWN := 4.0
const SLING_STUN_TIME := 4.5
# Bumping an animal stuns both; Oravitsa then recovers before it can recur.
const CONTACT_STUN_TIME := 1.2
const STONE_SPEED := 1050.0
const AGGRO_NONE := 0
const AGGRO_WARN := 1
const AGGRO_CHARGE := 2
# Analog triggers cast once per pull: fire past PRESS, re-arm below RELEASE.
const TRIGGER_PRESS := 0.6
const TRIGGER_RELEASE := 0.3

var terrain = PackedByteArray()
var objects = PackedByteArray()
var player_position := Vector2.ZERO
var basket := 0
var berries_basket := 0
var raw_meat := 0
var deer_caught := 0
var hares_caught := 0
var player_stun := 0.0
var shoo_cooldown := 0.0
var sling_cooldown := 0.0
var selected_target := -1
var _stones: Array[Dictionary] = []
var _sling_effects: Node2D
var _sling_label: Label
var _skill_hint_label: Label
var _sling_button: Button
var _shoo_button: Button
var _skill_bar: Control
var _map_toggle: Button
var _instructions_toggle: Button
var _help_panel: Panel
var _save_button: Button
var _load_button: Button
var _map_visible := false
var _instructions_visible := false
var _input_mode := "keyboard"
var active_skill := 0 # Shoo, Sling.
var _right_stick := Vector2.ZERO
var _target_stick_latched := false
var _trigger_latched := [false, false] # LT casts Shoo, RT casts Sling.
var _inventory: Control
var _ground: TileMapLayer
var _dirt: TileMapLayer
var _blocked_ground: Node2D
var _world: Node2D
var _player: AnimatedSprite2D
var _camera: Camera2D
var _minimap: Control
var _hint_label: Label
var _notice_label: Label
var _notice_time := 0.0
var _notice_duration := 2.5
var _touch_controls: Control
var _active_props: Dictionary = {}
var _animals: Array[Dictionary] = []
var _active_animals: Dictionary = {}
var _textures: Dictionary = {}
var _png_cache: Dictionary = {}
var _loaded_center := Vector2i(-999, -999)
var _loaded_half := Vector2i.ZERO
var _population_timer := POPULATION_INTERVAL
var _population_tick := 0
var _walk_phase := 0.0


func _ready() -> void:
	_generate_map()
	_build_world()
	_seed_animals()
	player_position = _cell_center(START)
	_player.position = player_position
	_camera.position = player_position
	_camera.reset_smoothing()
	_refresh_visible()
	_update_hud()


func _process(delta: float) -> void:
	player_stun = maxf(0.0, player_stun - delta)
	shoo_cooldown = maxf(0.0, shoo_cooldown - delta)
	_notice_time = maxf(0.0, _notice_time - delta)
	var direction := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	direction = (direction + _touch_controls.direction).limit_length()
	var before_move := player_position
	if direction.length_squared() > 0.0 and player_stun <= 0.0:
		var step := direction * SPEED * delta
		if not _try_move(step) and player_stun <= 0.0:
			_try_move(Vector2(step.x, 0.0))
			_try_move(Vector2(0.0, step.y))
	_update_player_walk(player_position - before_move)
	_player.modulate = Color(0.66, 0.78, 0.91) if player_stun > 0.0 else Color.WHITE
	_player.position = player_position
	_camera.position = player_position
	if _input_mode != "controller":
		_collect_nearby()
	var cell := _world_cell(player_position)
	if cell != _loaded_center or _stream_half() != _loaded_half:
		_refresh_visible()
	_update_respawns(delta)
	_move_animals(delta)
	_update_sling(delta)
	_population_timer -= delta
	if _population_timer <= 0.0:
		_population_timer = POPULATION_INTERVAL
		_replenish_local_animals()
	_update_hud()
	_minimap.queue_redraw()


func _update_player_walk(motion: Vector2) -> void:
	if motion.length_squared() <= 0.000001:
		_player.pause()
		_player.set_frame_and_progress(0, 0.0)
		return
	# Advance from distance actually travelled, including collision sliding and
	# partial thumb-stick input. One shared phase survives turns and pauses.
	_walk_phase = fposmod(_walk_phase + motion.length() / (SPEED * float(PLAYER_WALK.get_meta("cycle_seconds"))), 1.0)
	var wanted := _direction_name(motion)
	# Frames are driven by distance here; disable the sprite's time-based advance.
	_player.play(wanted, 0.0)
	_player.flip_h = false
	var frame_position := _walk_phase * 8.0
	_player.set_frame_and_progress(floori(frame_position), fposmod(frame_position, 1.0))


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			_toggle_map()
		elif event.keycode == KEY_H:
			_toggle_instructions()
		elif event.keycode == KEY_SPACE:
			_use_skill(0)
		elif event.physical_keycode == KEY_F or event.keycode == KEY_F:
			_use_skill(1)
		elif event.keycode == KEY_K and _can_save():
			_save_game()
		elif event.keycode == KEY_L and _can_save():
			_load_game()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		_controller_axis(event)
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_BACK:
			_toggle_map()
		elif event.button_index == JOY_BUTTON_START:
			_toggle_instructions()
		elif event.button_index == JOY_BUTTON_X and _instructions_visible and _can_save():
			_save_game() # Only with Help open, so a stray press never saves.
		elif event.button_index == JOY_BUTTON_B and _instructions_visible and _can_save():
			_load_game()
		elif event.is_action_pressed("skill_next"):
			active_skill = wrapi(active_skill + 1, 0, 2)
			_update_hud()
		elif event.is_action_pressed("skill_previous"):
			active_skill = wrapi(active_skill - 1, 0, 2)
			_update_hud()
		elif event.is_action_pressed("cast_skill"):
			_use_skill(active_skill)
		elif event.is_action_pressed("pick_up") and player_stun <= 0.0:
			_collect_nearby()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_sling_target(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_use_skill(1)
	elif event is InputEventScreenTouch and event.pressed:
		_select_sling_target(event.position)


func _controller_axis(event: InputEventJoypadMotion) -> void:
	if event.axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		if event.axis == JOY_AXIS_RIGHT_X:
			_right_stick.x = event.axis_value
		else:
			_right_stick.y = event.axis_value
		if _right_stick.length() < 0.3:
			_target_stick_latched = false
		elif not _target_stick_latched and maxf(absf(_right_stick.x), absf(_right_stick.y)) > 0.65:
			var value := _right_stick.x if absf(_right_stick.x) >= absf(_right_stick.y) else _right_stick.y
			_cycle_sling_target(1 if value > 0.0 else -1)
			_target_stick_latched = true
	elif event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
		var skill := 0 if event.axis == JOY_AXIS_TRIGGER_LEFT else 1
		if event.axis_value < TRIGGER_RELEASE:
			_trigger_latched[skill] = false
		elif event.axis_value >= TRIGGER_PRESS and not _trigger_latched[skill]:
			_trigger_latched[skill] = true
			# Direct casts leave the LB/RB selection for Y unchanged.
			_cast_skill(skill)


func _use_skill(skill: int) -> void:
	active_skill = skill
	_cast_skill(skill)


func _cast_skill(skill: int) -> void:
	if skill == 0:
		_shoo()
	else:
		_fire_sling()
	_update_hud()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		_right_stick = Vector2.ZERO
		_target_stick_latched = false
		_trigger_latched = [false, false]


func _input(event: InputEvent) -> void:
	if not is_instance_valid(_skill_bar):
		return
	var mode := _input_mode
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.2):
		mode = "controller"
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		mode = "touch"
	elif event is InputEventKey or event is InputEventMouseButton or (event is InputEventMouseMotion and event.relative.length_squared() > 4):
		mode = "keyboard"
	if mode != _input_mode:
		_input_mode = mode
		_update_hud()


func _show_controller_hint() -> void:
	_input_mode = "controller"
	_update_hud()


func _toggle_map() -> void:
	_map_visible = not _map_visible
	_update_hud()


func _toggle_instructions() -> void:
	_instructions_visible = not _instructions_visible
	_update_hud()


func _cycle_sling_target(step: int) -> void:
	var candidates: Array[int] = []
	for id in _active_animals:
		if _valid_sling_target(id) and player_position.distance_to(_animals[id]["position"]) <= SLING_RANGE:
			candidates.append(id)
	# Stable nearest-first order; the first stick flick selects the nearest.
	candidates.sort_custom(func(a: int, b: int) -> bool:
		var da := player_position.distance_squared_to(_animals[a]["position"])
		var db := player_position.distance_squared_to(_animals[b]["position"])
		return a < b if is_equal_approx(da, db) else da < db)
	var current := candidates.find(selected_target)
	selected_target = -1 if candidates.is_empty() else candidates[0 if current < 0 else wrapi(current + step, 0, candidates.size())]
	_update_hud()


func _valid_sling_target(id: int) -> bool:
	return id >= 0 and id < _animals.size() and _active_animals.has(id) and _animals[id]["alive"]


func _select_sling_target(screen_position: Vector2) -> void:
	if _inventory.get_global_rect().has_point(screen_position) or (_minimap.visible and _minimap.get_global_rect().has_point(screen_position)):
		return
	selected_target = -1
	var nearest := INF
	for id in _active_animals:
		if not _valid_sling_target(id):
			continue
		var sprite: AnimatedSprite2D = _active_animals[id]
		var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		var local_point := sprite.get_global_transform_with_canvas().affine_inverse() * screen_position
		var bounds := Rect2(sprite.offset - texture.get_size() * 0.5, texture.get_size()).grow(12.0)
		var distance := local_point.distance_squared_to(sprite.offset)
		if bounds.has_point(local_point) and distance < nearest:
			nearest = distance
			selected_target = id
	_update_hud()


func _sling_ready() -> bool:
	return _valid_sling_target(selected_target) and sling_cooldown <= 0.0 and player_stun <= 0.0 and player_position.distance_to(_animals[selected_target]["position"]) <= SLING_RANGE


func _fire_sling() -> void:
	if not _sling_ready():
		return
	var start := player_position + Vector2(10, -48)
	var destination: Vector2 = _animals[selected_target]["position"] + Vector2(0, -25)
	_stones.append({"target": selected_target, "position": start, "heading": start.direction_to(destination), "age": 0.0, "flight": maxf(0.1, start.distance_to(destination) / STONE_SPEED)})
	sling_cooldown = SLING_COOLDOWN
	_update_hud()


func _update_sling(delta: float) -> void:
	sling_cooldown = maxf(0.0, sling_cooldown - delta)
	if not _valid_sling_target(selected_target):
		selected_target = -1
	for index in range(_stones.size() - 1, -1, -1):
		var stone := _stones[index]
		var id: int = stone["target"]
		stone["age"] = float(stone["age"]) + delta
		if not _valid_sling_target(id) or stone["age"] > 1.5:
			_stones.remove_at(index)
			continue
		var destination: Vector2 = _animals[id]["position"] + Vector2(0, -25)
		var position: Vector2 = stone["position"]
		var step := STONE_SPEED * delta
		if position.distance_to(destination) <= step + ANIMAL_RADIUS[_animals[id]["kind"]]:
			# A hit never extends an existing stun: the stun outlasts the sling
			# cooldown, so refreshing it would let Oravitsa stun-lock an animal.
			if _animals[id]["stun"] <= 0.0:
				_animals[id]["stun"] = SLING_STUN_TIME
			_animals[id]["eat_time"] = 0.0 # A stun interrupts eating, like fear.
			_animals[id]["velocity"] = Vector2.ZERO
			_animals[id]["burst"] = 0.0
			_animals[id]["timeout"] = 0.0
			_active_animals[id].stop()
			_active_animals[id].modulate = Color(0.66, 0.78, 0.91)
			_stones.remove_at(index)
		else:
			stone["heading"] = position.direction_to(destination)
			stone["position"] = position.move_toward(destination, step)
	_sling_effects.queue_redraw()


func _direction_name(direction: Vector2) -> String:
	var angle := wrapi(roundi(direction.angle() / (PI / 4.0)), 0, 8)
	return ["e", "se", "s", "sw", "w", "nw", "n", "ne"][angle]


func _generate_map() -> void:
	terrain.resize(MAP_SIZE * MAP_SIZE)
	objects.resize(MAP_SIZE * MAP_SIZE)
	var grove_noise := FastNoiseLite.new()
	grove_noise.seed = 81824
	grove_noise.frequency = 0.075
	var horizontal_paths: Array[PackedFloat32Array] = []
	var vertical_paths: Array[PackedFloat32Array] = []
	for band in [0.22, 0.5, 0.78]:
		var horizontal := PackedFloat32Array()
		var vertical := PackedFloat32Array()
		horizontal.resize(MAP_SIZE)
		vertical.resize(MAP_SIZE)
		for i in MAP_SIZE:
			horizontal[i] = MAP_SIZE * band + 10.0 * sin(i * 0.075 + band * 8.0) + 4.0 * sin(i * 0.19)
			vertical[i] = MAP_SIZE * band + 13.0 * sin(i * 0.068 + band * 6.0) + 3.0 * cos(i * 0.16)
		horizontal_paths.append(horizontal)
		vertical_paths.append(vertical)
	for y in MAP_SIZE:
		for x in MAP_SIZE:
			var cell := Vector2i(x, y)
			var idx := _index(cell)
			var clearing := Vector2(x - START.x, y - START.y).length_squared() < 36.0
			var path := clearing
			for line in 3:
				if absf(y - horizontal_paths[line][x]) < 1.8 or absf(x - vertical_paths[line][y]) < 1.8:
					path = true
					break
			terrain[idx] = DIRT if path else GRASS
			if x < 2 or y < 2 or x > MAP_SIZE - 3 or y > MAP_SIZE - 3:
				objects[idx] = TREE
				continue
			if clearing or path:
				var food_roll := _hash(x, y, 23)
				objects[idx] = (MUSHROOM if food_roll < 0.012 else BERRIES if food_roll < 0.023 else EMPTY) if not clearing else EMPTY
				continue
			var density := grove_noise.get_noise_2d(x, y)
			var roll := _hash(x, y, 0)
			if roll < 0.09 + maxf(0.0, density) * 0.17:
				objects[idx] = TREE
			elif roll < 0.16 + maxf(0.0, density) * 0.21:
				objects[idx] = BUSH
			elif roll < 0.19:
				objects[idx] = STONE
			elif roll < 0.202:
				objects[idx] = LOG
			elif roll < 0.253:
				objects[idx] = FERN
			elif roll < 0.29:
				objects[idx] = MUSHROOM
			elif roll < 0.323:
				objects[idx] = BERRIES
			else:
				objects[idx] = EMPTY


func _hash(x: int, y: int, salt: int) -> float:
	var n := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791) ^ 472918
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xffff) / 65535.0


func _load_png(path: String) -> Texture2D:
	if _png_cache.has(path):
		return _png_cache[path]
	# Exports contain imported textures, not the source PNG bytes. Keep the raw
	# fallback for running a fresh checkout before the editor imports its art.
	if ResourceLoader.exists(path):
		var imported := load(path) as Texture2D
		if imported != null:
			_png_cache[path] = imported
			return imported
	var bytes := FileAccess.get_file_as_bytes(path)
	var image := Image.new()
	if bytes.is_empty() or image.load_png_from_buffer(bytes) != OK:
		push_error("Cannot read forest art: " + path)
		return null
	var texture := ImageTexture.create_from_image(image)
	_png_cache[path] = texture
	return texture


func _build_world() -> void:
	_ground = TileMapLayer.new()
	_ground.name = "ConnectedGround"
	_ground.z_index = -10
	add_child(_ground)
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	for kind in 2:
		var source := TileSetAtlasSource.new()
		source.texture = _load_png(ART + ("grass.png" if kind == GRASS else "dirt.png"))
		source.texture_region_size = Vector2i(TILE, TILE)
		for ay in 11:
			for ax in 11:
				source.create_tile(Vector2i(ax, ay))
		tile_set.add_source(source, kind)
	_ground.tile_set = tile_set
	_dirt = TileMapLayer.new()
	_dirt.name = "SoftDirt"
	_dirt.z_index = -9
	_dirt.tile_set = tile_set
	var mask := Image.create(MAP_SIZE, MAP_SIZE, false, Image.FORMAT_RGBA8)
	for y in MAP_SIZE:
		for x in MAP_SIZE:
			mask.set_pixel(x, y, Color.WHITE if terrain[y * MAP_SIZE + x] == DIRT else Color.BLACK)
	var material := ShaderMaterial.new()
	material.shader = load("res://scenes/forest_2d/dirt_blend.gdshader")
	material.set_shader_parameter("terrain_mask", ImageTexture.create_from_image(mask))
	material.set_shader_parameter("world_size", float(MAP_SIZE * TILE))
	_dirt.material = material
	add_child(_dirt)
	_blocked_ground = Node2D.new()
	_blocked_ground.name = "BlockedUndergrowth"
	_blocked_ground.z_index = -8
	_blocked_ground.set_script(load("res://scenes/forest_2d/blocked_ground.gd"))
	_blocked_ground.set("forest", self)
	add_child(_blocked_ground)
	_world = Node2D.new()
	_world.name = "YSortedWorld"
	_world.y_sort_enabled = true
	add_child(_world)
	_sling_effects = Node2D.new()
	_sling_effects.name = "SlingEffects"
	_sling_effects.set_script(load("res://scenes/forest_2d/sling_effects.gd"))
	_sling_effects.set("forest", self)
	_sling_effects.z_index = 20
	add_child(_sling_effects)
	for kind in PROP_NAMES:
		var file: String = CHARACTER_ART + "mushrooms.png" if kind == MUSHROOM else ART + PROP_NAMES[kind] + ".png"
		_textures[kind] = _load_png(file)
	_player = AnimatedSprite2D.new()
	_player.name = "Oravitsa"
	_player.sprite_frames = _make_character_frames()
	_player.scale = Vector2.ONE * float(PLAYER_WALK.get_meta("display_scale"))
	_player.offset = Vector2(128, 192) - Vector2(PLAYER_WALK.get_meta("pivot"))
	_player.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_world.add_child(_player)
	_player.animation = "s"
	_camera = Camera2D.new()
	_camera.name = "FollowCamera"
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = MAP_SIZE * TILE
	_camera.limit_bottom = MAP_SIZE * TILE
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 8.0
	add_child(_camera)
	_camera.make_current()
	_build_hud()


func _make_character_frames() -> SpriteFrames:
	return PLAYER_WALK


## Half-size, in cells, of the streamed area: the visible camera area plus margin.
func _stream_half() -> Vector2i:
	var visible := get_viewport_rect().size / _camera.zoom
	return Vector2i(ceili(visible.x * 0.5 / TILE), ceili(visible.y * 0.5 / TILE)) + Vector2i.ONE * STREAM_MARGIN


func _stream_rect(center: Vector2i, half: Vector2i) -> Rect2i:
	var top_left := Vector2i(maxi(0, center.x - half.x), maxi(0, center.y - half.y))
	var bottom_right := Vector2i(mini(MAP_SIZE, center.x + half.x + 1), mini(MAP_SIZE, center.y + half.y + 1))
	return Rect2i(top_left, bottom_right - top_left)


func _refresh_ground(rect: Rect2i) -> void:
	_ground.clear()
	_dirt.clear()
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var sx := posmod(x, 22)
			var sy := posmod(y, 22)
			var flip := 0
			if sx >= 11:
				sx = 21 - sx
				flip |= TileSetAtlasSource.TRANSFORM_FLIP_H
			if sy >= 11:
				sy = 21 - sy
				flip |= TileSetAtlasSource.TRANSFORM_FLIP_V
			_ground.set_cell(Vector2i(x, y), GRASS, Vector2i(sx, sy), flip)
			_dirt.set_cell(Vector2i(x, y), DIRT, Vector2i(sx, sy), flip)


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.10, 0.17, 0.92)
	style.border_color = Color("95876b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	_inventory = Control.new()
	_inventory.set_script(load("res://scenes/forest_2d/inventory_bar.gd"))
	_inventory.name = "Inventory"
	canvas.add_child(_inventory)
	_help_panel = Panel.new()
	_help_panel.add_theme_stylebox_override("panel", style)
	_help_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_help_panel)
	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.add_theme_color_override("font_color", Color("e9dfbb"))
	canvas.add_child(_hint_label)
	_notice_label = Label.new()
	_notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_label.add_theme_font_size_override("font_size", 16)
	_notice_label.add_theme_color_override("font_color", Color("fff1bd"))
	_notice_label.add_theme_color_override("font_shadow_color", Color("101820"))
	_notice_label.add_theme_constant_override("shadow_offset_x", 1)
	_notice_label.add_theme_constant_override("shadow_offset_y", 2)
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	canvas.add_child(_notice_label)
	_map_toggle = _hud_toggle(canvas, _toggle_map)
	_instructions_toggle = _hud_toggle(canvas, _toggle_instructions)
	_save_button = _hud_toggle(canvas, func(): _save_game())
	_load_button = _hud_toggle(canvas, func(): _load_game())
	_skill_bar = Control.new()
	_skill_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_bar.size = Vector2(212, 108)
	canvas.add_child(_skill_bar)
	_shoo_button = _skill_button("Shoo", func(): _use_skill(0))
	_shoo_button.position = Vector2.ZERO
	_sling_button = _skill_button("Sling", func(): _use_skill(1))
	_sling_button.position = Vector2(112, 0)
	_sling_label = Label.new()
	_sling_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sling_label.add_theme_font_size_override("font_size", 14)
	_sling_label.add_theme_color_override("font_color", Color("f4d58a"))
	_sling_label.add_theme_color_override("font_shadow_color", Color("101820"))
	_sling_label.add_theme_constant_override("shadow_offset_x", 1)
	_sling_label.add_theme_constant_override("shadow_offset_y", 2)
	_sling_label.position = Vector2(0, -25)
	_skill_bar.add_child(_sling_label)
	_skill_hint_label = Label.new()
	_skill_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_hint_label.add_theme_font_size_override("font_size", 13)
	_skill_hint_label.add_theme_color_override("font_color", Color("f4d58a"))
	_skill_hint_label.add_theme_color_override("font_shadow_color", Color("101820"))
	_skill_hint_label.add_theme_constant_override("shadow_offset_x", 1)
	_skill_hint_label.add_theme_constant_override("shadow_offset_y", 2)
	_skill_hint_label.position = Vector2(0, -47)
	_skill_bar.add_child(_skill_hint_label)
	_minimap = Control.new()
	_minimap.set_script(_minimap_script())
	_minimap.name = "Minimap"
	_minimap.custom_minimum_size = Vector2(244, 272)
	_minimap.size = Vector2(244, 272)
	_minimap.set("forest", self)
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_minimap)
	_touch_controls = Control.new()
	_touch_controls.set_script(load("res://scenes/forest_2d/touch_controls.gd"))
	_touch_controls.name = "TouchControls"
	_touch_controls.shoo_requested.connect(func(): _use_skill(0))
	_touch_controls.sling_requested.connect(func(): _use_skill(1))
	_touch_controls.touch_mode_changed.connect(func():
		_input_mode = "touch"
		_layout_hud())
	canvas.add_child(_touch_controls)
	get_viewport().size_changed.connect(_layout_hud)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_layout_hud()


func _hud_toggle(canvas: CanvasLayer, callback: Callable) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1a2a3e")
	style.border_color = Color("bca677")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", style)
	button.pressed.connect(callback)
	canvas.add_child(button)
	return button


func _skill_button(skill: String, callback: Callable) -> Button:
	var button := Button.new()
	button.set_script(load("res://scenes/forest_2d/skill_button.gd"))
	button.set("skill", skill)
	button.size = Vector2(100, 108)
	button.pressed.connect(callback)
	_skill_bar.add_child(button)
	return button


func _on_viewport_resized() -> void:
	if _stream_half() != _loaded_half:
		_refresh_visible()


func _layout_hud() -> void:
	var touch: bool = _touch_controls.touch_enabled
	if touch:
		var window := get_window()
		var wanted := Vector2i(960, 540) if window.size.x >= window.size.y else Vector2i(540, 960)
		if window.content_scale_size != wanted:
			window.content_scale_size = wanted
			call_deferred("_layout_hud")
			return
	var viewport_size := get_viewport_rect().size
	var map_scale := 0.58 if touch and viewport_size.x < 800.0 else (0.8 if touch else 1.0)
	_minimap.scale = Vector2.ONE * map_scale
	_minimap.position = Vector2(viewport_size.x - 20.0 - 244.0 * map_scale, 60.0)
	_map_toggle.position = Vector2(_minimap.position.x, 16)
	_map_toggle.size = Vector2(244.0 * map_scale, 32)
	_inventory.position = Vector2(viewport_size.x - 262, viewport_size.y - 104)
	_notice_label.position = _inventory.position + Vector2(-60, -52)
	_notice_label.size = Vector2(_inventory.size.x + 60, 24)
	_instructions_toggle.position = Vector2(18, 16)
	_instructions_toggle.size = Vector2(180, 32)
	_help_panel.position = Vector2(18, 60)
	_help_panel.size = Vector2(minf(340.0, _minimap.position.x - 36.0), 164)
	_save_button.position = _help_panel.position + Vector2(0, _help_panel.size.y + 8)
	_save_button.size = Vector2(124, 32)
	_load_button.position = _save_button.position + Vector2(132, 0)
	_load_button.size = Vector2(124, 32)
	_hint_label.position = _help_panel.position + Vector2(12, 9)
	_hint_label.size = _help_panel.size - Vector2(24, 18)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skill_bar.position = Vector2(18, viewport_size.y - 126)
	_update_hud()


func _refresh_visible() -> void:
	var center := _world_cell(player_position)
	_loaded_center = center
	_loaded_half = _stream_half()
	var rect := _stream_rect(center, _loaded_half)
	_refresh_ground(rect)
	_blocked_ground.queue_redraw()
	var wanted := {}
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			var kind: int = objects[_index(cell)]
			if kind == EMPTY:
				continue
			wanted[cell] = true
			if not _active_props.has(cell):
				_active_props[cell] = _make_prop(cell, kind)
	for cell in _active_props.keys():
		if not wanted.has(cell):
			_active_props[cell].queue_free()
			_active_props.erase(cell)
	_refresh_animals(center)


func _make_prop(cell: Vector2i, kind: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = PROP_NAMES[kind].capitalize() + "_%d_%d" % [cell.x, cell.y]
	sprite.texture = _textures[kind]
	sprite.position = _cell_center(cell)
	sprite.scale = Vector2.ONE * {TREE: 0.18, BUSH: 0.11, STONE: 0.09, MUSHROOM: 0.06, FERN: 0.075, LOG: 0.09, BERRIES: 0.052}[kind]
	sprite.offset.y = -sprite.texture.get_height() * {TREE: 0.30, BUSH: 0.17, STONE: 0.08, MUSHROOM: 0.08, FERN: 0.10, LOG: 0.08, BERRIES: 0.04}[kind]
	sprite.flip_h = _hash(cell.x, cell.y, 71) > 0.5
	_world.add_child(sprite)
	return sprite


func _seed_animals() -> void:
	# Hares introduce wildlife immediately; rarer species are found by exploring.
	for offset in [Vector2i(-4, 0), Vector2i(4, 0), Vector2i(-3, 2), Vector2i(3, -2)]:
		_add_animal(HARE, START + offset)
	for sector_y in range(1, MAP_SIZE / 24 - 1):
		for sector_x in range(1, MAP_SIZE / 24 - 1):
			if _hash(sector_x, sector_y, 101) > 0.65:
				continue
			var cell := Vector2i(
				sector_x * 24 + 4 + int(_hash(sector_x, sector_y, 102) * 16.0),
				sector_y * 24 + 4 + int(_hash(sector_x, sector_y, 103) * 16.0)
			)
			if _can_stand(_cell_center(cell)) and cell.distance_to(START) > 8.0:
				_add_animal(_spawn_kind(_hash(sector_x, sector_y, 104)), cell)


func _spawn_kind(sample: float) -> int:
	var weight := sample * 100.0
	for kind in SPAWN_WEIGHTS:
		weight -= SPAWN_WEIGHTS[kind]
		if weight < 0.0:
			return kind
	return LYNX


func _add_animal(kind: int, cell: Vector2i) -> void:
	assert(_can_stand(_cell_center(cell), ANIMAL_RADIUS[kind]))
	_animals.append(_animal_record(kind, _cell_center(cell)))


## A fresh animal state; subclasses add their fields so restores share defaults.
func _animal_record(kind: int, position: Vector2) -> Dictionary:
	return {
		"kind": kind,
		"position": position,
		"target": position,
		"timeout": 0.0,
		"turn": 0,
		"home": position,
		"stun": 0.0,
		"shoo": 0.0,
		"velocity": Vector2.ZERO,
		"facing": Vector2.DOWN,
		"state": "idle",
		"food_cell": Vector2i(-1, -1),
		"eat_time": 0.0,
		"alive": true,
		"respawn": 0.0,
		"feeding": 0.0,
		"burst": 0.0,
		"burst_cooldown": 0.0,
		"catch_target": -1,
		"catch_time": 0.0
	}


func _refresh_animals(center: Vector2i) -> void:
	var wanted := {}
	for id in _animals.size():
		if not _animals[id]["alive"]:
			continue
		var cell := _world_cell(_animals[id]["position"])
		if abs(cell.x - center.x) <= _loaded_half.x + 2 and abs(cell.y - center.y) <= _loaded_half.y + 2:
			wanted[id] = true
			if not _active_animals.has(id):
				var sprite := _make_animal_sprite(id)
				if sprite != null:
					_active_animals[id] = sprite
	for id in _active_animals.keys():
		if not wanted.has(id):
			_active_animals[id].queue_free()
			_active_animals.erase(id)


func _make_animal_sprite(id: int) -> AnimatedSprite2D:
	var kind: int = _animals[id]["kind"]
	var animal_name: String = ["boar", "deer", "fox", "lynx", "hare"][kind]
	var frames := SpriteFrames.new()
	var texture: Texture2D
	for direction in ["e", "se", "s", "ne", "n"]:
		frames.add_animation(direction)
		frames.set_animation_speed(direction, 7.0 if kind == BOAR else 9.0)
		var filename: String = ART + animal_name + "_walk_" + direction + ".png"
		# The original diagonal strip anchors the species' painted look.
		if direction == "se" and kind != HARE:
			filename = (CHARACTER_ART if kind <= DEER else ART) + animal_name + "_walk.png"
		texture = _load_png(filename)
		if texture == null:
			return null
		var width := float(texture.get_width()) / 4.0
		var sequence := [0, 1, 2, 3] if direction == "se" else [0, 1, 2, 1]
		for i in sequence:
			var frame := AtlasTexture.new()
			frame.atlas = texture
			frame.region = Rect2(width * i, 0, width, texture.get_height())
			frames.add_frame(direction, frame)
	var sprite := AnimatedSprite2D.new()
	sprite.name = ANIMAL_NAMES[kind] + "_%d" % id
	sprite.sprite_frames = frames
	sprite.scale = Vector2.ONE * [0.16, 0.17, 0.14, 0.15, 0.115][kind]
	sprite.offset = Vector2(0, -texture.get_height() * 0.35)
	sprite.position = _animals[id]["position"]
	_world.add_child(sprite)
	sprite.play("s")
	return sprite


func _choose_animal_target(id: int) -> void:
	var data := _animals[id]
	var cell := _world_cell(data["position"])
	var turn: int = data["turn"] + 1
	data["turn"] = turn
	for attempt in 16:
		var angle := _hash(id, turn + attempt, 201) * TAU
		var distance := 2 + int(_hash(id, turn + attempt, 202) * 5.0)
		var target_cell := cell + Vector2i(roundi(cos(angle) * distance), roundi(sin(angle) * distance))
		if _in_bounds(target_cell) and _can_stand(_cell_center(target_cell)) and _cell_center(target_cell).distance_to(data["home"]) < 720.0:
			data["target"] = _cell_center(target_cell)
			data["timeout"] = 5.0 + _hash(id, turn, 203) * 3.0
			data["state"] = "roam"
			return
	data["target"] = data["position"]
	data["timeout"] = 2.0
	data["state"] = "idle"


func _nearest_animal(position: Vector2, kinds: Array, except_id: int, radius: float) -> int:
	var nearest := -1
	var best := radius * radius
	for other_id in _active_animals.keys():
		if other_id == except_id or not _animals[other_id]["alive"] or _animals[other_id]["kind"] not in kinds:
			continue
		var distance: float = position.distance_squared_to(_animals[other_id]["position"])
		if distance < best:
			best = distance
			nearest = other_id
	return nearest


func _nearest_food(position: Vector2, kind: int) -> Vector2i:
	var center := _world_cell(position)
	var best := 99999999.0
	var result := Vector2i(-1, -1)
	for y in range(center.y - 4, center.y + 5):
		for x in range(center.x - 4, center.x + 5):
			var cell := Vector2i(x, y)
			if not _in_bounds(cell):
				continue
			if objects[_index(cell)] not in _food_kinds(kind):
				continue
			var distance := position.distance_squared_to(_cell_center(cell))
			if distance < best:
				best = distance
				result = cell
	return result


func _consume_food(cell: Vector2i) -> void:
	if not _in_bounds(cell) or objects[_index(cell)] not in [MUSHROOM, BERRIES]:
		return
	objects[_index(cell)] = EMPTY
	if _active_props.has(cell):
		_active_props[cell].queue_free()
		_active_props.erase(cell)


func _can_animal_move(id: int, candidate: Vector2) -> bool:
	var kind: int = _animals[id]["kind"]
	if not _can_stand(candidate, ANIMAL_RADIUS[kind]):
		return false
	if candidate.distance_to(player_position) < ANIMAL_RADIUS[kind] + PLAYER_RADIUS:
		return false
	for other_id in _active_animals.keys():
		if other_id == id or not _animals[other_id]["alive"]:
			continue
		var other := _animals[other_id]
		if candidate.distance_to(other["position"]) < ANIMAL_RADIUS[kind] + ANIMAL_RADIUS[other["kind"]]:
			return false
	return true


func _shoo() -> void:
	if not _shoo_ready():
		return
	shoo_cooldown = SHOO_COOLDOWN
	var data := _animals[selected_target]
	var away: Vector2 = (data["position"] - player_position).normalized()
	if away.length_squared() < 0.01:
		away = Vector2.DOWN
	data["shoo"] = SHOO_FEAR_TIME
	data["state"] = "scared"
	data["stun"] = 0.0
	data["feeding"] = 0.0
	data["eat_time"] = 0.0
	data["burst"] = 0.0
	data["catch_target"] = -1
	data["catch_time"] = 0.0
	data["timeout"] = 0.0
	data["velocity"] = away * SHOO_FLEE_SPEED
	if data.has("route"):
		data["route"] = PackedVector2Array()
		data["nav_cooldown"] = 0.0
		data["stuck"] = 0.0
		data["progress_time"] = 0.0
		data["progress_origin"] = data["position"]


func _shoo_ready() -> bool:
	return _valid_sling_target(selected_target) and shoo_cooldown <= 0 and player_stun <= 0 and player_position.distance_to(_animals[selected_target]["position"]) <= SHOO_RANGE


func _catch_prey(lynx_id: int, prey_id: int, delta: float = 0.0) -> bool:
	var lynx := _animals[lynx_id]
	var prey := _animals[prey_id]
	if not prey["alive"] or prey["kind"] not in _prey_kinds(lynx["kind"]):
		return false
	if prey["kind"] == DEER:
		if lynx["catch_target"] != prey_id:
			lynx["catch_time"] = 0.0
		lynx["catch_target"] = prey_id
		lynx["catch_time"] += delta
		if lynx["catch_time"] < DEER_CATCH_TIME:
			return false
	lynx["catch_target"] = -1
	lynx["catch_time"] = 0.0
	prey["alive"] = false
	prey["respawn"] = PREY_RESPAWN_TIME
	prey["velocity"] = Vector2.ZERO
	lynx["feeding"] = 1.7
	lynx["burst"] = 0.0
	lynx["velocity"] = Vector2.ZERO
	lynx["state"] = "feed"
	if prey["kind"] == DEER:
		deer_caught += 1
	else:
		hares_caught += 1
	if _active_animals.has(prey_id):
		_active_animals[prey_id].queue_free()
		_active_animals.erase(prey_id)
	return true


func _is_predator(kind: int) -> bool:
	return kind in [LYNX, WOLF]


## Prey species a hunter pursues; empty for animals that never hunt.
func _prey_kinds(kind: int) -> Array:
	return [DEER, HARE] if _is_predator(kind) else []


## Species an animal flees from on sight.
func _threat_kinds(kind: int) -> Array:
	if kind == FOX:
		return [BOAR, DEER, FOX, LYNX, HARE, WOLF]
	return [LYNX, WOLF] if kind in [DEER, HARE] else []


## Aggression phase toward Oravitsa; only the endless world provokes animals.
func _aggression(_id: int) -> int:
	return AGGRO_NONE


func _is_fighting(_id: int) -> bool:
	return false


func _charge_speed(kind: int) -> float:
	return ANIMAL_SPEEDS[kind]


## Food an animal forages for; hunting nearby prey takes priority over it.
func _food_kinds(kind: int) -> Array:
	if kind == BOAR:
		return [BERRIES, MUSHROOM]
	return [BERRIES] if kind in [DEER, HARE] else []


func _wants_to_hunt(id: int) -> bool:
	return not _prey_kinds(_animals[id]["kind"]).is_empty()


## Chase spurt speed, duration and recovery (measured from the spurt's start).
func _burst_profile(_kind: int) -> Vector3:
	return Vector3(LYNX_BURST_SPEED, LYNX_BURST_TIME, LYNX_BURST_RECOVERY)


func _update_respawns(delta: float) -> void:
	var refreshed := false
	for id in _animals.size():
		var data := _animals[id]
		if data["alive"] or not _should_respawn(id):
			continue
		data["respawn"] = maxf(0.0, float(data["respawn"]) - delta)
		if data["respawn"] > 0.0:
			continue
		var home: Vector2 = data["home"]
		if home.distance_to(player_position) < 450.0 or not _spawn_is_hidden(home, data["kind"]) or not _can_animal_move(id, home):
			data["respawn"] = 3.0
			continue
		data["position"] = home
		data["target"] = home
		data["timeout"] = 0.0
		data["state"] = "idle"
		data["alive"] = true
		refreshed = true
	if refreshed:
		_refresh_animals(_loaded_center)


func _should_respawn(_id: int) -> bool:
	return true


func _local_population(kind: int) -> int:
	var count := 0
	for animal in _animals:
		if animal["alive"] and animal["kind"] == kind and animal["position"].distance_to(player_position) <= _population_radius():
			count += 1
	return count


func _population_radius() -> float:
	return POPULATION_RADIUS


func _spawn_is_hidden(_spot: Vector2, _kind: int) -> bool:
	# The original 2D scene retains its distance-based exclusion below.
	return true


func _local_spawn_cell(kind: int, attempt: int) -> Vector2i:
	var angle := _hash(_population_tick + attempt, kind, 801) * TAU
	var distance := 7 + int(_hash(_population_tick + attempt, kind, 802) * 3.0)
	return _world_cell(player_position) + Vector2i(roundi(cos(angle) * distance), roundi(sin(angle) * distance))


func _find_local_spawn(kind: int) -> Vector2i:
	# Enter from outside the camera rather than appearing beside Oravitsa.
	for attempt in 48:
		var cell := _local_spawn_cell(kind, attempt)
		if not _in_bounds(cell):
			continue
		var spot := _cell_center(cell)
		if spot.distance_to(player_position) < 730.0 or not _spawn_is_hidden(spot, kind) or not _can_stand(spot, ANIMAL_RADIUS[kind]):
			continue
		var clear := true
		for animal in _animals:
			if animal["alive"] and animal["position"].distance_to(spot) < 150.0:
				clear = false
				break
		if clear:
			return cell
	return Vector2i(-1, -1)


func _replenish_local_animals() -> void:
	var changed := false
	_population_tick += 1
	for kind in LOCAL_POPULATION:
		# A shortage permits a spawn, but does not guarantee a rare encounter.
		if _hash(_population_tick, kind, 803) >= REPLENISH_CHANCE[kind]:
			continue
		for missing in maxi(0, int(LOCAL_POPULATION[kind]) - _local_population(kind)):
			var cell := _find_local_spawn(kind)
			if cell.x < 0:
				break
			var donor := -1
			for id in _animals.size():
				var animal := _animals[id]
				if animal["kind"] == kind and not _active_animals.has(id) and animal["position"].distance_to(player_position) > _population_radius() * 1.5:
					donor = id
					break
			if donor < 0:
				if _animals.size() >= 260:
					break
				_add_animal(kind, cell)
			else:
				var data := _animals[donor]
				data["position"] = _cell_center(cell)
				data["home"] = data["position"]
				data["target"] = data["position"]
				data["velocity"] = Vector2.ZERO
				data["timeout"] = 0.0
				data["stun"] = 0.0
				data["shoo"] = 0.0
				data["feeding"] = 0.0
				data["respawn"] = 0.0
				data["alive"] = true
				data["state"] = "idle"
				data["catch_target"] = -1
				data["catch_time"] = 0.0
			changed = true
	if changed:
		_refresh_animals(_loaded_center)


func _move_animals(delta: float) -> void:
	for id in _active_animals.keys():
		if not _active_animals.has(id) or not _animals[id]["alive"]:
			continue
		var data := _animals[id]
		# Only consecutive frames holding the same prey retain catch progress.
		var previous_catch_target: int = data["catch_target"]
		var previous_catch_time: float = data["catch_time"]
		data["catch_target"] = -1
		data["catch_time"] = 0.0
		var position: Vector2 = data["position"]
		var kind: int = data["kind"]
		var sprite: AnimatedSprite2D = _active_animals[id]
		data["stun"] = maxf(0.0, data["stun"] - delta)
		data["shoo"] = maxf(0.0, data["shoo"] - delta)
		sprite.speed_scale = 2.2 if data["shoo"] > 0 else 1.0
		if data["shoo"] <= 0.0 and data["state"] == "scared":
			data["state"] = "idle"
			data["timeout"] = 0.0
		var was_feeding: bool = data["feeding"] > 0.0
		data["feeding"] = maxf(0.0, data["feeding"] - delta)
		if was_feeding and data["feeding"] <= 0.0:
			data["state"] = "idle"
			data["timeout"] = 0.0
		data["burst"] = maxf(0.0, data["burst"] - delta)
		data["burst_cooldown"] = maxf(0.0, data["burst_cooldown"] - delta)
		if data["stun"] > 0.0:
			sprite.stop()
			sprite.modulate = Color(0.66, 0.78, 0.91)
			continue
		sprite.modulate = Color.WHITE
		if data["feeding"] > 0.0:
			sprite.stop()
			continue
		data["timeout"] = float(data["timeout"]) - delta
		var target: Vector2 = data["target"]
		var speed: float = ANIMAL_SPEEDS[kind]
		var threat := -1
		var threats := _threat_kinds(kind)
		if not threats.is_empty():
			threat = _nearest_animal(position, threats, id, 310.0 if kind == FOX else 340.0)
		# Hunters with no prey in reach fall through to foraging or roaming.
		var prey := _nearest_animal(position, _prey_kinds(kind), id, 650.0) if _wants_to_hunt(id) else -1
		var player_distance := position.distance_to(player_position)
		var avoid_player := player_distance < (135.0 if kind == BOAR else 235.0)
		if kind == BOAR and _hash(id, 0, 451) < 0.45 and player_distance > 80.0:
			avoid_player = false
		if data["shoo"] > 0.0:
			var away: Vector2 = (position - player_position).normalized()
			if away.length_squared() < 0.01:
				away = Vector2.DOWN
			target = position + away * 600
			data["state"] = "scared"
			speed = maxf(SHOO_FLEE_SPEED, ANIMAL_SPEEDS[kind] * 2.4)
		elif _is_fighting(id):
			# Fighting animals square off in place until the fight resolves.
			data["velocity"] = Vector2.ZERO
			data["state"] = "fight"
			sprite.stop()
			continue
		elif _aggression(id) == AGGRO_WARN:
			# A provoked animal stands its ground facing Oravitsa before charging.
			data["velocity"] = Vector2.ZERO
			data["state"] = "warn"
			sprite.stop()
			continue
		elif _aggression(id) == AGGRO_CHARGE:
			target = player_position
			data["state"] = "charge"
			speed = _charge_speed(kind)
		elif threat >= 0 or avoid_player:
			var away := Vector2.ZERO
			if avoid_player:
				away += (position - player_position).normalized()
			if threat >= 0:
				away += (position - _animals[threat]["position"]).normalized() * 1.4
			if away.length_squared() > 0.01:
				target = position + away.normalized() * 300.0
			data["state"] = "flee"
			speed *= 1.35 if kind != BOAR else 1.1
		elif position.distance_to(data["home"]) > 850.0:
			target = data["home"]
			data["state"] = "return"
		elif prey >= 0:
			var prey_position: Vector2 = _animals[prey]["position"]
			if position.distance_to(prey_position) <= ANIMAL_RADIUS[kind] + ANIMAL_RADIUS[_animals[prey]["kind"]] + 8.0:
				if previous_catch_target == prey:
					data["catch_target"] = previous_catch_target
					data["catch_time"] = previous_catch_time
				if _catch_prey(id, prey, delta):
					sprite.stop()
					continue
			target = prey_position
			data["state"] = "hunt"
			var burst := _burst_profile(kind)
			if data["burst_cooldown"] <= 0.0 and position.distance_to(prey_position) < 410.0:
				data["burst"] = burst.y
				data["burst_cooldown"] = burst.z
			speed = burst.x if data["burst"] > 0.0 or data["catch_target"] == prey else ANIMAL_SPEEDS[kind]
		elif not _food_kinds(kind).is_empty():
			var food_cell: Vector2i = data["food_cell"]
			if not _in_bounds(food_cell) or objects[_index(food_cell)] not in _food_kinds(kind):
				food_cell = _nearest_food(position, kind)
				data["food_cell"] = food_cell
			if _in_bounds(food_cell):
				target = _cell_center(food_cell)
				data["state"] = "forage"
				if position.distance_to(target) < 37.0:
					data["eat_time"] = float(data["eat_time"]) + delta
					if data["eat_time"] >= 0.7:
						_consume_food(food_cell)
						data["food_cell"] = Vector2i(-1, -1)
						data["eat_time"] = 0.0
						data["timeout"] = 0.0
					sprite.stop()
					continue
				else:
					data["eat_time"] = 0.0
		if data["state"] in ["roam", "idle", "return"] and (position.distance_to(target) < 15.0 or data["timeout"] <= 0.0 and data["state"] != "return"):
			_choose_animal_target(id)
			target = data["target"]
		if data["state"] in ["flee", "hunt", "forage"] and target == data["target"]:
			_choose_animal_target(id)
			target = data["target"]
		var heading := _steer_animal(id, position.direction_to(target), target, delta)
		var velocity: Vector2 = data["velocity"]
		velocity = velocity.move_toward(heading * speed, (520.0 if data["burst"] > 0.0 or data["state"] == "charge" else 290.0) * delta)
		data["velocity"] = velocity
		var step: Vector2 = velocity * delta
		var candidate := position
		if _can_animal_move(id, candidate + Vector2(step.x, 0)):
			candidate.x += step.x
		if _can_animal_move(id, candidate + Vector2(0, step.y)):
			candidate.y += step.y
		if candidate.distance_squared_to(position) < 0.1 and heading.length_squared() > 0.1:
			var side := Vector2(-heading.y, heading.x) * (1.0 if _hash(id, data["turn"], 377) < 0.5 else -1.0) * speed * delta
			if _can_animal_move(id, position + side):
				candidate = position + side
		if candidate.distance_squared_to(position) < 0.1:
			data["velocity"] = Vector2.ZERO
			if data["state"] == "roam":
				data["timeout"] = 0.0
		data["position"] = candidate
		sprite.position = candidate
		if candidate.distance_squared_to(position) > 0.1:
			data["facing"] = velocity.normalized()
			var facing: String = _direction_name(data["facing"])
			var base: String = {"w": "e", "sw": "se", "nw": "ne"}.get(facing, facing)
			sprite.flip_h = facing in ["w", "sw", "nw"]
			if sprite.animation != base or not sprite.is_playing():
				sprite.play(base)
		else:
			sprite.stop()


func _steer_animal(_id: int, heading: Vector2, _target: Vector2, _delta: float) -> Vector2:
	return heading


func _try_move(step: Vector2) -> bool:
	if player_stun > 0.0:
		return false
	var candidate := player_position + step
	candidate.x = clampf(candidate.x, 16.0, MAP_SIZE * TILE - 16.0)
	candidate.y = clampf(candidate.y, 12.0, MAP_SIZE * TILE - 12.0)
	if not _can_stand(candidate, PLAYER_RADIUS):
		return false
	for id in _active_animals.keys():
		var animal := _animals[id]
		if not animal["alive"]:
			continue
		if candidate.distance_to(animal["position"]) < PLAYER_RADIUS + ANIMAL_RADIUS[animal["kind"]]:
			player_stun = CONTACT_STUN_TIME
			animal["stun"] = maxf(animal["stun"], CONTACT_STUN_TIME)
			animal["velocity"] = Vector2.ZERO
			return false
	player_position = candidate
	return true


func _can_stand(point: Vector2, actor_radius: float = PLAYER_RADIUS) -> bool:
	var center := _world_cell(point)
	if center.x < 2 or center.y < 2 or center.x >= MAP_SIZE - 2 or center.y >= MAP_SIZE - 2:
		return false
	for y in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			var cell := Vector2i(x, y)
			if not _in_bounds(cell):
				return false
			var kind: int = objects[_index(cell)]
			if kind in BLOCKED and point.distance_to(_cell_center(cell)) < actor_radius + BLOCKER_RADIUS[kind]:
				return false
	return true


func _collect_nearby() -> void:
	var center := _world_cell(player_position)
	for y in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			var cell := Vector2i(x, y)
			if not _in_bounds(cell) or objects[_index(cell)] not in [MUSHROOM, BERRIES]:
				continue
			if player_position.distance_to(_cell_center(cell)) <= PICKUP_RADIUS:
				if objects[_index(cell)] == MUSHROOM:
					basket += 1
				else:
					berries_basket += 1
				_consume_food(cell)
				_update_hud()
	var hare := _stunned_hare_near(HARE_PICKUP_RADIUS)
	if hare >= 0 and player_stun <= 0.0:
		_collect_hare(hare)


## Nearest living, stunned hare within reach; only those can be collected.
func _stunned_hare_near(radius: float) -> int:
	var nearest := -1
	var best := radius
	for id in _active_animals:
		var animal := _animals[id]
		if animal["alive"] and animal["kind"] == HARE and animal["stun"] > 0.0:
			var distance := player_position.distance_to(animal["position"])
			if distance <= best:
				best = distance
				nearest = id
	return nearest


func _collect_hare(id: int) -> void:
	var data := _animals[id]
	if not data["alive"] or data["kind"] != HARE or data["stun"] <= 0.0:
		return
	# Removing it from the living set first makes collection happen once.
	data["alive"] = false
	data["stun"] = 0.0
	data["shoo"] = 0.0
	data["velocity"] = Vector2.ZERO
	_on_hare_collected(id)
	raw_meat += 1
	if _active_animals.has(id):
		_active_animals[id].queue_free()
		_active_animals.erase(id)
	if selected_target == id:
		selected_target = -1
	_show_notice("+1 raw meat")
	_update_hud()


## Finite scenes return a collected hare like a caught one, away from view.
func _on_hare_collected(id: int) -> void:
	_animals[id]["respawn"] = PREY_RESPAWN_TIME


func _show_notice(text: String, seconds: float = 2.5) -> void:
	_notice_label.text = text
	_notice_time = seconds
	_notice_duration = seconds


## Saving is offered only where a scene supports it (the endless woods).
func _can_save() -> bool:
	return false


func _save_game() -> void:
	pass


func _load_game() -> void:
	pass


func _update_hud() -> void:
	_inventory.set("mushrooms", basket)
	_inventory.set("berries", berries_basket)
	_inventory.set("meat", raw_meat)
	var prompt := "A / Cross: pick up" if _input_mode == "controller" else "Foraging bag"
	if player_stun <= 0.0 and _stunned_hare_near(HARE_NOTICE_RADIUS) >= 0:
		if _input_mode == "controller":
			prompt = "A / Cross: take stunned hare" if _stunned_hare_near(HARE_PICKUP_RADIUS) >= 0 else "Get closer to take the hare"
		else:
			prompt = "Walk to the stunned hare to take it"
	_inventory.set("pickup_prompt", prompt)
	_notice_label.visible = _notice_time > 0.0
	_notice_label.modulate.a = clampf(_notice_time / 0.6, 0.0, 1.0)
	_inventory.queue_redraw()
	_minimap.visible = _map_visible
	_help_panel.visible = _instructions_visible
	_hint_label.visible = _instructions_visible
	_save_button.visible = _instructions_visible and _can_save()
	_load_button.visible = _save_button.visible
	var controller := _input_mode == "controller"
	var touch := _input_mode == "touch"
	_skill_hint_label.visible = controller
	_skill_hint_label.text = "LT: Shoo · RT: Sling · LB / RB + Y"
	_map_toggle.text = ("− Map" if _map_visible else "+ Map") + (" [Select]" if controller else ("" if touch else " [M]"))
	_instructions_toggle.text = ("− Help" if _instructions_visible else "+ Help") + (" [Start]" if controller else ("" if touch else " [H]"))
	_save_button.text = "Save game" + (" [X]" if controller else ("" if touch else " [K]"))
	_load_button.text = "Load game" + (" [B]" if controller else ("" if touch else " [L]"))
	if controller:
		_hint_label.text = "Left stick / D-pad: walk\nRight stick: cycle targets\nLT / L2: Shoo · RT / R2: Sling\nLB / RB: select skill · Y / Triangle: cast it\nA / Cross: pick up · Select: map · Start: help"
	elif touch:
		_hint_label.text = "Right thumb stick: walk\nTap an animal to select\nTap Shoo or Sling on that target\nWalk over mushrooms & berries\nUse the top buttons to hide panels"
	else:
		_hint_label.text = "WASD / arrows: walk\nLeft click: select an animal\nRight click / F: sling target\nSpace: scare selected animal\nM: map · H: instructions"
	if _can_save():
		_hint_label.text += "\n" + ("X: save game · B: load game" if controller else ("Save or load with the buttons below" if touch else "K: save game · L: load game"))
	var target_name: String = ANIMAL_NAMES[_animals[selected_target]["kind"]] if _valid_sling_target(selected_target) else ""
	_sling_label.text = "Right stick: select target" if controller else ("Tap animal to target" if touch else "Click animal to target")
	if not target_name.is_empty():
		_sling_label.text = target_name + (" · Out of range" if player_position.distance_to(_animals[selected_target]["position"]) > SLING_RANGE else " · Selected")
	if player_stun > 0:
		_sling_label.text = "Recovering %.1fs" % player_stun
	_shoo_button.disabled = not _shoo_ready()
	_sling_button.disabled = not _sling_ready()
	_shoo_button.set("cooldown", shoo_cooldown)
	_sling_button.set("cooldown", sling_cooldown)
	_sling_button.set("cooldown_duration", SLING_COOLDOWN)
	_shoo_button.set("prompt", ("LT · Y" if active_skill == 0 else "LT") if controller else ("TAP" if touch else "SPACE"))
	_sling_button.set("prompt", ("RT · Y" if active_skill == 1 else "RT") if controller else ("TAP" if touch else "RMB / F"))
	_shoo_button.set("active", active_skill == 0)
	_sling_button.set("active", active_skill == 1)
	_shoo_button.queue_redraw()
	_sling_button.queue_redraw()
	if _touch_controls.touch_enabled:
		_touch_controls.cooldown = shoo_cooldown
		_touch_controls.stunned = player_stun > 0.0
		_touch_controls.sling_cooldown = sling_cooldown
		_touch_controls.sling_available = _sling_ready()
		_touch_controls.queue_redraw()


func _minimap_script() -> Script:
	return load("res://scenes/forest_2d/minimap.gd")


func _index(cell: Vector2i) -> int:
	return cell.y * MAP_SIZE + cell.x


func _world_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / TILE), floori(point.y / TILE))


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE + Vector2.ONE * (TILE * 0.5)


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < MAP_SIZE and cell.y < MAP_SIZE
