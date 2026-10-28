extends "res://scenes/forest_2d/forest.gd"

## Streamed 2.5D forest: the tested wildlife rules and HUD drive a 3D world.
## Legacy simulation coordinates are converted to metres at one boundary.
const METRE := 64.0
const CAMERA_OFFSET := Vector3(0, 18, 25.4558)
var landscape: Node3D
var stage: Node3D
var view: Camera3D
var heroine: AnimatedSprite3D
var _shadow: MeshInstance3D
var _animal_models: Dictionary = {}
var _animal_players: Dictionary = {}
var _animal_stars: Dictionary = {}
var _forage_visuals: Dictionary = {}
var _projectile_visuals: Array[MeshInstance3D] = []
var _target_ring: MeshInstance3D
var _landmark_label: Label
var _stats_label: Label
var _animal_shadows: Dictionary = {}
var _animal_frames: Dictionary = {}
var _animal_heights := {DEER: 1.45, FOX: 0.65, BOAR: 0.95, LYNX: 0.85, HARE: 0.45}
var _food_by_chunk: Dictionary = {}
var _food_chunks: Dictionary = {}
var _food_meshes: Dictionary = {}


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
	var rules = load("res://scenes/forest_25d/landscape.gd").new()
	var radius := floori(rules.EXTENT * METRE / TILE) - 1
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var cell := START + Vector2i(dx, dz)
			var p := to_ground(_cell_center(cell))
			if _hash(dx, dz, 910) < 0.065 and not rules.is_water(p, 0.5):
				objects[_index(cell)] = MUSHROOM if _hash(dx, dz, 911) < 0.55 else BERRIES
	# Familiar gathering spots remain around the original clearing.
	for data in [Vector3(1, 1, MUSHROOM), Vector3(2, -2, BERRIES), Vector3(4, 1, MUSHROOM), Vector3(5, -3, BERRIES), Vector3(-1, 3, MUSHROOM), Vector3(-6, 4, BERRIES), Vector3(-8, 2, MUSHROOM), Vector3(7, -6, MUSHROOM), Vector3(9, -3, BERRIES)]:
		var cell := START + Vector2i(int(data.x), int(data.y))
		objects[_index(cell)] = int(data.z)
	for offset in [Vector2i(7, 2), Vector2i(8, 2)]:
		objects[_index(START + offset)] = MUSHROOM
	rules.free()


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
	landscape = _make_landscape()
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


func _make_landscape() -> Node3D:
	return load("res://scenes/forest_25d/landscape.gd").new()


func _minimap_script() -> Script:
	return load("res://scenes/forest_25d/clearing_map.gd")


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
	env.ambient_light_color = Color("b8c8d0")
	env.ambient_light_energy = 0.72
	env.ambient_light_sky_contribution = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -32, 0)
	sun.light_color = Color("ffedcf")
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	# A fixed orthographic view does not need perspective shadow cascades.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 55
	sun.shadow_bias = 0.04
	sun.shadow_opacity = 0.75
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
	_add_animal(DEER, START + Vector2i(2, -2))
	_add_animal(DEER, START + Vector2i(5, 2))
	for off in [Vector2i(1, 3), Vector2i(4, 0), Vector2i(2, -3), Vector2i(-1, 5)]:
		_add_animal(HARE, START + off)
	var radius := floori(landscape.EXTENT * METRE / TILE) - 3
	for i in 120:
		var roll := _hash(i, 0, 950) * 100
		var kind := HARE if roll < 60 else (DEER if roll < 77 else (FOX if roll < 94 else (BOAR if roll < 99 else LYNX)))
		for attempt in 96:
			var cell := START + Vector2i(floori(lerpf(-radius, radius, _hash(i, attempt, 951))), floori(lerpf(-radius, radius, _hash(i, attempt, 952))))
			var position := _cell_center(cell)
			if not _can_stand(position, ANIMAL_RADIUS[kind]) or position.distance_to(_cell_center(START)) < (1800 if kind == LYNX else 600):
				continue
			var clear := true
			for animal in _animals:
				if animal["position"].distance_to(position) < 110:
					clear = false
					break
			if clear:
				_add_animal(kind, cell)
				break
	# Keep one rare predator territory in the remote woods, never in the
	# starting clearing. All other placements retain the species weights.
	var has_lynx := false
	for animal in _animals:
		has_lynx = has_lynx or animal["kind"] == LYNX
	if not has_lynx:
		for attempt in 64:
			var cell := START + Vector2i(-39 + attempt % 8, -34 + floori(attempt / 8.0))
			var clear := true
			for animal in _animals:
				if animal["position"].distance_to(_cell_center(cell)) < 110:
					clear = false
			if clear and _can_stand(_cell_center(cell), ANIMAL_RADIUS[LYNX]):
				_add_animal(LYNX, cell)
				break


