extends Node

## Hunter companions (#65). About three hamlets in five have one hunter, who
## stands near the edge of its clearing: a spear hunter (most common), a bow
## hunter or, rarely, a veteran bow hunter. Each has a seeded aura threshold
## within its kind's band; stronger kinds need more. With enough aura G,
## controller A or the HUD button asks one to follow Oravitsa (two at most),
## and asking again sends it home. A follower leaves as soon as her aura falls
## below its threshold. Followers walk a few metres behind her, never block or
## bump her and catch up when left behind. They go underground with her, and
## there they stun the rats, spiders, goblins and kobolds that come within
## reach; nobody is ever killed or harmed. On the surface they leave wildlife
## alone. Records keep absolute ground positions in metres (underground too,
## where the frozen surface origin still applies), so streaming and rebasing
## never move them. Only followers are saved; the rest regenerate.

const CREATURES := "res://scenes/endless_woods/creatures/"
const ORDER := ["spear", "bow", "veteran"]
## band: the aura thresholds a hunter of this kind is seeded within; reach:
## metres to a monster it can stun; stun: seconds it stuns one; cooldown:
## seconds before it strikes again; clip: the farmer model's attack clip.
const KINDS := {
	"spear": {"name": "spear hunter", "band": Vector2i(20, 40), "reach": 1.6, "stun": 2.5, "cooldown": 2.5, "clip": "Sword_Slash",
		"tint": {"LightBlue": Color(0.2, 0.32, 0.15), "Beige": Color(0.43, 0.36, 0.22), "Brown": Color(0.3, 0.22, 0.13)}},
	"bow": {"name": "bow hunter", "band": Vector2i(45, 70), "reach": 6.0, "stun": 2.0, "cooldown": 3.0, "clip": "Gun_Shoot",
		"tint": {"LightBlue": Color(0.36, 0.23, 0.12), "Beige": Color(0.3, 0.4, 0.2), "Brown": Color(0.22, 0.16, 0.1)}},
	"veteran": {"name": "veteran bow hunter", "band": Vector2i(75, 100), "reach": 8.0, "stun": 3.0, "cooldown": 2.0, "clip": "Gun_Shoot",
		"tint": {"LightBlue": Color(0.14, 0.19, 0.13), "Beige": Color(0.46, 0.12, 0.09), "Brown": Color(0.16, 0.12, 0.09)}},
}
const CHANCE := 0.6 # Share of hamlets with a hunter.
const KIND_CHANCES := [0.55, 0.88] # Cumulative: spear, then bow, then veteran.
const MAX_FOLLOWERS := 2
const HEIGHT := 1.65 # Metres.
const RADIUS := 0.3 # Metres; the footprint a hunter needs on walkable ground.
const PROMPT_RADIUS := 2.5 # Metres from a hamlet's hunter at which she can ask it.
const DISMISS_RADIUS := 1.2 # Metres: closer than followers keep, so asking one home is deliberate.
const POST_FROM_EDGE := 4.0 # Metres inside the clearing's edge.
const STROLL := 2.5 # Metres a hunter at its post wanders.
const STROLL_SPEED := 0.9
const RETURN_SPEED := 1.4 # Metres per second, walking home on its own.
const FOLLOW_START := 3.0 # A follower walks after her beyond this distance...
const FOLLOW_STOP := 2.2 # ...and stops once this close again, so it never jitters at one limit.
const HURRY := 4.5 # Beyond this it runs faster than she moves.
const MIN_PACE := 1.8 # Metres per second; slowest a follower walks after her.
const CATCH_UP := 25.0 # Farther than this, a follower appears just behind her.
const SPREAD := 0.9 # Metres two followers keep apart.
const STUCK := 1.5 # Seconds without progress before a follower catches up.
const ATTACK := 0.6 # Seconds a strike's clip plays.
const ARROW_SPEED := 30.0 # Metres per second; the arrow is only drawn, the stun is immediate.
const SHOWN := 90.0 # Metres within which hunters are drawn.
const LABEL_RANGE := 14.0 # Metres within which a hamlet hunter's threshold floats above it.
const STATES := ["post", "following", "returning"]

