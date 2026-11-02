extends Node

## Pets (#65). About three hamlets in five keep one pet near the edge of their
## clearing: a cat (most common), a Shiba Inu or, rarely, a husky. Each has a
## seeded aura threshold within its kind's band; stronger kinds need more.
## With enough aura G, controller A or the HUD button adopts one (two follow
## at most), and asking again right beside a follower sends it home. A
## follower leaves as soon as her aura falls below its threshold. Followers
## walk a few metres behind her, never block or bump her and catch up when
## left behind. They go underground with her, and there a healthy pet runs to
## a monster that is stunned, scared or slowed and kills it with a bite: cats
## take rats, spiders and kobolds, dogs goblins too. Oravitsa never kills.
## An awake monster that reaches a pet bites it: a spider poisons it, a rat or
## goblin wounds it, a kobold does nothing. A poisoned or wounded pet follows
## slowly and never attacks until Oravitsa's Cure heals it; there is no
## health and no death. On the surface pets leave wildlife and villagers
## alone. Records keep absolute ground positions in metres (underground too,
## where the frozen surface origin still applies), so streaming and rebasing
## never move them. Only followers are saved; the rest regenerate.

const CREATURES := "res://scenes/endless_woods/creatures/"
const STATUS_MARKER := preload("res://scenes/forest_25d/status_marker.gd")
const ORDER := ["cat", "shiba", "husky"]
## band: the aura thresholds a pet of this kind is seeded within; height:
## metres; reach: metres from a monster at which it bites; bite: seconds from
## starting a bite to the kill; rest: seconds before it hunts again; run:
## metres per second when it runs at prey; goblins: whether it takes goblins.
const KINDS := {
	"cat": {"name": "cat", "band": Vector2i(20, 40), "height": 0.42, "reach": 0.9, "bite": 0.45, "rest": 1.4, "run": 5.2, "goblins": false,
		"clips": {"bite": "Bite_Front", "run": "Walk", "walk_pace": 0.9, "run_pace": 2.2}},
	"shiba": {"name": "Shiba Inu", "band": Vector2i(40, 65), "height": 0.58, "reach": 1.1, "bite": 0.4, "rest": 1.0, "run": 5.8, "goblins": true,
		"clips": {"bite": "Attack", "run": "Gallop", "walk_pace": 1.2, "run_pace": 4.5}},
	"husky": {"name": "husky", "band": Vector2i(65, 90), "height": 0.76, "reach": 1.4, "bite": 0.3, "rest": 0.7, "run": 6.5, "goblins": true,
		"clips": {"bite": "Attack", "run": "Gallop", "walk_pace": 1.4, "run_pace": 5.0}},
}
const CHANCE := 0.6 # Share of hamlets with a pet.
const KIND_CHANCES := [0.55, 0.88] # Cumulative: cat, then Shiba Inu, then husky.
const MAX_FOLLOWERS := 2
const RADIUS := 0.25 # Metres; the footprint a pet needs on walkable ground.
const PROMPT_RADIUS := 2.5 # Metres from a hamlet's pet at which she can adopt it.
const DISMISS_RADIUS := 1.2 # Metres: closer than followers keep, so sending one home is deliberate.
const POST_FROM_EDGE := 4.0 # Metres inside the clearing's edge.
const STROLL := 2.5 # Metres a pet at home wanders.
const STROLL_SPEED := 0.7
const RETURN_SPEED := 1.4 # Metres per second, walking home on its own.
const FOLLOW_START := 3.0 # A follower walks after her beyond this distance...
const FOLLOW_STOP := 2.2 # ...and stops once this close again, so it never jitters at one limit.
const HURRY := 4.5 # Beyond this it runs faster than she moves.
const MIN_PACE := 1.8 # Metres per second; slowest a healthy follower walks after her.
const AFFLICTED_PACE := 0.6 # A poisoned or wounded pet keeps this share of its pace.
const CATCH_UP := 25.0 # Farther than this, a follower appears just behind her.
const SPREAD := 0.9 # Metres two followers keep apart.
const STUCK := 1.5 # Seconds without progress before a follower catches up.
const HUNT_RANGE := 8.0 # Metres from the pet to prey it runs at...
const HUNT_LEASH := 10.0 # ...which must also be this close to Oravitsa.
const HUNT_WALK := 12.0 # Metres of cave walking at most to reach it.
const CURE_RANGE := 6.0 # Metres from Oravitsa within which Cure heals a pet.
const SHOWN := 90.0 # Metres within which pets are drawn.
const LABEL_RANGE := 14.0 # Metres within which a hamlet pet's threshold floats above it.
const STATES := ["post", "following", "returning"]

