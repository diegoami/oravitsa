extends "res://scenes/forest_25d/landscape.gd"

## Unbounded deterministic world data. Chunks/cache keys are absolute; meshes
## are local to a rebased origin. Collision never depends on rendered meshes.
var origin := Vector2.ZERO
var _height_noise := FastNoiseLite.new()
var _biome_noise := FastNoiseLite.new()
var _bridge_cache: Dictionary = {}
var _fixed_nodes: Array[Node3D] = []
var _static_blockers: Array[Vector3] = []
var _grass_mesh: Mesh


func build() -> void:
	_height_noise.seed = 27102026
	_height_noise.frequency = 0.014
	_biome_noise.seed = 721019
	_biome_noise.frequency = 0.005
	_terrain_material = ShaderMaterial.new()
	_terrain_material.shader = load("res://scenes/endless_woods/ground.gdshader")
	_water_material = ShaderMaterial.new()
	_water_material.shader = load("res://scenes/endless_woods/water.gdshader")
	_prepare_trees()
	_rng.seed = 10262026
	_cottage()
	var details = load("res://scenes/forest_25d/cottage_details.gd").new()
	add_child(details)
	details.build(self)
	for child in get_children():
		if child is Node3D and not child.is_queued_for_deletion():
			_fixed_nodes.append(child)


func random_at(key: Vector2i, salt: int = 0) -> float:
	var n := (int(key.x) * 73856093) ^ (int(key.y) * 19349663) ^ (salt * 83492791)
	n = (n ^ (n >> 13)) * 1274126177
	return float(n & 0x7fffffff) / 2147483648.0


func road_z(x: float, row: int) -> float:
	var phase := 0.0 if row == 0 else random_at(Vector2i(0, row), 3) * TAU
	return row * 128.0 + 5 + sin(x * 0.022 + phase) * 8 + sin(x * 0.061 + phase) * 3


func road_x(z: float, column: int) -> float:
	var phase := random_at(Vector2i(column, 0), 5) * TAU
	return column * 256.0 + 70 + sin(z * 0.018 + phase) * 14 + sin(z * 0.047) * 4


func river_x(z: float, column: int = 0) -> float:
	var phase := 0.0 if column == 0 else random_at(Vector2i(column, 0), 9) * TAU
	return column * 256.0 - 6 + sin(z * 0.018 + phase) * 8 + sin(z * 0.051 + phase) * 3


func biome_at(p: Vector2) -> int:
	var q := p + origin
	var value := _biome_noise.get_noise_2d(q.x, q.y)
	return 0 if value < -0.22 else (1 if value < 0.02 else (2 if value < 0.26 else 3))


func biome_name(p: Vector2) -> String:
	return ["Alder marsh", "Wildflower meadow", "Birch woodland", "Pine wilderness"][biome_at(p)]


func lake_at(region: Vector2i) -> Vector4:
	return Vector4(region.x * 256 + 180 + random_at(region, 12) * 10, region.y * 128 + 64 + random_at(region, 13) * 8, 12 + random_at(region, 14) * 12, 8 + random_at(region, 15) * 8)


func landmark_at(region: Vector2i) -> Dictionary:
	return {"position": Vector2(region.x * 256 + 116 + random_at(region, 21) * 18, region.y * 128 + 55 + random_at(region, 22) * 24), "kind": int(random_at(region, 23) * 4)}


func _bridge_at(q: Vector2) -> Vector3:
	var key := Vector2i(roundi((q.x + 6) / 256.0), roundi((q.y - 5) / 128.0))
	if not _bridge_cache.has(key):
		var z := key.y * 128.0 + 5
		var x := river_x(z, key.x)
		for i in 5:
			z = road_z(x, key.y)
			x = river_x(z, key.x)
		var angle := atan((road_z(x + 0.2, key.y) - road_z(x - 0.2, key.y)) / 0.4)
		_bridge_cache[key] = Vector3(x, z, angle)
	return _bridge_cache[key]


