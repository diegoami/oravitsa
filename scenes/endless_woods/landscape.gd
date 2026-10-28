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
# Empty hamlets: one per block of 2 road columns x 3 road rows (512 x 384 m),
# at a seeded crossing, so about one crossing in six. Caves: exterior mouths
# on high ground in some landmark regions without a homestead.
const HAMLET_BLOCK := Vector2(512, 384)
const HAMLET_RADIUS := 30.0
const HAMLET_SLOTS := [Vector2(-12, -10), Vector2(12, -10), Vector2(-12, 10), Vector2(12, 10), Vector2(-25, -10), Vector2(25, 10)]
const HOUSE_SIZE := Vector2(4.2, 3.4)
const CAVE_CHANCE := 0.8
const CAVE_MIN_HEIGHT := 0.55
var _hamlet_cache: Dictionary = {}
var _cave_cache: Dictionary = {}


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


func _road_distance(q: Vector2) -> float:
	var row := roundi((q.y - 5) / 128.0)
	var column := roundi((q.x - 70) / 256.0)
	return minf(absf(q.y - road_z(q.x, row)), absf(q.x - road_x(q.y, column)))


func crossing(column: int, row: int) -> Vector2:
	var z := row * 128.0 + 5
	var x := road_x(z, column)
	for i in 6:
		z = road_z(x, row)
		x = road_x(z, column)
	return Vector2(x, z)


## The empty hamlet of an absolute block, or {} when its site is unusable.
func hamlet_at(block: Vector2i) -> Dictionary:
	if _hamlet_cache.has(block):
		return _hamlet_cache[block]
	var column := block.x * 2 + (1 if random_at(block, 61) < 0.5 else 0)
	var row := block.y * 3 + 1
	var center := crossing(column, row)
	var order: Array = range(HAMLET_SLOTS.size())
	order.sort_custom(func(a: int, b: int) -> bool: return random_at(block + Vector2i(a * 7, 3), 70) < random_at(block + Vector2i(b * 7, 3), 70))
	var wanted := 3 + int(random_at(block, 62) * 4)
	var houses: Array[Rect2] = []
	var doors: Array[Vector4] = []
	for slot in order:
		if houses.size() >= wanted:
			break
		var offset: Vector2 = HAMLET_SLOTS[slot]
		var house := Rect2(center + offset - HOUSE_SIZE * 0.5, HOUSE_SIZE)
		var clear := true
		for corner in [house.position, house.end, Vector2(house.position.x, house.end.y), Vector2(house.end.x, house.position.y), house.get_center()]:
			if _road_distance(corner) < 3.5 or water_edge(corner - origin) < 1.6:
				clear = false
		if not clear:
			continue
		houses.append(house)
		# Doors face the east/west road; a short trail joins them to it.
		var side := 1.0 if offset.y < 0 else -1.0
		var door := house.get_center() + Vector2(0, side * HOUSE_SIZE.y * 0.5)
		doors.append(Vector4(door.x, door.y, door.x, road_z(door.x, row)))
	var quadrant := Vector2(-1 if random_at(block, 63) < 0.5 else 1, -1 if random_at(block, 64) < 0.5 else 1)
	var well := center + quadrant * 5.5
	var result := {}
	if houses.size() >= 3 and water_edge(well - origin) > 1.6:
		result = {"center": center, "houses": houses, "doors": doors, "well": well, "block": block}
	_hamlet_cache[block] = result
	return result


func hamlet_near(q: Vector2) -> Dictionary:
	return hamlet_at(Vector2i(floori(q.x / HAMLET_BLOCK.x), floori(q.y / HAMLET_BLOCK.y)))


## Inside a hamlet's bare clearing (local coordinates): no food, trees or spawns.
func in_settlement(p: Vector2) -> bool:
	var q := p + origin
	var hamlet := hamlet_near(q)
	return not hamlet.is_empty() and q.distance_to(hamlet["center"]) < HAMLET_RADIUS