var world: Node2D
var pets: Array[Dictionary] = []
var _root: Node3D
var _last := Vector2.ZERO # Her absolute position last frame, for where "behind her" is.
var _heading := Vector2.DOWN


func setup(owner_world: Node2D) -> void:
	world = owner_world
	_root = Node3D.new()
	_root.name = "Pets"
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


func afflicted(record: Dictionary) -> bool:
	return record["poisoned"] or record["wounded"]


## Whether this pet takes a monster of `kind`: cats leave goblins alone.
func can_kill(record: Dictionary, kind: int) -> bool:
	return kind in [world.RAT, world.SPIDER, world.KOBOLD] or (kind == world.GOBLIN and KINDS[record["kind"]]["goblins"])


## The seeded pet of a hamlet, or {}: its kind, aura threshold and home near
## the edge of the clearing, on open ground.
func hamlet_pet(hamlet: Dictionary) -> Dictionary:
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
	return {"kind": spec["kind"], "hamlet": spec["hamlet"], "threshold": spec["threshold"], "post": spec["post"], "home_facing": spec["facing"], "facing": spec["facing"], "at": at, "state": state, "goal": spec["post"], "wait": 0.0, "turn": 0, "moving": false, "stuck": 0.0, "pace": 0.0, "cooldown": 0.0, "attack": 0.0, "bite": 0.0, "prey": -1, "poisoned": false, "wounded": false}


func find(block: Vector2i) -> Dictionary:
	for record in pets:
		if record["hamlet"] == block:
			return record
	return {}


func followers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record in pets:
		if record["state"] == "following":
			result.append(record)
	return result


## Hamlet pets appear with their hamlet's villagers and leave with them; a pet
## that follows her or walks home is kept, so its hamlet never shows a second
## copy of it.
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
			var spec := hamlet_pet(hamlet)
			if not spec.is_empty() and find(spec["hamlet"]).is_empty():
				pets.append(_record(spec, "post", spec["post"]))
	for i in range(pets.size() - 1, -1, -1):
		var record := pets[i]
		if record["state"] != "following" and here.distance_to(record["post"]) > world.VILLAGER_LEAVE:
			_free_visual(record)
			pets.remove_at(i)


## The pet the prompt is about: a follower she stands right beside (to send
## home), else the closest hamlet pet she could adopt, or {}.
func nearest() -> Dictionary:
	var here := _here()
	for record in followers():
		if here.distance_to(record["at"]) <= DISMISS_RADIUS:
			return record
	if world.in_cave():
		return {}
	var best := PROMPT_RADIUS
	var found := {}
	for record in pets:
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


## Whether controller A should adopt or send home the nearby pet rather than
## pick up.
func can_ask() -> bool:
	return prompt(nearest()) in ["dismiss", "join"] and world.player_stun <= 0.0


## G, controller A or the HUD button: adopt the pet beside her, or send a
## follower home. A refusal explains itself.
func toggle() -> void:
	var record := nearest()
	match prompt(record):
		"dismiss":
			_leave(record, "The %s goes back to %s" % [title(record), world.PLACE_NAMES.hamlet(record["hamlet"])])
		"aura":
			world._show_notice("The %s follows only at %d aura (you have %d)" % [title(record), threshold(record), world.aura], 3.0)
		"full":
			world._show_notice("Two pets already follow Oravitsa; the %s stays" % title(record), 3.0)
		"join":
			record["state"] = "following"
			record["moving"] = false
			record["stuck"] = 0.0
			world._show_notice("The %s follows Oravitsa while her aura stays at %d or more" % [title(record), threshold(record)], 3.5)
	world._update_hud()