func trail_distance(p: Vector2) -> float:
	var q := p + origin
	var row := roundi((q.y - 5) / 128.0)
	var column := roundi((q.x - 70) / 256.0)
	var distance := minf(absf(q.y - road_z(q.x, row)), absf(q.x - road_x(q.y, column)))
	var region := Vector2i(floori(q.x / 256), floori(q.y / 128))
	var feature := landmark_at(region)
	var site: Vector2 = feature["position"]
	# Ruins have a solid west wall and an open south side. Approach below
	# the walls, then turn north through that opening rather than into stone.
	var approach := site + Vector2(0, 4.5) if feature["kind"] == 0 else site
	var start := road_x(approach.y, region.x)
	if q.x >= start and q.x <= site.x:
		var t := (q.x - start) / maxf(1, site.x - start)
		var path_z := approach.y + sin(t * PI) * (3 + random_at(region, 29) * 4)
		distance = minf(distance, absf(q.y - path_z))
	if feature["kind"] == 0:
		distance = minf(distance, _segment_distance(q, approach, site))
	if q.y > -7 and q.y < 6:
		distance = minf(distance, absf(q.x - 7))
	distance = minf(distance, _segment_distance(q, Vector2(7, -0.8), WELL_POSITION + Vector2(0, 1.8)))
	return distance


func water_edge(p: Vector2) -> float:
	var q := p + origin
	var column := roundi((q.x + 6) / 256.0)
	var edge := absf(q.x - river_x(q.y, column)) / 1.7
	var lake := lake_at(Vector2i(floori(q.x / 256), floori(q.y / 128)))
	return minf(edge, ((q - Vector2(lake.x, lake.y)) / Vector2(lake.z, lake.w)).length())


func is_water(p: Vector2, margin: float = 0.0) -> bool:
	return water_edge(p) < 1.0 + margin / 1.7


func is_bridge(p: Vector2) -> bool:
	var q := p + origin
	var b := _bridge_at(q)
	var local := (q - Vector2(b.x, b.y)).rotated(-b.z)
	return absf(local.x) <= 3.2 and absf(local.y) <= 1.4


func terrain_height_at(p: Vector2) -> float:
	var q := p + origin
	if Rect2(4.5, -6.2, 5, 4.4).has_point(q):
		return 0.37
	var hill := maxf(0.15, 0.40 + _height_noise.get_noise_2d(q.x, q.y) * 0.8)
	var edge := water_edge(p)
	var dry := clampf((edge - 1) / 0.7, 0, 1)
	var h := lerpf(-0.75, -0.08, clampf((edge - 0.25) / 0.75, 0, 1)) if edge < 1 else lerpf(-0.08, hill, dry * (2 - dry))
	if edge >= 1:
		var b := _bridge_at(q)
		var local := (q - Vector2(b.x, b.y)).rotated(-b.z)
		var approach := (1 - smoothstep(3.1, 4.8, absf(local.x))) * (1 - smoothstep(1.3, 2.3, absf(local.y)))
		h = lerpf(h, 0.04, approach)
	return h


func height_at(p: Vector2) -> float:
	var q := p + origin
	if Rect2(4.5, -6.2, 5, 4.4).has_point(q) or Rect2(6.3, -1.975, 1.4, 0.75).has_point(q):
		return 0.55
	var h := terrain_height_at(p)
	if q.x >= 6.3 and q.x <= 7.7 and q.y >= -1.225 and q.y < -0.35:
		return lerpf(0.55, h, smoothstep(-1.225, -0.35, q.y))
	var b := _bridge_at(q)
	var local := (q - Vector2(b.x, b.y)).rotated(-b.z)
	if absf(local.y) <= 1.4 and absf(local.x) <= 4.6:
		return lerpf(0.24, h, smoothstep(3.2, 4.6, absf(local.x)))
	return h


