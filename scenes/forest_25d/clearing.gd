extends "res://scenes/forest_2d/forest.gd"

## Presentation prototype: the tested forest rules/HUD drive a real 3D scene.
## Legacy simulation coordinates are converted to metres at one boundary.
const METRE := 64.0
const CAMERA_OFFSET := Vector3(0, 18, 25.4558)
var landscape: Node3D
var stage: Node3D
var view: Camera3D
var heroine: AnimatedSprite3D
var _shadow: MeshInstance3D
var _deer_models: Dictionary = {}
var _deer_players: Dictionary = {}
var _deer_stars: Dictionary = {}
var _forage_visuals: Dictionary = {}
var _projectile_visuals: Array[MeshInstance3D] = []
var _target_ring: MeshInstance3D
var _landmark_label: Label
var _stats_label: Label


func to_ground(point: Vector2) -> Vector2:
	return (point - _cell_center(START)) / METRE


func from_ground(point: Vector2) -> Vector2:
	return _cell_center(START) + point * METRE


func to_world(point: Vector2) -> Vector3:
	var p := to_ground(point)
	return Vector3(p.x, landscape.height_at(p), p.y)


func _generate_map() -> void:
	terrain.resize(MAP_SIZE * MAP_SIZE)
	objects.resize(MAP_SIZE * MAP_SIZE)
	terrain.fill(GRASS)
	objects.fill(EMPTY)
	# Small deliberate foraging routes, rather than the large forest generator.
	for data in [Vector3(1, 1, MUSHROOM), Vector3(2, -2, BERRIES), Vector3(4, 1, MUSHROOM), Vector3(5, -3, BERRIES), Vector3(-1, 3, MUSHROOM), Vector3(-6, 4, BERRIES), Vector3(-8, 2, MUSHROOM), Vector3(7, -6, MUSHROOM), Vector3(9, -3, BERRIES)]:
		var cell := START + Vector2i(int(data.x), int(data.y))
		objects[_index(cell)] = int(data.z)


func _build_world() -> void:
	# Invisible 2D sprites retain the existing walk phase, targeting and wildlife
	# state interfaces. Camera2D is disabled; only Camera3D renders the world.
	_world = Node2D.new()
	_world.visible = false
	add_child(_world)
	_player = AnimatedSprite2D.new()
	_player.sprite_frames = PLAYER_WALK
	_player.animation = "s"
	_world.add_child(_player)
	_camera = Camera2D.new()
	_camera.enabled = false
	add_child(_camera)
	_sling_effects = Node2D.new()
	_sling_effects.visible = false
	add_child(_sling_effects)
	stage = Node3D.new()
	stage.name = "Clearing3D"
	add_child(stage)
	landscape = load("res://scenes/forest_25d/landscape.gd").new()
	stage.add_child(landscape)
	landscape.build()
	_lighting()
	view = Camera3D.new()
	view.projection = Camera3D.PROJECTION_ORTHOGONAL
	view.size = 13.5
	view.near = 0.1
	view.far = 100.0
	stage.add_child(view)
	view.position = CAMERA_OFFSET
	view.look_at(Vector3.ZERO)
	view.make_current()
	heroine = AnimatedSprite3D.new()
	heroine.name = "ApprovedOravitsa"
	heroine.sprite_frames = PLAYER_WALK
	heroine.animation = "s"
	heroine.pixel_size = 1.5 / 241.0
	heroine.offset = Vector2(0, float(PLAYER_WALK.get_meta("pivot").y) - 192.0)
	heroine.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	heroine.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	heroine.shaded = false
	heroine.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	heroine.alpha_scissor_threshold = 0.25
	stage.add_child(heroine)
	_shadow = _contact_shadow(0.48)
	stage.add_child(_shadow)
	_target_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.48
	ring.outer_radius = 0.52
	ring.rings = 24
	ring.ring_segments = 6
	_target_ring.mesh = ring
	_target_ring.material_override = landscape.material("e5ca83")
	_target_ring.visible = false
	stage.add_child(_target_ring)
	_build_food()
	_build_hud()
	_minimap.set_script(load("res://scenes/forest_25d/clearing_map.gd"))
	_minimap.set("forest", self)
	_landmark_label = Label.new()
	_landmark_label.position = Vector2(18, 58)
	_landmark_label.add_theme_font_size_override("font_size", 14)
	_landmark_label.add_theme_color_override("font_color", Color("e5d6ad"))
	_landmark_label.add_theme_color_override("font_shadow_color", Color("172820"))
	_landmark_label.add_theme_constant_override("shadow_offset_x", 1)
	_landmark_label.add_theme_constant_override("shadow_offset_y", 2)
	get_node("HUD").add_child(_landmark_label)
	_stats_label = Label.new()
	_stats_label.visible = false
	_stats_label.add_theme_font_size_override("font_size", 14)
	_stats_label.add_theme_color_override("font_color", Color("fff1bd"))
	_stats_label.add_theme_color_override("font_shadow_color", Color("172820"))
	_stats_label.add_theme_constant_override("shadow_offset_y", 2)
	get_node("HUD").add_child(_stats_label)
	_layout_hud()


