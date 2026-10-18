extends Node2D

## A finite, seeded forest made of connected painted ground tiles. Ground,
## props, and animals are streamed around the camera; map data drives collision.

const TILE := 114
const MAP_SIZE := 416
const ART := "res://scenes/forest_2d/art/"
const CHARACTER_ART := "res://prototypes/foraging_2d/art/"
const SPEED := 210.0
const PICKUP_RADIUS := 40.0
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
const BLOCKED := [TREE, BUSH, STONE, LOG]
const PROP_NAMES := {TREE: "tree", BUSH: "bush", STONE: "stone", MUSHROOM: "mushroom", FERN: "fern", LOG: "log"}
const BOAR := 0
const DEER := 1
const FOX := 2
const LYNX := 3
const ANIMAL_NAMES := {BOAR: "Boar", DEER: "Deer", FOX: "Fox", LYNX: "Lynx"}
const ANIMAL_SPEEDS := {BOAR: 75.0, DEER: 105.0, FOX: 95.0, LYNX: 88.0}

var terrain := PackedByteArray()
var objects := PackedByteArray()
var player_position := Vector2.ZERO
var basket := 0
var _ground: TileMapLayer
var _dirt: TileMapLayer
var _world: Node2D
var _player: AnimatedSprite2D
var _camera: Camera2D
var _minimap: Control
var _count_label: Label
var _active_props: Dictionary = {}
var _animals: Array[Dictionary] = []
var _active_animals: Dictionary = {}
var _textures: Dictionary = {}
var _loaded_center := Vector2i(-999, -999)
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
	var direction := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if direction.length_squared() > 0.0:
		var step := direction.normalized() * SPEED * delta
		_try_move(Vector2(step.x, 0.0))
		_try_move(Vector2(0.0, step.y))
		var wanted := "side" if absf(direction.x) > absf(direction.y) * 1.15 else ("away" if direction.y < 0.0 else "toward")
		if _player.animation != wanted or not _player.is_playing():
			_player.play(wanted)
		_player.flip_h = wanted == "side" and direction.x < 0.0
		_walk_phase += delta * 11.0 * TAU / 4.0
		_player.offset.y = -290.0 + sin(_walk_phase * 2.0) * 5.0
		_player.rotation = sin(_walk_phase) * 0.012
	else:
		_player.stop()
		_player.offset.y = -290.0
		_player.rotation = 0.0
	_player.position = player_position
	_camera.position = player_position
	_collect_nearby()
	var cell := _world_cell(player_position)
	if cell != _loaded_center:
		_refresh_visible()
	_move_animals(delta)
	_minimap.queue_redraw()


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
				objects[idx] = MUSHROOM if _hash(x, y, 23) < 0.012 and not clearing else EMPTY
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
			else:
				objects[idx] = EMPTY


func _hash(x: int, y: int, salt: int) -> float:
	var n := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791) ^ 472918
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xffff) / 65535.0


func _build_world() -> void:
	_ground = TileMapLayer.new()
	_ground.name = "ConnectedGround"
	_ground.z_index = -10
	add_child(_ground)
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	for kind in 2:
		var source := TileSetAtlasSource.new()
		source.texture = load(ART + ("grass.png" if kind == GRASS else "dirt.png"))
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
	_world = Node2D.new()
	_world.name = "YSortedWorld"
	_world.y_sort_enabled = true
	add_child(_world)
	for kind in PROP_NAMES:
		var file: String = CHARACTER_ART + "mushrooms.png" if kind == MUSHROOM else ART + PROP_NAMES[kind] + ".png"
		_textures[kind] = load(file)
	_player = AnimatedSprite2D.new()
	_player.name = "Oravitsa"
	_player.sprite_frames = _make_character_frames()
	_player.scale = Vector2.ONE * 0.20
	_player.offset = Vector2(0, -290)
	_world.add_child(_player)
	_player.play("toward")
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
	var frames := SpriteFrames.new()
	for direction in ["toward", "away", "side"]:
		frames.add_animation(direction)
		frames.set_animation_speed(direction, 11.0)
		var filename: String = ART + "oravitsa_walk_side.png" if direction == "side" else CHARACTER_ART + "oravitsa_walk_" + direction + ".png"
		var texture: Texture2D = load(filename)
		var width := float(texture.get_width()) / 4.0
		for i in 4:
			var frame := AtlasTexture.new()
			frame.atlas = texture
			frame.region = Rect2(width * i, 0, width, texture.get_height())
			frames.add_frame(direction, frame)
	return frames


