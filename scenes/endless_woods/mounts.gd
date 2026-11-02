extends Node

## Hamlet mounts (#67): donkeys, mules and horses tethered beside each
## hamlet's store tent. Oravitsa can ride one once her aura reaches its
## requirement; riding multiplies her fed speed, and each kind treats the
## stuns she suffers differently. Records keep absolute ground positions in
## metres, so streaming and origin rebasing never move them. A tethered mount
## regenerates from its hamlet's seed and is never saved; one that is ridden,
## or left away from its tether, is saved with its absolute position.

const CREATURES := "res://scenes/endless_woods/creatures/"
const ORDER := ["donkey", "mule", "horse"]
## aura: required to ride; speed: multiplies her fed speed; height: model
## height in metres (head); seat: saddle height in metres; stun: share of a
## stun she suffers while riding; throws: a stun also dismounts her.
const KINDS := {
	"donkey": {"aura": 15, "speed": 1.3, "height": 1.3, "seat": 0.88, "stun": 0.5, "throws": false, "file": "donkey", "tint": Color(1, 1, 1)},
	"mule": {"aura": 35, "speed": 1.5, "height": 1.3 * 1.15, "seat": 1.0, "stun": 1.0, "throws": false, "file": "donkey", "tint": Color(0.58, 0.5, 0.46)},
	"horse": {"aura": 70, "speed": 1.8, "height": 1.75, "seat": 1.22, "stun": 1.0, "throws": true, "file": "horse", "tint": Color(1, 1, 1)},
}
const CHANCES := [0.55, 0.85] # Cumulative: donkey most common, then mule, then horse.
const RADIUS := 0.5 # Metres; the footprint a mount needs on walkable ground.
const BODY := {"donkey": 1.3, "mule": 1.45, "horse": 1.9} # Metres from nose to tail.
const NOSE_RADIUS := 0.2 # Metres of clear ground its nose needs.
const PROMPT_RADIUS := 2.5 # Metres from a mount at which she can ride it.
const HOME_RADIUS := 1.5 # Left this close to its tether, a mount is tethered again.
const RETURN_SPEED := 1.3 # Metres per second, walking home on its own.
const GALLOP := 5.0 # Metres per second above which a ridden mount gallops.
const SHOWN := 90.0 # Metres within which mounts are drawn.
const MAX_AWAY := 32 # Mounts left away from home; beyond this the oldest walks home.
const CAVE_STOP := 1.7 # Metres from a cave mouth at which she has to get off.
const STATES := ["ridden", "waiting", "returning"]
const BOB := {"Walk": 0.03, "Gallop": 0.08} # Metres she rises per beat of each clip (#106).
const RIDER_HIP := 0.62 # Metres from her feet to where she sits, in her sprite.

var world: Node2D
var mounts: Array[Dictionary] = []
var ridden: Dictionary = {}
var _root: Node3D
var _last := Vector2.ZERO # Her absolute position last frame, for the ridden mount's pace.
var _away_tick := 0


func setup(owner_world: Node2D) -> void:
	world = owner_world
	_root = Node3D.new()
	_root.name = "Mounts"
	world.stage.add_child(_root)


func riding() -> bool:
	return not ridden.is_empty()


func ridden_kind() -> String:
	return ridden["kind"] if riding() else ""


## Metres from a mount's middle to its nose, which must stay clear of trees,
## rocks and walls ahead of it (#103).
func nose(kind: String) -> float:
	return float(BODY[kind]) * 0.5


## Whether a mount walking on its own toward `goal` may step from `from` to `p`
## (absolute metres): its body and nose fit the ground and it never steps
## further into a creature (#103). The nose never reaches past the goal.
func _fits(record: Dictionary, p: Vector2, from: Vector2, goal: Vector2) -> bool:
	var land: Node3D = world.landscape
	if not land.can_walk(p - land.origin, RADIUS):
		return false
	var ahead := p - from
	var reach := minf(nose(record["kind"]), p.distance_to(goal))
	if ahead.length() > 0.0001 and not land.can_walk(p + ahead.normalized() * reach - land.origin, NOSE_RADIUS):
		return false
	return world.clear_of_creatures(p, from, RADIUS)


