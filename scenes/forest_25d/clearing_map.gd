extends Control
var forest: Node2D

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("172538"))
	var rect := Rect2(10, 28, 224, 220)
	draw_rect(rect, Color("566b3f"))
	var convert := func(p: Vector2) -> Vector2: return rect.position + (p + Vector2(24, 24)) / 48.0 * rect.size
	var lake: Vector2 = convert.call(Vector2(-9, -5))
	draw_set_transform(lake, 0, Vector2(1.22, 1))
	draw_circle(Vector2.ZERO, 21, Color("568f89"))
	draw_set_transform(Vector2.ZERO)
	for i in 58:
		var z := -5 + i * 0.5
		var a: Vector2 = convert.call(Vector2(forest.landscape.river_x(z), z))
		var b: Vector2 = convert.call(Vector2(forest.landscape.river_x(z + 0.5), z + 0.5))
		draw_line(a, b, Color("568f89"), 10)
	var bridge: Vector2 = convert.call(Vector2(forest.landscape.river_x(5), 5))
	draw_line(bridge - Vector2(13, 0), bridge + Vector2(13, 0), Color("c3a679"), 6)
	draw_rect(Rect2(convert.call(Vector2(4.5, -6)), Vector2(24, 20)), Color("bba481"))
	for animal in forest._animals:
		draw_circle(convert.call(forest.to_ground(animal["position"])), 3, Color("e8c690"))
	draw_circle(convert.call(forest.to_ground(forest.player_position)), 5, Color("fff0b0"))
	draw_rect(rect, Color("bca677"), false, 1)
	draw_string(ThemeDB.fallback_font, Vector2(12, 20), "MOSSBANK CLEARING", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ead9a9"))
	draw_string(ThemeDB.fallback_font, Vector2(12, 265), "Lake · bridge · cottage", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ead9a9"))
