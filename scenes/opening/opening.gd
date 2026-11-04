extends Node

## Launch -> disposable bot world -> instructions -> fresh player world.
enum {DEMO, RULES, STARTING, PLAYING}
const DEMO_WORLD := preload("res://scenes/opening/demo_world.gd")
const GAME := preload("res://scenes/endless_woods/woods.tscn")
const ACCEPT_KEYS := [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
const ACCEPT_BUTTONS := [JOY_BUTTON_A, JOY_BUTTON_START]
var state := DEMO
var world: Node2D
var canvas: CanvasLayer
var screen: Control
var title: Label
var demo_badge: Label
var caption: Label
var action: Button
var rules: RichTextLabel
var card: PanelContainer
var guard := 0.0
var demo_time := 0.0
var accept_held := false
var scroll_axis := 0.0
var action_finger := -1
var touches := {}


func _ready() -> void:
	_new_demo()
	_build_screen()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _new_demo() -> void:
	if is_instance_valid(world):
		remove_child(world)
		world.free()
	world = Node2D.new()
	world.set_script(DEMO_WORLD)
	add_child(world)
	demo_time = 0.0


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.10, 0.085, 0.96)
	style.border_color = Color("96855b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	return style


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("fff1cf"))
	return label


func _build_screen() -> void:
	canvas = CanvasLayer.new()
	canvas.layer = 30
	add_child(canvas)
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(screen)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.055, 0.045, 0.2)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(shade)
	title = _label("ORAVITSA", 26)
	title.add_theme_color_override("font_shadow_color", Color("10251b"))
	title.add_theme_constant_override("shadow_offset_y", 3)
	screen.add_child(title)
	demo_badge = _label("DEMO MODE · Oravitsa is playing automatically", 16)
	demo_badge.add_theme_color_override("font_shadow_color", Color("10251b"))
	demo_badge.add_theme_constant_override("shadow_offset_y", 2)
	screen.add_child(demo_badge)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _panel_style())
	screen.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	caption = _label("Looking for woodland food", 15)
	box.add_child(caption)
	rules = RichTextLabel.new()
	rules.bbcode_enabled = true
	rules.add_theme_color_override("default_color", Color("e9e1c9"))
	rules.add_theme_font_size_override("normal_font_size", 16)
	rules.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rules.text = "[b]Welcome to Mossbank[/b]\nExplore endless woods, hamlets and caves. Gather berries and mushrooms; Oravitsa eats from her bag automatically. Hunger slows her, but never harms her.\n\nEarn aura at cave checkpoints and by giving food to chieftains. Aura lets you ride mounts and adopt up to two pets. Fright and bumps only interrupt your journey: there is no player health or death.\n\n[b]Be kind to wildlife[/b]\nSling stuns, Shoo scares, Slow halves movement, and Cure ends your stun or panic and heals nearby pets. Only stunned hares can be collected for raw meat. Only pets can defeat hindered cave monsters.\n\n[b]Keyboard & mouse[/b]\nWASD / arrows: walk · Shift: sprint\nClick an animal: target · F / right-click: Sling\nSpace: Shoo · E: Slow · R: Cure\nWalk over food or a stunned hare to collect\nO: give food · T: ride / dismount · G: adopt / dismiss\nM: maps · H: Help · P / Esc: pause · K / L: save / load\n\n[b]Controller[/b]\nLeft stick / D-pad: walk · L3: sprint\nRight-stick flick: target · LT: Shoo · RT: Sling\nLB: Slow · RB: Cure · A: collect / give / adopt\nY: ride / dismount · Select: maps · Start: Help · R3: pause\nWith Help open, X saves and B loads.\n\n[b]Touch[/b]\nUse the movement stick, tap animals to target, and use the named skill and interaction buttons. Pick up food by walking over it.\n\nMaps and Help remain available while playing. On the world map, + / −, the wheel or right stick changes zoom."
	rules.hide()
	box.add_child(rules)
	action = Button.new()
	action.text = "Start   ·   Enter / A"
	action.custom_minimum_size = Vector2(0, 42)
	action.add_theme_font_size_override("font_size", 18)
	var floating := _panel_style()
	floating.bg_color = Color(0.04, 0.12, 0.085, 0.55)
	floating.border_color = Color(0.9, 0.83, 0.64, 0.5)
	floating.set_corner_radius_all(21)
	floating.content_margin_top = 8
	floating.content_margin_bottom = 8
	action.add_theme_stylebox_override("normal", floating)
	var hover := floating.duplicate()
	hover.bg_color.a = 0.8
	action.add_theme_stylebox_override("hover", hover)
	action.add_theme_stylebox_override("pressed", hover)
	var focus := floating.duplicate()
	focus.bg_color = Color.TRANSPARENT
	focus.set_border_width_all(2)
	focus.border_color = Color("e9d6a2")
	action.add_theme_stylebox_override("focus", focus)
	action.pressed.connect(_activate)
	box.add_child(action)
	action.grab_focus()


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	title.position = Vector2(16, 80 if state == DEMO else 12)
	title.size = Vector2(size.x - 32, 40)
	demo_badge.position = Vector2(12, 112)
	demo_badge.size = Vector2(size.x - 24, 44)
	var width := minf(340 if state == DEMO else 720, size.x - 24)
	var height := minf(128, size.y - 120) if state == DEMO else size.y - 110
	var style := _panel_style()
	if state == DEMO:
		style.bg_color = Color(0.03, 0.08, 0.06, 0.15)
		style.set_border_width_all(0)
	card.add_theme_stylebox_override("panel", style)
	card.position = Vector2((size.x - width) * 0.5, size.y - height - 16)
	card.size = Vector2(width, height)