var world: Node2D
var hunters: Array[Dictionary] = []
var _root: Node3D
var _arrows: Array[Dictionary] = []
var _last := Vector2.ZERO # Her absolute position last frame, for where "behind her" is.
var _heading := Vector2.DOWN


func setup(owner_world: Node2D) -> void:
	world = owner_world
	_root = Node3D.new()
	_root.name = "Hunters"
	world.stage.add_child(_root)


func _origin() -> Vector2:
	return Vector2(world.origin_cells) * world.TILE / world.METRE


func _here() -> Vector2:
	return world.absolute_ground(world.player_position)


## Local ground metres of an absolute spot, on the surface or underground.
func _local(at: Vector2) -> Vector2:
	return at - _origin()


func _can_walk(at: Vector2) -> bool:
	return world.landscape.can_walk(_local(at), RADIUS)


func title(record: Dictionary) -> String:
	return KINDS[record["kind"]]["name"]


func threshold(record: Dictionary) -> int:
	return int(record["threshold"])


## The seeded hunter of a hamlet, or {}: its kind, aura threshold and post
## near the edge of the clearing, on open ground.
func hamlet_hunter(hamlet: Dictionary) -> Dictionary:
	var land: Node3D = world._surface_landscape if world.in_cave() else world.landscape
	var block: Vector2i = hamlet["block"]
	if land.random_at(block, 160) >= CHANCE:
		return {}
	var roll: float = land.random_at(block, 161)
	var kind: String = ORDER[0] if roll < KIND_CHANCES[0] else (ORDER[1] if roll < KIND_CHANCES[1] else ORDER[2])
	var band: Vector2i = KINDS[kind]["band"]
	var needed := band.x + mini(band.y - band.x, int(land.random_at(block, 162) * (band.y - band.x + 1)))
	var start: float = land.random_at(block, 163) * TAU
	var center: Vector2 = hamlet["center"]
	for attempt in 16:
		var direction := Vector2.from_angle(start + attempt * TAU / 16.0)
		var q: Vector2 = center + direction * (land.HAMLET_RADIUS - POST_FROM_EDGE)
		if land.can_walk(q - land.origin, RADIUS + 0.6) and not land.is_water(q - land.origin, 1.0):
			return {"kind": kind, "hamlet": block, "threshold": needed, "post": q, "facing": -direction}
	return {}


func _record(spec: Dictionary, state: String, at: Vector2) -> Dictionary:
	return {"kind": spec["kind"], "hamlet": spec["hamlet"], "threshold": spec["threshold"], "post": spec["post"], "home_facing": spec["facing"], "facing": spec["facing"], "at": at, "state": state, "goal": spec["post"], "wait": 0.0, "turn": 0, "moving": false, "stuck": 0.0, "pace": 0.0, "cooldown": 0.0, "attack": 0.0}


func find(block: Vector2i) -> Dictionary:
	for record in hunters:
		if record["hamlet"] == block:
			return record
	return {}


func followers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record in hunters:
		if record["state"] == "following":
			result.append(record)
	return result


## Hamlet hunters appear with their hamlet's villagers and leave with them; a
## hunter that follows her or walks home is kept, so its hamlet never shows a
## second copy of it.
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
			var spec := hamlet_hunter(hamlet)
			if not spec.is_empty() and find(spec["hamlet"]).is_empty():
				hunters.append(_record(spec, "post", spec["post"]))
	for i in range(hunters.size() - 1, -1, -1):
		var record := hunters[i]
		if record["state"] != "following" and here.distance_to(record["post"]) > world.VILLAGER_LEAVE:
			_free_visual(record)
			hunters.remove_at(i)


## The hunter the prompt is about: a follower she stands right beside (to
## send home), else the closest hamlet hunter she could ask, or {}.
func nearest() -> Dictionary:
	var here := _here()
	for record in followers():
		if here.distance_to(record["at"]) <= DISMISS_RADIUS:
			return record
	if world.in_cave():
		return {}
	var best := PROMPT_RADIUS
	var found := {}
	for record in hunters:
		var distance: float = here.distance_to(record["at"])
		if record["state"] != "following" and distance <= best:
			best = distance
			found = record
	return found


func allowed(record: Dictionary) -> bool:
	return not record.is_empty() and world.aura >= threshold(record)