## Her speed factor while riding, on top of how well fed she is.
func speed_factor() -> float:
	return KINDS[ridden["kind"]]["speed"] if riding() else 1.0


func _here() -> Vector2:
	return world.absolute_ground(world.player_position)


func _key(block: Vector2i, index: int) -> String:
	return "%d,%d,%d" % [block.x, block.y, index]


## The seeded mounts of a hamlet: one or two, each with its kind and tether
## spot beside the store tent (never in front of its entrance, where the
## chieftain stands), facing sideways so the camera sees it in profile.
func hamlet_mounts(hamlet: Dictionary) -> Array[Dictionary]:
	var land: Node3D = world.landscape
	var block: Vector2i = hamlet["block"]
	var store: Vector2 = hamlet["store"]
	var away := signf(store.x - hamlet["center"].x)
	away = away if away != 0.0 else 1.0
	var reach: float = land.STORE_HALF + 1.7
	var spots := [Vector2(away * reach, 0.4), Vector2(-away * reach, 0.4), Vector2(away * reach, land.STORE_HALF + 1.6), Vector2(-away * reach, land.STORE_HALF + 1.6)]
	var count := 1 + (1 if land.random_at(block, 150) < 0.5 else 0)
	var result: Array[Dictionary] = []
	for spot in spots:
		if result.size() >= count:
			break
		var q: Vector2 = store + spot
		if not land.can_walk(q - land.origin, RADIUS) or land.is_water(q - land.origin, 0.6):
			continue
		var index := result.size()
		var roll: float = land.random_at(block + Vector2i(index * 11, 5), 151)
		var kind: String = ORDER[0] if roll < CHANCES[0] else (ORDER[1] if roll < CHANCES[1] else ORDER[2])
		result.append({"kind": kind, "hamlet": block, "index": index, "tether": q, "facing": Vector2(signf(spot.x), 0)})
	return result


func _record(spec: Dictionary, state: String, at: Vector2) -> Dictionary:
	return {"kind": spec["kind"], "hamlet": spec["hamlet"], "index": spec["index"], "tether": spec["tether"], "home_facing": spec["facing"], "facing": spec["facing"], "at": at, "state": state, "graze": float(spec["index"]) * 3.0, "stuck": 0.0, "away_since": 0}


func find(block: Vector2i, index: int) -> Dictionary:
	for record in mounts:
		if record["hamlet"] == block and record["index"] == index:
			return record
	return {}


## Tethered mounts appear with their hamlet's villagers and leave with them;
## a mount that is ridden or left elsewhere is kept, so its hamlet never shows
## a second copy of it.
func refresh() -> void:
	if world.in_cave():
		return
	var here := _here()
	var land: Node3D = world.landscape
	var block := Vector2i(floori(here.x / land.HAMLET_BLOCK.x), floori(here.y / land.HAMLET_BLOCK.y))
	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var hamlet: Dictionary = land.hamlet_at(block + Vector2i(dx, dz))
			if hamlet.is_empty() or here.distance_to(hamlet["center"]) >= world.VILLAGER_APPEAR:
				continue
			for spec in hamlet_mounts(hamlet):
				if find(spec["hamlet"], spec["index"]).is_empty():
					mounts.append(_record(spec, "tethered", spec["tether"]))
	for i in range(mounts.size() - 1, -1, -1):
		var record := mounts[i]
		if record["state"] == "tethered" and here.distance_to(record["tether"]) > world.VILLAGER_LEAVE:
			_free_visual(record)
			mounts.remove_at(i)