## A follower walks home from where it is; underground it climbs out first.
func _leave(record: Dictionary, notice: String) -> void:
	_drop_bite(record)
	record["state"] = "returning"
	record["moving"] = false
	record["attack"] = 0.0
	record["stuck"] = 0.0
	if world.in_cave():
		record["at"] = world._cave_return
	world._show_notice(notice, 3.5)


## Called every frame after she has moved, on the surface and underground:
## aura below a threshold sends that follower home; followers keep up and,
## underground, hunt hindered monsters and get bitten by awake ones; pets at
## home stroll; sent home, they walk.
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
		if not (world.in_cave() and _hunt(record, delta)):
			_follow(record, slot, delta)
		slot += 1
	if world.in_cave():
		_monster_bites()
		return
	for record in pets:
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


## Underground a pet walks straight to `goal` when the floor between is open,
## else to the next cell on the shortest way around the walls.
func _way(record: Dictionary, goal: Vector2, flow: Dictionary = {}) -> Vector2:
	if not world.in_cave() or _clear_floor(record["at"], goal):
		return goal
	var cave: Node3D = world._cave
	if flow.is_empty():
		var target: Vector2i = cave.cell_at(_local(goal))
		flow = world._cave_flow if world._cave_flow_cell == target else cave.distances_to(target)
	var cell: Vector2i = cave.cell_at(_local(record["at"]))
	var steps: int = flow.get(cell, -1)
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if steps > 0 and flow.get(cell + step, -1) == steps - 1:
			return cave.cell_center(cell + step) + _origin()
	return goal


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
	if afflicted(record):
		pace *= AFFLICTED_PACE
	var goal := _way(record, here)
	# Two followers keep a little apart instead of walking inside each other.
	for other in followers():
		if other != record and other["at"].distance_to(record["at"]) < SPREAD:
			var apart: Vector2 = record["at"] - other["at"]
			var side := Vector2(-_heading.y, _heading.x) * (1.0 if slot == 0 else -1.0)
			goal += (apart.normalized() if apart.length() > 0.01 else side) * SPREAD
	var moved := _step(record, goal, pace * delta)
	record["pace"] = moved / delta
	record["stuck"] = 0.0 if moved > pace * delta * 0.3 else float(record["stuck"]) + delta


## Whether a monster is hindered: stunned, scared or slowed. Only then may a
## pet go for it.
func hindered(data: Dictionary) -> bool:
	return data["stun"] > 0.0 or data["shoo"] > 0.0 or data.get("slow", 0.0) > 0.0


## The hindered monster this pet can kill that is nearest to it, within reach
## of a short run and close to Oravitsa, or -1.
func _prey(record: Dictionary) -> int:
	var here := _here()
	var best := -1
	var best_distance := INF
	for id in world._active_animals:
		var data: Dictionary = world._animals[id]
		if data["kind"] not in world.MONSTERS or not data["alive"] or not hindered(data) or not can_kill(record, data["kind"]):
			continue
		var at: Vector2 = world.absolute_ground(data["position"])
		var distance: float = record["at"].distance_to(at)
		if distance > HUNT_RANGE or distance >= best_distance or here.distance_to(at) > HUNT_LEASH:
			continue
		if not _clear_floor(record["at"], at):
			var flow: Dictionary = world._cave.distances_to(world._cave.cell_at(_local(at)))
			if flow.get(world._cave.cell_at(_local(record["at"])), 999) * world._cave.CELL > HUNT_WALK:
				continue
		best = id
		best_distance = distance
	return best