## What asking would do: "dismiss", "join", "aura" (too little) or "full".
func prompt(record: Dictionary) -> String:
	if record.is_empty():
		return ""
	if record["state"] == "following":
		return "dismiss"
	if not allowed(record):
		return "aura"
	return "full" if followers().size() >= MAX_FOLLOWERS else "join"


## Whether controller A should ask the nearby hunter rather than pick up.
func can_ask() -> bool:
	return prompt(nearest()) in ["dismiss", "join"] and world.player_stun <= 0.0


## G, controller A or the HUD button: ask the hunter beside her to follow, or
## send a follower home. A refusal explains itself.
func toggle() -> void:
	var record := nearest()
	match prompt(record):
		"dismiss":
			_leave(record, "The %s goes back to %s" % [title(record), world.PLACE_NAMES.hamlet(record["hamlet"])])
		"aura":
			world._show_notice("The %s follows only at %d aura (you have %d)" % [title(record), threshold(record), world.aura], 3.0)
		"full":
			world._show_notice("Two hunters already follow Oravitsa; the %s stays" % title(record), 3.0)
		"join":
			record["state"] = "following"
			record["moving"] = false
			record["stuck"] = 0.0
			world._show_notice("The %s follows Oravitsa while her aura stays at %d or more" % [title(record), threshold(record)], 3.5)
	world._update_hud()


## A follower walks home from where it is; underground it climbs out first.
func _leave(record: Dictionary, notice: String) -> void:
	record["state"] = "returning"
	record["moving"] = false
	record["attack"] = 0.0
	record["stuck"] = 0.0
	if world.in_cave():
		record["at"] = world._cave_return
	world._show_notice(notice, 3.5)


## Called every frame after she has moved, on the surface and underground:
## aura below a threshold sends that follower home; followers keep up and,
## underground, stun monsters; hunters at home stroll; sent home, they walk.
func update(delta: float) -> void:
	var here := _here()
	if here.distance_to(_last) > 0.01:
		_heading = (here - _last).normalized()
	_last = here
	for record in followers():
		if world.aura < threshold(record):
			_leave(record, "The %s leaves: Oravitsa's aura fell below %d" % [title(record), threshold(record)])
			world._update_hud()
	var slot := 0
	for record in followers():
		_follow(record, slot, delta)
		if world.in_cave():
			_fight(record, delta)
		slot += 1
	_update_arrows(delta)
	if world.in_cave():
		return
	for record in hunters:
		if record["state"] == "returning":
			_walk_home(record, delta)
		elif record["state"] == "post":
			_stroll(record, delta)


## Steps `at` toward `goal` by at most `length` metres, sliding along walls.
func _step(record: Dictionary, goal: Vector2, length: float) -> float:
	var at: Vector2 = record["at"]
	var step := (goal - at).limit_length(length)
	var moved := at
	for part in [Vector2(step.x, 0), Vector2(0, step.y)]:
		if _can_walk(moved + part):
			moved += part
	if moved.distance_to(at) > 0.0005:
		record["facing"] = (moved - at).normalized()
	record["at"] = moved
	return moved.distance_to(at)


## Underground a follower walks straight to her when the floor between is
## open, else to the next cell on the shortest way around the walls.
func _goal(record: Dictionary, here: Vector2) -> Vector2:
	if not world.in_cave() or _clear_floor(record["at"], here):
		return here
	var cave: Node3D = world._cave
	var target: Vector2i = cave.cell_at(_local(here))
	var flow: Dictionary = world._cave_flow if world._cave_flow_cell == target else cave.distances_to(target)
	var cell: Vector2i = cave.cell_at(_local(record["at"]))
	var steps: int = flow.get(cell, -1)
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if steps > 0 and flow.get(cell + step, -1) == steps - 1:
			return cave.cell_center(cell + step) + _origin()
	return here


