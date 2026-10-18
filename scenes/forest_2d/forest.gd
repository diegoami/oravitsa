extends Node2D

## A finite, seeded forest made of connected painted ground tiles. Props are
## streamed around the camera; the map data also drives collision and minimap.

const TILE := 114
const MAP_SIZE := 128
const ART := "res://scenes/forest_2d/art/"
const CHARACTER_ART := "res://prototypes/foraging_2d/art/"
const SPEED := 240.0
const PICKUP_RADIUS := 40.0
const START := Vector2i(64, 64)
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

var terrain := PackedByteArray()
var objects := PackedByteArray()
var player_position := Vector2.ZERO
var basket := 0
var _ground: TileMapLayer
var _world: Node2D
var _player: AnimatedSprite2D
var _camera: Camera2D
var _minimap: Control
var _count_label: Label
var _active_props: Dictionary = {}
var _textures: Dictionary = {}
var _loaded_center := Vector2i(-999, -999)
var _facing_up := false


func _ready() -> void:
	_generate_map()
	_build_world()
	player_position = _cell_center(START)
	_player.position = player_position
	_camera.position = player_position
	_camera.reset_smoothing()
	_refresh_props()
	_update_hud()


func _process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if direction.length_squared() > 0.0:
		var step := direction.normalized() * SPEED * delta
		_try_move(Vector2(step.x, 0.0))
		_try_move(Vector2(0.0, step.y))
		_facing_up = direction.y < -0.15 if absf(direction.y) > 0.15 else _facing_up
		var wanted := "away" if _facing_up else "toward"
		if _player.animation != wanted or not _player.is_playing():
			_player.play(wanted)
		_player.flip_h = direction.x < -0.1
	else:
		_player.stop()
	_player.position = player_position
	_camera.position = player_position
	_collect_nearby()
	var cell := _world_cell(player_position)
	if cell != _loaded_center:
		_refresh_props()
	_minimap.queue_redraw()


func _generate_map() -> void:
	terrain.resize(MAP_SIZE * MAP_SIZE)
	objects.resize(MAP_SIZE * MAP_SIZE)
	var grove_noise := FastNoiseLite.new()
	grove_noise.seed = 81824
	grove_noise.frequency = 0.075
	for y in MAP_SIZE:
		for x in MAP_SIZE:
			var cell := Vector2i(x, y)
			var idx := _index(cell)
			var horizontal := absf(y - (64.0 + 10.0 * sin(x * 0.075) + 4.0 * sin(x * 0.19)))
			var vertical := absf(x - (64.0 + 13.0 * sin(y * 0.068) + 3.0 * cos(y * 0.16)))
			var clearing := Vector2(x - 64, y - 64).length() < 6.0
			var side_path := absf(y - (28.0 + 7.0 * sin(x * 0.09))) < 1.7
			var path := horizontal < 1.8 or vertical < 1.8 or side_path or clearing
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
	for y in MAP_SIZE:
		for x in MAP_SIZE:
			var sx := posmod(x, 22)
			var sy := posmod(y, 22)
			var flip := 0
			if sx >= 11:
				sx = 21 - sx
				flip |= TileSetAtlasSource.TRANSFORM_FLIP_H
			if sy >= 11:
				sy = 21 - sy
				flip |= TileSetAtlasSource.TRANSFORM_FLIP_V
			_ground.set_cell(Vector2i(x, y), terrain[y * MAP_SIZE + x], Vector2i(sx, sy), flip)
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
	for direction in ["toward", "away"]:
		frames.add_animation(direction)
		frames.set_animation_speed(direction, 8.0)
		var texture: Texture2D = load(CHARACTER_ART + "oravitsa_walk_" + direction + ".png")
		var width := float(texture.get_width()) / 4.0
		for i in 4:
			var frame := AtlasTexture.new()
			frame.atlas = texture
			frame.region = Rect2(width * i, 0, width, texture.get_height())
			frames.add_frame(direction, frame)
	return frames


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


func _refresh_props() -> void:
	var center := _world_cell(player_position)
	_loaded_center = center
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
