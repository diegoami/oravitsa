## A single pickable mushroom.
##
## The mushroom detects the forager rather than the forager scanning for
## mushrooms: one Area3D per pickup scales better than a per-frame radius
## query, and keeps the pickup rule in the thing being picked up.
extends Area3D

## Emitted just before the mushroom removes itself.
signal collected(by: Node3D)

## Vertical bob, in metres. Purely so pickups read as pickups in a grey scene.
@export_range(0.0, 0.3, 0.005) var bob_height: float = 0.04

## Bob cycles per second.
@export_range(0.0, 4.0, 0.05) var bob_speed: float = 1.1

var _rest_y: float = 0.0
var _phase: float = 0.0
var _taken: bool = false


func _ready() -> void:
	_rest_y = position.y
	# Desync the bob so a spawned field does not pulse in lockstep.
	_phase = randf() * TAU
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if bob_height <= 0.0:
		return
	_phase += delta * bob_speed * TAU
	position.y = _rest_y + sin(_phase) * bob_height


func _on_body_entered(body: Node3D) -> void:
	# Guard against a second body touching it in the same frame as the first.
	if _taken:
		return
	if not body.has_method("collect_mushroom"):
		return
	_taken = true
	body.collect_mushroom()
	collected.emit(body)
	queue_free()