func _layout_hud() -> void:
	super._layout_hud()
	if is_instance_valid(_stats_label):
		_stats_label.position = Vector2(get_viewport_rect().size.x * 0.5 - 130, get_viewport_rect().size.y - 32)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_stats_label.visible = not _stats_label.visible
	else:
		super._unhandled_key_input(event)


func _lighting() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9ba98c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("bbc8a3")
	env.ambient_light_energy = 0.85
	env.ambient_light_sky_contribution = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -32, 0)
	sun.light_color = Color("fff7e8")
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55
	sun.shadow_bias = 0.04
	stage.add_child(sun)


func _contact_shadow(radius: float) -> MeshInstance3D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var distance := Vector2(x - 31.5, y - 31.5).length() / 31.5
			image.set_pixel(x, y, Color(0.07, 0.09, 0.06, pow(maxf(0, 1 - distance), 1.5) * 0.48))
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = ImageTexture.create_from_image(image)
	var plane := PlaneMesh.new()
	plane.size = Vector2(radius * 2, radius * 1.4)
	var node := MeshInstance3D.new()
	node.mesh = plane
	node.material_override = mat
	return node


func _seed_animals() -> void:
	_add_animal(DEER, START + Vector2i(3, -2))
	_add_animal(DEER, START + Vector2i(5, 2))


func _refresh_visible() -> void:
	_loaded_center = _world_cell(player_position)
	_loaded_half = Vector2i(30, 30)
	_refresh_animals(_loaded_center)
	for id in _active_animals:
		if not _deer_models.has(id):
			_add_deer_visual(id)


func _stream_half() -> Vector2i:
	return Vector2i(30, 30)


func _replenish_local_animals() -> void:
	pass # This bounded art slice has two deer, not the large forest's population.


func _add_deer_visual(id: int) -> void:
	var deer: Node3D = load("res://scenes/forest_25d/assets/deer.gltf").instantiate()
	deer.name = "AnimatedDeer%d" % id
	stage.add_child(deer)
	# The source is authored in metres; normalize once from its static bounds.
	var bounds := _model_bounds(deer)
	var scale_factor := 1.45 / maxf(bounds.size.y, 0.01)
	deer.scale = Vector3.ONE * scale_factor
	deer.rotation.y = -PI * 0.3 if id == 0 else PI * 0.25
	_deer_models[id] = deer
	var animator := _find_animator(deer)
	if animator != null:
		for animation in animator.get_animation_list():
			animator.get_animation(animation).loop_mode = Animation.LOOP_LINEAR
		animator.play("Idle")
		_deer_players[id] = animator
	var stars := Label3D.new()
	stars.text = "✦  ✦  ✦"
	stars.font_size = 32
	stars.pixel_size = 0.012
	stars.modulate = Color("ffe2a0")
	stars.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	stars.no_depth_test = false
	stars.visible = false
	stage.add_child(stars)
	_deer_stars[id] = stars
	var shadow := _contact_shadow(0.65)
	shadow.name = "ContactShadow"
	deer.add_child(shadow)


func _model_bounds(node: Node3D) -> AABB:
	var result := AABB()
	var found := false
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var local: AABB = (node.global_transform.affine_inverse() * child.global_transform) * child.get_aabb()
		result = result.merge(local) if found else local
		found = true
	return result


func _find_animator(node: Node) -> AnimationPlayer:
	for child in node.find_children("*", "AnimationPlayer", true, false):
		return child
	return null


func _build_food() -> void:
	for z in range(START.y - 12, START.y + 12):
		for x in range(START.x - 12, START.x + 12):
			var cell := Vector2i(x, z)
			var kind: int = objects[_index(cell)]
			if kind not in [MUSHROOM, BERRIES]:
				continue
			var at := to_world(_cell_center(cell))
			var root := Node3D.new()
			stage.add_child(root)
			root.position = at
			for i in 3:
				var off := Vector3((i - 1) * 0.13, 0, (i % 2) * 0.14)
				if kind == MUSHROOM:
					var stem := CylinderMesh.new()
					stem.top_radius = 0.04
					stem.bottom_radius = 0.055
					stem.height = 0.2
					_food_mesh(root, stem, "ddd1a7", off + Vector3(0, 0.1, 0))
					var cap := SphereMesh.new()
					cap.radius = 0.14
					cap.height = 0.16
					cap.radial_segments = 10
					cap.rings = 4
					_food_mesh(root, cap, "b48150", off + Vector3(0, 0.23, 0))
				else:
					var berry := SphereMesh.new()
					berry.radius = 0.095
					berry.height = 0.19
					berry.radial_segments = 8
					berry.rings = 4
					_food_mesh(root, berry, "af4f59", off + Vector3(0, 0.09, 0))
			_forage_visuals[cell] = root


