extends CanvasLayer

## Pauses and resumes the game (#57). This layer keeps running while the scene
## tree is paused, so its Pause button, the Resume overlay and the P / Esc /
## right-stick-click toggles still work; everything else freezes, including
## animals, monsters, hunger, timers, animations and sound.

const TOGGLE_KEYS := [KEY_P, KEY_ESCAPE]
const TOGGLE_BUTTON := JOY_BUTTON_RIGHT_STICK

var button: Button # The HUD's Pause button; the forest styles and places it.
var resume_prompt := "" # Shown on Resume, such as " [P]".
var _overlay: ColorRect
var _resume: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_overlay = ColorRect.new()
	_overlay.color = Color(0.04, 0.06, 0.1, 0.6)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	_overlay.add_child(box)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("fff1bd"))
	box.add_child(title)
	_resume = Button.new()
	_resume.custom_minimum_size = Vector2(200, 48)
	_resume.add_theme_font_size_override("font_size", 18)
	_resume.pressed.connect(func(): set_paused(false))
	box.add_child(_resume)


func _exit_tree() -> void:
	if is_paused():
		get_tree().paused = false


func is_paused() -> bool:
	return _overlay != null and _overlay.visible


func toggle() -> void:
	set_paused(not is_paused())


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_overlay.visible = paused
	_resume.text = "Resume" + resume_prompt
	if button != null:
		button.visible = not paused
	if paused:
		_resume.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	var key: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode in TOGGLE_KEYS
	var pad: bool = event is InputEventJoypadButton and event.pressed and event.button_index == TOGGLE_BUTTON
	# A on a controller also resumes, through the focused Resume button.
	if key or pad:
		toggle()
		get_viewport().set_input_as_handled()