func _follow(record: Dictionary, slot: int, delta: float) -> void:
	var here := _here()
	var distance: float = here.distance_to(record["at"])
	var hidden: bool = distance > 8.0 and world._spawn_is_hidden(world.from_ground(_local(record["at"])), world.VILLAGER)
	if distance > CATCH_UP or hidden or (record["stuck"] > STUCK and distance > FOLLOW_START):
		place_behind(record, slot)
		return
	if not record["moving"] and distance > FOLLOW_START:
		record["moving"] = true
	elif record["moving"] and distance < FOLLOW_STOP:
		record["moving"] = false
	if not record["moving"] or delta <= 0.0:
		record["pace"] = 0.0
		record["stuck"] = 0.0
		return
	var pace := maxf(MIN_PACE, world._move_speed() / world.METRE * (1.25 if distance > HURRY else 1.0))
	var goal := _goal(record, here)
	# Two followers keep a little apart instead of walking inside each other.
	for other in followers():
		if other != record and other["at"].distance_to(record["at"]) < SPREAD:
			var apart: Vector2 = record["at"] - other["at"]
			var side := Vector2(-_heading.y, _heading.x) * (1.0 if slot == 0 else -1.0)
			goal += (apart.normalized() if apart.length() > 0.01 else side) * SPREAD
	var moved := _step(record, goal, pace * delta)
	record["pace"] = moved / delta
	record["stuck"] = 0.0 if moved > pace * delta * 0.3 else float(record["stuck"]) + delta


## Puts a follower on open ground just behind her (beside her for `beside`),
## each slot on its own side, or on her own spot if nothing else is free.
func place_behind(record: Dictionary, slot: int, beside: bool = false) -> void:
	var here := _here()
	var back := -_heading
	var side := Vector2(-back.y, back.x) * (1.0 if slot == 0 else -1.0)
	var spots := [side * 1.3, back * 1.5 + side * 0.6, back * 2.0, side * 0.9 + back * 0.9, -side * 1.3, back * 1.0, -back * 1.5] if beside else [back * 2.0 + side * 0.6, back * 1.5 + side * 1.0, side * 1.4, back * 1.2, -side * 1.4, back * 2.6, -back * 1.5]
	var placed := here
	for offset in spots:
		var spot: Vector2 = here + offset
		if _can_walk(spot) and (not world.in_cave() or _clear_floor(here, spot)):
			placed = spot
			break
	record["at"] = placed
	record["facing"] = (here - placed).normalized() if here.distance_to(placed) > 0.01 else _heading
	record["moving"] = false
	record["stuck"] = 0.0
	record["pace"] = 0.0
	record["attack"] = 0.0


## After she enters a cave, changes level, comes out or loads a save, her
## followers stand beside her.
func arrive() -> void:
	_heading = Vector2.UP if world.in_cave() else Vector2.DOWN
	_last = _here()
	for arrow in _arrows:
		arrow["node"].queue_free()
	_arrows.clear()
	var slot := 0
	for record in followers():
		place_behind(record, slot, true)
		slot += 1


## Whether the cave floor is open all along the straight line from `a` to `b`
## (absolute metres): no shot, thrust or straight walk goes through a wall.
func _clear_floor(a: Vector2, b: Vector2) -> bool:
	var cave: Node3D = world._cave
	var samples := maxi(1, ceili(a.distance_to(b) / 0.2))
	for i in samples + 1:
		if not cave.is_open(_local(a.lerp(b, float(i) / samples))):
			return false
	return true


## Underground a follower stuns the awake, unscared monster within its reach
## that is nearest to Oravitsa, along open floor only. A stun is all it does:
## monsters are never killed, and hunter stuns give no aura.
func _fight(record: Dictionary, delta: float) -> void:
	record["cooldown"] = maxf(0.0, float(record["cooldown"]) - delta)
	record["attack"] = maxf(0.0, float(record["attack"]) - delta)
	if record["cooldown"] > 0.0:
		return
	var kind: Dictionary = KINDS[record["kind"]]
	var here := _here()
	var best := -1
	var best_distance := INF
	for id in world._active_animals:
		var data: Dictionary = world._animals[id]
		if data["kind"] not in world.MONSTERS or not data["alive"] or data["stun"] > 0.0 or data["shoo"] > 0.0:
			continue
		var at: Vector2 = world.absolute_ground(data["position"])
		if record["at"].distance_to(at) > kind["reach"] or not _clear_floor(record["at"], at):
			continue
		var distance := here.distance_to(at)
		if distance < best_distance:
			best_distance = distance
			best = id
	if best >= 0:
		strike(record, best)