func _food_mesh(root: Node3D, mesh: Mesh, color: String, at: Vector3) -> void:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = landscape.material(color)
	node.position = at
	root.add_child(node)


func _consume_food(cell: Vector2i) -> void:
	super._consume_food(cell)
	if _forage_visuals.has(cell):
		_forage_visuals[cell].queue_free()
		_forage_visuals.erase(cell)


func _can_stand(point: Vector2, actor_radius: float = PLAYER_RADIUS) -> bool:
	return landscape.can_walk(to_ground(point), actor_radius / METRE)


func _select_sling_target(screen_position: Vector2) -> void:
	if _inventory.get_global_rect().has_point(screen_position) or (_minimap.visible and _minimap.get_global_rect().has_point(screen_position)):
		return
	selected_target = -1
	var nearest := 70.0
	for id in _deer_models:
		if not _valid_sling_target(id):
			continue
		var position := to_world(_animals[id]["position"]) + Vector3.UP * 0.8
		var distance := screen_position.distance_to(view.unproject_position(position))
		if distance < nearest:
			selected_target = id
			nearest = distance
	_update_hud()


func _process(delta: float) -> void:
	super._process(delta)
	_sync_presentation(delta)


func _sync_presentation(delta: float) -> void:
	var feet := to_world(player_position)
	heroine.position = feet + Vector3.UP * 0.02
	heroine.animation = _player.animation
	heroine.frame = _player.frame
	heroine.modulate = _player.modulate
	_shadow.position = feet + Vector3.UP * 0.015
	var camera_target := feet + CAMERA_OFFSET
	view.position = view.position.lerp(camera_target, 1 - exp(-5.0 * delta))
	# Camera orientation stays fixed; facing remains aligned with screen controls.
	for id in _deer_models:
		var data: Dictionary = _animals[id]
		var deer: Node3D = _deer_models[id]
		deer.position = to_world(data["position"])
		var velocity: Vector2 = data["velocity"]
		if velocity.length_squared() > 1:
			deer.rotation.y = atan2(velocity.x, velocity.y)
		if _deer_players.has(id):
			var animator: AnimationPlayer = _deer_players[id]
			var wanted := "Idle" if data["stun"] > 0.0 or velocity.length_squared() < 1 else "Walk"
			if animator.current_animation != wanted:
				animator.play(wanted, 0.2)
			animator.speed_scale = 0.0 if data["stun"] > 0 else 1.0
		var stars: Label3D = _deer_stars[id]
		stars.position = deer.position + Vector3.UP * (1.7 + sin(Time.get_ticks_msec() * 0.005) * 0.05)
		stars.visible = data["stun"] > 0.0
	_target_ring.visible = _valid_sling_target(selected_target)
	if _target_ring.visible:
		_target_ring.position = to_world(_animals[selected_target]["position"]) + Vector3.UP * 0.04
	while _projectile_visuals.size() < _stones.size():
		var node := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.065
		ball.height = 0.13
		node.mesh = ball
		node.material_override = landscape.material("d9d2b2")
		stage.add_child(node)
		_projectile_visuals.append(node)
	for i in _projectile_visuals.size():
		_projectile_visuals[i].visible = i < _stones.size()
		if i < _stones.size():
			var stone: Dictionary = _stones[i]
			_projectile_visuals[i].position = to_world(stone["position"]) + Vector3.UP * (0.65 + sin(clampf(stone["age"] / stone["flight"], 0, 1) * PI) * 0.4)
	var p := to_ground(player_position)
	var inside := Rect2(4.7, -5.8, 4.6, 3.8).has_point(p)
	for roof in landscape.roofs:
		roof.visible = not inside
	_landmark_label.visible = not _instructions_visible
	_landmark_label.text = "Mossbank · the old forester’s cottage" if p.distance_to(Vector2(7, -4)) < 5 else "Mossbank clearing"
	if _stats_label.visible:
		_stats_label.text = "%d FPS · %d draws · %dk triangles" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000]
