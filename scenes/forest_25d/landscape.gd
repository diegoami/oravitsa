extends Node3D

## Deterministic world data is independent of the streamed render nodes.
const EXTENT := 96.0
const CHUNK := 16.0
const LAKES := [Vector4(-9, -5, 5.5, 4.5), Vector4(38, -44, 12, 9), Vector4(-48, 42, 11, 8)]
const TRIBUTARY := [Vector2(-48, 42), Vector2(-30, 30), Vector2(-12, 28), Vector2(-5.419, 24)]
const SITES := [Vector2(7, -4), Vector2(45, -30), Vector2(-64, 28), Vector2(-55, -45), Vector2(35, 58)]
const SITE_NAMES := ["Forester’s cottage", "Old watchhouse", "Alderwater mill", "Overgrown orchard", "Southern shelter"]
var blockers: Array[Vector3] = []
var walls: Array[Rect2] = []
var roofs: Array[MeshInstance3D] = []
var bridges: Array[Vector3] = [] # x, z, rotation in the ground plane.
var chunks: Dictionary = {}
var _nature: Dictionary = {}
var _blocker_cells: Dictionary = {}
var _materials: Dictionary = {}
var _tree_sources: Array[Dictionary] = []
var _leaf_materials: Array[ShaderMaterial] = []
var _rng := RandomNumberGenerator.new()
var _build_parent: Node3D
var _terrain_material: ShaderMaterial
var _water_material: ShaderMaterial
var _stream_rect := Rect2i()


func river_x(z: float) -> float:
	if z >= -5.0:
		return -5.0 + 1.5 * sin(z * 0.25)
	return lerpf(-6.423477, 38.0, clampf((-z - 5.0) / 39.0, 0, 1)) + sin((z + 5.0) * 0.15)


func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(a + (b - a) * clampf((p - a).dot(b - a) / (b - a).length_squared(), 0, 1))


func water_edge(p: Vector2) -> float:
	var edge := absf(p.x - river_x(p.y)) / 1.2
	for lake in LAKES:
		edge = minf(edge, ((p - Vector2(lake.x, lake.y)) / Vector2(lake.z, lake.w)).length())
	for i in TRIBUTARY.size() - 1:
		edge = minf(edge, _segment_distance(p, TRIBUTARY[i], TRIBUTARY[i + 1]) / 1.2)
	return edge


func is_water(p: Vector2, margin: float = 0.0) -> bool:
	if absf(p.x - river_x(p.y)) < 1.2 + margin:
		return true
	for lake in LAKES:
		if ((p - Vector2(lake.x, lake.y)) / Vector2(lake.z + margin, lake.w + margin)).length() < 1.0:
			return true
	for i in TRIBUTARY.size() - 1:
		if _segment_distance(p, TRIBUTARY[i], TRIBUTARY[i + 1]) < 1.2 + margin:
			return true
	return false


func is_bridge(p: Vector2) -> bool:
	for b in bridges:
		var local := (p - Vector2(b.x, b.y)).rotated(-b.z)
		if absf(local.x) < 2.6 and absf(local.y) < 0.85:
			return true
	return false


func height_at(p: Vector2) -> float:
	if is_bridge(p):
		return 0.27
	if Rect2(4.5, -6.2, 5.0, 4.4).has_point(p):
		return 0.55
	return terrain_height_at(p)


func terrain_height_at(p: Vector2) -> float:
	# Walking surfaces belong to the structures, not to the ground mesh. Baking
	# their tops into the terrain produces coplanar faces and camera-motion flicker.
	if Rect2(4.5, -6.2, 5.0, 4.4).has_point(p):
		return 0.37 # Below the cottage foundation, whose bottom is at 0.39.
	var hill := 0.22 * sin(p.x * 0.16) * cos(p.y * 0.14) + 0.8 * exp(-p.distance_squared_to(Vector2(13, -11)) / 65.0)
	hill += 0.3 * sin(p.x * 0.045) * sin(p.y * 0.06)
	var edge := water_edge(p)
	var height := lerpf(-0.72, hill + 0.16, smoothstep(0.85, 1.35, edge))
	if edge < 1.0:
		return height # Bridge approaches must not dam the water beside the deck.
	# Low, smooth approaches meet each deck instead of stepping off a hillside.
	for b in bridges:
		var local := (p - Vector2(b.x, b.y)).rotated(-b.z)
		var approach := (1 - smoothstep(2.5, 4.5, absf(local.x))) * (1 - smoothstep(0.85, 1.8, absf(local.y)))
		height = lerpf(height, 0.10, approach) # Below the plank undersides (0.11).
	return height