## The exterior cave mouth of a landmark region, or {} when it has none.
func cave_at(region: Vector2i) -> Dictionary:
	if _cave_cache.has(region):
		return _cave_cache[region]
	var result := {}
	var feature := landmark_at(region)
	if feature["kind"] != 0 and random_at(region, 81) < CAVE_CHANCE:
		var best := -INF
		var mouth := Vector2.ZERO
		for i in 14:
			var q := Vector2(region.x * 256 + 20 + random_at(region, 90 + i) * 216, region.y * 128 + 24 + random_at(region, 110 + i) * 80)
			if _road_distance(q) < 14 or q.distance_to(feature["position"]) < 16 or water_edge(q - origin) < 3:
				continue
			var hamlet := hamlet_near(q)
			if not hamlet.is_empty() and q.distance_to(hamlet["center"]) < HAMLET_RADIUS + 12:
				continue
			var h := terrain_height_at(q - origin)
			if h > best:
				best = h
				mouth = q
		if best >= CAVE_MIN_HEIGHT:
			# The fixed camera looks north, so every mouth opens south toward it.
			# The trail leaves the mouth southward, then turns to the nearest road.
			var facing := Vector2(0, 1)
			var elbow := mouth + facing * 6.0
			var row := roundi((elbow.y - 5) / 128.0)
			var options := [Vector2(road_x(elbow.y, region.x), elbow.y), Vector2(elbow.x, road_z(elbow.x, row))]
			options.sort_custom(func(u: Vector2, v: Vector2) -> bool: return elbow.distance_to(u) < elbow.distance_to(v))
			# Trees and trail dressing look up the cave of their own region, so
			# the whole trail must stay inside this region.
			var inside := Rect2(Vector2(region) * Vector2(256, 128), Vector2(256, 128)).grow(-3)
			var parts := _cave_parts(mouth, facing, region)
			for road in options:
				if elbow.distance_to(road) > 80:
					continue
				var clear := true
				for leg in [[mouth, elbow], [elbow, road]]:
					for step in int(leg[0].distance_to(leg[1])) + 1:
						var q: Vector2 = leg[0].move_toward(leg[1], step)
						if water_edge(q - origin) < 1.5 or q.distance_to(feature["position"]) < 7 or not inside.has_point(q):
							clear = false
						for part in parts:
							if q.distance_to(Vector2(part.x, part.y)) < part.z + 0.5:
								clear = false # Never route the trail back through the outcrop.
				if clear:
					result = {"mouth": mouth, "facing": facing, "elbow": elbow, "road": road, "parts": parts, "region": region}
					break
	_cave_cache[region] = result
	return result