## The closest mount she could get on, or {}.
func nearest() -> Dictionary:
	if world.in_cave() or riding():
		return {}
	var here := _here()
	var best := PROMPT_RADIUS
	var found := {}
	for record in mounts:
		var distance: float = here.distance_to(record["at"])
		if distance <= best:
			best = distance
			found = record
	return found


func requirement(record: Dictionary) -> int:
	return KINDS[record["kind"]]["aura"]


func allowed(record: Dictionary) -> bool:
	return not record.is_empty() and world.aura >= requirement(record)


## T, controller Y or the HUD button: get on the mount beside her, or off the
## one she rides. Too little aura only explains the requirement.
func toggle() -> void:
	if riding():
		dismount("Oravitsa gets off the %s" % ridden["kind"])
		return
	var record := nearest()
	if record.is_empty():
		return
	if not allowed(record):
		world._show_notice("The %s needs %d aura (you have %d)" % [record["kind"], requirement(record), world.aura], 3.0)
		return
	if world.player_stun > 0.0 or world.player_fright > 0.0:
		return
	var spot: Vector2 = world._local_point([record["at"].x, record["at"].y])
	if world._can_stand(spot):
		world.player_position = spot
	ridden = record
	record["state"] = "ridden"
	record["at"] = _here()
	_last = record["at"]
	world._show_notice("Oravitsa rides the %s" % record["kind"])
	world._update_hud()


## She gets off where she is, stepping aside if she can. The mount waits
## there, is tethered again if it is home, or walks home when `home` is set.
func dismount(notice: String, home: bool = false) -> void:
	if not riding():
		return
	var record := ridden
	ridden = {}
	record["at"] = _here()
	_away_tick += 1
	record["away_since"] = _away_tick
	if record["at"].distance_to(record["tether"]) <= HOME_RADIUS and not home:
		_tether(record)
	else:
		record["state"] = "returning" if home else "waiting"
		_limit_away()
	var side: Vector2 = Vector2(-record["facing"].y, record["facing"].x)
	for offset in [side, -side, Vector2.DOWN, Vector2.UP]:
		var spot: Vector2 = world.player_position + offset * 0.9 * world.METRE
		if world._can_stand(spot):
			world.player_position = spot
			break
	world._show_notice(notice, 3.0)
	world._update_hud()


func _tether(record: Dictionary) -> void:
	record["state"] = "tethered"
	record["at"] = record["tether"]
	record["facing"] = record["home_facing"]
	record["stuck"] = 0.0


## Bounded: beyond MAX_AWAY mounts left around the world, the oldest walks home.
func _limit_away() -> void:
	var away := mounts.filter(func(r: Dictionary) -> bool: return r["state"] == "waiting")
	if away.size() <= MAX_AWAY:
		return
	away.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["away_since"] < b["away_since"])
	away[0]["state"] = "returning"


## Called every surface frame after she has moved: the ridden mount follows
## her; aura below its requirement makes it leave her; mounts sent home walk
## back to their tethers.
func update(delta: float) -> void:
	if world.in_cave():
		return
	if riding():
		if world.aura < requirement(ridden):
			dismount("The %s no longer trusts Oravitsa" % ridden["kind"], true)
		else:
			ridden["at"] = _here()
	for record in mounts:
		if record["state"] == "returning":
			_walk_home(record, delta)
		elif record["state"] == "tethered":
			record["graze"] = float(record["graze"]) + delta


func _walk_home(record: Dictionary, delta: float) -> void:
	var at: Vector2 = record["at"]
	var to_home: Vector2 = record["tether"] - at
	var local_px: Vector2 = world._local_point([at.x, at.y])
	# Far from her, or stuck out of her sight, it simply gets home.
	if to_home.length() <= 0.2 or _here().distance_to(at) > SHOWN or record["stuck"] > 2.0 and world._spawn_is_hidden(local_px, world.VILLAGER):
		_tether(record)
		return
	var aim: Vector2 = world.detour_aim(record, record["tether"], RADIUS, delta)
	var step := (aim - at).limit_length(RETURN_SPEED * delta)
	var moved := at
	for part in [Vector2(step.x, 0), Vector2(0, step.y)]:
		if _fits(record, moved + part, moved, aim):
			moved += part
	record["stuck"] = 0.0 if moved.distance_to(at) > step.length() * 0.3 else float(record["stuck"]) + delta
	if moved != at:
		record["facing"] = (moved - at).normalized()
	record["at"] = moved