func strike(record: Dictionary, id: int) -> void:
	var kind: Dictionary = KINDS[record["kind"]]
	var data: Dictionary = world._animals[id]
	var at: Vector2 = world.absolute_ground(data["position"])
	data["stun"] = kind["stun"]
	data["velocity"] = Vector2.ZERO
	data["burst"] = 0.0
	data["dart"] = 0.0
	data["attack_time"] = 0.0
	data["timeout"] = 0.0
	if world._active_animals.has(id):
		world._active_animals[id].stop()
		world._active_animals[id].modulate = Color(0.66, 0.78, 0.91)
	record["cooldown"] = kind["cooldown"]
	record["attack"] = ATTACK
	if record["at"].distance_to(at) > 0.01:
		record["facing"] = (at - record["at"]).normalized()
	if record["kind"] != "spear":
		_shoot(record["at"], at)


## An arrow streak from bow to monster, purely drawn.
func _shoot(from: Vector2, to: Vector2) -> void:
	var node := MeshInstance3D.new()
	var shaft := BoxMesh.new()
	shaft.size = Vector3(0.025, 0.025, 0.55)
	node.mesh = shaft
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("e8d7a8")
	node.material_override = glow
	node.name = "Arrow"
	_root.add_child(node)
	_arrows.append({"node": node, "from": from, "to": to, "age": 0.0, "flight": maxf(0.08, from.distance_to(to) / ARROW_SPEED)})


func _update_arrows(delta: float) -> void:
	for i in range(_arrows.size() - 1, -1, -1):
		var arrow := _arrows[i]
		arrow["age"] = float(arrow["age"]) + delta
		if arrow["age"] >= arrow["flight"]:
			arrow["node"].queue_free()
			_arrows.remove_at(i)


## A hunter at its post strolls a little around it, with pauses.
func _stroll(record: Dictionary, delta: float) -> void:
	record["wait"] = float(record["wait"]) - delta
	var goal: Vector2 = record["goal"]
	if record["at"].distance_to(goal) < 0.15:
		record["pace"] = 0.0
		if record["wait"] > 0.0:
			return
		record["turn"] += 1
		var key: Vector2i = record["hamlet"] + Vector2i(record["turn"], 7)
		var land: Node3D = world.landscape
		var spot: Vector2 = record["post"] + Vector2.from_angle(land.random_at(key, 164) * TAU) * land.random_at(key, 165) * STROLL
		record["goal"] = spot if _can_walk(spot) else record["post"]
		record["wait"] = 2.0 + land.random_at(key, 166) * 4.0
		return
	var moved := _step(record, goal, STROLL_SPEED * delta)
	record["pace"] = moved / maxf(delta, 0.0001)
	if moved < STROLL_SPEED * delta * 0.3:
		record["goal"] = record["at"]


func _walk_home(record: Dictionary, delta: float) -> void:
	var at: Vector2 = record["at"]
	var to_home: Vector2 = record["post"] - at
	var far: bool = _here().distance_to(at) > SHOWN
	if to_home.length() <= 0.2 or far or (record["stuck"] > 2.0 and world._spawn_is_hidden(world.from_ground(_local(at)), world.VILLAGER)):
		_home(record)
		return
	var moved := _step(record, record["post"], RETURN_SPEED * delta)
	record["pace"] = moved / maxf(delta, 0.0001)
	record["stuck"] = 0.0 if moved > RETURN_SPEED * delta * 0.3 else float(record["stuck"]) + delta


func _home(record: Dictionary) -> void:
	record["state"] = "post"
	record["at"] = record["post"]
	record["goal"] = record["post"]
	record["facing"] = record["home_facing"]
	record["stuck"] = 0.0
	record["pace"] = 0.0
	record["cooldown"] = 0.0
	record["attack"] = 0.0


## The followers for a save: hamlet block, kind and threshold.
func save() -> Array:
	var result := []
	for record in followers():
		result.append({"hamlet": [record["hamlet"].x, record["hamlet"].y], "kind": record["kind"], "threshold": record["threshold"]})
	return result