func _refresh_ground(center: Vector2i) -> void:
	_ground.clear()
	_dirt.clear()
	for y in range(maxi(0, center.y - 7), mini(MAP_SIZE, center.y + 8)):
		for x in range(maxi(0, center.x - 10), mini(MAP_SIZE, center.x + 11)):
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
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 16)
	panel.custom_minimum_size = Vector2(400, 76)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.17, 0.13, 0.88)
	style.set_corner_radius_all(14)
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)
	_count_label = Label.new()
	_count_label.position = Vector2(36, 22)
	_count_label.add_theme_font_size_override("font_size", 22)
	_count_label.add_theme_color_override("font_color", Color("f8eed5"))
	canvas.add_child(_count_label)
	var hint := Label.new()
	hint.position = Vector2(36, 56)
	hint.text = "WASD / arrows: explore   •   Walk over mushrooms to collect"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("e9dfbb"))
	canvas.add_child(hint)
	_minimap = Control.new()
	_minimap.set_script(load("res://scenes/forest_2d/minimap.gd"))
	_minimap.name = "Minimap"
	_minimap.position = Vector2(1016, 16)
	_minimap.custom_minimum_size = Vector2(244, 244)
	_minimap.size = Vector2(244, 244)
	_minimap.set("forest", self)
	canvas.add_child(_minimap)


func _refresh_visible() -> void:
	var center := _world_cell(player_position)
	_loaded_center = center
	_refresh_ground(center)
	var wanted := {}
	for y in range(maxi(0, center.y - 7), mini(MAP_SIZE, center.y + 8)):
		for x in range(maxi(0, center.x - 10), mini(MAP_SIZE, center.x + 11)):
			var cell := Vector2i(x, y)
			var kind := objects[_index(cell)]
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
	sprite.scale = Vector2.ONE * {TREE: 0.18, BUSH: 0.11, STONE: 0.09, MUSHROOM: 0.06, FERN: 0.075, LOG: 0.09}[kind]
	sprite.offset.y = -sprite.texture.get_height() * {TREE: 0.30, BUSH: 0.17, STONE: 0.08, MUSHROOM: 0.08, FERN: 0.10, LOG: 0.08}[kind]
	sprite.flip_h = _hash(cell.x, cell.y, 71) > 0.5
	_world.add_child(sprite)
	return sprite


func _seed_animals() -> void:
	# The first four are deliberately near the starting clearing so each species
	# can be evaluated immediately. Other animals are stable across runs.
	for entry in [
		[BOAR, Vector2i(-3, -2)], [DEER, Vector2i(3, -2)],
		[FOX, Vector2i(-3, 2)], [LYNX, Vector2i(3, 2)]
	]:
		_add_animal(entry[0], START + entry[1])
	for sector_y in range(1, MAP_SIZE / 24 - 1):
		for sector_x in range(1, MAP_SIZE / 24 - 1):
			if _hash(sector_x, sector_y, 101) > 0.65:
				continue
			var cell := Vector2i(
				sector_x * 24 + 4 + int(_hash(sector_x, sector_y, 102) * 16.0),
				sector_y * 24 + 4 + int(_hash(sector_x, sector_y, 103) * 16.0)
			)
			if _can_stand(_cell_center(cell)) and cell.distance_to(START) > 8.0:
				_add_animal(mini(3, int(_hash(sector_x, sector_y, 104) * 4.0)), cell)


func _add_animal(kind: int, cell: Vector2i) -> void:
	assert(_can_stand(_cell_center(cell)))
	_animals.append({
		"kind": kind,
		"position": _cell_center(cell),
		"target": _cell_center(cell),
		"timeout": 0.0,
		"turn": 0
	})


func _refresh_animals(center: Vector2i) -> void:
	var wanted := {}
	for id in _animals.size():
		var cell := _world_cell(_animals[id]["position"])
		if abs(cell.x - center.x) <= 12 and abs(cell.y - center.y) <= 9:
			wanted[id] = true
			if not _active_animals.has(id):
				_active_animals[id] = _make_animal_sprite(id)
	for id in _active_animals.keys():
		if not wanted.has(id):
			_active_animals[id].queue_free()
			_active_animals.erase(id)