func _visible_half() -> Vector2:
	var aspect := get_viewport_rect().size.x / maxf(1.0, get_viewport_rect().size.y)
	return Vector2(view.size * 0.5 * aspect, view.size * 0.5 / 0.57735)


func _spawn_is_hidden(spot: Vector2, kind: int) -> bool:
	# Project the whole animal, including height, through the actual smoothed
	# camera. A player-distance threshold cannot cover wide or tall viewports.
	var feet := to_world(spot)
	var height: float = _animal_heights[kind]
	var radius := maxf(ANIMAL_RADIUS[kind] / METRE, height * 0.8)
	var bounds := Rect2(view.unproject_position(feet), Vector2.ZERO)
	for x in [-radius, radius]:
		for z in [-radius, radius]:
			for y in [-0.1, height + 0.2]:
				bounds = bounds.expand(view.unproject_position(feet + Vector3(x, y, z)))
	return not get_viewport_rect().grow(48).intersects(bounds)


func _local_spawn_cell(kind: int, attempt: int) -> Vector2i:
	var center := Vector2(view.position.x - CAMERA_OFFSET.x, view.position.z - CAMERA_OFFSET.z)
	var half := _visible_half() + Vector2.ONE * (3.5 + _hash(_population_tick + attempt, kind, 804) * 2.0)
	var side := int(_hash(_population_tick + attempt, kind, 801) * 4.0)
	var along := _hash(_population_tick + attempt, kind, 802) * 2.0 - 1.0
	var offset := Vector2(half.x if side == 0 else -half.x, along * half.y) if side < 2 else Vector2(along * half.x, half.y if side == 2 else -half.y)
	return _world_cell(from_ground(center + offset))


func _population_radius() -> float:
	# Count the offscreen entry ring too, otherwise a wide viewport continually
	# replenishes animals just outside the old, smaller 2D population radius.
	var center := Vector2(view.position.x - CAMERA_OFFSET.x, view.position.z - CAMERA_OFFSET.z)
	return maxf(POPULATION_RADIUS, (_visible_half().length() + 10.0 + center.distance_to(to_ground(player_position))) * METRE)


func _refresh_visible() -> void:
	_loaded_center = _world_cell(player_position)
	_loaded_half = _stream_half()
	_refresh_animals(_loaded_center)
	_sync_animal_lifecycle()
	var camera_center := Vector2(view.position.x - CAMERA_OFFSET.x, view.position.z - CAMERA_OFFSET.z)
	landscape.stream(camera_center, _visible_half())
	_refresh_food()


func _stream_half() -> Vector2i:
	var half := _visible_half()
	return Vector2i(ceili(half.x * METRE / TILE), ceili(half.y * METRE / TILE)) + Vector2i(6, 6)


func _replenish_local_animals() -> void:
	super._replenish_local_animals()
	_sync_animal_lifecycle()


func _refresh_animals(center: Vector2i) -> void:
	var previous := _active_animals.keys()
	super._refresh_animals(center)
	for id in previous:
		if not _active_animals.has(id):
			_animals[id]["catch_target"] = -1
			_animals[id]["catch_time"] = 0.0


func _move_animals(delta: float) -> void:
	super._move_animals(delta)
	for id in _animals.size():
		if not _active_animals.has(id):
			var was_feeding: bool = _animals[id]["feeding"] > 0.0
			for timer in ["stun", "shoo", "feeding", "burst", "burst_cooldown"]:
				_animals[id][timer] = maxf(0, _animals[id][timer] - delta)
			if was_feeding and _animals[id]["feeding"] <= 0.0:
				_animals[id]["state"] = "idle"
				_animals[id]["timeout"] = 0.0


func _make_animal_sprite(id: int) -> AnimatedSprite2D:
	var kind: int = _animals[id]["kind"]
	if not _animal_frames.has(kind):
		var first := super._make_animal_sprite(id)
		_animal_frames[kind] = first.sprite_frames
		return first
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = _animal_frames[kind]
	sprite.scale = Vector2.ONE * [0.16, 0.17, 0.14, 0.15, 0.115][kind]
	var texture := sprite.sprite_frames.get_frame_texture("s", 0)
	sprite.offset = Vector2(0, -texture.get_height() * 0.35)
	sprite.position = _animals[id]["position"]
	_world.add_child(sprite)
	sprite.play("s")
	return sprite


func _sync_animal_lifecycle() -> void:
	for id in _animal_models.keys():
		if not _active_animals.has(id) or not _animals[id]["alive"]:
			_animal_models[id].queue_free()
			_animal_models.erase(id)
			_animal_players.erase(id)
			_animal_stars[id].queue_free()
			_animal_stars.erase(id)
			_animal_shadows[id].queue_free()
			_animal_shadows.erase(id)
	for id in _active_animals:
		if not _animal_models.has(id):
			_add_animal_visual(id)


