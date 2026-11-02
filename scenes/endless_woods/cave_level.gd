extends "res://scenes/forest_25d/landscape.gd"

## The first level behind a cave mouth (#45): a seeded grid of rooms joined by
## tunnels, built north of the mouth so Oravitsa walks straight in. The same
## region always yields the same level, its checkpoints and its giant rats
## and spiders (#46). Collision comes from the grid, independent of visuals.
## Its way down leads to a larger, darker second level (#62), seeded with a
## different salt, where goblins and kobolds lair; that level's arrival spot is
## the way up.

const CELL := 2.0 # Metres per grid cell.
const GRID := Vector2i(26, 20)
const DEEP_GRID := Vector2i(30, 24)
const WALL_HEIGHT := 0.65 # Low enough for the fixed camera to see over, even south of her.
const ROOMS := Vector2i(5, 7)
const CHECKPOINTS := Vector2i(2, 3)
const RATS := Vector2i(4, 6)
const SPIDERS := Vector2i(2, 3)
const DEEP_ROOMS := Vector2i(6, 8)
const GOBLIN_PACKS := Vector2i(2, 3) # Packs of PACK_SIZE goblins.
const KOBOLD_PACKS := Vector2i(2, 2)
const PACK_SIZE := Vector2i(2, 3)
const CHECKPOINT_RADIUS := 1.4
const EXIT_RADIUS := 1.0

var region := Vector2i.ZERO
var depth := 1 # 1 for the first level, 2 for the second.
var grid := GRID
var anchor := Vector2.ZERO # Local ground position of the entrance cell's centre.
var open: Dictionary = {} # Vector2i cell -> true for walkable floor.
var rooms: Array[Rect2i] = []
var entrance := Vector2.ZERO # The way out on the first level, the way up on the second.
var way_down := Vector2.INF # First level only.
var checkpoints: Array[Vector2] = []
var spawns: Array[Vector3] = [] # x, z (local ground metres) and creature kind.
var _checkpoint_lights: Array[OmniLight3D] = []
var _checkpoint_crystals: Array[MeshInstance3D] = []


## The first level is populated with `first_kind` (rats) and `second_kind`
## (spiders); the second level with packs of each (goblins and kobolds).
func setup(cave_region: Vector2i, mouth: Vector2, first_kind: int, second_kind: int, level_depth: int = 1) -> void:
	region = cave_region
	anchor = mouth
	depth = level_depth
	grid = GRID if depth == 1 else DEEP_GRID
	_generate(first_kind, second_kind)


func build() -> void:
	_draw_level()


func _rand(key: Vector2i, salt: int) -> float:
	var value := hash(Vector3i(key.x * 92821 + region.x, key.y * 68917 + region.y, salt + (depth - 1) * 1000))
	return float(value & 0xffffff) / float(0x1000000)


func _range(bounds: Vector2i, key: Vector2i, salt: int) -> int:
	return bounds.x + mini(bounds.y - bounds.x, int(_rand(key, salt) * (bounds.y - bounds.x + 1)))


func cell_center(cell: Vector2i) -> Vector2:
	return anchor + Vector2(cell.x - grid.x / 2, cell.y - (grid.y - 1)) * CELL


func cell_at(p: Vector2) -> Vector2i:
	var q := (p - anchor) / CELL + Vector2(grid.x / 2, grid.y - 1)
	return Vector2i(roundi(q.x), roundi(q.y))


