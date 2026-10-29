extends "res://scenes/forest_25d/landscape.gd"

## The first level behind a cave mouth (#45): a seeded grid of rooms joined by
## tunnels, built north of the mouth so Oravitsa walks straight in. The same
## region always yields the same level, its checkpoints and its giant rats
## and spiders (#46). Collision comes from the grid, independent of visuals.

const CELL := 2.0 # Metres per grid cell.
const GRID := Vector2i(26, 20)
const WALL_HEIGHT := 0.65 # Low enough for the fixed camera to see over, even south of her.
const ROOMS := Vector2i(5, 7)
const CHECKPOINTS := Vector2i(2, 3)
const RATS := Vector2i(4, 6)
const SPIDERS := Vector2i(2, 3)
const CHECKPOINT_RADIUS := 1.4
const EXIT_RADIUS := 1.0

var region := Vector2i.ZERO
var anchor := Vector2.ZERO # Local ground position of the entrance cell's centre.
var open: Dictionary = {} # Vector2i cell -> true for walkable floor.
var rooms: Array[Rect2i] = []
var entrance := Vector2.ZERO
var checkpoints: Array[Vector2] = []
var spawns: Array[Vector3] = [] # x, z (local ground metres) and creature kind.
var _checkpoint_lights: Array[OmniLight3D] = []
var _checkpoint_crystals: Array[MeshInstance3D] = []


func setup(cave_region: Vector2i, mouth: Vector2, rat_kind: int, spider_kind: int) -> void:
	region = cave_region
	anchor = mouth
	_generate(rat_kind, spider_kind)


func build() -> void:
	_draw_level()


func _rand(key: Vector2i, salt: int) -> float:
	var value := hash(Vector3i(key.x * 92821 + region.x, key.y * 68917 + region.y, salt))
	return float(value & 0xffffff) / float(0x1000000)


func _range(bounds: Vector2i, key: Vector2i, salt: int) -> int:
	return bounds.x + mini(bounds.y - bounds.x, int(_rand(key, salt) * (bounds.y - bounds.x + 1)))


func cell_center(cell: Vector2i) -> Vector2:
	return anchor + Vector2(cell.x - GRID.x / 2, cell.y - (GRID.y - 1)) * CELL


func cell_at(p: Vector2) -> Vector2i:
	var q := (p - anchor) / CELL + Vector2(GRID.x / 2, GRID.y - 1)
	return Vector2i(roundi(q.x), roundi(q.y))


func _carve(rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if x > 0 and y > 0 and x < GRID.x - 1 and y < GRID.y - 1:
				open[Vector2i(x, y)] = true


func _tunnel(a: Vector2i, b: Vector2i, wide: bool) -> void:
	# An L-shaped tunnel; the seeded bend direction keeps levels varied.
	var corner := Vector2i(b.x, a.y) if _rand(a + b, 7) < 0.5 else Vector2i(a.x, b.y)
	for leg in [[a, corner], [corner, b]]:
		var from: Vector2i = leg[0]
		var to: Vector2i = leg[1]
		var step := Vector2i(signi(to.x - from.x), signi(to.y - from.y))
		var at := from
		while true:
			_carve(Rect2i(at, Vector2i(2, 2) if wide else Vector2i.ONE))
			if at == to:
				break
			at += step


func _generate(rat_kind: int, spider_kind: int) -> void:
	var start := Vector2i(GRID.x / 2, GRID.y - 2)
	rooms.append(Rect2i(start - Vector2i(1, 1), Vector2i(3, 2)))
	_carve(rooms[0])
	open[Vector2i(GRID.x / 2, GRID.y - 1)] = true # The way out, under the mouth.
	var wanted := _range(ROOMS, Vector2i(1, 0), 11)
	for attempt in 80:
		if rooms.size() >= wanted + 1:
			break
		var size := Vector2i(3 + int(_rand(Vector2i(attempt, 1), 12) * 3), 3 + int(_rand(Vector2i(attempt, 2), 13) * 3))
		var at := Vector2i(1 + int(_rand(Vector2i(attempt, 3), 14) * (GRID.x - size.x - 2)), 1 + int(_rand(Vector2i(attempt, 4), 15) * (GRID.y - size.y - 6)))
		var rect := Rect2i(at, size)
		var clear := true
		for other in rooms:
			if rect.grow(1).intersects(other):
				clear = false
		if clear:
			rooms.append(rect)
	# Join each room to the nearest room already reachable from the entrance.
	var joined: Array[Rect2i] = [rooms[0]]
	var pending: Array[Rect2i] = rooms.slice(1)
	while not pending.is_empty():
		var best := 0
		var best_link := 0
		var best_distance := INF
		for i in pending.size():
			for j in joined.size():
				var distance := Vector2(pending[i].get_center()).distance_to(Vector2(joined[j].get_center()))
				if distance < best_distance:
					best_distance = distance
					best = i
					best_link = j
		var room: Rect2i = pending.pop_at(best)
		_carve(room)
		_tunnel(room.get_center(), joined[best_link].get_center(), _rand(room.position, 16) < 0.35)
		joined.append(room)
	entrance = cell_center(Vector2i(GRID.x / 2, GRID.y - 1))
	# Checkpoints in the rooms farthest from the entrance, deepest last.
	var by_depth := rooms.slice(1)
	by_depth.sort_custom(func(u: Rect2i, v: Rect2i) -> bool: return cell_center(u.get_center()).distance_to(entrance) > cell_center(v.get_center()).distance_to(entrance))
	for i in mini(_range(CHECKPOINTS, Vector2i(2, 0), 17), by_depth.size()):
		checkpoints.append(cell_center(by_depth[i].get_center()))
	checkpoints.reverse()
	# Creatures in rooms and tunnels at least 10 m from the entrance.
	var cells := open.keys()
	cells.sort()
	var taken: Array[Vector2] = []
	for group in [[rat_kind, _range(RATS, Vector2i(3, 0), 18)], [spider_kind, _range(SPIDERS, Vector2i(4, 0), 19)]]:
		for i in int(group[1]):
			for attempt in 60:
				var cell: Vector2i = cells[int(_rand(Vector2i(i * 7 + int(group[0]), attempt), 20) * cells.size()) % cells.size()]
				var p := cell_center(cell)
				var clear := p.distance_to(entrance) >= 10.0
				for other in taken + checkpoints:
					clear = clear and p.distance_to(other) >= 3.0
				if clear:
					taken.append(p)
					spawns.append(Vector3(p.x, p.y, int(group[0])))
					break


func is_open(p: Vector2) -> bool:
	return open.has(cell_at(p))


func can_walk(p: Vector2, radius: float) -> bool:
	for off in [Vector2.ZERO, Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius), Vector2(0, -radius)]:
		if not is_open(p + off):
			return false
	return true