func _make_animal_sprite(id: int) -> AnimatedSprite2D:
	var kind: int = _animals[id]["kind"]
	var filename: String = [
		CHARACTER_ART + "boar_walk.png", CHARACTER_ART + "deer_walk.png",
		ART + "fox_walk.png", ART + "lynx_walk.png"
	][kind]
	var texture: Texture2D = load(filename)
	var frames := SpriteFrames.new()
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 9.0)
	var width := float(texture.get_width()) / 4.0
	for i in 4:
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(width * i, 0, width, texture.get_height())
		frames.add_frame("walk", frame)
	var sprite := AnimatedSprite2D.new()
	sprite.name = ANIMAL_NAMES[kind] + "_%d" % id
	sprite.sprite_frames = frames
	sprite.scale = Vector2.ONE * [0.16, 0.17, 0.14, 0.15][kind]
	sprite.offset = Vector2(0, -texture.get_height() * 0.35)
	sprite.position = _animals[id]["position"]
	_world.add_child(sprite)
	sprite.play("walk")
	return sprite


func _choose_animal_target(id: int) -> void:
	var data := _animals[id]
	var cell := _world_cell(data["position"])
	var turn: int = data["turn"] + 1
	data["turn"] = turn
	for attempt in 8:
		var angle := _hash(id, turn + attempt, 201) * TAU
		var distance := 1 + int(_hash(id, turn + attempt, 202) * 4.0)
		var target_cell := cell + Vector2i(roundi(cos(angle) * distance), roundi(sin(angle) * distance))
		if _in_bounds(target_cell) and _can_stand(_cell_center(target_cell)):
			data["target"] = _cell_center(target_cell)
			data["timeout"] = 3.0 + _hash(id, turn, 203) * 2.0
			return
	data["target"] = data["position"]
	data["timeout"] = 1.0


func _move_animals(delta: float) -> void:
	for id in _active_animals.keys():
		var data := _animals[id]
		var position: Vector2 = data["position"]
		var target: Vector2 = data["target"]
		data["timeout"] = float(data["timeout"]) - delta
		if position.distance_to(target) < 9.0 or data["timeout"] <= 0.0:
			_choose_animal_target(id)
			target = data["target"]
		var heading := position.direction_to(target)
		var step: Vector2 = heading * ANIMAL_SPEEDS[data["kind"]] * delta
		var candidate := position
		if _can_stand(candidate + Vector2(step.x, 0)):
			candidate.x += step.x
		if _can_stand(candidate + Vector2(0, step.y)):
			candidate.y += step.y
		if candidate.distance_squared_to(position) < 0.1:
			data["timeout"] = 0.0
		data["position"] = candidate
		var sprite: AnimatedSprite2D = _active_animals[id]
		sprite.position = candidate
		if absf(heading.x) > 0.1:
			sprite.flip_h = heading.x < 0.0
		if candidate.distance_squared_to(position) > 0.1:
			if not sprite.is_playing():
				sprite.play("walk")
		else:
			sprite.stop()


func _try_move(step: Vector2) -> void:
	var candidate := player_position + step
	candidate.x = clampf(candidate.x, 16.0, MAP_SIZE * TILE - 16.0)
	candidate.y = clampf(candidate.y, 12.0, MAP_SIZE * TILE - 12.0)
	if _can_stand(candidate):
		player_position = candidate


func _can_stand(point: Vector2) -> bool:
	for offset in [Vector2(-18, -12), Vector2(18, -12), Vector2(-18, 12), Vector2(18, 12)]:
		var cell := _world_cell(point + offset)
		if not _in_bounds(cell) or objects[_index(cell)] in BLOCKED:
			return false
	return true


func _collect_nearby() -> void:
	var center := _world_cell(player_position)
	for y in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			var cell := Vector2i(x, y)
			if not _in_bounds(cell) or objects[_index(cell)] != MUSHROOM:
				continue
			if player_position.distance_to(_cell_center(cell)) <= PICKUP_RADIUS:
				objects[_index(cell)] = EMPTY
				basket += 1
				if _active_props.has(cell):
					_active_props[cell].queue_free()
					_active_props.erase(cell)
				_update_hud()


func _update_hud() -> void:
	_count_label.text = "Oravitsa’s forest    Mushrooms: %d" % basket


func _index(cell: Vector2i) -> int:
	return cell.y * MAP_SIZE + cell.x


func _world_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / TILE), floori(point.y / TILE))


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE + Vector2.ONE * (TILE * 0.5)


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < MAP_SIZE and cell.y < MAP_SIZE
