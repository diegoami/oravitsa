## The forager. Camera-relative movement on a flat plane, plus the mushroom
## count for iteration 1.
##
## She has no attacks and never will -- influence spells come later, and
## nothing in this game may damage a creature. Nothing here should grow into
## a combat path.
extends CharacterBody3D

## Emitted whenever the carried count changes, with the new total.
signal inventory_changed(total: int)

## Movement and body tuning. See res://resources/default_stats.tres.
@export var stats: ForagerStats

## The camera the movement is relative to. Without it, input is treated as
## world-aligned, which is only useful for headless tests.
@export var camera_rig: Node3D

## Iteration-1 shortcut: the player writes its own count straight to this
## label. A real HUD script owns this once there is more than one number to
## show -- see docs/prototype_log.md.
@export var inventory_label: Label

var _mushrooms: int = 0


func _ready() -> void:
	if stats == null:
		# A missing resource would silently produce a 0-speed, 0-size player,
		# which reads as "the build is broken" rather than "the file is gone".
		push_warning("Oravitsa has no ForagerStats; falling back to defaults.")
		stats = ForagerStats.new()
	_apply_body_size()
	_refresh_label()


func _physics_process(delta: float) -> void:
	var input := Input.get_vector(
		"move_left", "move_right", "move_forward", "move_back"
	)
	var direction := _input_to_world(input)

	var target_velocity := direction * stats.move_speed
	var rate := stats.acceleration if direction != Vector3.ZERO else stats.deceleration
	velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)

	# Keep her on the ground. Flat plane in iteration 1, but gravity means a
	# capsule that starts slightly above the floor settles instead of hovering.
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y += get_gravity().y * delta

	move_and_slide()

	if direction != Vector3.ZERO:
		_face(direction, delta)


## Converts a 2D input vector into a world-space ground direction, relative to
## the camera. Input up (-Y) means "away from the camera".
func _input_to_world(input: Vector2) -> Vector3:
	if input == Vector2.ZERO:
		return Vector3.ZERO
	var right := Vector3.RIGHT
	var forward := Vector3.FORWARD
	if camera_rig and camera_rig.has_method("get_ground_basis"):
		var basis := camera_rig.get_ground_basis() as Basis
		right = basis.x
		forward = -basis.z
	return (right * input.x + forward * -input.y).normalized()


func _face(direction: Vector3, delta: float) -> void:
	# Godot's convention is that a node's front is its -Z axis, so the yaw that
	# aims -Z along `direction` is atan2 of the negated components.
	var target_yaw := atan2(-direction.x, -direction.z)
	rotation.y = rotate_toward(rotation.y, target_yaw, stats.turn_speed * delta)


## Sizes the collision capsule and its greybox mesh from the canonical height,
## so changing docs/character.md's figure in the .tres changes the body too.
func _apply_body_size() -> void:
	var shape := $CollisionShape3D as CollisionShape3D
	var capsule := shape.shape as CapsuleShape3D
	if capsule:
		# CapsuleShape3D.height is the full tip-to-tip height, so it is the
		# character's height directly -- no need to subtract the end caps.
		capsule.height = stats.height
		capsule.radius = stats.radius
	# Origin sits at the feet; the capsule is centred on the body.
	shape.position.y = stats.height * 0.5

	var mesh_instance := $Body as MeshInstance3D
	var mesh := mesh_instance.mesh as CapsuleMesh
	if mesh:
		mesh.height = stats.height
		mesh.radius = stats.radius
	mesh_instance.position.y = stats.height * 0.5

	# The cap is the bandana stand-in and the only facing cue on a greybox
	# capsule. It has to overlap the capsule's dome, or the dome's apex pokes
	# through it; the marker has to clear the disc, or it is buried inside it.
	var cap := $Cap as MeshInstance3D
	var cap_mesh := cap.mesh as CylinderMesh
	if cap_mesh:
		cap_mesh.top_radius = stats.radius + 0.02
		cap_mesh.bottom_radius = stats.radius + 0.02
		cap.position.y = stats.height - cap_mesh.height * 0.3
		$Cap/Prow.position.z = -(stats.radius + 0.1)


## Called by mushrooms when they are walked into.
func collect_mushroom() -> void:
	_mushrooms += 1
	_refresh_label()
	inventory_changed.emit(_mushrooms)


func get_mushroom_count() -> int:
	return _mushrooms


func _refresh_label() -> void:
	if inventory_label:
		inventory_label.text = "Mushrooms: %d" % _mushrooms
