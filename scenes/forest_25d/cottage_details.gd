extends Node3D

## Hand-placed geometry, batched by material; no generated art or paid assets.
var _landscape: Node3D
var _surfaces: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func build(landscape: Node3D) -> void:
	name = "CottageDetails"
	_landscape = landscape
	_rng.seed = 102628
	_cottage()
	_crossing()
	_well()
	_flush()


func _piece(mesh: Mesh, color: String, at: Vector3, rotation: Vector3 = Vector3.ZERO, roof: bool = false) -> void:
	var key := color + ("_roof" if roof else "")
	if not _surfaces.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_surfaces[key] = st
	_surfaces[key].append_from(mesh, 0, Transform3D(Basis.from_euler(rotation), at))


func _box(at: Vector3, size: Vector3, color: String, rotation: Vector3 = Vector3.ZERO, roof: bool = false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_piece(mesh, color, at, rotation, roof)


func _beam(a: Vector3, b: Vector3, width: float, color: String, roof: bool = false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, a.distance_to(b), width)
	_piece(mesh, color, (a + b) * 0.5, Basis(Quaternion(Vector3.UP, (b - a).normalized())).get_euler(), roof)


func _stone(p: Vector2, size: Vector3, color: String) -> void:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 7
	mesh.rings = 3
	mesh.radius = 1.0
	mesh.height = 2.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(mesh, 0, Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(size), Vector3(p.x, _landscape.height_at(p) + size.y * 0.2, p.y)))
	var key := color
	if not _surfaces.has(key):
		_surfaces[key] = SurfaceTool.new()
		_surfaces[key].begin(Mesh.PRIMITIVE_TRIANGLES)
	_surfaces[key].append_from(st.commit(), 0, Transform3D.IDENTITY)


func _cottage() -> void:
	var base: float = _landscape.height_at(Vector2(7, -4)) - 0.16
	# Irregular masonry plinth, with a clear opening at the existing doorway.
	for side in [-1, 1]:
		for row in 2:
			for i in 5:
				_box(Vector3(7 + side * (1.05 + i * 0.30), base + 0.16 + row * 0.18, -1.88), Vector3(0.27, 0.15, 0.23), "828472" if (row + i) % 3 else "686e61")
		# Braces sit proud of the plaster rather than fighting it in depth.
		_beam(Vector3(7 + side * 0.92, base + 0.55, -1.74), Vector3(7 + side * 2.26, base + 2.3, -1.74), 0.10, "645540")
		for i in 9:
			_box(Vector3(7 + side * (1.05 + _rng.randf() * 1.25), base + _rng.randf_range(0.6, 2.25), -1.87), Vector3(_rng.randf_range(0.10, 0.27), _rng.randf_range(0.06, 0.15), 0.04), "b0a185")
	# Foundation and side-wall framing make the east side read as timber/plaster.
	for i in 12:
		_box(Vector3(9.56, base + 0.18, -5.9 + i * 0.34), Vector3(0.18, 0.32, 0.30), "828472" if i % 3 else "686e61")
	for z in [-5.9, -4.0, -2.1]:
		_box(Vector3(9.57, base + 1.55, z), Vector3(0.14, 2.35, 0.14), "645540")
	_beam(Vector3(9.58, base + 0.45, -5.8), Vector3(9.58, base + 2.6, -4.1), 0.12, "645540")
	_box(Vector3(9.59, base + 1.65, -3.0), Vector3(0.08, 0.83, 0.83), "273d34")
	for z in [-3.46, -2.54]:
		_box(Vector3(9.65, base + 1.65, z), Vector3(0.12, 0.96, 0.10), "645540")
	_box(Vector3(9.65, base + 1.20, -3.0), Vector3(0.20, 0.10, 1.05), "828472")
	_box(Vector3(9.65, base + 1.65, -3.0), Vector3(0.10, 0.80, 0.06), "645540")
	# Roof shingles follow the existing pitch and preserve its missing section.
	for side in [-1, 1]:
		for row in 5:
			var u := 0.30 + row * 0.56
			for column in 8:
				var z := -5.91 + column * 0.54 + (row % 2) * 0.09
				if side == -1 and (z > -5.10 and z < -4.0 or row == 4 and column == 7):
					continue
				_box(Vector3(7 + side * u * cos(0.5), base + 4.10 - u * sin(0.5), z), Vector3(0.54, 0.065, 0.51), ["53644c", "5d6950", "4d5e48"][(row + column) % 3], Vector3(0, 0, -side * 0.5), true)
	for side in [-1, 1]:
		_beam(Vector3(7, base + 4.14, -1.70), Vector3(7 + side * 2.52, base + 2.77, -1.70), 0.13, "645540", true)
	# A gable infill closes the triangular gap beneath the roof.
	var gable := SurfaceTool.new()
	gable.begin(Mesh.PRIMITIVE_TRIANGLES)
	_landscape._tri(gable, Vector3(4.52, base + 2.74, -1.80), Vector3(9.48, base + 2.74, -1.80), Vector3(7, base + 4.06, -1.80))
	_piece(gable.commit(), "a19478", Vector3.ZERO, Vector3.ZERO, true)
	_beam(Vector3(7, base + 2.80, -1.72), Vector3(7, base + 4.04, -1.72), 0.12, "645540", true)
	# A broken fence and firewood stay beside the house, outside the doorway.
	for i in 5:
		var p := Vector2(11.4 + i * 0.45, -5.1)
		var y: float = _landscape.height_at(p)
		_box(Vector3(p.x, y + 0.45, p.y), Vector3(0.15, 0.9 - i * 0.05, 0.12), "645540", Vector3(0, 0, (i - 2) * 0.035))
		_landscape._register_blocker(p, 0.12)
	_beam(Vector3(11.4, _landscape.height_at(Vector2(11.4, -5.1)) + 0.55, -5.1), Vector3(13.2, _landscape.height_at(Vector2(13.2, -5.1)) + 0.38, -5.1), 0.09, "645540")
	for i in 6:
		var y: float = _landscape.height_at(Vector2(10.3, -4.3))
		_box(Vector3(10.3 + (i % 3) * 0.19, y + 0.12 + (i / 3) * 0.18, -4.3), Vector3(0.16, 0.16, 0.65), "796449", Vector3(0, 0.08, 0))
	_landscape._register_blocker(Vector2(10.5, -4.3), 0.45)


