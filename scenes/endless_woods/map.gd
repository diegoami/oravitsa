extends Control
var forest: Node2D
var _map_texture: ImageTexture
var _map_center := Vector2(INF, INF)
const COLORS := [Color("ad7460"), Color("e8c690"), Color("f59a52"), Color("d6ad53"), Color("eee7cc"), Color("a8b5bc"), Color("8c7f8e"), Color("6c5a78"), Color("7fc7e8")]


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("172538"))
	var center: Vector2 = forest.absolute_ground(forest.player_position)
	if _map_texture == null or center.distance_to(_map_center) > 2:
		_map_center = center
		var pixels := Image.create(64, 64, false, Image.FORMAT_RGB8)
		for z in 64:
			for x in 64:
				var local: Vector2 = center + Vector2(x - 32, z - 32) * 2 - forest.landscape.origin
				var color: Color = forest.landscape.ground_color(local)
				if forest.landscape.is_water(local) and not forest.landscape.is_bridge(local):
					color = Color("568f89")
				pixels.set_pixel(x, z, color)
		_map_texture = ImageTexture.create_from_image(pixels)
	var rect := Rect2(10, 28, 224, 220)
	draw_texture_rect(_map_texture, rect, false)
	var convert := func(p: Vector2) -> Vector2: return rect.get_center() + (p - _map_center) / 128 * rect.size
	for id in forest._active_animals:
		var data: Dictionary = forest._animals[id]
		if data["alive"]:
			var p: Vector2 = convert.call(forest.absolute_ground(data["position"]))
			if rect.has_point(p):
				draw_circle(p, 2, COLORS[data["kind"]])
	# Hamlets and cave mouths within the map's 128 m view.
	var land: Node3D = forest.landscape
	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var hamlet: Dictionary = land.hamlet_near(center + Vector2(dx, dz) * 64)
			if not hamlet.is_empty():
				var h: Vector2 = convert.call(hamlet["center"])
				if rect.has_point(h):
					draw_rect(Rect2(h - Vector2(4, 3), Vector2(8, 6)), Color("d8cfb2"))
					draw_colored_polygon(PackedVector2Array([h + Vector2(-5, -3), h + Vector2(0, -8), h + Vector2(5, -3)]), Color("8a6a52"))
			var cave: Dictionary = land.cave_at(Vector2i(floori((center.x + dx * 64) / 256), floori((center.y + dz * 64) / 128)))
			if not cave.is_empty():
				var c: Vector2 = convert.call(cave["mouth"])
				if rect.has_point(c):
					draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 3), c + Vector2(0, -5), c + Vector2(5, 3)]), Color("2a2b26"))
	draw_circle(convert.call(center), 4, Color("fff0b0"))
	draw_rect(rect, Color("bca677"), false, 1)
	draw_string(ThemeDB.fallback_font, Vector2(12, 20), "MOSSBANK · LOCAL MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ead9a9"))
	draw_string(ThemeDB.fallback_font, Vector2(12, 265), "N ↑  %d E · %d S" % [roundi(center.x), roundi(center.y)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ead9a9"))
