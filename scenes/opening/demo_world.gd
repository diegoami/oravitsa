extends "res://scenes/endless_woods/woods.gd"

## The demo owns no player input and cannot read or write the manual save.
var bot: RefCounted


func _ready() -> void:
	super._ready()
	bot = preload("res://scenes/opening/demo_bot.gd").new(self)
	_pause.hide()
	_pause.process_mode = Node.PROCESS_MODE_DISABLED
	_touch_controls.process_mode = Node.PROCESS_MODE_DISABLED
	set_process_input(false)
	set_process_unhandled_input(false)
	set_process_unhandled_key_input(false)


func _process(delta: float) -> void:
	bot.update(delta)
	super._process(delta)


func _movement_direction() -> Vector2:
	return bot.direction if bot != null else Vector2.ZERO


func _sprint_requested() -> bool:
	return false


func _can_save() -> bool:
	return false


func _save_game() -> void:
	pass


func _load_game() -> void:
	pass


func _collect_nearby() -> void:
	var food_before := basket + berries_basket
	var mushrooms_before := basket
	var meat_before := raw_meat
	super._collect_nearby()
	if bot != null:
		bot.foods_collected += maxi(0, basket + berries_basket - food_before)
		bot.mushrooms_collected += maxi(0, basket - mushrooms_before)
		bot.hares_collected += maxi(0, raw_meat - meat_before)
