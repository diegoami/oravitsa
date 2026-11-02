extends Control

## The zoomed-out exploration map (#66): only the 32 m cells Oravitsa has
## walked near are drawn, with their ground, roads and water; discovered
## hamlets and cave mouths are marked with their names, and she is the bright
## dot in the middle. Everything is in absolute metres, so streaming and
## rebasing never change it.

const METRES_PER_PIXEL := 4.0
const UNEXPLORED := Color("10161f")
const ROAD := Color("c9ad7c")
const WATER := Color("4f8a92")

var forest: Node2D
var _colors := {} # Explored cell -> its colour, computed once per session.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP # Clicks on the open map never select animals behind it.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


## The colour of an explored cell: water, road or the ground there.
func cell_color(cell: Vector2i) -> Color:
	if not _colors.has(cell):
		var land: Node3D = forest.landscape if not forest.in_cave() else forest._surface_landscape
		var q: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * forest.EXPLORE_CELL
		var local: Vector2 = q - land.origin
		var color: Color = land.ground_color(local)
		if land.is_water(local) and not land.is_bridge(local):
			color = WATER
		elif land._road_distance(q) < 3.0:
			color = ROAD
		_colors[cell] = color
	return _colors[cell]


func _draw() -> void:
	var area := Rect2(Vector2(24, 64), size - Vector2(48, 100))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.05, 0.08, 0.92))
	draw_rect(area, UNEXPLORED)
	var center: Vector2 = forest.map_center()
	var to_screen := func(p: Vector2) -> Vector2: return area.get_center() + (p - center) / METRES_PER_PIXEL
	var cell_pixels: float = forest.EXPLORE_CELL / METRES_PER_PIXEL
	for cell in forest.explored:
		var corner: Vector2 = to_screen.call(Vector2(cell) * forest.EXPLORE_CELL)
		var rect := Rect2(corner, Vector2.ONE * cell_pixels)
		if area.intersects(rect):
			draw_rect(rect.intersection(area), cell_color(cell))
	var font := ThemeDB.fallback_font
	for block in forest.discovered_hamlets:
		var hamlet: Dictionary = forest.discovered_hamlets[block]
		var h: Vector2 = to_screen.call(hamlet["at"])
		if area.grow(-4).has_point(h):
			draw_rect(Rect2(h - Vector2(6, 4), Vector2(12, 9)), Color("e3d8b8"))
			draw_colored_polygon(PackedVector2Array([h + Vector2(-8, -4), h + Vector2(0, -12), h + Vector2(8, -4)]), Color("9a6b4c"))
			_label(font, h + Vector2(11, 4), hamlet["name"], Color("fff1c9"))
	for region in forest.discovered_caves:
		var cave: Dictionary = forest.discovered_caves[region]
		var c: Vector2 = to_screen.call(cave["at"])
		if area.grow(-4).has_point(c):
			draw_colored_polygon(PackedVector2Array([c + Vector2(-8, 5), c + Vector2(0, -8), c + Vector2(8, 5)]), Color("2a2b26"))
			draw_polyline(PackedVector2Array([c + Vector2(-8, 5), c + Vector2(0, -8), c + Vector2(8, 5), c + Vector2(-8, 5)]), Color("d6e4f0"), 1.5)
			_label(font, c + Vector2(11, 4), cave["name"], Color("d6e4f0"))
	var me: Vector2 = to_screen.call(center)
	draw_circle(me, 7, Color("1d150c"))
	draw_circle(me, 5, Color("fff0b0"))
	draw_rect(area, Color("bca677"), false, 1.5)
	_label(font, area.position + Vector2(12, 24), "MOSSBANK · EXPLORED MAP", Color("ead9a9"), 18)
	var note: String = ("Underground in " + forest._cave_name() + " · ") if forest.in_cave() else ""
	note += "%d hamlets and %d caves found · N ↑ · 100 m ≈ %d px" % [forest.discovered_hamlets.size(), forest.discovered_caves.size(), roundi(100 / METRES_PER_PIXEL)]
	draw_string(font, Vector2(26, size.y - 14), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ead9a9"))


func _label(font: Font, at: Vector2, text: String, color: Color, font_size: int = 14) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color("10161f"))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