func _reserved(p: Vector2) -> bool:
	var q := p + origin
	var site: Vector2 = landmark_at(Vector2i(floori(q.x / 256), floori(q.y / 128)))["position"]
	return q.length() < 5 or Rect2(3, -8, 12, 10).has_point(q) or trail_distance(p) < 2.8 or q.distance_to(site) < 5.5


func _register_blocker(p: Vector2, radius: float) -> void:
	_static_blockers.append(Vector3(p.x + origin.x, p.y + origin.y, radius))


func _ensure_nature(key: Vector2i) -> Dictionary:
	if _nature.has(key):
		return _nature[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_for(key)
	var trees: Array[Vector3] = []
	var rocks: Array[Vector3] = []
	var density: int = [5, 5, 12, 17][biome_at(Vector2(key) * CHUNK - origin)]
	for i in density:
		var q := Vector2(key) * CHUNK + Vector2(rng.randf(), rng.randf()) * CHUNK
		if is_water(q - origin, 0.7) or _reserved(q - origin):
			continue
		trees.append(Vector3(q.x, q.y, rng.randf_range(4.0, 7.0)))
	for i in 4:
		var q := Vector2(key) * CHUNK + Vector2(rng.randf(), rng.randf()) * CHUNK
		if is_water(q - origin, 0.3) or _reserved(q - origin):
			continue
		rocks.append(Vector3(q.x, q.y, rng.randf_range(0.2, 0.6)))
	_nature[key] = {"trees": trees, "rocks": rocks}
	return _nature[key]


func can_walk(p: Vector2, radius: float) -> bool:
	for off in [Vector2.ZERO, Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius), Vector2(0, -radius)]:
		if is_water(p + off) and not is_bridge(p + off):
			return false
	var q := p + origin
	var key := Vector2i(floori(q.x / CHUNK), floori(q.y / CHUNK))
	for z in range(key.y - 1, key.y + 2):
		for x in range(key.x - 1, key.x + 2):
			var data := _ensure_nature(Vector2i(x, z))
			for tree in data["trees"]:
				if q.distance_to(Vector2(tree.x, tree.y)) < radius + 0.30:
					return false
			for rock in data["rocks"]:
				if q.distance_to(Vector2(rock.x, rock.y)) < radius + rock.z * 0.7:
					return false
	for b in _static_blockers:
		if q.distance_to(Vector2(b.x, b.y)) < radius + b.z:
			return false
	for wall in walls:
		if wall.grow(radius).has_point(q):
			return false
	var landmark := landmark_at(Vector2i(floori(q.x / 256), floori(q.y / 128)))
	var d: Vector2 = q - landmark["position"]
	if landmark["kind"] == 0 and (Rect2(-2.6, -2.2, 0.3, 4.4).grow(radius).has_point(d) or Rect2(2.3, -2.2, 0.3, 4.4).grow(radius).has_point(d) or Rect2(-2.6, -2.2, 5.2, 0.3).grow(radius).has_point(d)):
		return false
	if landmark["kind"] == 1:
		for i in 7:
			if d.distance_to(Vector2.from_angle(i * TAU / 7.0) * 2.2) < radius + 0.28:
				return false
	return true


func ground_color(p: Vector2) -> Color:
	var q := p + origin
	var color: Color = [Color("65754d"), Color("7f8950"), Color("657b48"), Color("536b43")][biome_at(p)]
	color = color.lerp(Color("85905e"), random_at(Vector2i(floori(q.x), floori(q.y)), 28) * 0.18)
	color = color.lerp(Color("99815c"), (1 - smoothstep(0.8, 1.7, trail_distance(p))) * 0.85)
	color = color.lerp(Color("596858"), (1 - smoothstep(1, 1.5, water_edge(p))) * 0.8)
	return color