func height_at(_p: Vector2) -> float:
	return 0.0


func terrain_height_at(_p: Vector2) -> float:
	return 0.0


func is_water(_p: Vector2, _margin: float = 0.0) -> bool:
	return false


func is_bridge(_p: Vector2) -> bool:
	return false


func water_edge(_p: Vector2) -> float:
	return 99.0


func stream(_center: Vector2, _half: Vector2) -> bool:
	return false


func reveal_player(_position: Vector3) -> void:
	pass


func checkpoint_collected(index: int) -> void:
	# A collected checkpoint's crystal dims to gold and its glow fades.
	_checkpoint_crystals[index].material_override = material("8a7440")
	_checkpoint_lights[index].light_energy = 0.25


func _draw_level() -> void:
	var floor_tiles: Array[Transform3D] = []
	var walls: Array[Transform3D] = []
	for y in GRID.y:
		for x in GRID.x:
			var cell := Vector2i(x, y)
			var c := cell_center(cell)
			if open.has(cell):
				floor_tiles.append(Transform3D(Basis.IDENTITY, Vector3(c.x, -0.02, c.y)))
				continue
			var edge := false
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					edge = edge or open.has(cell + Vector2i(dx, dy))
			if edge:
				var h := WALL_HEIGHT * (0.85 + _rand(cell, 30) * 0.3)
				walls.append(Transform3D(Basis.IDENTITY.scaled(Vector3(CELL, h, CELL)), Vector3(c.x, h * 0.5, c.y)))
	var ground := PlaneMesh.new()
	ground.size = Vector2(GRID.x + 4, GRID.y + 4) * CELL
	var middle := cell_center(Vector2i(GRID.x / 2, GRID.y / 2))
	_mesh(ground, material("0d0c0b"), Vector3(middle.x, -0.04, middle.y))
	var tile := PlaneMesh.new()
	tile.size = Vector2.ONE * CELL
	_batch(tile, material("6a5f50"), floor_tiles)
	var block := BoxMesh.new()
	_batch(block, material("7a6e5c"), walls)
	# Daylight falls in through the mouth at the way out.
	var shaft := PlaneMesh.new()
	shaft.size = Vector2(CELL * 1.6, CELL * 1.2)
	_mesh(shaft, material("b9b08a"), Vector3(entrance.x, -0.01, entrance.y))
	var daylight := OmniLight3D.new()
	daylight.position = Vector3(entrance.x, 2.2, entrance.y)
	daylight.light_color = Color("fff2cf")
	daylight.light_energy = 1.4
	daylight.omni_range = 5.0
	add_child(daylight)
	for p in checkpoints:
		var crystal := _mesh(_sphere(), material("7fd8ff"), Vector3(p.x, 0.55, p.y))
		crystal.scale = Vector3(0.28, 0.6, 0.28)
		var rune := CylinderMesh.new()
		rune.top_radius = 0.75
		rune.bottom_radius = 0.75
		rune.height = 0.03
		_mesh(rune, material("2c5d73"), Vector3(p.x, 0.0, p.y))
		var glow := OmniLight3D.new()
		glow.position = Vector3(p.x, 1.2, p.y)
		glow.light_color = Color("8fdcff")
		glow.light_energy = 1.6
		glow.omni_range = 4.5
		add_child(glow)
		_checkpoint_crystals.append(crystal)
		_checkpoint_lights.append(glow)