## A mount never goes underground: close to a cave mouth she gets off, and the
## mount waits just outside, beside the way she will come out.
func leave_at_cave(cave: Dictionary) -> void:
	if not riding():
		return
	var record := ridden
	dismount("The %s will not go into the cave; it waits outside" % record["kind"])
	var land: Node3D = world.landscape
	var facing: Vector2 = cave["facing"]
	var side := Vector2(-facing.y, facing.x)
	for offset in [facing * 3.0 + side * 1.3, facing * 3.0 - side * 1.3, facing * 4.0]:
		var q: Vector2 = cave["mouth"] + offset
		if land.can_walk(q - land.origin, RADIUS):
			record["at"] = q
			break
	record["facing"] = side if side.x >= 0 else -side
	world._update_hud()


## The away mounts for a save: kind, hamlet, index, absolute position, state.
func save() -> Array:
	var result := []
	for record in mounts:
		if record["state"] == "tethered":
			continue
		var at: Vector2 = _here() if record == ridden else record["at"]
		result.append({"kind": record["kind"], "hamlet": [record["hamlet"].x, record["hamlet"].y], "index": record["index"], "at": [at.x, at.y], "state": record["state"], "facing": [record["facing"].x, record["facing"].y]})
	return result


## Restores the saved away mounts (none for older saves) and her ride. A
## mount whose hamlet no longer has it is dropped; underground nobody rides.
func apply(saved: Array, underground: bool) -> void:
	for record in mounts:
		_free_visual(record)
	mounts.clear()
	ridden = {}
	for item in saved:
		var block := Vector2i(int(item["hamlet"][0]), int(item["hamlet"][1]))
		var hamlet: Dictionary = world.landscape.hamlet_at(block)
		if hamlet.is_empty():
			continue
		var spec := {}
		for candidate in hamlet_mounts(hamlet):
			if candidate["index"] == int(item["index"]) and candidate["kind"] == item["kind"]:
				spec = candidate
		if spec.is_empty() or not find(block, spec["index"]).is_empty():
			continue
		var state: String = item["state"]
		if state == "ridden" and (underground or riding()):
			state = "waiting"
		var record := _record(spec, state, Vector2(item["at"][0], item["at"][1]))
		var facing := Vector2(item["facing"][0], item["facing"][1])
		if facing.length_squared() > 0.01:
			record["facing"] = facing.normalized()
		mounts.append(record)
		if state == "ridden":
			ridden = record
	_last = _here()
	refresh()


func _free_visual(record: Dictionary) -> void:
	for field in ["node", "shadow", "post"]:
		if record.has(field) and is_instance_valid(record[field]):
			record[field].queue_free()
		record.erase(field)
	record.erase("animator")