func trail_distance(p: Vector2) -> float:
	var nearest := 1000.0
	for z in [5.0, -28.0, 58.0]:
		nearest = minf(nearest, absf(p.y - (z + 0.6 * sin(p.x * 0.15))))
	if p.y > -5 and p.y < 6:
		nearest = minf(nearest, absf(p.x - 7))
	if p.x < -28 and p.x > -69:
		nearest = minf(nearest, absf(p.y - 28))
	if p.y > 20 and p.y < 59:
		nearest = minf(nearest, absf(p.x + 30))
	if p.y > -48 and p.y < -27:
		nearest = minf(nearest, absf(p.x + 55))
	return nearest


func _reserved(p: Vector2) -> bool:
	if p.length() < 3.0 or trail_distance(p) < 2.0:
		return true
	for site in SITES:
		if p.distance_to(site) < 5.5:
			return true
	return Rect2(-5, -9, 10, 21).has_point(p)


func can_walk(p: Vector2, radius: float) -> bool:
	if absf(p.x) > EXTENT - radius or absf(p.y) > EXTENT - radius:
		return false
	for offset in [Vector2.ZERO, Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius), Vector2(0, -radius)]:
		if is_water(p + offset) and not is_bridge(p + offset):
			return false
	var key := Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))
	for z in range(key.y - 1, key.y + 2):
		for x in range(key.x - 1, key.x + 2):
			for b in _blocker_cells.get(Vector2i(x, z), []):
				if p.distance_to(Vector2(b.x, b.y)) < radius + b.z:
					return false
	for wall in walls:
		if wall.grow(radius).has_point(p):
			return false
	return true


func build() -> void:
	_rng.seed = 10262026
	for z in [5.0, -28.0, 58.0]:
		bridges.append(Vector3(river_x(z), z, 0))
	bridges.append(Vector3(-30, 30, PI * 0.5))
	_terrain_material = ShaderMaterial.new()
	_terrain_material.shader = load("res://scenes/forest_25d/terrain.gdshader")
	_water_material = ShaderMaterial.new()
	_water_material.shader = load("res://scenes/forest_25d/water.gdshader")
	_water()
	_bridge()
	_cottage()
	for i in range(1, SITES.size()):
		_ruin(SITES[i], i)
	_prepare_trees()
	_generate_nature_data()


func stream(center: Vector2, half: Vector2) -> bool:
	var minimum := Vector2i(floori((center.x - half.x - 9) / CHUNK), floori((center.y - half.y - 9) / CHUNK))
	var maximum := Vector2i(floori((center.x + half.x + 9) / CHUNK), floori((center.y + half.y + 9) / CHUNK))
	minimum = minimum.max(Vector2i(-8, -8))
	maximum = maximum.min(Vector2i(7, 7))
	var rect := Rect2i(minimum, maximum - minimum + Vector2i.ONE)
	if rect == _stream_rect:
		return false
	_stream_rect = rect
	for key in chunks.keys():
		if not rect.has_point(key):
			chunks[key].queue_free()
			chunks.erase(key)
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var key := Vector2i(x, z)
			if chunks.has(key):
				continue
			var chunk := Node3D.new()
			chunk.name = "Chunk_%d_%d" % [x, z]
			add_child(chunk)
			chunks[key] = chunk
			_build_parent = chunk
			_terrain_chunk(key)
			_vegetation_chunk(key)
	_build_parent = null
	return true


func material(color: String) -> StandardMaterial3D:
	if not _materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(color).srgb_to_linear().lerp(Color(color), 0.35)
		mat.roughness = 1.0
		_materials[color] = mat
	return _materials[color]


func reveal_player(position: Vector3) -> void:
	for mat in _leaf_materials:
		mat.set_shader_parameter("player_world", position)


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for v in [a, b, c]:
		st.set_normal(normal)
		st.add_vertex(v)


