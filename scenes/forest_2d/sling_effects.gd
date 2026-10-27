extends Node2D

var forest: Node2D


func _draw() -> void:
	if forest._valid_sling_target(forest.selected_target):
		var target: Dictionary = forest._animals[forest.selected_target]
		var reachable: bool = forest.player_position.distance_to(target["position"]) <= forest.SLING_RANGE
		var color := Color("f3d58a") if reachable else Color("dc9278")
		var radius: float = forest.ANIMAL_RADIUS[target["kind"]] + 10.0
		var center: Vector2 = target["position"] + Vector2(0, 5)
		draw_arc(center, radius, 0.0, TAU, 48, color, 2.5, true)
		for corner in 4:
			var outward := Vector2.from_angle(corner * PI * 0.5)
			draw_line(center + outward * (radius - 4), center + outward * (radius + 6), color, 2.5, true)
	for stone in forest._stones:
		var position: Vector2 = stone["position"]
		position.y -= sin(clampf(stone["age"] / stone["flight"], 0.0, 1.0) * PI) * 22.0
		draw_line(position - stone["heading"] * 14.0, position, Color(0.95, 0.89, 0.72, 0.65), 2.0, true)
		draw_circle(position + Vector2(1, 2), 6.0, Color(0.12, 0.18, 0.15, 0.7))
		draw_circle(position, 4.5, Color("ddd8c7"))
	for id in forest._active_animals:
		var animal: Dictionary = forest._animals[id]
		if not animal["alive"]:
			continue
		var sprite: AnimatedSprite2D = forest._active_animals[id]
		var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		var center: Vector2 = animal["position"] - Vector2(0, texture.get_height() * sprite.scale.y * 0.75)
		if animal["shoo"] > 0:
			var text := "!! SCARED %.1fs" % animal["shoo"]
			if animal["stun"] > 0:
				text = "STUNNED %.1fs / " % animal["stun"] + text
			var font := ThemeDB.fallback_font
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(font, center - Vector2(width * 0.5, 20 if animal["stun"] > 0 else 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ffcb79"))
		if animal["stun"] <= 0:
			continue
		for star in 3:
			var angle := Time.get_ticks_msec() * 0.003 + star * TAU / 3.0
			var at := center + Vector2(cos(angle) * 16.0, sin(angle) * 5.0)
			var points := PackedVector2Array()
			for point in 10:
				points.append(Vector2.from_angle(point * PI / 5.0 - PI * 0.5) * (5.0 if point % 2 == 0 else 2.3))
			# Triangulate near the origin: tiny polygons at large forest coordinates
			# lose precision and can fail Godot's polygon triangulation.
			draw_set_transform(at)
			draw_colored_polygon(points, Color("fff0ac"))
			draw_set_transform(Vector2.ZERO)
