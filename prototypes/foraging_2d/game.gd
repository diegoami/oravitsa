extends Node2D

## One fixed, hand-composed clearing for testing the foraging loop.
## All visible world art is generated raster illustration. Gameplay positions
## are explicit so every attempt has the same route choices.

const ART := "res://prototypes/foraging_2d/art/"
const ROUND_LENGTH := 90.0
const BASKET_GOAL := 9
const WALK_SPEED := 205.0
const BOAR_SPEED := 68.0
const BOAR_FORAGE_PAUSE := 5.0
const DEER_SPEED := 60.0
const PICKUP_DISTANCE := 27.0
const SHOO_RANGE := 145.0
const SHOO_DURATION := 2.2
const SHOO_COOLDOWN := 9.0
const FIELD := Rect2(105.0, 178.0, 1070.0, 475.0)
const PATCHES: Array[Vector2] = [
	Vector2(218, 219), Vector2(372, 250), Vector2(568, 231),
	Vector2(781, 214), Vector2(1010, 232), Vector2(1115, 301),
	Vector2(990, 364), Vector2(784, 340), Vector2(598, 351),
	Vector2(401, 355), Vector2(238, 405), Vector2(152, 553),
	Vector2(347, 566), Vector2(534, 534), Vector2(726, 535),
	Vector2(917, 549), Vector2(1087, 584)
]
const DEER_POINTS: Array[Vector2] = [
	Vector2(775, 250), Vector2(1093, 430), Vector2(798, 613),
	Vector2(388, 555), Vector2(543, 293)
]

var player_position := Vector2(234, 470)
var boar_position := Vector2(1040, 440)
var deer_position := Vector2(738, 260)
var patches: Array[Vector2] = []
var patches_sprites: Array[Sprite2D] = []
var basket := 0
var boar_taken := 0
var seconds_left := ROUND_LENGTH
var shoo_left := 0.0
var shoo_ready_in := 0.0
var boar_forage_pause := 0.0
var deer_target := 0
var playing := true
var _message := ""
var _last_direction := Vector2.DOWN

var _world: Node2D
var _player: AnimatedSprite2D
var _boar: AnimatedSprite2D
var _deer: AnimatedSprite2D
var _hud: Label
var _hint: Label
var _result_panel: PanelContainer
var _result_label: Label


func _ready() -> void:
	_build_visuals()
	restart_round()


func _build_visuals() -> void:
	var background := Sprite2D.new()
	background.name = "PaintedForest"
	background.texture = load(ART + "forest_clearing.png")
	background.centered = false
	background.scale = Vector2(1280.0 / background.texture.get_width(), 720.0 / background.texture.get_height())
	background.z_index = -10
	add_child(background)

	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)

	_player = _make_walk_sprite("Oravitsa", "oravitsa_walk_toward.png", 0.245, -291.0, 8.0)
	_boar = _make_walk_sprite("Boar", "boar_walk.png", 0.195, -218.0, 7.0)
	_deer = _make_walk_sprite("Deer", "deer_walk.png", 0.195, -298.0, 7.0)

	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)
	var bar := PanelContainer.new()
	bar.position = Vector2(18, 16)
	bar.custom_minimum_size = Vector2(1244, 94)
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.10, 0.18, 0.16, 0.87)
	bar_style.set_corner_radius_all(16)
	bar.add_theme_stylebox_override("panel", bar_style)
	canvas.add_child(bar)
	_hud = _make_label(canvas, Vector2(42, 25), 25)
	_hint = _make_label(canvas, Vector2(42, 64), 18)

	_result_panel = PanelContainer.new()
	_result_panel.position = Vector2(247, 251)
	_result_panel.custom_minimum_size = Vector2(786, 218)
	var result_style := StyleBoxFlat.new()
	result_style.bg_color = Color(0.09, 0.18, 0.17, 0.95)
	result_style.set_corner_radius_all(20)
	_result_panel.add_theme_stylebox_override("panel", result_style)
	canvas.add_child(_result_panel)
	_result_label = _make_label(canvas, Vector2(285, 285), 26)
	_result_label.custom_minimum_size = Vector2(710, 140)
	_result_panel.visible = false
	_result_label.visible = false


func _make_label(parent: Node, at: Vector2, size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("f7ebd5"))
	parent.add_child(label)
	return label


func _make_walk_sprite(node_name: String, filename: String, sprite_scale: float, foot_offset: float, fps: float) -> AnimatedSprite2D:
	var texture: Texture2D = load(ART + filename)
	var frames := SpriteFrames.new()
	frames.add_animation("walk")
	frames.set_animation_speed("walk", fps)
	var frame_width := float(texture.get_width()) / 4.0
	for i in 4:
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(frame_width * i, 0.0, frame_width, float(texture.get_height()))
		frames.add_frame("walk", frame)
	var sprite := AnimatedSprite2D.new()
	sprite.name = node_name
	sprite.sprite_frames = frames
	sprite.animation = "walk"
	sprite.scale = Vector2.ONE * sprite_scale
	sprite.offset = Vector2(0.0, foot_offset)
	_world.add_child(sprite)
	return sprite


