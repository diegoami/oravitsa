extends Control

## Touch input stays separate from Input actions so releasing a finger never
## releases a desktop key. Each control owns its finger for multitouch play.
signal shoo_requested
signal touch_mode_changed

var touch_enabled := false
var direction := Vector2.ZERO
var cooldown := 0.0
var stunned := false
var _stick_finger := -1
var _shoo_finger := -1
var _stick_center := Vector2.ZERO
var _shoo_center := Vector2.ZERO
var _radius := 78.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	resized.connect(_layout)
	_layout()
	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		_enable_touch()


func _enable_touch() -> void:
	if touch_enabled:
		return
	touch_enabled = true
	visible = true
	touch_mode_changed.emit()


func _layout() -> void:
	_radius = clampf(minf(size.x, size.y) * 0.145, 64.0, 82.0)
	_stick_center = Vector2(28.0 + _radius, size.y - 28.0 - _radius)
	_shoo_center = Vector2(size.x - 28.0 - _radius * 0.72, _stick_center.y)
	_reset()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_enable_touch()
		if event.pressed:
			if _stick_finger < 0 and event.position.distance_to(_stick_center) <= _radius * 1.25:
				_stick_finger = event.index
				_update_direction(event.position)
			elif _shoo_finger < 0 and event.position.distance_to(_shoo_center) <= _radius * 0.85:
				_shoo_finger = event.index
				shoo_requested.emit()
			else:
				return
		elif event.index == _stick_finger:
			_stick_finger = -1
			direction = Vector2.ZERO
		elif event.index == _shoo_finger:
			_shoo_finger = -1
		else:
			return
		get_viewport().set_input_as_handled()
		queue_redraw()
	elif event is InputEventScreenDrag and event.index == _stick_finger:
		_update_direction(event.position)
		get_viewport().set_input_as_handled()


func _update_direction(point: Vector2) -> void:
	var offset := (point - _stick_center) / _radius
	direction = Vector2.ZERO if offset.length() < 0.15 else offset.limit_length()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_reset()


func _reset() -> void:
	direction = Vector2.ZERO
	_stick_finger = -1
	_shoo_finger = -1
	queue_redraw()


func _draw() -> void:
	if not touch_enabled:
		return
	var outline := Color(0.96, 0.92, 0.78, 0.75)
	draw_circle(_stick_center, _radius, Color(0.06, 0.14, 0.10, 0.58))
	draw_arc(_stick_center, _radius, 0.0, TAU, 64, outline, 2.0, true)
	draw_circle(_stick_center + direction * _radius * 0.55, _radius * 0.38, Color(0.94, 0.89, 0.72, 0.75))
	var ready := cooldown <= 0.0 and not stunned
	var fill := Color(0.25, 0.39, 0.24, 0.86) if ready else Color(0.08, 0.16, 0.12, 0.72)
	if _shoo_finger >= 0:
		fill = fill.lightened(0.16)
	draw_circle(_shoo_center, _radius * 0.72, fill)
	draw_arc(_shoo_center, _radius * 0.72, 0.0, TAU, 64, outline, 2.0, true)
	var caption := "%.1fs" % cooldown if cooldown > 0.0 else "Shoo"
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	draw_string(font, _shoo_center + Vector2(-text_size.x * 0.5, 8.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, outline)