func _process(delta: float) -> void:
	guard = maxf(0.0, guard - delta)
	if state == DEMO:
		demo_time += delta
		caption.text = world.bot.activity
	elif state == RULES:
		rules.get_v_scroll_bar().value += scroll_axis * delta * 300.0
	elif state == STARTING and guard <= 0.0 and touches.is_empty() and not Input.is_anything_pressed():
		_begin_game()


func _activate() -> void:
	if guard > 0.0:
		return
	if state == DEMO:
		state = RULES
		world.process_mode = Node.PROCESS_MODE_DISABLED
		world.bot.direction = Vector2.ZERO
		world.get_node("HUD").hide()
		caption.text = "Your woodland journey"
		caption.add_theme_font_size_override("font_size", 20)
		demo_badge.hide()
		rules.show()
		action.text = "Begin game   ·   Enter / A"
		guard = 0.25
		_layout()
	elif state == RULES:
		state = STARTING
		action.disabled = true
		action.text = "Release controls to begin…"
		guard = 0.2


func _begin_game() -> void:
	remove_child(world)
	world.free()
	world = GAME.instantiate()
	add_child(world)
	state = PLAYING
	canvas.queue_free()
	set_process(false)
	set_process_input(false)


func _input(event: InputEvent) -> void:
	# Accept on release: a held Start cannot also dismiss instructions. All
	# other keys/axes/buttons are swallowed before any gameplay UI sees them.
	if event is InputEventKey:
		if state == RULES and event.pressed:
			if event.keycode in [KEY_DOWN, KEY_UP, KEY_PAGEDOWN, KEY_PAGEUP]:
				var amount := 180.0 if event.keycode in [KEY_PAGEDOWN, KEY_PAGEUP] else 40.0
				rules.get_v_scroll_bar().value += amount * (1 if event.keycode in [KEY_DOWN, KEY_PAGEDOWN] else -1)
			elif event.keycode == KEY_HOME:
				rules.get_v_scroll_bar().value = 0.0
			elif event.keycode == KEY_END:
				rules.get_v_scroll_bar().value = rules.get_v_scroll_bar().max_value
		if event.keycode in ACCEPT_KEYS and not event.echo:
			if event.pressed:
				accept_held = true
			elif accept_held:
				accept_held = false
				_activate()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton:
		if state == RULES and event.button_index in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
			scroll_axis = (1.0 if event.button_index == JOY_BUTTON_DPAD_DOWN else -1.0) if event.pressed else 0.0
		if event.button_index in ACCEPT_BUTTONS:
			if event.pressed:
				accept_held = true
			elif accept_held:
				accept_held = false
				_activate()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion:
		if state == RULES and event.axis in [JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_Y]:
			scroll_axis = event.axis_value if absf(event.axis_value) > 0.2 else 0.0
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		# The game deliberately disables touch-to-mouse emulation. Own the
		# opening button's finger explicitly, including release/cancel.
		if event.pressed:
			touches[event.index] = true
			if action_finger < 0 and action.get_global_rect().has_point(event.position):
				action_finger = event.index
		else:
			touches.erase(event.index)
			if event.index == action_finger:
				action_finger = -1
				if not event.canceled and action.get_global_rect().has_point(event.position):
					_activate()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if state == RULES and rules.get_global_rect().has_point(event.position) and event.index != action_finger:
			rules.get_v_scroll_bar().value -= event.relative.y
		get_viewport().set_input_as_handled()