func _crossing() -> void:
	var x: float = _landscape.river_x(5)
	# Worn stones settle into the path, not on the wooden deck.
	for side in [-1, 1]:
		for i in 7:
			var p := Vector2(x + side * (2.9 + i * 0.36), 5 + _rng.randf_range(-0.52, 0.52))
			_stone(p, Vector3(0.22, 0.05, 0.16), "828472")
	# One surviving low rail; its break keeps the old crossing's silhouette.
	for side in [-1, 1]:
		_beam(Vector3(x + side * 2.35, 0.95, 4.1), Vector3(x + side * 0.65, 0.81, 4.1), 0.09, "645540")
	for i in 10:
		var t := float(i) / 9
		var p := Vector2(7, -0.8).lerp(Vector2(12, 2.5), t) + Vector2(_rng.randf_range(-0.2, 0.2), 0)
		_stone(p, Vector3(0.22, 0.055, 0.17), "828472")


func _well() -> void:
	var p: Vector2 = _landscape.WELL_POSITION
	var y: float = _landscape.height_at(p)
	_landscape._register_blocker(p, 0.78)
	# A hollow, two-course stone ring, not a solid cylinder.
	for row in 3:
		for i in 12:
			var angle := (i + row * 0.5) * TAU / 12
			_box(Vector3(p.x + cos(angle) * 0.61, y + 0.12 + row * 0.23, p.y + sin(angle) * 0.61), Vector3(0.24, 0.21, 0.30), "828472" if i % 3 else "686e61", Vector3(0, -angle, 0))
	var water := CylinderMesh.new()
	water.top_radius = 0.47
	water.bottom_radius = 0.47
	water.height = 0.02
	water.radial_segments = 16
	_piece(water, "273d34", Vector3(p.x, y + 0.05, p.y))
	for side in [-1, 1]:
		_box(Vector3(p.x + side * 0.78, y + 1.0, p.y), Vector3(0.13, 2.0, 0.13), "645540")
	_box(Vector3(p.x, y + 1.88, p.y), Vector3(1.85, 0.16, 0.18), "645540")
	_box(Vector3(p.x, y + 1.12, p.y), Vector3(0.025, 1.5, 0.025), "aa9871")
	# A little moss at the foot and stepping stones lead to real forage nearby.
	for i in 7:
		var angle := i * TAU / 7.0
		_stone(p + Vector2.from_angle(angle) * 0.86, Vector3(0.14, 0.045, 0.12), "64774c")
	for i in 5:
		_stone(Vector2(12.0 + i * 0.3, 2.8 + _rng.randf_range(-0.3, 0.3)), Vector3(0.13, 0.04, 0.11), "828472")


func _flush() -> void:
	for key in _surfaces:
		var node := MeshInstance3D.new()
		node.name = key
		node.mesh = _surfaces[key].commit()
		node.material_override = _landscape.material(key.trim_suffix("_roof"))
		add_child(node)
		if key.ends_with("_roof"):
			_landscape.roofs.append(node)
	_surfaces.clear()