## Underground a healthy follower runs at a hindered monster it can take and
## bites it; the bite kills it once it lands. Returns whether the pet is busy
## hunting or biting this frame (it does not follow her then).
func _hunt(record: Dictionary, delta: float) -> bool:
	record["cooldown"] = maxf(0.0, float(record["cooldown"]) - delta)
	record["attack"] = maxf(0.0, float(record["attack"]) - delta)
	if record["bite"] > 0.0:
		record["bite"] = float(record["bite"]) - delta
		record["pace"] = 0.0
		if record["bite"] <= 0.0:
			_land_bite(record)
		return true
	if afflicted(record) or record["cooldown"] > 0.0:
		record["prey"] = -1
		return false
	var prey := _prey(record)
	record["prey"] = prey
	if prey < 0:
		return false
	var data: Dictionary = world._animals[prey]
	var at: Vector2 = world.absolute_ground(data["position"])
	var kind: Dictionary = KINDS[record["kind"]]
	if record["at"].distance_to(at) <= kind["reach"] and _clear_floor(record["at"], at):
		start_bite(record, prey)
		return true
	if delta <= 0.0:
		return true
	var pace := maxf(float(kind["run"]), world._move_speed() / world.METRE)
	var flow := {}
	if not _clear_floor(record["at"], at):
		flow = world._cave.distances_to(world._cave.cell_at(_local(at)))
	var moved := _step(record, _way(record, at, flow), pace * delta)
	record["pace"] = moved / delta
	record["moving"] = true
	record["stuck"] = 0.0 if moved > pace * delta * 0.3 else float(record["stuck"]) + delta
	if record["stuck"] > STUCK:
		record["cooldown"] = kind["rest"] # Gives up on this one for a moment.
		record["stuck"] = 0.0
		record["prey"] = -1
	return true


## The pet bites: the monster is held still for the bite, which kills it.
func start_bite(record: Dictionary, id: int) -> void:
	var kind: Dictionary = KINDS[record["kind"]]
	var data: Dictionary = world._animals[id]
	var at: Vector2 = world.absolute_ground(data["position"])
	record["prey"] = id
	record["bite"] = kind["bite"]
	record["attack"] = kind["bite"] + 0.1
	record["pace"] = 0.0
	if record["at"].distance_to(at) > 0.01:
		record["facing"] = (at - record["at"]).normalized()
	data["held"] = float(kind["bite"]) + 0.1
	data["velocity"] = Vector2.ZERO


func _land_bite(record: Dictionary) -> void:
	var id: int = record["prey"]
	record["bite"] = 0.0
	record["prey"] = -1
	record["cooldown"] = KINDS[record["kind"]]["rest"]
	if id >= 0 and id < world._animals.size():
		world.pet_kill_monster(id, title(record))


## A bite that is cut short (the pet is bitten or leaves) releases its prey.
func _drop_bite(record: Dictionary) -> void:
	var id: int = record["prey"]
	if record["bite"] > 0.0 and id >= 0 and id < world._animals.size():
		world._animals[id]["held"] = 0.0
	record["bite"] = 0.0
	record["prey"] = -1


## An awake, unscared, unstunned rat, spider or goblin that reaches a follower
## bites it, on the same cooldown as its bites at Oravitsa: a spider poisons
## the pet, a rat or goblin wounds it. Kobolds never bite.
func _monster_bites() -> void:
	for id in world._active_animals:
		var data: Dictionary = world._animals[id]
		var kind: int = data["kind"]
		if kind not in [world.RAT, world.SPIDER, world.GOBLIN] or not data["alive"] or data["stun"] > 0.0 or data["shoo"] > 0.0:
			continue
		if data.get("bite_cooldown", 0.0) > 0.0 or data.get("attack_time", 0.0) > 0.0 or data.get("held", 0.0) > 0.0:
			continue
		var at: Vector2 = world.absolute_ground(data["position"])
		for record in followers():
			if record["at"].distance_to(at) > world.ANIMAL_RADIUS[kind] / world.METRE + RADIUS + 0.15:
				continue
			bitten(record, id)
			break