## Restores the saved followers beside her (none for older saves). A hunter
## whose hamlet no longer has it, or with too little aura, is dropped; every
## other hunter is back at its post.
func apply(saved: Array) -> void:
	for record in hunters:
		_free_visual(record)
	hunters.clear()
	for arrow in _arrows:
		arrow["node"].queue_free()
	_arrows.clear()
	var land: Node3D = world._surface_landscape if world.in_cave() else world.landscape
	for item in saved:
		if followers().size() >= MAX_FOLLOWERS:
			break
		var block := Vector2i(int(item["hamlet"][0]), int(item["hamlet"][1]))
		var hamlet: Dictionary = land.hamlet_at(block)
		if hamlet.is_empty():
			continue
		var spec := hamlet_hunter(hamlet)
		if spec.is_empty() or spec["kind"] != item["kind"] or spec["threshold"] != int(item["threshold"]) or not find(block).is_empty():
			continue
		hunters.append(_record(spec, "following", _here()))
	arrive()
	refresh()


func _free_visual(record: Dictionary) -> void:
	for field in ["node", "shadow", "label"]:
		if record.has(field) and is_instance_valid(record[field]):
			record[field].queue_free()
		record.erase(field)
	record.erase("animator")


static func _clip(animator: AnimationPlayer, clip: String) -> String:
	for full in animator.get_animation_list():
		if full == clip or full.ends_with("|" + clip):
			return full
	return ""


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material


## A spear (shaft and iron tip) or a bow (an arc of short staves and a
## string), held in the right hand, sized in metres.
func _weapon(kind: String, scale: float) -> Node3D:
	var weapon := Node3D.new()
	weapon.name = "Spear" if kind == "spear" else "Bow"
	var wood := _material(Color("6b4a2a") if kind != "veteran" else Color("3d2a1a"))
	if kind == "spear":
		var shaft := MeshInstance3D.new()
		var pole := CylinderMesh.new()
		pole.top_radius = 0.018
		pole.bottom_radius = 0.022
		pole.height = 1.9
		pole.radial_segments = 6
		shaft.mesh = pole
		shaft.material_override = wood
		shaft.position = Vector3(0, 0.35, 0)
		weapon.add_child(shaft)
		var tip := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.045
		cone.height = 0.22
		cone.radial_segments = 6
		tip.mesh = cone
		tip.material_override = _material(Color("b9bdc2"))
		tip.position = Vector3(0, 0.35 + 0.95 + 0.11, 0)
		weapon.add_child(tip)
	else:
		var span := 1.25 if kind == "veteran" else 1.05
		var bend := 0.22
		var parts := 7
		for i in parts:
			var t0 := float(i) / parts - 0.5
			var t1 := float(i + 1) / parts - 0.5
			# The grip, mid-bow, sits in the hand; the tips curve back to the string.
			var p0 := Vector3(0, t0 * span, -bend * 4.0 * t0 * t0)
			var p1 := Vector3(0, t1 * span, -bend * 4.0 * t1 * t1)
			var stave := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.035, p0.distance_to(p1) + 0.01, 0.035)
			stave.mesh = box
			stave.material_override = wood
			stave.position = (p0 + p1) * 0.5
			stave.rotation.x = atan2(p1.z - p0.z, p1.y - p0.y)
			weapon.add_child(stave)
		var string := MeshInstance3D.new()
		var line := BoxMesh.new()
		line.size = Vector3(0.008, span, 0.008)
		string.mesh = line
		string.material_override = _material(Color("e6dcc3"))
		string.position = Vector3(0, 0, -bend)
		weapon.add_child(string)
	weapon.scale = Vector3.ONE / maxf(scale, 0.0001)
	return weapon


