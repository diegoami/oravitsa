extends Control

var mushrooms := 0
var berries := 0
var pickup_prompt := "Foraging bag"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(160, 86)
	tooltip_text = "Collected berries and mushrooms"


func _text(value: String, center_x: float, y: float, font_size: int) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(center_x - width * 0.5 + 1, y + 2), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("101820"))
	draw_string(font, Vector2(center_x - width * 0.5, y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("ead9a9"))


func _draw() -> void:
	_text(pickup_prompt, 80, -9, 13)
	for slot in 2:
		var x := slot * 84.0
		draw_rect(Rect2(x, 0, 76, 86), Color("172538"))
		draw_rect(Rect2(x, 0, 76, 86), Color("bca677"), false, 2)
		_text("Berries" if slot == 0 else "Mushrooms", x + 38, 17, 12)
		draw_set_transform(Vector2(x + 38, 41))
		if slot == 0:
			draw_line(Vector2(0, 0), Vector2(3, -15), Color("8aaa62"), 2, true)
			draw_colored_polygon(PackedVector2Array([Vector2(1, -9), Vector2(-12, -15), Vector2(-8, -7)]), Color("8aaa62"))
			for at in [Vector2(-8, -2), Vector2(7, -4), Vector2(0, 8)]:
				draw_circle(at, 7, Color("b94459"))
				draw_circle(at + Vector2(-2, -2), 2, Color("f2999b"))
		else:
			draw_style_box(_stem(), Rect2(-5, -2, 10, 19))
			draw_colored_polygon(PackedVector2Array([Vector2(-18, 0), Vector2(-15, -9), Vector2(-7, -16), Vector2(5, -17), Vector2(15, -9), Vector2(18, 0)]), Color("bc8053"))
			draw_line(Vector2(-16, 0), Vector2(16, 0), Color("e7c59c"), 3, true)
			draw_circle(Vector2(-6, -8), 2, Color("e7c59c"))
			draw_circle(Vector2(7, -10), 2, Color("e7c59c"))
		draw_set_transform(Vector2.ZERO)
		_text(str(berries if slot == 0 else mushrooms), x + 38, 77, 20)


func _stem() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e7c59c")
	style.set_corner_radius_all(3)
	return style