## Rock parts as (x, z, radius, height): one list drives collision and meshes,
## so no rock can be walked into or stop Oravitsa short of its surface.
func _cave_parts(mouth: Vector2, facing: Vector2, region: Vector2i) -> Array[Vector4]:
	var side := Vector2(-facing.y, facing.x)
	var parts: Array[Vector4] = []
	for i in 5:
		var at := mouth - facing * (3.2 + (i % 2) * 0.8) + side * (i - 2) * 1.1
		parts.append(Vector4(at.x, at.y, 2.4, 2.4 + random_at(region + Vector2i(i, 0), 82) * 1.2))
	for s in [-1, 1]:
		var at: Vector2 = mouth - facing * 1.0 + side * s * 1.9
		parts.append(Vector4(at.x, at.y, 0.85, 0.9))
	return parts


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
	var hamlet := hamlet_near(q)
	if not hamlet.is_empty() and q.distance_to(hamlet["center"]) < HAMLET_RADIUS + 20:
		for door in hamlet["doors"]:
			distance = minf(distance, _segment_distance(q, Vector2(door.x, door.y), Vector2(door.z, door.w)))
	var cave := cave_at(region)
	if not cave.is_empty():
		distance = minf(distance, minf(_segment_distance(q, cave["mouth"] + cave["facing"] * 0.6, cave["elbow"]), _segment_distance(q, cave["elbow"], cave["road"])))
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
	if in_settlement(p):
		return true
	var cave := cave_at(Vector2i(floori(q.x / 256), floori(q.y / 128)))
	if not cave.is_empty() and q.distance_to(cave["mouth"] - cave["facing"] * 2.0) < 7.0:
		return true
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
	var hamlet := hamlet_near(q)
	if not hamlet.is_empty() and q.distance_to(hamlet["center"]) < HAMLET_RADIUS + 4:
		for house in hamlet["houses"]:
			if house.grow(radius).has_point(q):
				return false
		if q.distance_to(hamlet["well"]) < radius + 0.7:
			return false
	var cave := cave_at(Vector2i(floori(q.x / 256), floori(q.y / 128)))
	if not cave.is_empty() and q.distance_to(cave["mouth"]) < 8:
		for part in cave["parts"]:
			if q.distance_to(Vector2(part.x, part.y)) < radius + part.z:
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
	for key in _hamlet_cache.keys():
		if absf((key.x + 0.5) * HAMLET_BLOCK.x - center.x - origin.x) > 1100 or absf((key.y + 0.5) * HAMLET_BLOCK.y - center.y - origin.y) > 800:
			_hamlet_cache.erase(key)
	for key in _cave_cache.keys():
		if absf(key.x * 256 - center.x - origin.x) > 600 or absf(key.y * 128 - center.y - origin.y) > 400:
			_cave_cache.erase(key)
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
	_hamlet_chunk(key, hamlet_near(center))
	_cave_chunk(key, cave_at(region))
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


func _in_chunk(q: Vector2, key: Vector2i) -> bool:
	return Vector2i((q / CHUNK).floor()) == key


func _hamlet_chunk(key: Vector2i, hamlet: Dictionary) -> void:
	if hamlet.is_empty():
		return
	var block: Vector2i = hamlet["block"]
	for i in hamlet["houses"].size():
		var house: Rect2 = hamlet["houses"][i]
		if _in_chunk(house.get_center(), key):
			_empty_house(house, hamlet["doors"][i], block + Vector2i(i * 13, 5))
	var well: Vector2 = hamlet["well"]
	if _in_chunk(well, key):
		var p := well - origin
		var y := height_at(p)
		for side in 4:
			var offset := Vector2(0.55, 0).rotated(side * PI * 0.5)
			var stone := box(Vector3(p.x + offset.x, y + 0.35, p.y + offset.y), Vector3(0.28, 0.7, 1.2), "7d7f70")
			stone.rotation.y = side * PI * 0.5
		box(Vector3(p.x, y + 0.05, p.y), Vector3(0.9, 0.1, 0.9), "1e2420")
		for side in [-1, 1]:
			box(Vector3(p.x + side * 0.55, y + 1.1, p.y), Vector3(0.1, 1.5, 0.1), "5d5240")
		box(Vector3(p.x, y + 1.85, p.y), Vector3(1.4, 0.1, 0.5), "5b5446")