func _mesh(mesh: Mesh, mat: Material, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	(_build_parent if is_instance_valid(_build_parent) else self).add_child(node)
	return node


func _terrain_chunk(key: Vector2i) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cells := 24
	var step := CHUNK / cells
	# Shared vertices and world-space derivatives keep rolling hills smooth and
	# give neighboring chunks identical normals along their common boundary.
	for z in cells + 1:
		for x in cells + 1:
			var p := Vector2(key) * CHUNK + Vector2(x, z) * step
			st.set_normal(terrain_normal_at(p))
			st.add_vertex(Vector3(p.x, terrain_height_at(p), p.y))
	for z in cells:
		for x in cells:
			var i := z * (cells + 1) + x
			for index in [i, i + cells + 1, i + 1, i + 1, i + cells + 1, i + cells + 2]:
				st.add_index(index)
	_mesh(st.commit(), _terrain_material).name = "RollingTerrain"


func terrain_normal_at(p: Vector2) -> Vector3:
	const SAMPLE := 0.12
	var dx := terrain_height_at(p + Vector2(SAMPLE, 0)) - terrain_height_at(p - Vector2(SAMPLE, 0))
	var dz := terrain_height_at(p + Vector2(0, SAMPLE)) - terrain_height_at(p - Vector2(0, SAMPLE))
	return Vector3(-dx, SAMPLE * 2, -dz).normalized()


func _water() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for lake in LAKES:
		var center := Vector3(lake.x, -0.08, lake.y)
		for i in 80:
			var a := float(i) * TAU / 80
			var b := float(i + 1) * TAU / 80
			_tri(st, center, center + Vector3(cos(b) * lake.z, 0, sin(b) * lake.w), center + Vector3(cos(a) * lake.z, 0, sin(a) * lake.w))
	for i in int((EXTENT + CHUNK) * 4):
		var z := -EXTENT - CHUNK + i * 0.5
		var a := Vector3(river_x(z) - 1.2, -0.075, z)
		var b := a + Vector3(2.4, 0, 0)
		var c := Vector3(river_x(z + 0.5) - 1.2, -0.075, z + 0.5)
		var d := c + Vector3(2.4, 0, 0)
		_tri(st, a, c, b)
		_tri(st, b, c, d)
	for i in TRIBUTARY.size() - 1:
		var a: Vector2 = TRIBUTARY[i]
		var b: Vector2 = TRIBUTARY[i + 1]
		var side := (b - a).normalized().orthogonal() * 1.2
		_tri(st, Vector3(a.x + side.x, -0.075, a.y + side.y), Vector3(b.x + side.x, -0.075, b.y + side.y), Vector3(a.x - side.x, -0.075, a.y - side.y))
		_tri(st, Vector3(a.x - side.x, -0.075, a.y - side.y), Vector3(b.x + side.x, -0.075, b.y + side.y), Vector3(b.x - side.x, -0.075, b.y - side.y))
		for j in 20:
			var u := Vector2.from_angle(j * TAU / 20.0) * 1.2
			var v := Vector2.from_angle((j + 1) * TAU / 20.0) * 1.2
			_tri(st, Vector3(b.x, -0.075, b.y), Vector3(b.x + u.x, -0.075, b.y + u.y), Vector3(b.x + v.x, -0.075, b.y + v.y))
	_mesh(st.commit(), _water_material).name = "LakesAndRivers"


func box(at: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(mesh, material(color), at)


func _bridge() -> void:
	for bridge in bridges:
		var root := Node3D.new()
		root.position = Vector3(bridge.x, 0, bridge.y)
		root.rotation.y = -bridge.z
		add_child(root)
		_build_parent = root
		for i in 18:
			var plank := box(Vector3(-2.5 + i * 0.29, 0.19, 0), Vector3(0.27, 0.16, 1.75), "796247" if i % 3 else "99805b")
			plank.rotation.y = _rng.randf_range(-0.035, 0.035)
		for z in [-0.9, 0.9]:
			box(Vector3(0, 0.0, z), Vector3(5.3, 0.22, 0.14), "4e4435")
			for dx in [-2.4, 2.4]:
				box(Vector3(dx, 0.56, z), Vector3(0.13, 1.3, 0.13), "6a553c")
	_build_parent = null


func _ruin(p: Vector2, variant: int) -> void:
	var y := height_at(p)
	box(Vector3(p.x, y + 0.03, p.y), Vector3(5, 0.06, 4.4), "747265")
	for side in [-1, 1]:
		walls.append(Rect2(p.x + side * 2.3 - 0.15, p.y - 2.0, 0.3, 4.0))
		for i in 7:
			var h := 0.6 + _rng.randf() * (1.2 if variant % 2 else 2.0)
			box(Vector3(p.x + side * 2.3, y + h * 0.5, p.y - 1.7 + i * 0.55), Vector3(0.35, h, 0.52), "7c7e6c" if i % 2 else "656b5c")
	walls.append(Rect2(p.x - 2.3, p.y - 2.15, 4.6, 0.3))
	box(Vector3(p.x, y + 0.65, p.y - 2), Vector3(4.6, 1.3, 0.3), "737563")
	var timber := box(Vector3(p.x + 0.3, y + 0.7, p.y), Vector3(4.1, 0.19, 0.19), "5b4c37")
	timber.rotation.z = 0.32 if variant % 2 else -0.22
	for i in 8:
		var rock := _sphere()
		rock.radius = 0.25
		rock.height = 0.3
		_mesh(rock, material("777c68"), Vector3(p.x + _rng.randf_range(-2, 2), y + 0.12, p.y + _rng.randf_range(-1.5, 1.5)))


func _cottage() -> void:
	var base := height_at(Vector2(7, -4)) - 0.16
	box(Vector3(7, base + 0.08, -4), Vector3(4.9, 0.16, 4.3), "655e4c")
	# Real opening in the front wall, a sheltered interior, and solid side/back walls.
	for data in [Vector4(4.55, -4, 0.18, 4.1), Vector4(9.45, -4, 0.18, 4.1), Vector4(7, -6, 4.9, 0.18), Vector4(5.35, -2, 1.6, 0.18), Vector4(8.65, -2, 1.6, 0.18)]:
		walls.append(Rect2(data.x - data.z * 0.5, data.y - data.w * 0.5, data.z, data.w))
		box(Vector3(data.x, base + 1.35, data.y), Vector3(data.z, 2.7, data.w), "92856a")
	box(Vector3(7, base + 2.4, -2), Vector3(1.6, 0.6, 0.2), "92856a")
	for x in [4.55, 6.25, 7.75, 9.45]:
		box(Vector3(x, base + 1.35, -1.86), Vector3(0.13, 2.7, 0.15), "514c3b")
	for y in [0.3, 2.6]:
		box(Vector3(7, base + y, -1.84), Vector3(5.0, 0.14, 0.16), "514c3b")
	# Mossy roof sections with a missing strip expose the old rafters.
	for side in [-1, 1]:
		for section in 4:
			if side == -1 and section == 1:
				continue
			var roof := box(Vector3(7 + side * 1.3, base + 3.3, -5.65 + section * 1.1), Vector3(3.0, 0.14, 1.08), "435446" if section % 2 else "52604b")
			roof.rotation.z = -side * 0.5
			roofs.append(roof)
	for z in [-5.9, -4.6, -3.3, -2.0]:
		for side in [-1, 1]:
			var beam := box(Vector3(7 + side * 1.3, base + 3.19, z), Vector3(3.05, 0.12, 0.14), "4d4738")
			beam.rotation.z = -side * 0.5
			roofs.append(beam)
	box(Vector3(8.7, base + 3.55, -5.2), Vector3(0.65, 1.7, 0.6), "747566")
	box(Vector3(8.7, base + 4.4, -5.2), Vector3(0.82, 0.18, 0.76), "575f54")
	# Shuttered window, worn doorstep, leaning broken door, and ivy leaves.
	box(Vector3(5.3, base + 1.5, -1.79), Vector3(0.9, 0.85, 0.05), "263c33")
	for x in [5.0, 5.32, 5.64]:
		box(Vector3(x, base + 1.5, -1.73), Vector3(0.14, 0.88, 0.06), "64573e")
	box(Vector3(7, base + 0.08, -1.6), Vector3(1.4, 0.16, 0.75), "84826e")
	var door := box(Vector3(9.65, base + 0.9, -1.75), Vector3(0.8, 1.7, 0.09), "62553b")
	door.rotation = Vector3(-0.12, 0.15, -0.2)
	var ivy: Array[Transform3D] = []
	for i in 90:
		var x := 8.1 + _rng.randf() * 1.35
		var y := _rng.randf() * 2.8
		if _rng.randf() < (x - 7.8) * 0.65:
			ivy.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.13, 0.09, 0.06)), Vector3(x, base + y, -1.68)))
	_batch(_sphere(), material("456044"), ivy)


