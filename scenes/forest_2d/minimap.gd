extends Control

var forest: Node2D
var _texture: ImageTexture


func _ready() -> void:
	var size: int = forest.MAP_SIZE
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var index: int = y * size + x
			var color := Color("527b4e") if forest.terrain[index] == forest.GRASS else Color("ae8d5d")
			match forest.objects[index]:
				forest.TREE: color = Color("284d38")
				forest.BUSH: color = Color("395f40")
				forest.STONE: color = Color("79817c")
				forest.LOG: color = Color("695844")
			image.set_pixel(x, y, color)
	_texture = ImageTexture.create_from_image(image)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.14, 0.10, 0.92), true)
	var map_rect := Rect2(Vector2(10, 27), Vector2(224, 207))
	draw_texture_rect(_texture, map_rect, false)
	draw_rect(map_rect, Color("dfd4ad"), false, 2.0)
	var center: Vector2 = forest.player_position / float(forest.MAP_SIZE * forest.TILE)
	var dot := map_rect.position + center * map_rect.size
	draw_circle(dot, 4.5, Color("fff1b7"))
	draw_arc(dot, 6.0, 0.0, TAU, 16, Color("344532"), 1.5)
	draw_string(ThemeDB.fallback_font, Vector2(11, 20), "FOREST MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f8eed5"))
