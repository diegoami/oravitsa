## Orthographic isometric camera that follows a target on the ground plane.
##
## The rig itself is what moves; the Camera3D child holds a fixed offset and
## rotation, so the view angle can never drift. Smoothing is exponential and
## therefore framerate independent.
extends Node3D

## What to follow. Usually the player.
@export var target: Node3D

## Higher converges on the target faster. Units are "per second" in the
## exponential sense, not metres.
@export_range(0.5, 20.0, 0.1) var follow_speed: float = 6.0

## Follow the target's Y as well. Off for iteration 1 -- the ground is flat,
## and ignoring Y stops the camera bobbing if the capsule settles on the floor.
@export var follow_vertical: bool = false

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	if target:
		global_position = _target_position()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	# Exponential smoothing: the 1 - exp(-k * dt) form gives the same visual
	# easing regardless of framerate, unlike a raw lerp(a, b, k * dt).
	var weight := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(_target_position(), weight)


func _target_position() -> Vector3:
	var p := target.global_position
	if not follow_vertical:
		p.y = global_position.y
	return p


## The camera's flattened basis, for converting input into world directions.
## Callers use this so movement stays camera-relative if the angle ever changes.
func get_ground_basis() -> Basis:
	var b := _camera.global_transform.basis
	var forward := -b.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := b.x
	right.y = 0.0
	right = right.normalized()
	return Basis(right, Vector3.UP, -forward)