func _add_animal_visual(id: int) -> void:
	var kind: int = _animals[id]["kind"]
	var height: float = _animal_heights[kind]
	var model: Node3D
	if kind in [DEER, FOX, WOLF]:
		var filename := "deer" if kind == DEER else ("fox" if kind == FOX else "wolf")
		model = load("res://scenes/forest_25d/assets/" + filename + ".gltf").instantiate()
		stage.add_child(model)
		var bounds := _model_bounds(model)
		model.scale = Vector3.ONE * height / maxf(bounds.size.y, 0.01)
		model.rotation.y = -PI * 0.3 if id % 2 == 0 else PI * 0.25
		var animator := _find_animator(model)
		if animator != null:
			for animation in animator.get_animation_list():
				animator.get_animation(animation).loop_mode = Animation.LOOP_LINEAR
			animator.play("Idle")
			_animal_players[id] = animator
	else:
		var sprite := AnimatedSprite3D.new()
		var driver: AnimatedSprite2D = _active_animals[id]
		sprite.sprite_frames = driver.sprite_frames
		sprite.animation = "s"
		var texture := driver.sprite_frames.get_frame_texture("s", 0)
		sprite.pixel_size = height / (texture.get_height() * 0.7)
		sprite.offset = Vector2(0, texture.get_height() * 0.35)
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.alpha_scissor_threshold = 0.25
		sprite.shaded = false
		stage.add_child(sprite)
		model = sprite
	model.name = ANIMAL_NAMES[kind] + "_%d" % id
	_animal_models[id] = model
	var stars := Label3D.new()
	stars.text = "✦  ✦  ✦"
	stars.font_size = 32
	stars.pixel_size = 0.012
	stars.modulate = Color("ffe2a0")
	stars.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	stars.no_depth_test = false
	stars.visible = false
	stage.add_child(stars)
	_animal_stars[id] = stars
	var shadow := _contact_shadow(height * 0.45)
	stage.add_child(shadow)
	_animal_shadows[id] = shadow


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
	var radius := floori(landscape.EXTENT * METRE / TILE)
	for z in range(START.y - radius, START.y + radius + 1):
		for x in range(START.x - radius, START.x + radius + 1):
			var cell := Vector2i(x, z)
			if objects[_index(cell)] not in [MUSHROOM, BERRIES]:
				continue
			var p := to_ground(_cell_center(cell))
			if not landscape.can_walk(p, 0.12) or landscape.is_bridge(p):
				objects[_index(cell)] = EMPTY
				continue
			var key := Vector2i(floori(p.x / landscape.CHUNK), floori(p.y / landscape.CHUNK))
			if not _food_by_chunk.has(key):
				_food_by_chunk[key] = []
			_food_by_chunk[key].append(cell)


func _refresh_food() -> void:
	for cell in _forage_visuals.keys():
		var p := to_ground(_cell_center(cell))
		var key := Vector2i(floori(p.x / landscape.CHUNK), floori(p.y / landscape.CHUNK))
		if not landscape.chunks.has(key):
			_forage_visuals[cell].queue_free()
			_forage_visuals.erase(cell)
	for key in _food_chunks.keys():
		if not landscape.chunks.has(key):
			_food_chunks.erase(key)
	for key in landscape.chunks:
		if _food_chunks.has(key):
			continue
		_food_chunks[key] = true
		for cell in _food_by_chunk.get(key, []):
			if objects[_index(cell)] in [MUSHROOM, BERRIES]:
				_add_food_visual(cell)


func _add_food_visual(cell: Vector2i) -> void:
	var kind: int = objects[_index(cell)]
	if not _food_meshes.has(kind):
		_food_meshes[kind] = _food_cluster_mesh(kind)
	var node := MeshInstance3D.new()
	node.mesh = _food_meshes[kind]
	node.position = to_world(_cell_center(cell))
	stage.add_child(node)
	_forage_visuals[cell] = node


