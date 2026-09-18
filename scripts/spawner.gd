## Scatters mushrooms across the ground plane at startup.
##
## Iteration 1 only: a flat random scatter with a clear radius around the
## player start. This is deliberately not procedural generation -- no noise,
## no biomes, no seeded world. It exists so there is something to walk into.
extends Node3D

## What to scatter. Expected to be res://scenes/mushroom.tscn.
@export var mushroom_scene: PackedScene

## How many to place.
@export_range(0, 200, 1) var count: int = 24

## Scatter radius in metres, measured from this node.
@export_range(1.0, 100.0, 0.5) var area_radius: float = 16.0

## Nothing spawns within this many metres of the player start, so the first
## pickup is a walk rather than an accident.
@export_range(0.0, 20.0, 0.5) var clear_radius: float = 3.0

## Minimum gap between two mushrooms, in metres.
@export_range(0.0, 10.0, 0.1) var min_spacing: float = 1.2

## Fixed seed keeps the greybox layout identical between runs, so a movement
## or camera change is the only thing that differs. Set to 0 for a fresh
## scatter each run.
@export var random_seed: int = 20260918

var _placed: Array[Vector2] = []


func _ready() -> void:
	if mushroom_scene == null:
		push_warning("Spawner has no mushroom_scene; nothing to scatter.")
		return

	var rng := RandomNumberGenerator.new()
	if random_seed != 0:
		rng.seed = random_seed
	else:
		rng.randomize()

	for i in count:
		# Variant rather than Vector2: null is how "no room left" is reported,
		# and Vector2 has no spare value to use as a sentinel.
		var spot: Variant = _find_spot(rng)
		if spot == null:
			# Ran out of room. Better to place fewer than to stack them.
			push_warning("Spawner placed %d of %d mushrooms; area is full." % [_placed.size(), count])
			break
		_place(spot)


## Rejection sampling: try a handful of times, give up rather than loop forever
## if the spacing constraints cannot be satisfied.
func _find_spot(rng: RandomNumberGenerator) -> Variant:
	for _attempt in 32:
		# sqrt on the radius keeps the scatter uniform by area rather than
		# clumping toward the centre.
		var angle := rng.randf() * TAU
		var distance := sqrt(rng.randf()) * area_radius
		if distance < clear_radius:
			continue
		var candidate := Vector2(cos(angle), sin(angle)) * distance
		if _is_clear(candidate):
			return candidate
	return null


func _is_clear(candidate: Vector2) -> bool:
	for existing in _placed:
		if existing.distance_to(candidate) < min_spacing:
			return false
	return true


func _place(spot: Vector2) -> void:
	var mushroom := mushroom_scene.instantiate() as Node3D
	add_child(mushroom)
	mushroom.position = Vector3(spot.x, 0.0, spot.y)
	# A little variety in facing and size so a grey field is still readable.
	mushroom.rotation.y = randf() * TAU
	var scale_factor := randf_range(0.85, 1.2)
	mushroom.scale = Vector3.ONE * scale_factor
	_placed.append(spot)