func _sphere() -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 10
	mesh.rings = 5
	mesh.radius = 1.0
	mesh.height = 2.0
	return mesh


func _batch(mesh: Mesh, mat: Material, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = mat
	(_build_parent if is_instance_valid(_build_parent) else self).add_child(node)


func _seed_for(key: Vector2i) -> int:
	return ((key.x + 128) * 73856093) ^ ((key.y + 128) * 19349663) ^ 10262026


func _register_blocker(p: Vector2, radius: float) -> void:
	var key := Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))
	if not _blocker_cells.has(key):
		_blocker_cells[key] = []
	var b := Vector3(p.x, p.y, radius)
	_blocker_cells[key].append(b)
	blockers.append(b)


func _generate_nature_data() -> void:
	for z in range(-8, 8):
		for x in range(-8, 8):
			var key := Vector2i(x, z)
			var rng := RandomNumberGenerator.new()
			rng.seed = _seed_for(key)
			var trees: Array[Vector3] = []
			var rocks: Array[Transform3D] = []
			for i in 11:
				var p := Vector2(key) * CHUNK + Vector2(rng.randf(), rng.randf()) * CHUNK
				if is_water(p, 1) or _reserved(p):
					continue
				trees.append(Vector3(p.x, p.y, rng.randf_range(4.5, 7.0)))
				_register_blocker(p, 0.32)
			for i in 5:
				var p := Vector2(key) * CHUNK + Vector2(rng.randf(), rng.randf()) * CHUNK
				if is_water(p, 0.3) or _reserved(p):
					continue
				var r := rng.randf_range(0.2, 0.65)
				rocks.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(r, r * 0.6, r * 0.8)), Vector3(p.x, height_at(p) + r * 0.2, p.y)))
				_register_blocker(p, r * 0.7)
			_nature[key] = {"trees": trees, "rocks": rocks}