func stream(center: Vector2, half: Vector2) -> bool:
	var minimum := Vector2i(((center + origin - half - Vector2.ONE * 11) / CHUNK).floor())
	var maximum := Vector2i(((center + origin + half + Vector2.ONE * 11) / CHUNK).floor())
	var rect := Rect2i(minimum, maximum - minimum + Vector2i.ONE)
	var immediate := chunks.is_empty() or center.distance_to(_stream_center) > 9 or not half.is_equal_approx(_stream_half)
	_stream_center = center
	_stream_half = half
	var changed := rect != _stream_rect
	if changed:
		_stream_rect = rect
		for key in chunks.keys():
			if not rect.has_point(key):
				chunks[key].queue_free()
				chunks.erase(key)
		_pending_chunks.clear()
		for z in range(minimum.y, maximum.y + 1):
			for x in range(minimum.x, maximum.x + 1):
				if not chunks.has(Vector2i(x, z)):
					_pending_chunks.append(Vector2i(x, z))
		_pending_chunks.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (Vector2(a) * CHUNK - center - origin).length_squared() < (Vector2(b) * CHUNK - center - origin).length_squared())
	var frame := Engine.get_process_frames()
	var budget := _pending_chunks.size() if immediate else (1 if frame != _last_build_frame else 0)
	for i in mini(budget, _pending_chunks.size()):
		var key: Vector2i = _pending_chunks.pop_front()
		var chunk := Node3D.new()
		chunk.name = "Woods_%d_%d" % [key.x, key.y]
		add_child(chunk)
		chunks[key] = chunk
		_build_parent = chunk
		_terrain_chunk(key)
		_vegetation_chunk(key)
		_landmark_chunk(key)
		_last_build_frame = frame
		changed = true
	_build_parent = null
	for key in _nature.keys():
		if not rect.grow(2).has_point(key):
			_nature.erase(key)
	for key in _bridge_cache.keys():
		if absf(key.x * 256 - center.x - origin.x) > 600 or absf(key.y * 128 - center.y - origin.y) > 400:
			_bridge_cache.erase(key)
	return changed


func _terrain_chunk(key: Vector2i) -> void:
	var cells := 32
	var step := CHUNK / cells
	var stride := cells + 3
	var heights := PackedFloat32Array()
	heights.resize(stride * stride)
	var base := Vector2(key) * CHUNK - origin
	for z in stride:
		for x in stride:
			heights[z * stride + x] = terrain_height_at(base + Vector2(x - 1, z - 1) * step)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in cells + 1:
		for x in cells + 1:
			var p := base + Vector2(x, z) * step
			var h := (z + 1) * stride + x + 1
			st.set_color(ground_color(p))
			st.set_normal(Vector3(heights[h - 1] - heights[h + 1], step * 2, heights[h - stride] - heights[h + stride]).normalized())
			st.add_vertex(Vector3(p.x, heights[h], p.y))
	for z in cells:
		for x in cells:
			var i := z * (cells + 1) + x
			for index in [i, i + cells + 1, i + 1, i + 1, i + cells + 1, i + cells + 2]:
				st.add_index(index)
	_mesh(st.commit(), _terrain_material)
	var water := PlaneMesh.new()
	water.size = Vector2.ONE * CHUNK
	_mesh(water, _water_material, Vector3(base.x + CHUNK * 0.5, -0.08, base.y + CHUNK * 0.5))


