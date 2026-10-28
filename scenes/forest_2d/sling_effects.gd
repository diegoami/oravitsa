extends Node2D

const STATUS_ICONS := {
	"stunned": preload("res://scenes/forest_2d/status_icons/stunned.svg"),
	"scared": preload("res://scenes/forest_2d/status_icons/scared.svg"),
	"angry": preload("res://scenes/forest_2d/status_icons/angry.svg"),
	"charging": preload("res://scenes/forest_2d/status_icons/charging.svg"),
	"fighting": preload("res://scenes/forest_2d/status_icons/fighting.svg"),
}
const STATUS_COLORS := {"stunned": Color("ffd95a"), "scared": Color("8fd3ff"), "angry": Color("ff4a3a"), "charging": Color("ff4a3a"), "fighting": Color("ffb02e")}

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
		var states: Array = forest._status_states(id)
		for i in states.size():
			# Icons side by side above the head, each with its time-left bar.
			var at := center + Vector2((i - (states.size() - 1) * 0.5) * 44.0, -36.0)
			draw_texture_rect(STATUS_ICONS[states[i][0]], Rect2(at - Vector2(20, 20), Vector2(40, 40)), false)
			if states[i][1] >= 0.0:
				draw_rect(Rect2(at + Vector2(-17, 22), Vector2(34, 5)), Color(0.08, 0.1, 0.08, 0.8))
				draw_rect(Rect2(at + Vector2(-17, 22), Vector2(34 * states[i][1], 5)), STATUS_COLORS[states[i][0]])
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
