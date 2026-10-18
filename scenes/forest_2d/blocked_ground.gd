extends Node2D

## A dark, soft footprint below solid foliage. Open grass remains bright.
var forest: Node2D


func _draw() -> void:
	if forest == null:
		return
	var center: Vector2i = forest._loaded_center
	for y in range(maxi(0, center.y - 7), mini(forest.MAP_SIZE, center.y + 8)):
		for x in range(maxi(0, center.x - 10), mini(forest.MAP_SIZE, center.x + 11)):
			var cell := Vector2i(x, y)
			var kind: int = forest.objects[forest._index(cell)]
			if kind != forest.TREE and kind != forest.BUSH:
				continue
			var point: Vector2 = forest._cell_center(cell)
			draw_circle(point, 54.0, Color(0.09, 0.22, 0.14, 0.22), true, -1.0, true)
			draw_circle(point, 43.0, Color(0.07, 0.20, 0.12, 0.28), true, -1.0, true)
