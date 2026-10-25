extends Button

## Small painted-vector icons stay sharp at desktop and mobile HUD scales.
var skill := "Shoo"
var prompt := "SPACE"
var cooldown := 0.0
var cooldown_duration := 7.0
var active := false


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(100, 108)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("172538") if state != "hover" else Color("273c52")
		style.border_color = Color("bca677") if state != "disabled" else Color("6a6c65")
		style.set_border_width_all(2)
		style.set_corner_radius_all(5)
		style.shadow_color = Color(0, 0, 0, 0.5)
		style.shadow_size = 3
		add_theme_stylebox_override(state, style)


func _text(value: String, y: float, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((size.x - width) * 0.5, y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw() -> void:
	var gold := Color("ead9a9")
	if active:
		draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), Color("f3d58a"), false, 2)
	var ink := Color("a7d9d2") if skill == "Shoo" else Color("e8c18a")
	_text(prompt, 18, 12, gold)
	draw_line(Vector2(12, 25), Vector2(size.x - 12, 25), Color("526378"), 1)
	var origin := Vector2(size.x * 0.5, 50)
	draw_set_transform(origin)
	if skill == "Shoo":
		# Open hand and outward sound waves.
		var hand := PackedVector2Array([Vector2(-12, 12), Vector2(-17, 0), Vector2(-14, -3), Vector2(-9, 2), Vector2(-9, -13), Vector2(-5, -14), Vector2(-4, -2), Vector2(-3, -19), Vector2(1, -19), Vector2(2, -2), Vector2(5, -16), Vector2(9, -15), Vector2(7, 0), Vector2(11, -9), Vector2(14, -7), Vector2(11, 12)])
		draw_colored_polygon(hand, ink)
		draw_arc(Vector2(5, 0), 19, -0.75, 0.75, 18, ink, 2, true)
		draw_arc(Vector2(5, 0), 25, -0.65, 0.65, 18, ink, 2, true)
	else:
		# Two sling cords, a leather pouch, and the released stone's arc.
		draw_line(Vector2(-17, -13), Vector2(-5, 14), ink, 2.5, true)
		draw_line(Vector2(15, -13), Vector2(5, 14), ink, 2.5, true)
		draw_style_box(_pouch_style(), Rect2(-8, 8, 16, 11))
		draw_arc(Vector2(0, -3), 21, -2.8, -0.55, 24, ink, 1.5, true)
		draw_circle(Vector2(23, -15), 4, Color("f8ead0"))
	draw_set_transform(Vector2.ZERO)
	if cooldown > 0.0:
		var fraction := clampf(cooldown / cooldown_duration, 0, 1)
		draw_rect(Rect2(3, 27 + 43 * (1 - fraction), size.x - 6, 43 * fraction), Color(0.02, 0.05, 0.10, 0.70))
	_text(skill, 85, 17, gold)
	_text("%.1fs" % cooldown if cooldown > 0.0 else ("READY" if not disabled else "—"), 102, 14, Color("f6e5b8") if cooldown > 0 else Color("a2baae"))


func _pouch_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("9f744c")
	style.set_corner_radius_all(4)
	return style
