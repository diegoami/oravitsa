extends Control

## Aura, the game's points: the glowing icon with the number drawn on top of
## it, and beside it how well fed Oravitsa is: a bowl with a meter, or a
## crossed-out bowl while she is starving.

const AURA_ICON := preload("res://scenes/endless_woods/hud_icons/aura.svg")
const FED_ICON := preload("res://scenes/endless_woods/hud_icons/fed.svg")
const HUNGRY_ICON := preload("res://scenes/endless_woods/hud_icons/hungry.svg")
const ICON := 54.0
const BOWL := 40.0
const METER := Vector2(64, 12)

var aura := 0
var fed := 1.0 # 0 (starving) to 1 (full).
var _flash := 0.0 # Seconds of highlight after a change.
var _flash_color := Color.WHITE


func _ready() -> void:
	custom_minimum_size = Vector2(ICON + 10 + BOWL + 6 + METER.x, ICON)
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
	draw_texture_rect(AURA_ICON, rect, false)
	var font := ThemeDB.fallback_font
	var text := str(aura)
	var font_size := 22 if text.length() <= 3 else 17
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := Vector2(ICON * 0.5 - width * 0.5, ICON * 0.5 + font_size * 0.36)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color("2a1d08"))
	var fill := Color("fffbea").lerp(_flash_color, _flash / 0.8)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fill)
	var bowl := Rect2(Vector2(ICON + 10, (ICON - BOWL) * 0.5), Vector2(BOWL, BOWL))
	draw_texture_rect(HUNGRY_ICON if fed <= 0.0 else FED_ICON, bowl, false)
	var meter := Rect2(Vector2(bowl.end.x + 6, (ICON - METER.y) * 0.5), METER)
	draw_rect(meter.grow(2), Color(0.1, 0.07, 0.05, 0.85))
	var level := clampf(fed, 0.0, 1.0)
	var color := Color("d9483b").lerp(Color("e8b84a"), clampf(level * 2.0, 0.0, 1.0)).lerp(Color("6fc24f"), clampf(level * 2.0 - 1.0, 0.0, 1.0))
	draw_rect(Rect2(meter.position, Vector2(meter.size.x * level, meter.size.y)), color)
	draw_rect(meter.grow(2), Color("f4ecd0"), false, 1.5)