func restart_round() -> void:
	player_position = Vector2(234, 470)
	boar_position = Vector2(1040, 440)
	deer_position = Vector2(738, 260)
	patches = PATCHES.duplicate()
	basket = 0
	boar_taken = 0
	seconds_left = ROUND_LENGTH
	shoo_left = 0.0
	shoo_ready_in = 0.0
	boar_forage_pause = 0.0
	deer_target = 0
	playing = true
	_message = ""
	_last_direction = Vector2.DOWN
	_result_panel.visible = false
	_result_label.visible = false
	for sprite in patches_sprites:
		sprite.queue_free()
	patches_sprites.clear()
	var texture: Texture2D = load(ART + "mushrooms.png")
	for patch in patches:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.scale = Vector2.ONE * 0.057
		sprite.offset = Vector2(0, -436)
		sprite.position = patch
		sprite.z_index = int(patch.y)
		_world.add_child(sprite)
		patches_sprites.append(sprite)
	_player.position = player_position
	_boar.position = boar_position
	_deer.position = deer_position
	_player.stop()
	_boar.play()
	_deer.play()
	_refresh_hud()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_R and not playing:
		restart_round()
	elif event.keycode == KEY_SPACE and playing:
		if shoo_ready_in <= 0.0 and player_position.distance_to(boar_position) <= SHOO_RANGE:
			shoo_left = SHOO_DURATION
			shoo_ready_in = SHOO_COOLDOWN
			_refresh_hud()


func _process(delta: float) -> void:
	if not playing:
		return
	seconds_left = maxf(0.0, seconds_left - delta)
	shoo_left = maxf(0.0, shoo_left - delta)
	shoo_ready_in = maxf(0.0, shoo_ready_in - delta)
	boar_forage_pause = maxf(0.0, boar_forage_pause - delta)
	_move_player(delta)
	_move_boar(delta)
	_move_deer(delta)
	_collect_patches()
	if basket >= BASKET_GOAL:
		_finish("The basket is full!\nOravitsa has enough for supper.")
	elif seconds_left <= 0.0 or patches.is_empty() or basket + patches.size() < BASKET_GOAL:
		_finish("Supper is still short.\nTry a different route through the clearing.")
	_refresh_hud()


func _move_player(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input.length_squared() > 0.0:
		_last_direction = input.normalized()
		player_position = _clamp_to_field(player_position + _last_direction * WALK_SPEED * delta)
		if _last_direction.y < -0.15:
			_set_player_direction("oravitsa_walk_away.png")
		else:
			_set_player_direction("oravitsa_walk_toward.png")
		_player.flip_h = _last_direction.x < -0.15
		if not _player.is_playing():
			_player.play()
	else:
		_player.stop()
	_player.position = player_position
	_player.z_index = int(player_position.y)


func _set_player_direction(filename: String) -> void:
	if _player.get_meta("sheet", "") == filename:
		return
	_player.set_meta("sheet", filename)
	var texture: Texture2D = load(ART + filename)
	var width := float(texture.get_width()) / 4.0
	for i in 4:
		var frame := AtlasTexture.new()
		frame.atlas = texture
		frame.region = Rect2(width * i, 0.0, width, float(texture.get_height()))
		_player.sprite_frames.set_frame("walk", i, frame)


func _move_boar(delta: float) -> void:
	var target := boar_position
	var speed := BOAR_SPEED
	if shoo_left > 0.0:
		target = _clamp_to_field(boar_position + boar_position.direction_to(player_position) * -260.0)
		speed *= 1.65
	elif not patches.is_empty():
		var best := INF
		for patch in patches:
			var distance := boar_position.distance_squared_to(patch)
			if distance < best:
				best = distance
				target = patch
	if boar_position.distance_to(target) > 3.0:
		var heading := boar_position.direction_to(target)
		boar_position = _clamp_to_field(boar_position + heading * speed * delta)
		_boar.flip_h = heading.x < 0.0
		_boar.play()
	else:
		_boar.stop()
	_boar.position = boar_position
	_boar.z_index = int(boar_position.y)
	_boar.modulate = Color("d7dbed") if shoo_left > 0.0 else Color.WHITE
	if shoo_left <= 0.0 and boar_forage_pause <= 0.0:
		for i in range(patches.size() - 1, -1, -1):
			if boar_position.distance_to(patches[i]) < 25.0:
				_remove_patch(i)
				boar_taken += 1
				boar_forage_pause = BOAR_FORAGE_PAUSE
				break


func _move_deer(delta: float) -> void:
	var target := DEER_POINTS[deer_target]
	if deer_position.distance_to(target) < 12.0:
		deer_target = (deer_target + 1) % DEER_POINTS.size()
		target = DEER_POINTS[deer_target]
	if deer_position.distance_to(player_position) < 116.0:
		target = _clamp_to_field(deer_position + player_position.direction_to(deer_position) * 180.0)
	var heading := deer_position.direction_to(target)
	deer_position = _clamp_to_field(deer_position + heading * DEER_SPEED * delta)
	_deer.position = deer_position
	_deer.flip_h = heading.x > 0.0
	_deer.z_index = int(deer_position.y)


func _collect_patches() -> void:
	for i in range(patches.size() - 1, -1, -1):
		if player_position.distance_to(patches[i]) < PICKUP_DISTANCE:
			_remove_patch(i)
			basket += 1


func _remove_patch(index: int) -> void:
	patches.remove_at(index)
	patches_sprites[index].queue_free()
	patches_sprites.remove_at(index)


func _clamp_to_field(point: Vector2) -> Vector2:
	return point.clamp(FIELD.position, FIELD.end)


func _refresh_hud() -> void:
	_hud.text = "ORAVITSA     Basket %d/%d     Boar %d     %ds left" % [basket, BASKET_GOAL, boar_taken, ceili(seconds_left)]
	var shoo := "SPACE: shoo boar nearby" if shoo_ready_in <= 0.0 else "Shoo ready in %.1fs" % shoo_ready_in
	_hint.text = "WASD / arrows: move     %s     Gather by walking near mushrooms" % shoo


func _finish(message: String) -> void:
	playing = false
	_message = message
	_player.stop()
	_boar.stop()
	_deer.stop()
	_result_label.text = "%s\n\nBasket %d  •  Boar %d     Press R to try again" % [message, basket, boar_taken]
	_result_panel.visible = true
	_result_label.visible = true