func _build_visual(record: Dictionary) -> void:
	var kind: Dictionary = KINDS[record["kind"]]
	var model: Node3D = load(CREATURES + kind["file"] + ".glb").instantiate()
	model.name = record["kind"].capitalize() + "_" + _key(record["hamlet"], record["index"]).replace(",", "_")
	_root.add_child(model)
	var bounds: AABB = world._model_bounds(model)
	model.scale = Vector3.ONE * float(kind["height"]) / maxf(bounds.size.y, 0.01)
	if kind["tint"] != Color(1, 1, 1):
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			for i in mesh.mesh.get_surface_count():
				var material: Material = mesh.get_active_material(i)
				if material is BaseMaterial3D:
					material = material.duplicate()
					material.albedo_color = material.albedo_color * kind["tint"]
					mesh.set_surface_override_material(i, material)
	var animator: AnimationPlayer = world._find_animator(model)
	if animator != null:
		for clip in ["Idle", "Walk", "Gallop", "Eating"]:
			if animator.has_animation(clip):
				animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		animator.play("Idle")
		record["animator"] = animator
	record["node"] = model
	var shadow: MeshInstance3D = world._contact_shadow(float(kind["height"]) * 0.55)
	_root.add_child(shadow)
	record["shadow"] = shadow
	# A plain hitching post marks the tether, whether or not the mount is there.
	var post := MeshInstance3D.new()
	var pole := CylinderMesh.new()
	pole.top_radius = 0.05
	pole.bottom_radius = 0.07
	pole.height = 1.0
	pole.radial_segments = 6
	post.mesh = pole
	post.material_override = world.landscape.material("5d4a33")
	_root.add_child(post)
	record["post"] = post


func _ground(at: Vector2) -> Vector3:
	var land: Node3D = world.landscape
	var p: Vector2 = at - land.origin
	return Vector3(p.x, land.height_at(p), p.y)


## Places, turns and animates the mounts near her; the heroine sits on the
## one she rides.
func sync(delta: float) -> void:
	_root.visible = not world.in_cave()
	if world.in_cave():
		return
	var here := _here()
	var pace := 0.0
	if riding():
		var moved: Vector2 = here - _last
		pace = moved.length() / maxf(delta, 0.0001) if delta > 0.0 else 0.0
		if moved.length() > 0.001:
			ridden["facing"] = moved.normalized()
		_last = here
	for record in mounts:
		var near: bool = here.distance_to(record["at"]) <= SHOWN or here.distance_to(record["tether"]) <= SHOWN
		if not near:
			_free_visual(record)
			continue
		if not record.has("node"):
			_build_visual(record)
		var node: Node3D = record["node"]
		node.position = _ground(record["at"])
		var facing: Vector2 = record["facing"]
		node.rotation.y = atan2(facing.x, facing.y)
		record["shadow"].position = node.position + Vector3.UP * 0.015
		var home_facing: Vector2 = record["home_facing"]
		record["post"].position = _ground(record["tether"] + home_facing * 1.15) + Vector3.UP * 0.5
		if record.has("animator"):
			var animator: AnimationPlayer = record["animator"]
			var wanted := "Idle"
			var rate := 1.0
			match record["state"]:
				"ridden":
					if pace > GALLOP:
						wanted = "Gallop"
						rate = clampf(pace / 7.0, 0.8, 1.4)
					elif pace > 0.2:
						wanted = "Walk"
						rate = clampf(pace / 2.6, 0.7, 1.7)
				"returning":
					wanted = "Walk"
					rate = 0.6
				"tethered":
					# Grazing by the tether: a seeded rhythm of eating and resting.
					wanted = "Eating" if fmod(float(record["graze"]), 14.0) < 7.0 else "Idle"
			if animator.current_animation != wanted:
				animator.play(wanted, 0.25)
			animator.speed_scale = rate
	if riding():
		var seat: float = KINDS[ridden["kind"]]["seat"]
		world.heroine.position = _ground(here) + Vector3.UP * (seat - RIDER_HIP + rider_bob(ridden))


## How far above her seat Oravitsa rises right now (#106): she bobs twice per
## stride of the mount's Walk or Gallop clip, higher at a gallop, and sits
## still while it stands. Her pose itself is still one frame.
func rider_bob(record: Dictionary) -> float:
	if not record.has("animator"):
		return 0.0
	var animator: AnimationPlayer = record["animator"]
	var lift: float = BOB.get(animator.current_animation, 0.0)
	if lift <= 0.0 or animator.current_animation_length <= 0.0:
		return 0.0
	var phase: float = animator.current_animation_position / animator.current_animation_length
	return lift * absf(sin(phase * TAU * 2.0))
