extends Node3D

## Status icons floating above an animal in place of text: up to two side by
## side (a stun and fear can overlap), each timed state with a time-left bar.

const ICONS := preload("res://scenes/forest_2d/sling_effects.gd").STATUS_ICONS
const COLORS := preload("res://scenes/forest_2d/sling_effects.gd").STATUS_COLORS
const PIXEL := 0.0105
const SPACING := 70.0 # Texture pixels between icon centres.
const BAR := Vector2(52, 8)

## What is shown, for tests and tools: icon names and their time-left fractions.
var icons: Array[String] = []
var fractions: Array[float] = []
var _slots: Array[Array] = [] # [icon, bar background, bar fill] Sprite3Ds.
var _on_top := false
static var _bar_texture: ImageTexture


func show_states(states: Array) -> void:
	icons.clear()
	fractions.clear()
	while _slots.size() < states.size():
		_slots.append(_make_slot())
	for i in _slots.size():
		var slot: Array = _slots[i]
		var used := i < states.size()
		for sprite in slot:
			sprite.visible = used
		if not used:
			continue
		var icon_name: String = states[i][0]
		var fraction: float = states[i][1]
		icons.append(icon_name)
		fractions.append(fraction)
		var x := (i - (states.size() - 1) * 0.5) * SPACING
		slot[0].texture = ICONS[icon_name]
		slot[0].offset = Vector2(x, 0)
		slot[1].visible = fraction >= 0.0
		slot[2].visible = fraction >= 0.0
		slot[1].offset = Vector2(x - BAR.x * 0.5, -46)
		slot[2].offset = slot[1].offset
		slot[2].region_rect = Rect2(0, 0, maxf(1.0, BAR.x * clampf(fraction, 0.0, 1.0)), BAR.y)
		slot[2].modulate = COLORS[icon_name]
	visible = not states.is_empty()


## Fights and threats stay readable through trees; stun and fear may be hidden.
func set_on_top(on_top: bool) -> void:
	_on_top = on_top
	for slot in _slots:
		for sprite in slot:
			sprite.no_depth_test = on_top


func _make_slot() -> Array:
	if _bar_texture == null:
		var image := Image.create(int(BAR.x), int(BAR.y), false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_bar_texture = ImageTexture.create_from_image(image)
	var slot := []
	for part in 3:
		var sprite := Sprite3D.new()
		sprite.pixel_size = PIXEL
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.no_depth_test = _on_top
		sprite.render_priority = part
		if part > 0:
			sprite.texture = _bar_texture
			sprite.centered = false
			sprite.region_enabled = true
			sprite.region_rect = Rect2(Vector2.ZERO, BAR)
			sprite.modulate = Color(0.08, 0.1, 0.08, 0.75) if part == 1 else Color.WHITE
		add_child(sprite)
		slot.append(sprite)
	return slot
