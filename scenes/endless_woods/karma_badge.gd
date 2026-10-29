extends Control

## Karma, the game's points: the lotus icon with the number drawn on top of
## it, and a hungry icon beside it while Oravitsa has nothing to eat.

const KARMA_ICON := preload("res://scenes/endless_woods/hud_icons/karma.svg")
const HUNGRY_ICON := preload("res://scenes/endless_woods/hud_icons/hungry.svg")
const ICON := 54.0

var karma := 0
var hungry := false
var _flash := 0.0 # Seconds of highlight after a change.
var _flash_color := Color.WHITE


func _ready() -> void:
	custom_minimum_size = Vector2(ICON * 2 + 10, ICON)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_change(amount: int) -> void:
	_flash = 0.8
	_flash_color = Color("ffe58a") if amount >= 0 else Color("ff8a78")
	queue_redraw()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		queue_redraw()


func _draw() -> void:
	var grow := 1.0 + _flash * 0.12
	var side := ICON * grow
	var rect := Rect2(Vector2(ICON, ICON) * 0.5 - Vector2(side, side) * 0.5, Vector2(side, side))
	draw_texture_rect(KARMA_ICON, rect, false)
	var font := ThemeDB.fallback_font
	var text := str(karma)
	var font_size := 22 if text.length() <= 3 else 17
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := Vector2(ICON * 0.5 - width * 0.5, ICON * 0.5 + font_size * 0.36)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color("2a1d08"))
	var fill := Color("fffbea").lerp(_flash_color, _flash / 0.8)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fill)
	if hungry:
		draw_texture_rect(HUNGRY_ICON, Rect2(Vector2(ICON + 10, 4), Vector2(ICON - 8, ICON - 8)), false)