func _carve(rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if x > 0 and y > 0 and x < grid.x - 1 and y < grid.y - 1:
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


func _generate(first_kind: int, second_kind: int) -> void:
	var start := Vector2i(grid.x / 2, grid.y - 2)
	if depth == 1:
		rooms.append(Rect2i(start - Vector2i(1, 1), Vector2i(3, 2)))
		_carve(rooms[0])
		open[Vector2i(grid.x / 2, grid.y - 1)] = true # The way out, under the mouth.
	else:
		# The way up sits in the middle of a 3 × 3 arrival room, clear of walls.
		rooms.append(Rect2i(start - Vector2i(1, 2), Vector2i(3, 3)))
		_carve(rooms[0])
	var wanted := _range(ROOMS if depth == 1 else DEEP_ROOMS, Vector2i(1, 0), 11)
	for attempt in 80:
		if rooms.size() >= wanted + 1:
			break
		var size := Vector2i(3 + int(_rand(Vector2i(attempt, 1), 12) * 3), 3 + int(_rand(Vector2i(attempt, 2), 13) * 3))
		var at := Vector2i(1 + int(_rand(Vector2i(attempt, 3), 14) * (grid.x - size.x - 2)), 1 + int(_rand(Vector2i(attempt, 4), 15) * (grid.y - size.y - 6)))
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
	entrance = cell_center(Vector2i(grid.x / 2, grid.y - 1) if depth == 1 else start - Vector2i(0, 1))
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
	if depth == 1:
		for group in [[first_kind, _range(RATS, Vector2i(3, 0), 18)], [second_kind, _range(SPIDERS, Vector2i(4, 0), 19)]]:
			for i in int(group[1]):
				var lair := _lair(cells, taken, Vector2i(i * 7 + int(group[0]), 0))
				if lair.x >= 0:
					var p := cell_center(lair)
					taken.append(p)
					spawns.append(Vector3(p.x, p.y, int(group[0])))
		_place_way_down()
		return
	# Second level: goblins and kobolds lair in packs on neighbouring cells.
	for group in [[first_kind, _range(GOBLIN_PACKS, Vector2i(3, 0), 18)], [second_kind, _range(KOBOLD_PACKS, Vector2i(4, 0), 19)]]:
		for i in int(group[1]):
			var lair := _lair(cells, taken, Vector2i(i * 7 + int(group[0]), 0))
			if lair.x < 0:
				continue
			var size := _range(PACK_SIZE, Vector2i(i, int(group[0])), 21)
			var members: Array[Vector2i] = [lair]
			for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				if members.size() < size and open.has(lair + step) and cell_center(lair + step).distance_to(entrance) >= 10.0:
					members.append(lair + step)
			for cell in members:
				var p := cell_center(cell)
				taken.append(p)
				spawns.append(Vector3(p.x, p.y, int(group[0])))


## A seeded floor cell for a lair, at least 10 m from the entrance and 3 m from
## other lairs and checkpoints; (-1, -1) when none is found.
func _lair(cells: Array, taken: Array[Vector2], key: Vector2i) -> Vector2i:
	for attempt in 60:
		var cell: Vector2i = cells[int(_rand(Vector2i(key.x, attempt), 20) * cells.size()) % cells.size()]
		var p := cell_center(cell)
		var clear := p.distance_to(entrance) >= 10.0
		for other in taken + checkpoints:
			clear = clear and p.distance_to(other) >= 3.0
		if clear:
			return cell
	return Vector2i(-1, -1)


## The way down: the floor cell farthest on foot from the way out that lies
## inside a room (all eight neighbours open) and at least 4 m from every
## checkpoint, so it never shares a spot with one.
func _place_way_down() -> void:
	var steps := distances_to(cell_at(entrance))
	var cells := steps.keys()
	cells.sort()
	for need_room in [true, false]:
		var best := Vector2i(-1, -1)
		for cell in cells:
			var inside := true
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					inside = inside and (open.has(cell + Vector2i(dx, dy)) or not need_room)
			var clear := inside
			for p in checkpoints:
				clear = clear and cell_center(cell).distance_to(p) >= 4.0
			if clear and (best.x < 0 or steps[cell] > steps[best]):
				best = cell
		if best.x >= 0:
			way_down = cell_center(best)
			return
	way_down = cell_center(rooms[rooms.size() - 1].get_center())


## Walking steps from every floor cell to `goal`, for finding a way around walls.
func distances_to(goal: Vector2i) -> Dictionary:
	if not open.has(goal):
		return {}
	var steps := {goal: 0}
	var frontier: Array[Vector2i] = [goal]
	var head := 0
	while head < frontier.size():
		var cell: Vector2i = frontier[head]
		head += 1
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if open.has(cell + step) and not steps.has(cell + step):
				steps[cell + step] = steps[cell] + 1
				frontier.append(cell + step)
	return steps


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
	for y in grid.y:
		for x in grid.x:
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
	ground.size = Vector2(grid.x + 4, grid.y + 4) * CELL
	var middle := cell_center(Vector2i(grid.x / 2, grid.y / 2))
	# The second level is darker and colder: bluish slate instead of sandstone.
	_mesh(ground, material("0d0c0b" if depth == 1 else "070609"), Vector3(middle.x, -0.04, middle.y))
	var tile := PlaneMesh.new()
	tile.size = Vector2.ONE * CELL
	_batch(tile, material("6a5f50" if depth == 1 else "4c4854"), floor_tiles)
	var block := BoxMesh.new()
	_batch(block, material("7a6e5c" if depth == 1 else "5c5668"), walls)
	if depth == 1:
		# Daylight falls in through the mouth at the way out.
		var shaft := PlaneMesh.new()
		shaft.size = Vector2(CELL * 1.6, CELL * 1.2)
		_mesh(shaft, material("b9b08a"), Vector3(entrance.x, -0.01, entrance.y))
		_light(Vector3(entrance.x, 2.2, entrance.y), "fff2cf", 1.4, 5.0)
		# The way down: a dark shaft ringed with stones and lit amber from below.
		_stone_ring(way_down, "050403", "8d8577")
		_light(Vector3(way_down.x, 0.5, way_down.y), "ff9a3c", 1.8, 4.5)
	else:
		# The way up: a pale patch under the shaft she climbed down, ringed with stones.
		_stone_ring(entrance, "8f8a74", "a39b88")
		_light(Vector3(entrance.x, 2.4, entrance.y), "d9e4ff", 1.2, 4.5)
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


func _light(at: Vector3, color: String, energy: float, reach: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = Color(color)
	light.light_energy = energy
	light.omni_range = reach
	add_child(light)
	return light


func _stone_ring(p: Vector2, hole: String, stone: String) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = 0.8
	disc.bottom_radius = 0.8
	disc.height = 0.03
	_mesh(disc, material(hole), Vector3(p.x, 0.0, p.y))
	for i in 10:
		var at := p + Vector2.from_angle(i * TAU / 10.0) * 1.0
		var rock := _mesh(_sphere(), material(stone), Vector3(at.x, 0.08, at.y))
		rock.scale = Vector3(0.3, 0.2, 0.26) * (0.85 + _rand(Vector2i(i, 0), 31) * 0.3)
