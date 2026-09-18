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

## A finished model to use instead of the primitive blockout. Leave this
## empty and the blockout is used unless MODEL_PATH exists on disk.
@export var model_scene: PackedScene

## The height the blockout meshes in oravitsa.tscn are modelled at, in metres.
## This is the canonical 150 cm from docs/character.md; it is not a tunable.
const BLOCKOUT_HEIGHT := 1.5

## Where export_glb.py puts a model exported from the "Oravitsa" collection.
## Dropping a file here is enough to see it in game -- see docs/art-pipeline.md.
const MODEL_PATH := "res://models/oravitsa.glb"

var _mushrooms: int = 0


func _ready() -> void:
	if stats == null:
		# A missing resource would silently produce a 0-speed, 0-size player,
		# which reads as "the build is broken" rather than "the file is gone".
		push_warning("Oravitsa has no ForagerStats; falling back to defaults.")
		stats = ForagerStats.new()
	_apply_body_size()
	_use_model_if_available()
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


## The blockout in oravitsa.tscn is authored at BLOCKOUT_HEIGHT. Sizing the
## capsule and scaling the visual to match keeps the canonical figure in one
## place -- change height in default_stats.tres and the body follows.
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

	$Body.scale = Vector3.ONE * (stats.height / BLOCKOUT_HEIGHT)


## Swaps the primitive blockout for a real model when one exists, so that
## exporting from Blender is the only step needed to see it in game.
##
## The blockout is kept in the scene rather than deleted: it is the measured
## reference the model is built against, and being able to toggle back to it
## is how you catch a model that came in at the wrong scale.
func _use_model_if_available() -> void:
	var scene := model_scene
	if scene == null and ResourceLoader.exists(MODEL_PATH):
		scene = load(MODEL_PATH) as PackedScene
	if scene == null:
		return

	var model := scene.instantiate() as Node3D
	if model == null:
		push_warning("%s is not a 3D scene; keeping the blockout." % MODEL_PATH)
		return

	model.name = "Model"
	add_child(model)
	$Body.visible = false

	# A model that is not close to the canonical height means the export scale
	# is wrong. Say so loudly -- silently scaling it would hide the bug and
	# break every measurement in docs/character.md.
	var height := _measure_height(model)
	if height > 0.0 and absf(height - stats.height) > 0.15:
		push_warning(
			"%s is %.2f m tall but Oravitsa is %.2f m. Check the glTF export scale (docs/art-pipeline.md)."
			% [MODEL_PATH, height, stats.height]
		)


## World-space height of every mesh under a node, in metres.
func _measure_height(root_node: Node3D) -> float:
	var lo := INF
	var hi := -INF
	for child in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var box := mesh_instance.get_aabb()
		var basis_xform := mesh_instance.global_transform
		for i in 8:
			var corner := box.position + box.size * Vector3(
				float(i & 1), float((i >> 1) & 1), float((i >> 2) & 1))
			var world_y := (basis_xform * corner).y
			lo = minf(lo, world_y)
			hi = maxf(hi, world_y)
	return hi - lo if lo < INF else 0.0


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
