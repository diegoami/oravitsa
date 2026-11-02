extends Control

## The zoomed-out exploration map (#66): only the 32 m cells Oravitsa has
## walked near are drawn, with their ground, roads and water; discovered
## hamlets and cave mouths are marked with their names, and she is the bright
## dot in the middle. Everything is in absolute metres, so streaming and
## rebasing never change it. It zooms (#105) through SCALES: + / − (or the
## numeric keypad), the mouse wheel, the on-map buttons or right-stick flicks
## while it is open; the zoom lasts for the session.

const SCALES := [1.0, 2.0, 4.0, 8.0, 16.0, 32.0] # Metres per pixel, closest first.
const DEFAULT_ZOOM := 2
const UNEXPLORED := Color("10161f")
const ROAD := Color("c9ad7c")
const WATER := Color("4f8a92")

var forest: Node2D
var zoom := DEFAULT_ZOOM # Index into SCALES.
var _colors := {} # Explored cell -> its colour, computed once per session.
var _zoom_in: Button
var _zoom_out: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP # Clicks on the open map never select animals behind it.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_zoom_in = _zoom_button("+", -1, 132)
	_zoom_out = _zoom_button("−", 1, 82)
	_sync_buttons()


func _zoom_button(text: String, step: int, from_right: float) -> Button:
	var button := Button.new()
	button.text = text
	button.name = "ZoomIn" if step < 0 else "ZoomOut"
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 22)
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.offset_left = -from_right
	button.offset_right = -from_right + 44
	button.offset_top = -84
	button.offset_bottom = -44
	button.pressed.connect(zoom_by.bind(step))
	add_child(button)
	return button


## Metres of ground per pixel at the current zoom.
func metres_per_pixel() -> float:
	return SCALES[zoom]


## Zooms out by `step` scales (negative zooms in), within SCALES. Returns
## whether the scale changed.
func zoom_by(step: int) -> bool:
	var wanted := clampi(zoom + step, 0, SCALES.size() - 1)
	if wanted == zoom:
		return false
	zoom = wanted
	_sync_buttons()
	queue_redraw()
	return true


func _sync_buttons() -> void:
	_zoom_in.disabled = zoom == 0
	_zoom_out.disabled = zoom == SCALES.size() - 1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		zoom_by(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		accept_event()


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
	var mpp: float = metres_per_pixel()
	var to_screen := func(p: Vector2) -> Vector2: return area.get_center() + (p - center) / mpp
	var cell_pixels: float = forest.EXPLORE_CELL / mpp
	for cell in forest.explored:
		var corner: Vector2 = to_screen.call(Vector2(cell) * forest.EXPLORE_CELL)
		var rect := Rect2(corner, Vector2.ONE * cell_pixels)
		if area.intersects(rect):
			draw_rect(rect.intersection(area), cell_color(cell))
	var font := ThemeDB.fallback_font
	var taken: Array[Rect2] = [] # Place names drawn so far: a crowded one is left out.
	for block in forest.discovered_hamlets:
		var hamlet: Dictionary = forest.discovered_hamlets[block]
		var h: Vector2 = to_screen.call(hamlet["at"])
		if area.grow(-4).has_point(h):
			draw_rect(Rect2(h - Vector2(6, 4), Vector2(12, 9)), Color("e3d8b8"))
			draw_colored_polygon(PackedVector2Array([h + Vector2(-8, -4), h + Vector2(0, -12), h + Vector2(8, -4)]), Color("9a6b4c"))
			_place_label(font, h + Vector2(11, 4), hamlet["name"], Color("fff1c9"), taken)
	for region in forest.discovered_caves:
		var cave: Dictionary = forest.discovered_caves[region]
		var c: Vector2 = to_screen.call(cave["at"])
		if area.grow(-4).has_point(c):
			draw_colored_polygon(PackedVector2Array([c + Vector2(-8, 5), c + Vector2(0, -8), c + Vector2(8, 5)]), Color("2a2b26"))
			draw_polyline(PackedVector2Array([c + Vector2(-8, 5), c + Vector2(0, -8), c + Vector2(8, 5), c + Vector2(-8, 5)]), Color("d6e4f0"), 1.5)
			_place_label(font, c + Vector2(11, 4), cave["name"], Color("d6e4f0"), taken)
	var me: Vector2 = to_screen.call(center)
	draw_circle(me, 7, Color("1d150c"))
	draw_circle(me, 5, Color("fff0b0"))
	draw_rect(area, Color("bca677"), false, 1.5)
	_label(font, area.position + Vector2(12, 24), "MOSSBANK · EXPLORED MAP", Color("ead9a9"), 18)
	var note: String = ("Underground in " + forest._cave_name() + " · ") if forest.in_cave() else ""
	note += "%d hamlets and %d caves found · N ↑ · %s · zoom: + / −, wheel or right stick" % [forest.discovered_hamlets.size(), forest.discovered_caves.size(), _scale_text(mpp)]
	draw_string(font, Vector2(26, size.y - 14), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ead9a9"))


## A round scale bar length for the footer, such as "100 m ≈ 25 px".
func _scale_text(mpp: float) -> String:
	var metres := 100.0 if mpp <= 4.0 else 1000.0
	return "%s ≈ %d px" % ["100 m" if metres < 1000.0 else "1 km", roundi(metres / mpp)]


## Draws a place name unless it would overlap one already in `taken`, so
## zoomed out, crowded names never pile up unreadably; their markers remain.
func _place_label(font: Font, at: Vector2, text: String, color: Color, taken: Array[Rect2]) -> void:
	if claim_label(font, at, text, taken):
		_label(font, at, text, color)


## Whether a place name at `at` is clear of those in `taken`; if so it is
## added to them.
static func claim_label(font: Font, at: Vector2, text: String, taken: Array[Rect2]) -> bool:
	var extent := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	var box := Rect2(at - Vector2(2, extent.y * 0.8), extent + Vector2(4, 2))
	for other in taken:
		if other.intersects(box):
			return false
	taken.append(box)
	return true


func _label(font: Font, at: Vector2, text: String, color: Color, font_size: int = 14) -> void:
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color("10161f"))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
