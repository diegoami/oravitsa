## Tunable movement and pickup values for the forager.
##
## Kept as a Resource so iteration-1 tuning happens in the inspector on
## res://resources/default_stats.tres rather than in code.
##
## All distances are in metres: the project uses 1 unit = 1 metre.
class_name ForagerStats
extends Resource

## Top ground speed, metres per second. A relaxed walk, not a run.
@export_range(0.5, 10.0, 0.1) var move_speed: float = 3.2

## How quickly the forager reaches move_speed, in metres per second squared.
## Higher feels snappier; lower feels heavier.
@export_range(1.0, 60.0, 0.5) var acceleration: float = 18.0

## How quickly she stops once input is released, metres per second squared.
@export_range(1.0, 60.0, 0.5) var deceleration: float = 24.0

## How quickly she turns to face her heading, in radians per second.
@export_range(1.0, 30.0, 0.5) var turn_speed: float = 11.0

## Canonical standing height in metres. See docs/character.md -- the design
## sheets disagreed (145 vs 150 cm) and 150 cm was chosen as canonical.
## This drives the capsule size and therefore the scale of every future asset.
@export_range(0.5, 2.5, 0.01) var height: float = 1.5

## Capsule radius in metres. Roughly shoulder half-width for this build.
@export_range(0.1, 1.0, 0.01) var radius: float = 0.28