func _build_visual(record: Dictionary) -> void:
	var kind: Dictionary = KINDS[record["kind"]]
	var model: Node3D = load(CREATURES + "farmer.glb").instantiate()
	model.name = "Hunter_%d_%d" % [record["hamlet"].x, record["hamlet"].y]
	_root.add_child(model)
	var bounds: AABB = world._model_bounds(model)
	var scale := HEIGHT / maxf(bounds.size.y, 0.01)
	model.scale = Vector3.ONE * scale
	# Hunter's clothes: the farmer's shirt, trousers and hat in the kind's colours.
	var tint: Dictionary = kind["tint"]
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var material: Material = mesh.get_active_material(i)
			if material is BaseMaterial3D and tint.has(material.resource_name):
				material = material.duplicate()
				material.albedo_color = tint[material.resource_name]
				mesh.set_surface_override_material(i, material)
	var skeleton: Skeleton3D = null
	for found in model.find_children("*", "Skeleton3D", true, false):
		skeleton = found
	if skeleton != null and skeleton.find_bone("Wrist.R") >= 0:
		var hand := BoneAttachment3D.new()
		hand.bone_name = "Wrist.R"
		skeleton.add_child(hand)
		var weapon := _weapon(record["kind"], skeleton.global_transform.basis.get_scale().x)
		hand.add_child(weapon)
		record["weapon"] = weapon
	var animator: AnimationPlayer = world._find_animator(model)
	if animator != null:
		for clip in ["Idle", "Walk", "Run"]:
			var full := _clip(animator, clip)
			if not full.is_empty():
				animator.get_animation(full).loop_mode = Animation.LOOP_LINEAR
		animator.play(_clip(animator, "Idle"))
		record["animator"] = animator
	record["node"] = model
	var shadow: MeshInstance3D = world._contact_shadow(0.45)
	_root.add_child(shadow)
	record["shadow"] = shadow
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.006
	label.font_size = 40
	label.outline_size = 10
	label.modulate = Color("f3e6c4")
	label.outline_modulate = Color("1d150c")
	label.no_depth_test = true
	label.name = "Threshold"
	_root.add_child(label)
	record["label"] = label


func _ground(at: Vector2) -> Vector3:
	var p := _local(at)
	return Vector3(p.x, world.landscape.height_at(p), p.y)


## Places, turns and animates the hunters near her; underground only her
## followers are there. Hamlet hunters show their aura threshold close by.
func sync(_delta: float) -> void:
	var here := _here()
	var underground: bool = world.in_cave()
	for record in hunters:
		var shown: bool = record["state"] == "following" if underground else here.distance_to(record["at"]) <= SHOWN
		if not shown:
			_free_visual(record)
			continue
		if not record.has("node"):
			_build_visual(record)
		var node: Node3D = record["node"]
		node.position = _ground(record["at"])
		var facing: Vector2 = record["facing"]
		if record["state"] == "post" and record["pace"] < 0.05 and here.distance_to(record["at"]) < 7.0:
			facing = (here - record["at"]).normalized() if here.distance_to(record["at"]) > 0.01 else facing # It turns to her.
		node.rotation.y = atan2(facing.x, facing.y)
		record["shadow"].position = node.position + Vector3.UP * 0.015
		var label: Label3D = record["label"]
		label.visible = record["state"] != "following" and here.distance_to(record["at"]) <= LABEL_RANGE
		var name := title(record)
		label.text = "%s · %d aura" % [name.left(1).to_upper() + name.substr(1), threshold(record)]
		label.position = node.position + Vector3.UP * (HEIGHT + 0.35)
		if record.has("animator"):
			var animator: AnimationPlayer = record["animator"]
			var wanted := "Idle"
			var rate := 1.0
			var pace: float = record["pace"]
			if record["attack"] > 0.0:
				wanted = KINDS[record["kind"]]["clip"]
				rate = 1.6
			elif pace > 2.6:
				wanted = "Run"
				rate = clampf(pace / 4.0, 0.8, 1.6)
			elif pace > 0.1:
				wanted = "Walk"
				rate = clampf(pace / 1.4, 0.6, 1.6)
			var full := _clip(animator, wanted)
			if not full.is_empty() and animator.current_animation != full:
				animator.play(full, 0.15)
			animator.speed_scale = rate
	for arrow in _arrows:
		var t: float = clampf(float(arrow["age"]) / float(arrow["flight"]), 0.0, 1.0)
		var from := _ground(arrow["from"]) + Vector3.UP * 1.25
		var to := _ground(arrow["to"]) + Vector3.UP * 0.4
		var node: Node3D = arrow["node"]
		node.position = from.lerp(to, t)
		if from.distance_to(to) > 0.01:
			node.look_at_from_position(node.position, to, Vector3.UP)