## Monster `id` bites a pet: poisoned by a spider, wounded by a rat or goblin.
func bitten(record: Dictionary, id: int) -> void:
	var data: Dictionary = world._animals[id]
	data["bite_cooldown"] = world.BITE_COOLDOWN
	data["attack_time"] = world.BITE_ATTACK
	data["velocity"] = Vector2.ZERO
	_drop_bite(record)
	record["attack"] = 0.0
	var harm := "poisoned" if data["kind"] == world.SPIDER else "wounded"
	var already: bool = record[harm]
	record[harm] = true
	if not already:
		var by: String = "goblin clubbed" if data["kind"] == world.GOBLIN else "%s bit" % world.ANIMAL_NAMES[data["kind"]].to_lower()
		world._show_notice("The %s the %s: it is %s until Oravitsa cures it" % [by, title(record), harm], 3.5)
		world._update_hud()


## Following pets within CURE_RANGE of her that are poisoned or wounded.
func afflicted_near() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var here := _here()
	for record in followers():
		if afflicted(record) and here.distance_to(record["at"]) <= CURE_RANGE:
			result.append(record)
	return result


## Cure heals the afflicted pets near her; returns what was healed, as
## phrases such as "the cat's poison".
func cure_near() -> Array[String]:
	var healed: Array[String] = []
	for record in afflicted_near():
		var harms := []
		if record["poisoned"]:
			harms.append("poison")
		if record["wounded"]:
			harms.append("wounds")
		healed.append("the %s's %s" % [title(record), " and ".join(PackedStringArray(harms))])
		record["poisoned"] = false
		record["wounded"] = false
	return healed


## Puts a follower on open ground just behind her (beside her for `beside`),
## each slot on its own side, or on her own spot if nothing else is free.
func place_behind(record: Dictionary, slot: int, beside: bool = false) -> void:
	_drop_bite(record)
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
	var slot := 0
	for record in followers():
		place_behind(record, slot, true)
		record["cooldown"] = 0.0
		slot += 1


## Whether the cave floor is open all along the straight line from `a` to `b`
## (absolute metres): no bite or straight walk goes through a wall.
func _clear_floor(a: Vector2, b: Vector2) -> bool:
	var cave: Node3D = world._cave
	var samples := maxi(1, ceili(a.distance_to(b) / 0.2))
	for i in samples + 1:
		if not cave.is_open(_local(a.lerp(b, float(i) / samples))):
			return false
	return true


## A pet at home strolls a little around it, with pauses.
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
	record["bite"] = 0.0
	record["prey"] = -1


## The followers for a save: hamlet block, kind, threshold and afflictions.
func save() -> Array:
	var result := []
	for record in followers():
		result.append({"hamlet": [record["hamlet"].x, record["hamlet"].y], "kind": record["kind"], "threshold": record["threshold"], "poisoned": record["poisoned"], "wounded": record["wounded"]})
	return result


## Restores the saved followers beside her (none for older saves). A pet whose
## hamlet no longer has it is dropped; every other pet is back at home.
func apply(saved: Array) -> void:
	for record in pets:
		_free_visual(record)
	pets.clear()
	var land: Node3D = world._surface_landscape if world.in_cave() else world.landscape
	for item in saved:
		if followers().size() >= MAX_FOLLOWERS:
			break
		var block := Vector2i(int(item["hamlet"][0]), int(item["hamlet"][1]))
		var hamlet: Dictionary = land.hamlet_at(block)
		if hamlet.is_empty():
			continue
		var spec := hamlet_pet(hamlet)
		if spec.is_empty() or spec["kind"] != item["kind"] or spec["threshold"] != int(item["threshold"]) or not find(block).is_empty():
			continue
		var record := _record(spec, "following", _here())
		record["poisoned"] = bool(item.get("poisoned", false))
		record["wounded"] = bool(item.get("wounded", false))
		pets.append(record)
	arrive()
	refresh()