func _vegetation_chunk(key: Vector2i) -> void:
	var data: Dictionary = _nature.get(key, {"trees": [], "rocks": []})
	_tree_batches(data["trees"])
	_batch(_sphere(), material("858879"), data["rocks"])
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_for(key) ^ 83492791
	var grasses: Array[Transform3D] = []
	var flowers: Array[Transform3D] = []
	for i in 180:
		var p := Vector2(key) * CHUNK + Vector2(rng.randf(), rng.randf()) * CHUNK
		if is_water(p, 0.1) or is_bridge(p) or trail_distance(p) < 1.2:
			continue
		var near_site := false
		for site in SITES:
			if p.distance_to(site) < 3.5:
				near_site = true
		if near_site:
			continue
		var h := rng.randf_range(0.12, 0.3)
		grasses.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(0.16, h, 0.16)), Vector3(p.x, height_at(p), p.y)))
		if i % 13 == 0:
			flowers.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.055, 0.035, 0.055)), Vector3(p.x, height_at(p) + h, p.y)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for angle in 3:
		var side := Vector3(cos(angle * PI / 3), 0, sin(angle * PI / 3))
		_tri(st, -side * 0.18, Vector3(0, 1, 0), side * 0.18)
	var grass_mat := material("6c8245")
	grass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	grass_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_batch(st.commit(), grass_mat, grasses)
	_batch(_sphere(), material("e1ce84"), flowers)


func _prepare_trees() -> void:
	for filename in ["birch", "pine"]:
		var source: Node3D = load("res://scenes/forest_25d/assets/" + filename + ".glb").instantiate()
		add_child(source)
		var meshes := source.find_children("*", "MeshInstance3D", true, false)
		var bounds := AABB()
		var first := true
		var parts: Array[Dictionary] = []
		for child in meshes:
			var relative: Transform3D = source.global_transform.affine_inverse() * child.global_transform
			var local: AABB = relative * child.get_aabb()
			bounds = local if first else bounds.merge(local)
			first = false
			var mesh: Mesh = child.mesh.duplicate()
			for surface in mesh.get_surface_count():
				var original: Material = mesh.surface_get_material(surface)
				if original is BaseMaterial3D:
					var mat: BaseMaterial3D = original.duplicate()
					mat.roughness = 1.0
					mat.metallic_specular = 0.0
					var replacement: Material = mat
					if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
						var leaves := ShaderMaterial.new()
						leaves.shader = load("res://scenes/forest_25d/foliage.gdshader")
						leaves.set_shader_parameter("leaf_texture", mat.albedo_texture)
						leaves.set_shader_parameter("tint", Color("5d7455"))
						_leaf_materials.append(leaves)
						replacement = leaves
					mesh.surface_set_material(surface, replacement)
			parts.append({"mesh": mesh, "relative": relative})
		_tree_sources.append({"bounds": bounds, "parts": parts})
		source.queue_free()


func _tree_batches(points: Array[Vector3]) -> void:
	for species in 2:
		var source := _tree_sources[species]
		var bounds: AABB = source["bounds"]
		for part in source["parts"]:
			var transforms: Array[Transform3D] = []
			for i in points.size():
				if i % 2 != species:
					continue
				var p := points[i]
				var scale_factor := p.z / maxf(bounds.size.y, 0.01)
				var base := Vector3(p.x, height_at(Vector2(p.x, p.y)) - bounds.position.y * scale_factor, p.y)
				var placement := Transform3D(Basis(Vector3.UP, float(i) * 2.39996).scaled(Vector3.ONE * scale_factor), base)
				transforms.append(placement * part["relative"])
			_batch(part["mesh"], null, transforms)
