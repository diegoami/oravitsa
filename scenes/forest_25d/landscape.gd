extends Node3D

## Deterministic, bounded art slice. Analytic collision and mesh use the same
## terrain/water functions, so a sprite's feet follow the visible landscape.
const EXTENT := 24.0
var blockers: Array[Vector3] = [] # x, z, radius.
var walls: Array[Rect2] = []
var roofs: Array[MeshInstance3D] = []
var _materials: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func river_x(z: float) -> float:
	return -5.0 + 1.5 * sin(z * 0.25)


func is_water(p: Vector2, margin: float = 0.0) -> bool:
	return ((p - Vector2(-9, -5)) / Vector2(5.5 + margin, 4.5 + margin)).length() < 1.0 or (p.y > -5.0 and absf(p.x - river_x(p.y)) < 1.2 + margin)


func is_bridge(p: Vector2) -> bool:
	return absf(p.x - river_x(5.0)) < 2.6 and absf(p.y - 5.0) < 0.85


func height_at(p: Vector2) -> float:
	if is_bridge(p):
		return 0.27
	if Rect2(4.5, -6.2, 5.0, 4.4).has_point(p):
		return 0.55
	var hill := 0.22 * sin(p.x * 0.16) * cos(p.y * 0.14) + 0.8 * exp(-p.distance_squared_to(Vector2(13, -11)) / 65.0)
	var lake := ((p - Vector2(-9, -5)) / Vector2(5.5, 4.5)).length()
	var river := absf(p.x - river_x(p.y)) / 1.2 if p.y > -5 else 10.0
	var edge := minf(lake, river)
	return lerpf(-0.72, hill + 0.16, smoothstep(0.85, 1.35, edge))


func can_walk(p: Vector2, radius: float) -> bool:
	if absf(p.x) > EXTENT - radius or absf(p.y) > EXTENT - radius:
		return false
	for offset in [Vector2.ZERO, Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius), Vector2(0, -radius)]:
		if is_water(p + offset) and not is_bridge(p + offset):
			return false
	for b in blockers:
		if p.distance_to(Vector2(b.x, b.y)) < radius + b.z:
			return false
	for wall in walls:
		if wall.grow(radius).has_point(p):
			return false
	return true


func build() -> void:
	_rng.seed = 10262026
	_terrain()
	_water()
	_bridge()
	_cottage()
	_vegetation()


func material(color: String) -> StandardMaterial3D:
	if not _materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(color).srgb_to_linear().lerp(Color(color), 0.35)
		mat.roughness = 1.0
		_materials[color] = mat
	return _materials[color]


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
	add_child(node)
	return node


func _terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cells := 128
	var span := EXTENT + 20.0
	var step := span * 2 / cells
	for z in cells:
		for x in cells:
			var p := Vector2(-span + x * step, -span + z * step)
			var points: Array[Vector3] = []
			for off in [Vector2.ZERO, Vector2(step, 0), Vector2(0, step), Vector2(step, step)]:
				var q: Vector2 = p + off
				points.append(Vector3(q.x, height_at(q), q.y))
			_tri(st, points[0], points[2], points[1])
			_tri(st, points[1], points[2], points[3])
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scenes/forest_25d/terrain.gdshader")
	_mesh(st.commit(), mat).name = "RollingTerrain"


func _water() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(-9, -0.08, -5)
	for i in 80:
		var a := float(i) * TAU / 80
		var b := float(i + 1) * TAU / 80
		_tri(st, center, center + Vector3(cos(b) * 5.5, 0, sin(b) * 4.5), center + Vector3(cos(a) * 5.5, 0, sin(a) * 4.5))
	for i in 116:
		var z := -5.0 + i * 0.25
		var a := Vector3(river_x(z) - 1.2, -0.075, z)
		var b := a + Vector3(2.4, 0, 0)
		var c := Vector3(river_x(z + 0.25) - 1.2, -0.075, z + 0.25)
		var d := c + Vector3(2.4, 0, 0)
		_tri(st, a, c, b)
		_tri(st, b, c, d)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scenes/forest_25d/water.gdshader")
	_mesh(st.commit(), mat).name = "LakeAndStream"