func _food_cluster_mesh(kind: int) -> ArrayMesh:
	var parts: Array[Dictionary] = []
	for i in 3:
		var off := Vector3((i - 1) * 0.13, 0, (i % 2) * 0.14)
		if kind == MUSHROOM:
			var stem := CylinderMesh.new()
			stem.top_radius = 0.04
			stem.bottom_radius = 0.055
			stem.height = 0.2
			stem.radial_segments = 8
			parts.append({"mesh": stem, "at": off + Vector3(0, 0.1, 0), "color": "ddd1a7"})
			var cap := SphereMesh.new()
			cap.radius = 0.14
			cap.height = 0.16
			cap.radial_segments = 10
			cap.rings = 4
			parts.append({"mesh": cap, "at": off + Vector3(0, 0.23, 0), "color": "b48150"})
		else:
			var berry := SphereMesh.new()
			berry.radius = 0.095
			berry.height = 0.19
			berry.radial_segments = 8
			berry.rings = 4
			parts.append({"mesh": berry, "at": off + Vector3(0, 0.09, 0), "color": "af4f59"})
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		var arrays: Array = part["mesh"].surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var color: Color = landscape.material(part["color"]).albedo_color
		for index in indices:
			st.set_color(color)
			st.set_normal(normals[index])
			st.add_vertex(vertices[index] + part["at"])
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	st.set_material(mat)
	return st.commit()


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
	for id in _animal_models:
		if not _valid_sling_target(id):
			continue
		var position: Vector3 = to_world(_animals[id]["position"]) + Vector3.UP * (_animal_heights[_animals[id]["kind"]] * 0.55)
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
	landscape.reveal_player(feet)
	heroine.position = feet + Vector3.UP * 0.02
	heroine.animation = _player.animation
	heroine.frame = _player.frame
	heroine.modulate = _player.modulate
	_shadow.position = feet + Vector3.UP * 0.015
	var camera_target := feet + CAMERA_OFFSET
	view.position = view.position.lerp(camera_target, 1 - exp(-5.0 * delta))
	var camera_center := Vector2(view.position.x - CAMERA_OFFSET.x, view.position.z - CAMERA_OFFSET.z)
	if landscape.stream(camera_center, _visible_half()):
		_refresh_food()
	_sync_animal_lifecycle()
	# Camera orientation stays fixed; facing remains aligned with screen controls.
	for id in _animal_models:
		var data: Dictionary = _animals[id]
		var model: Node3D = _animal_models[id]
		model.position = to_world(data["position"])
		var velocity: Vector2 = data["velocity"]
		var kind: int = data["kind"]
		if model is AnimatedSprite3D:
			var driver: AnimatedSprite2D = _active_animals[id]
			model.animation = driver.animation
			model.frame = driver.frame
			model.flip_h = driver.flip_h
			model.modulate = driver.modulate
		elif velocity.length_squared() > 1:
			model.rotation.y = atan2(velocity.x, velocity.y)
		if _animal_players.has(id):
			var animator: AnimationPlayer = _animal_players[id]
			var wanted := "Idle" if data["stun"] > 0.0 or velocity.length_squared() < 1 else "Walk"
			if data["stun"] <= 0.0 and (data["state"] == "forage" and data["eat_time"] > 0.0 or data["state"] == "feed" and data["feeding"] > 0.0) and animator.has_animation("Eating"):
				wanted = "Eating"
			if data["shoo"] > 0 and velocity.length_squared() > 1 and animator.has_animation("Gallop"):
				wanted = "Gallop"
			if animator.current_animation != wanted:
				animator.play(wanted, 0.2)
			animator.speed_scale = 0.0 if data["stun"] > 0 else (1.4 if data["shoo"] > 0 else 1.0)
		_animal_shadows[id].position = model.position + Vector3.UP * 0.015
		var stars: Label3D = _animal_stars[id]
		stars.position = model.position + Vector3.UP * (_animal_heights[kind] + 0.25 + sin(Time.get_ticks_msec() * 0.005) * 0.05)
		stars.text = "!! SCARED %.1fs" % data["shoo"] if data["shoo"] > 0 else ""
		if data["stun"] > 0:
			stars.text = ("STUNNED %.1fs\n" % data["stun"] + stars.text) if data["shoo"] > 0 else "✦ STUNNED %.1fs ✦" % data["stun"]
		stars.modulate = Color("ffcb79") if data["shoo"] > 0 else Color("ffe2a0")
		stars.no_depth_test = data["shoo"] > 0
		stars.visible = data["stun"] > 0.0 or data["shoo"] > 0.0

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
	_landmark_label.text = "Mossbank woods"
	for i in landscape.SITES.size():
		if p.distance_to(landscape.SITES[i]) < 8:
			_landmark_label.text = landscape.SITE_NAMES[i]
	if p.distance_to(Vector2(-48, 42)) < 15:
		_landmark_label.text = "Alderwater lake"
	elif p.distance_to(Vector2(38, -44)) < 16:
		_landmark_label.text = "Pinewater lake"
	if p.distance_to(landscape.WELL_POSITION) < 3.0:
		_landmark_label.text = "The forester’s old well"
	if _stats_label.visible:
		_stats_label.text = "%d FPS · %d draws · %dk triangles" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000]