func _free_visual(record: Dictionary) -> void:
	for field in ["node", "shadow", "label", "marker"]:
		if record.has(field) and is_instance_valid(record[field]):
			record[field].queue_free()
		record.erase(field)
	record.erase("animator")
	record.erase("rim")


static func _clip(animator: AnimationPlayer, clip: String) -> String:
	for full in animator.get_animation_list():
		if full == clip or full.ends_with("|" + clip):
			return full
	return ""


func _build_visual(record: Dictionary) -> void:
	var kind: Dictionary = KINDS[record["kind"]]
	var model: Node3D = load(CREATURES + record["kind"] + ".glb").instantiate()
	model.name = "Pet_%d_%d" % [record["hamlet"].x, record["hamlet"].y]
	_root.add_child(model)
	var bounds: AABB = world._model_bounds(model)
	model.scale = Vector3.ONE * float(kind["height"]) / maxf(bounds.size.y, 0.0001)
	var animator: AnimationPlayer = world._find_animator(model)
	if animator != null:
		for clip in ["Idle", "Walk", "Gallop"]:
			var full := _clip(animator, clip)
			if not full.is_empty():
				animator.get_animation(full).loop_mode = Animation.LOOP_LINEAR
		animator.play(_clip(animator, "Idle"))
		record["animator"] = animator
	record["node"] = model
	var shadow: MeshInstance3D = world._contact_shadow(float(kind["height"]) * 0.7)
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
	var marker := Node3D.new()
	marker.set_script(STATUS_MARKER)
	marker.name = "PetStatus"
	marker.visible = false
	_root.add_child(marker)
	record["marker"] = marker


func _ground(at: Vector2) -> Vector3:
	var p := _local(at)
	return Vector3(p.x, world.landscape.height_at(p), p.y)


## The status icons over a pet: poisoned and/or wounded, untimed.
func status(record: Dictionary) -> Array:
	var states := []
	if record["poisoned"]:
		states.append(["poisoned", -1.0])
	if record["wounded"]:
		states.append(["wounded", -1.0])
	return states


## Places, turns and animates the pets near her; underground only her
## followers are there. Hamlet pets show their aura threshold close by.
func sync(_delta: float) -> void:
	var here := _here()
	var underground: bool = world.in_cave()
	for record in pets:
		var shown: bool = record["state"] == "following" if underground else here.distance_to(record["at"]) <= SHOWN
		if not shown:
			_free_visual(record)
			continue
		if not record.has("node"):
			_build_visual(record)
		var kind: Dictionary = KINDS[record["kind"]]
		var node: Node3D = record["node"]
		if record.get("rim", false) != underground:
			# Underground a warm rim keeps dark pets readable (#102).
			world.set_rim(node, world.RIM_PET if underground else Color.TRANSPARENT)
			record["rim"] = underground
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
		label.position = node.position + Vector3.UP * (float(kind["height"]) + 0.35)
		var marker: Node3D = record["marker"]
		marker.show_states(status(record))
		marker.set_on_top(true)
		marker.position = node.position + Vector3.UP * (float(kind["height"]) + 0.45)
		if record.has("animator"):
			var animator: AnimationPlayer = record["animator"]
			var clips: Dictionary = kind["clips"]
			var wanted := "Idle"
			var rate := 1.0
			var pace: float = record["pace"]
			var full := ""
			if record["attack"] > 0.0:
				full = _clip(animator, clips["bite"])
				if not full.is_empty():
					rate = clampf(animator.get_animation(full).length / (float(kind["bite"]) + 0.1), 0.8, 4.0)
			elif pace > 2.6:
				wanted = clips["run"]
				rate = clampf(pace / float(clips["run_pace"]), 0.7, 2.5)
			elif pace > 0.1:
				wanted = "Walk"
				rate = clampf(pace / float(clips["walk_pace"]), 0.5, 2.5)
			if full.is_empty():
				full = _clip(animator, wanted)
			if not full.is_empty() and animator.current_animation != full:
				animator.play(full, 0.12)
			animator.speed_scale = rate