func _vegetation_chunk(key: Vector2i) -> void:
	var data := _ensure_nature(key)
	var trees: Array[Vector3] = []
	for tree in data["trees"]:
		trees.append(Vector3(tree.x - origin.x, tree.y - origin.y, tree.z))
	_tree_batches(trees)
	var rocks: Array[Transform3D] = []
	for rock in data["rocks"]:
		var p := Vector2(rock.x, rock.y) - origin
		rocks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(rock.z, rock.z * 0.6, rock.z * 0.8)), Vector3(p.x, height_at(p) + rock.z * 0.2, p.y)))
	_batch(_sphere(), material("858879"), rocks)
	var grasses: Array[Transform3D] = []
	var flowers: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_for(key) ^ 1783
	for i in 120:
		var p := Vector2(key) * CHUNK - origin + Vector2(rng.randf(), rng.randf()) * CHUNK
		if is_water(p) or is_bridge(p) or trail_distance(p) < 1.6 or (p + origin).distance_to(Vector2(7, -4)) < 4:
			continue
		var h := rng.randf_range(0.12, 0.3)
		grasses.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * h), Vector3(p.x, height_at(p), p.y)))
		if i % (5 if biome_at(p) == 1 else 15) == 0:
			flowers.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.06, 0.04, 0.06)), Vector3(p.x, height_at(p) + h, p.y)))
	if _grass_mesh == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 3:
			var side := Vector3(cos(i * PI / 3), 0, sin(i * PI / 3)) * 0.18
			_tri(st, -side, Vector3.UP, side)
		_grass_mesh = st.commit()
	var grass_material := material("69814b")
	grass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_batch(_grass_mesh, grass_material, grasses)
	_batch(_sphere(), material("dcc783"), flowers)


func _landmark_chunk(key: Vector2i) -> void:
	var center := Vector2(key) * CHUNK + Vector2.ONE * CHUNK * 0.5
	var bridge := _bridge_at(center)
	if Vector2i(floori(bridge.x / CHUNK), floori(bridge.y / CHUNK)) == key:
		var pos := Vector2(bridge.x, bridge.y) - origin
		for i in 19:
			var p := pos + Vector2(-3.06 + i * 0.34, 0).rotated(bridge.z)
			var plank := box(Vector3(p.x, 0.16, p.y), Vector3(0.32, 0.16, 2.8), "796247" if i % 3 else "8d7553")
			plank.rotation.y = -bridge.z
		for side in [-1, 1]:
			_ramp(pos + Vector2(side * 3.2, 0).rotated(bridge.z), pos + Vector2(side * 4.6, 0).rotated(bridge.z), 1.4, "796247")
			for end in [-1, 1]:
				var p := pos + Vector2(side * 3, end * 1.45).rotated(bridge.z)
				box(Vector3(p.x, 0.55, p.y), Vector3(0.14, 1.1, 0.14), "645540")
	var region := Vector2i(floori(center.x / 256), floori(center.y / 128))
	var feature := landmark_at(region)
	var absolute: Vector2 = feature["position"]
	if Vector2i((absolute / CHUNK).floor()) != key:
		return
	var p := absolute - origin
	var y := height_at(p)
	if feature["kind"] == 0:
		for side in [-1, 1]:
			for i in 8:
				var h := 0.5 + random_at(region + Vector2i(i, side), 40) * 1.2
				box(Vector3(p.x + side * 2.45, y + h * 0.5, p.y - 1.9 + i * 0.55), Vector3(0.3, h, 0.5), "7c7e6c")
		box(Vector3(p.x, y + 0.55, p.y - 2.05), Vector3(5.2, 1.1, 0.3), "737563")
	elif feature["kind"] == 1:
		for i in 7:
			var q := p + Vector2.from_angle(i * TAU / 7.0) * 2.2
			box(Vector3(q.x, height_at(q) + 0.5, q.y), Vector3(0.4, 1.0, 0.4), "808774")
	elif feature["kind"] == 2:
		for i in 5:
			var log := box(Vector3(p.x + i * 0.3, y + 0.16, p.y), Vector3(0.25, 0.3, 2.3), "6a553c")
			log.rotation.y = 0.25
	else:
		for i in 8:
			var q := p + Vector2(random_at(region + Vector2i(i, 0), 50) - 0.5, random_at(region + Vector2i(0, i), 51) - 0.5) * 5
			box(Vector3(q.x, height_at(q) + 0.2, q.y), Vector3(0.5, 0.4, 0.5), "788471")


func rebase(delta: Vector2) -> void:
	origin += delta
	var shift := Vector3(delta.x, 0, delta.y)
	for chunk in chunks.values():
		chunk.position -= shift
	for node in _fixed_nodes:
		node.position -= shift
	_stream_center -= delta
