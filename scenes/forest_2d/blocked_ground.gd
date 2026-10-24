extends Node2D

## A dark, soft footprint below solid foliage. Open grass remains bright.
var forest: Node2D


func _draw() -> void:
	if forest == null:
		return
	var rect: Rect2i = forest._stream_rect(forest._loaded_center, forest._loaded_half)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			var kind: int = forest.objects[forest._index(cell)]
			if kind != forest.TREE and kind != forest.BUSH:
				continue
			var point: Vector2 = forest._cell_center(cell)
			draw_circle(point, 54.0, Color(0.09, 0.22, 0.14, 0.22), true, -1.0, true)
			draw_circle(point, 43.0, Color(0.07, 0.20, 0.12, 0.28), true, -1.0, true)