## A closed, weathered cottage: grey timber walls, a shut door facing the road,
## a dark window, and a seeded collapsed roof section and cold chimney.
func _empty_house(house: Rect2, door: Vector4, seed_key: Vector2i) -> void:
	var c := house.get_center() - origin
	var low := INF
	for corner in [house.position, house.end, Vector2(house.position.x, house.end.y), Vector2(house.end.x, house.position.y)]:
		low = minf(low, height_at(corner - origin))
	var base := low - 0.1
	var walls_color := "8a8574" if random_at(seed_key, 1) < 0.5 else "7d7a6b"
	box(Vector3(c.x, base + 1.25, c.y), Vector3(house.size.x, 2.5, house.size.y), walls_color)
	box(Vector3(c.x, base + 2.52, c.y), Vector3(house.size.x - 0.2, 0.04, house.size.y - 0.2), "24261f")
	var front := signf(door.y - house.get_center().y)
	var face := c.y + front * (house.size.y * 0.5 + 0.03)
	box(Vector3(c.x, base + 0.95, face), Vector3(0.9, 1.7, 0.06), "4f4433")
	box(Vector3(c.x + 1.2, base + 1.55, face), Vector3(0.7, 0.6, 0.06), "1f2a26")
	# Shuttered windows on the back wall too, since the camera may face it.
	var back := c.y - front * (house.size.y * 0.5 + 0.03)
	for x in [c.x - 1.0, c.x + 0.9]:
		box(Vector3(x, base + 1.5, back), Vector3(0.7, 0.6, 0.06), "1f2a26")
		box(Vector3(x, base + 1.5, back - front * 0.02), Vector3(0.12, 0.66, 0.06), "5a4c37")
	for x in [c.x - house.size.x * 0.5, c.x + house.size.x * 0.5]:
		box(Vector3(x, base + 1.25, c.y), Vector3(0.14, 2.55, house.size.y + 0.1), "5a5343")
	var missing := int(random_at(seed_key, 2) * 6)
	for side in [-1, 1]:
		for section in 3:
			if section + (side + 1) * 1.5 == missing:
				continue # A collapsed section shows the dark rafters below.
			var roof := box(Vector3(c.x, base + 3.0, c.y + side * 0.9), Vector3(house.size.x + 0.3, 0.14, 2.1), "4b5446" if section % 2 else "585c4c")
			roof.position.x = c.x - house.size.x * 0.5 + (section + 0.5) * (house.size.x / 3.0)
			roof.scale.x = 1.0 / 3.0 + 0.02
			roof.rotation.x = side * 0.55
	box(Vector3(c.x, base + 3.45, c.y), Vector3(house.size.x + 0.2, 0.12, 0.16), "4d4738")
	if random_at(seed_key, 3) < 0.7:
		box(Vector3(c.x + house.size.x * 0.3, base + 3.6, c.y - 0.5), Vector3(0.5, 1.2, 0.5), "6f7062")


## A mossy outcrop with a dark recessed mouth facing its trail; Oravitsa can
## stand in the entrance, while the rock mass stays solid.
func _cave_chunk(key: Vector2i, cave: Dictionary) -> void:
	if cave.is_empty() or not _in_chunk(cave["mouth"], key):
		return
	var mouth: Vector2 = cave["mouth"]
	var facing: Vector2 = cave["facing"]
	var side := Vector2(-facing.y, facing.x)
	var region: Vector2i = cave["region"]
	var angle := atan2(facing.x, facing.y)
	for i in cave["parts"].size():
		var part: Vector4 = cave["parts"][i]
		var p := Vector2(part.x, part.y) - origin
		var rock := _mesh(_sphere(), material(["5f6458", "686c5e", "636758"][i % 3]), Vector3(p.x, height_at(p) + part.w * 0.3, p.y))
		rock.scale = Vector3(part.z, part.w, part.z)
	var m := mouth - facing * 0.85 - origin
	var opening := box(Vector3(m.x, height_at(m) + 0.75, m.y), Vector3(1.8, 1.5, 0.5), "121512")
	opening.rotation.y = angle
	var lintel := box(Vector3(m.x, height_at(m) + 1.6, m.y), Vector3(2.4, 0.4, 0.7), "6a6e60")
	lintel.rotation.y = angle
	var moss: Array[Transform3D] = []
	for i in 18:
		var q := mouth - facing * (2.0 + random_at(region + Vector2i(i, 1), 83) * 2.5) + side * (random_at(region + Vector2i(1, i), 84) - 0.5) * 6.0 - origin
		moss.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.35, 0.18, 0.35)), Vector3(q.x, height_at(q) + 1.9 + random_at(region + Vector2i(i, i), 85) * 0.6, q.y)))
	_batch(_sphere(), material("4f6a41"), moss)


func rebase(delta: Vector2) -> void:
	origin += delta
	var shift := Vector3(delta.x, 0, delta.y)
	for chunk in chunks.values():
		chunk.position -= shift
	for node in _fixed_nodes:
		node.position -= shift
	_stream_center -= delta