func box(at: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(mesh, material(color), at)


func _bridge() -> void:
	var x := river_x(5)
	for i in 18:
		var plank := box(Vector3(x - 2.5 + i * 0.29, 0.19, 5), Vector3(0.27, 0.16, 1.75), "796247" if i % 3 else "99805b")
		plank.rotation.y = _rng.randf_range(-0.035, 0.035)
	for z in [4.1, 5.9]:
		box(Vector3(x, 0.0, z), Vector3(5.3, 0.22, 0.14), "4e4435")
		for dx in [-2.4, 2.4]:
			box(Vector3(x + dx, 0.56, z), Vector3(0.13, 1.3, 0.13), "6a553c")


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
			var roof := box(Vector3(7 + side * 1.3, base + 3.3, -5.65 + section * 1.1), Vector3(3.0, 0.14, 1.16), "435446" if section % 2 else "52604b")
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
	add_child(node)


func _vegetation() -> void:
	var tree_points: Array[Vector3] = []
	var rocks: Array[Transform3D] = []
	var grasses: Array[Transform3D] = []
	var flowers: Array[Transform3D] = []
	for i in 160:
		var p := Vector2(_rng.randf_range(-23, 23), _rng.randf_range(-23, 23))
		if is_water(p, 1) or absf(p.y - (5 + 0.6 * sin(p.x * 0.15))) < 2.0 or (absf(p.x) < 5.0 and p.y > -9 and p.y < 12) or p.distance_to(Vector2(7, -4)) < 5.5 or Rect2(3.5, -8, 7, 11).has_point(p):
			continue
		var h := _rng.randf_range(4.5, 7.0)
		var y := height_at(p)
		blockers.append(Vector3(p.x, p.y, 0.32))
		tree_points.append(Vector3(p.x, p.y, h))
	for i in 85:
		var p := Vector2(_rng.randf_range(-22, 22), _rng.randf_range(-22, 22))
		if is_water(p, 0.3) or p.distance_to(Vector2(7, -4)) < 4.0 or p.length() < 2:
			continue
		var r := _rng.randf_range(0.2, 0.65)
		rocks.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(r, r * 0.6, r * 0.8)), Vector3(p.x, height_at(p) + r * 0.2, p.y)))
		blockers.append(Vector3(p.x, p.y, r * 0.7))
	for i in 3400:
		var p := Vector2(_rng.randf_range(-23, 23), _rng.randf_range(-23, 23))
		if is_water(p, 0.1) or is_bridge(p) or (p.distance_to(Vector2(7, -4)) < 3.5) or absf(p.y - (5 + 0.6 * sin(p.x * 0.15))) < 1.2 or (absf(p.x - 7) < 1 and p.y < 5 and p.y > -4):
			continue
		var h := _rng.randf_range(0.12, 0.3)
		grasses.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(0.16, h, 0.16)), Vector3(p.x, height_at(p), p.y)))
		if i % 13 == 0:
			flowers.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.055, 0.035, 0.055)), Vector3(p.x, height_at(p) + h, p.y)))
	_tree_batches(tree_points)
	_batch(_sphere(), material("858879"), rocks)
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


func _tree_batches(points: Array[Vector3]) -> void:
	for species in 2:
		var filename := "birch" if species == 0 else "pine"
		var source: Node3D = load("res://scenes/forest_25d/assets/" + filename + ".glb").instantiate()
		add_child(source)
		var meshes := source.find_children("*", "MeshInstance3D", true, false)
		var bounds := AABB()
		var first := true
		for child in meshes:
			var local: AABB = (source.global_transform.affine_inverse() * child.global_transform) * child.get_aabb()
			bounds = local if first else bounds.merge(local)
			first = false
		for child in meshes:
			var transforms: Array[Transform3D] = []
			var mesh: Mesh = child.mesh.duplicate()
			for surface in mesh.get_surface_count():
				var original: Material = mesh.surface_get_material(surface)
				if original is BaseMaterial3D:
					var mat: BaseMaterial3D = original.duplicate()
					mat.roughness = 1.0
					mat.metallic_specular = 0.0
					if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
						mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
						mat.alpha_scissor_threshold = 0.4
						mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
						mat.albedo_color = Color("79906d")
					mesh.surface_set_material(surface, mat)
			var relative: Transform3D = source.global_transform.affine_inverse() * child.global_transform
			for i in points.size():
				if i % 2 != species:
					continue
				var p := points[i]
				var scale_factor := p.z / maxf(bounds.size.y, 0.01)
				var base := Vector3(p.x, height_at(Vector2(p.x, p.y)) - bounds.position.y * scale_factor, p.y)
				var placement := Transform3D(Basis(Vector3.UP, float(i) * 2.39996).scaled(Vector3.ONE * scale_factor), base)
				transforms.append(placement * relative)
			_batch(mesh, null, transforms)
		source.queue_free()
