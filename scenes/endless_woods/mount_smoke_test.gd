extends SceneTree

## Hamlet mounts (#67): donkeys, mules and horses ridden through aura.


func _initialize() -> void:
	call_deferred("_run")


func _travel(world: Node2D, absolute: Vector2) -> void:
	world.player_position = world.from_ground(absolute - world.landscape.origin)
	world._rebase_if_needed()
	world.view.position = world.to_world(world.player_position) + world.CAMERA_OFFSET
	world._refresh_visible()
	world.mounts.refresh()
	world._sync_presentation(0.0)
	await process_frame


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


func _y() -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_Y
	event.pressed = true
	return event


## The live record of a hamlet's mount, or {}.
func _live(world: Node2D, spec: Dictionary) -> Dictionary:
	return world.mounts.find(spec["hamlet"], spec["index"])


func _count(world: Node2D, spec: Dictionary) -> int:
	var count := 0
	for record in world.mounts.mounts:
		count += 1 if record["hamlet"] == spec["hamlet"] and record["index"] == spec["index"] else 0
	return count


## Walks up to a hamlet's mount and gets on it with plenty of aura.
func _ride(world: Node2D, spec: Dictionary) -> void:
	await _travel(world, spec["tether"])
	world.aura = 100
	world.player_stun = 0.0
	world.player_fright = 0.0
	world.mounts.toggle()
	assert(world.mounts.riding() and world.mounts.ridden_kind() == spec["kind"], "She rides the %s" % spec["kind"])


func _run() -> void:
	var world = load("res://scenes/endless_woods/woods.tscn").instantiate()
	world.save_path = "user://mount_smoke_save.json"
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	await process_frame
	var land: Node3D = world.landscape
	var mounts: Node = world.mounts
	world.fright_chance = 0.0
	# Seeding: one or two mounts per hamlet beside its store tent, donkeys
	# most common, then mules, then horses.
	# Protects: hamlets with no mount or crowds of them, missing kinds, mounts
	# on solid ground or blocking the chieftain's post.
	var found := {}
	var tally := {"donkey": 0, "mule": 0, "horse": 0}
	var hamlets := 0
	for by in range(-6, 7):
		for bx in range(-6, 7):
			var hamlet: Dictionary = land.hamlet_at(Vector2i(bx, by))
			if hamlet.is_empty():
				continue
			hamlets += 1
			var specs: Array[Dictionary] = mounts.hamlet_mounts(hamlet)
			assert(specs.size() >= 1 and specs.size() <= 2, "One or two mounts per hamlet")
			assert(mounts.hamlet_mounts(hamlet) == specs, "Seeded identically")
			var post: Vector2 = hamlet["store"] + Vector2(0, land.STORE_HALF + 0.9)
			for spec in specs:
				tally[spec["kind"]] += 1
				assert(land.can_walk(spec["tether"] - land.origin, mounts.RADIUS), "Tethered on open ground")
				assert(spec["tether"].distance_to(post) > 1.5 and spec["tether"].distance_to(hamlet["store"]) < 5.0, "Beside the store tent, clear of the chieftain")
				if not found.has(spec["kind"]):
					found[spec["kind"]] = spec
	assert(hamlets > 20 and found.size() == 3)
	assert(tally["donkey"] > tally["mule"] and tally["mule"] > tally["horse"] and tally["horse"] > 0, "Donkeys most common, horses rarest: %s" % tally)
	# Revisits: the hamlet shows the same mounts, drawn with Idle/Walk/Gallop/Eating.
	# Protects: mounts that change, vanish or multiply when she comes back.
	var donkey: Dictionary = found["donkey"]
	var home: Dictionary = land.hamlet_at(donkey["hamlet"])
	await _travel(world, home["center"] + Vector2(0, 8))
	var first := []
	for spec in mounts.hamlet_mounts(home):
		var record := _live(world, spec)
		assert(record["state"] == "tethered" and record["at"] == spec["tether"] and record.has("node"))
		assert(record["animator"].has_animation("Gallop") and record["animator"].has_animation("Eating"))
		first.append([record["kind"], record["at"]])
	await _travel(world, home["center"] + Vector2(3000, 0))
	assert(_live(world, donkey).is_empty(), "Tethered mounts leave with their hamlet")
	await _travel(world, home["center"] + Vector2(0, 8))
	var again := []
	for spec in mounts.hamlet_mounts(home):
		assert(_count(world, spec) == 1)
		again.append([_live(world, spec)["kind"], _live(world, spec)["at"]])
	assert(again == first, "The same mounts return on revisit")
	assert(mounts.KINDS["mule"]["height"] > mounts.KINDS["donkey"]["height"], "A mule is a larger donkey")
	# The prompt states the requirement; too little aura cannot mount, by
	# key, controller or button.
	# Protects: riding below the requirement and an unexplained refusal.
	await _travel(world, donkey["tether"] + donkey["facing"] * 1.2)
	world.aura = 3
	world._input_mode = "keyboard"
	world._update_hud()
	assert(world._mount_button.visible and world._mount_button.disabled, "The button shows, disabled")
	assert(world._mount_button.text == "The donkey needs 15 aura (you have 3)", world._mount_button.text)
	world._unhandled_key_input(_key(KEY_T))
	world._unhandled_input(_y())
	world._mount_button.pressed.emit()
	assert(not mounts.riding() and "needs 15 aura" in world._notice_label.text)
	# T mounts and dismounts.
	# Protects: a key that does nothing, a rider left at ground level, and a
	# mount that walks off when she gets off at its tether.
	world.aura = 15
	world._update_hud()
	assert(world._mount_button.text == "Ride the donkey [T]" and not world._mount_button.disabled)
	world._unhandled_key_input(_key(KEY_T))
	assert(mounts.riding() and _live(world, donkey)["state"] == "ridden" and "rides the donkey" in world._notice_label.text)
	world._sync_presentation(0.0)
	var feet: Vector3 = world.to_world(world.player_position)
	assert(world.heroine.position.y > feet.y + 0.1, "She sits up on the mount")
	assert(_live(world, donkey)["node"].position.distance_to(feet) < 0.05, "The mount is under her")
	world._update_hud()
	assert(world._mount_button.text == "Get off the donkey [T]")
	world._unhandled_key_input(_key(KEY_T))
	assert(not mounts.riding() and _live(world, donkey)["state"] == "tethered" and "gets off" in world._notice_label.text)
	world._sync_presentation(0.0)
	assert(world.heroine.position.y < world.to_world(world.player_position).y + 0.1, "Back on her feet")
	# Controller Y and the touch button do the same.
	world._input_mode = "controller"
	world._update_hud()
	assert(world._mount_button.text == "Ride the donkey [Y]" and "Y: ride" in world._hint_label.text)
	world._unhandled_input(_y())
	assert(mounts.riding())
	world._unhandled_input(_y())
	assert(not mounts.riding())
	world._input_mode = "touch"
	world._update_hud()
	assert(world._mount_button.text == "Ride the donkey" and "Tap Ride" in world._hint_label.text)
	world._mount_button.pressed.emit()
	assert(mounts.riding())
	world._mount_button.pressed.emit()
	assert(not mounts.riding())
	world._input_mode = "keyboard"
	world._update_hud()
	assert("T: ride" in world._hint_label.text)
	# Speed: each kind multiplies her fed speed; no sprint while riding.
	# Protects: wrong multipliers, sprint stacking on a mount, and riding
	# that ignores hunger.
	world.fed = 50.0
	var walking: float = world._move_speed()
	for kind in ["donkey", "mule", "horse"]:
		await _ride(world, found[kind])
		world.fed = 50.0
		assert(is_equal_approx(world._move_speed(), walking * mounts.KINDS[kind]["speed"]), kind)
		world.fed = world.FED_MAX
		assert(is_equal_approx(world._move_speed(), world.SPEED * world.FULL_SPEED * mounts.KINDS[kind]["speed"]))
		Input.action_press("move_right")
		Input.action_press("sprint")
		world._update_player(0.1)
		assert(not world.sprinting and not world._sprint_wanted, "No sprint while riding")
		Input.action_release("sprint")
		Input.action_release("move_right")
		world._update_player(0.1)
		mounts.toggle()
	assert(mounts.KINDS["donkey"]["speed"] < mounts.KINDS["mule"]["speed"] and mounts.KINDS["mule"]["speed"] < mounts.KINDS["horse"]["speed"])
	assert(mounts.KINDS["donkey"]["aura"] == 15 and mounts.KINDS["mule"]["aura"] == 35 and mounts.KINDS["horse"]["aura"] == 70)
	# Stuns while riding: a donkey halves them, a mule changes nothing, a
	# horse throws her off (it then waits there); panic makes her slip off.
	# Protects: unhalved donkey stuns, a horse that keeps her after a bump,
	# and panic carried out on horseback.
	world.fed = 0.0 # Full-length stuns.
	await _ride(world, found["donkey"])
	world.fed = 0.0
	world._stun_player(1.2, world.player_position + Vector2(50, 0))
	assert(is_equal_approx(world.player_stun, 0.6) and mounts.riding(), "A donkey halves the stun")
	world.player_stun = 0.0
	mounts.toggle()
	await _ride(world, found["mule"])
	world.fed = 0.0
	world._stun_player(1.2, world.player_position + Vector2(50, 0))
	assert(is_equal_approx(world.player_stun, 1.2) and mounts.riding(), "A mule is sure-footed")
	world.player_stun = 0.0
	world.fright_chance = 1.0
	world._stun_player(1.2, world.player_position + Vector2(50, 0))
	assert(world.player_fright > 0.0 and not mounts.riding() and _live(world, found["mule"])["state"] != "ridden", "Panic dismounts her first")
	world.fright_chance = 0.0
	world.player_fright = 0.0
	# A real bump on horseback, among the wildlife near the start.
	await _ride(world, found["horse"])
	await _travel(world, Vector2(2, 3))
	assert(mounts.riding(), "The ride travels with her")
	var wild := -1
	for id in world._active_animals:
		if world._animals[id]["alive"] and world._animals[id]["kind"] != world.VILLAGER:
			wild = id
	assert(wild >= 0)
	world._animals[wild]["stun"] = 0.0
	world._animals[wild]["position"] = world.player_position + Vector2(48, 0)
	var thrown_at: Vector2 = world.absolute_ground(world.player_position)
	assert(not world._try_move(Vector2(10, 0)) and world.player_stun > 0.0, "The bump stuns her")
	assert(not mounts.riding() and "threw Oravitsa off" in world._notice_label.text, "A horse throws her off on a bump")
	var horse := _live(world, found["horse"])
	assert(horse["state"] == "waiting" and horse["at"].distance_to(thrown_at) < 0.01, "The horse waits where it threw her")
	world.player_stun = 0.0
	world._animals[wild]["position"] += Vector2(0, 2000)
	# Aura falling below the requirement (decay #64) dismounts her at once;
	# the mount stays where she got off, then walks home by itself.
	# Protects: riding on without the aura, a mount that vanishes or jumps
	# home, and one that never goes home.
	world.aura = 70
	await _travel(world, horse["at"] + Vector2(0, 1.0))
	mounts.toggle()
	assert(mounts.riding() and mounts.ridden_kind() == "horse")
	var off_at: Vector2 = world.absolute_ground(world.player_position)
	world._aura_decay = world.AURA_DECAY_SECONDS - 0.1
	world._update_aura_decay(0.2)
	assert(world.aura == 69)
	mounts.update(0.0)
	assert(not mounts.riding() and "no longer trusts" in world._notice_label.text)
	assert(horse["state"] == "returning" and horse["at"].distance_to(off_at) < 0.01, "It stays where she got off")
	var horse_home: Vector2 = horse["tether"]
	# Far from its hamlet it reaches home out of her sight; check the walk on the way.
	var before: float = horse["at"].distance_to(horse_home)
	for step in 30:
		mounts.update(0.1)
	assert(horse["state"] == "tethered" or horse["at"].distance_to(horse_home) < before, "It walks home")
	await _travel(world, horse_home + Vector2(4, 4))
	for step in 400:
		mounts.update(0.1)
	assert(horse["state"] == "tethered" and horse["at"] == horse_home, "Back at its tether")
	# Near home, it visibly walks the last part.
	world.aura = 70
	await _travel(world, horse_home)
	mounts.toggle()
	await _travel(world, horse_home + Vector2(6, 6))
	assert(mounts.riding())
	world.aura = 10
	mounts.update(0.0)
	var left_at: Vector2 = horse["at"]
	mounts.update(0.5)
	world._sync_presentation(0.0)
	assert(horse["state"] == "returning" and horse["at"].distance_to(horse_home) < left_at.distance_to(horse_home) and horse["animator"].current_animation == "Walk")
	for step in 200:
		mounts.update(0.1)
	assert(horse["state"] == "tethered")
	# Cave mouths: she gets off just outside; the mount waits there, hidden
	# while she is underground and still there when she comes out.
	# Protects: mounts going underground and mounts lost at a cave.
	var cave: Dictionary = {}
	for rz in range(-6, 7):
		for rx in range(-4, 5):
			if cave.is_empty():
				cave = land.cave_at(Vector2i(rx, rz))
	assert(not cave.is_empty())
	await _ride(world, found["donkey"])
	await _travel(world, cave["mouth"] + cave["facing"] * 4.0)
	assert(mounts.riding())
	await _travel(world, cave["mouth"] + cave["facing"] * 1.2)
	world._cave_armed = true
	world._check_cave_mouth()
	assert(not world.in_cave() and not mounts.riding() and "waits outside" in world._notice_label.text, "A mount never enters a cave")
	var waiting := _live(world, found["donkey"])
	var wait_at: Vector2 = waiting["at"]
	assert(waiting["state"] == "waiting" and wait_at.distance_to(cave["mouth"]) > world.CAVE_REARM)
	await _travel(world, cave["mouth"])
	world._cave_armed = true
	world._check_cave_mouth()
	assert(world.in_cave())
	world._sync_presentation(0.0)
	assert(not mounts._root.visible and mounts.nearest().is_empty(), "No mounts underground")
	for step in 30:
		world._process_cave(0.1)
	var underground: Dictionary = world.save_state()
	assert(world.SAVE_GAME.validate(underground) == "" and underground["mounts"].size() >= 1)
	world._exit_cave()
	world._sync_presentation(0.0)
	assert(mounts._root.visible and waiting["state"] == "waiting" and waiting["at"] == wait_at, "Still waiting outside")
	assert(mounts.nearest() == waiting, "And close enough to ride from the way out")
	# Rebasing and streaming keep a waiting mount at its absolute spot, and
	# its hamlet never shows a second copy.
	# Protects: mounts drifting with the floating origin, and duplicates.
	var origin_before: Vector2i = world.origin_cells
	await _travel(world, cave["mouth"] + Vector2(2600, 1900))
	assert(world.origin_cells != origin_before, "The origin rebased")
	await _travel(world, cave["mouth"] + cave["facing"] * 2.2)
	assert(waiting["at"] == wait_at and _count(world, found["donkey"]) == 1)
	assert(waiting["node"].position.distance_to(mounts._ground(wait_at)) < 0.001, "Drawn at the same absolute spot")
	await _travel(world, home["center"] + Vector2(0, 8))
	assert(_count(world, found["donkey"]) == 1 and _live(world, found["donkey"])["state"] == "waiting", "No duplicate at its hamlet")
	# Saving and loading: a waiting mount and a ride come back; older saves
	# load with no mount; bad mount records are rejected.
	# Protects: lost or duplicated mounts after loading, a lost ride, and old
	# saves that no longer load.
	var with_waiting: Dictionary = world.save_state()
	assert(world.SAVE_GAME.validate(with_waiting) == "")
	await _ride(world, found["mule"])
	await _travel(world, home["center"] + Vector2(40, 30))
	var ride_at: Vector2 = world.absolute_ground(world.player_position)
	var riding_state: Dictionary = world.save_state()
	assert(world.SAVE_GAME.validate(riding_state) == "")
	mounts.toggle()
	await _travel(world, home["center"] + Vector2(900, 0))
	world.apply_state(riding_state)
	assert(mounts.riding() and mounts.ridden_kind() == "mule", "Loading restores the ride")
	assert(world.absolute_ground(world.player_position).distance_to(ride_at) < 0.01)
	assert(_live(world, found["donkey"])["at"] == wait_at, "And the donkey still waits at the cave")
	world._sync_presentation(0.0)
	assert(world.heroine.position.y > world.to_world(world.player_position).y + 0.1)
	world.apply_state(with_waiting)
	assert(not mounts.riding() and _live(world, found["donkey"])["state"] == "waiting" and _live(world, found["donkey"])["at"] == wait_at)
	assert(_live(world, found["mule"]).get("state", "tethered") == "tethered", "The mule was at home in that save")
	var old: Dictionary = riding_state.duplicate(true)
	old.erase("mounts")
	assert(world.SAVE_GAME.validate(old) == "", "Saves from before mounts remain valid")
	world.apply_state(old)
	assert(not mounts.riding() and _live(world, found["donkey"])["state"] == "tethered", "Older saves load with every mount at home")
	for record in mounts.mounts:
		assert(record["state"] == "tethered")
	for broken in [{"kind": "unicorn"}, {"state": "flying"}, {"at": [1, "x"]}, {"index": 9}, {"hamlet": [1]}]:
		var bad: Dictionary = riding_state.duplicate(true)
		bad["mounts"][0].merge(broken, true)
		assert(world.SAVE_GAME.validate(bad) != "", "Rejects %s" % broken)
	var two: Dictionary = riding_state.duplicate(true)
	for record in riding_state["mounts"]:
		if record["state"] == "ridden":
			var copy: Dictionary = record.duplicate(true)
			copy["index"] = 1 - int(copy["index"])
			two["mounts"].append(copy)
	assert(world.SAVE_GAME.validate(two) != "", "At most one ride")
	# Mounts are never wildlife: no sling or shoo target, nothing to harm.
	for data in world._animals:
		assert(not data.has("tether"))
	# Protects: a ridden horse that pushes its head into a tree, and a mount
	# walking home into a creature or unable to step away from one (#103).
	if mounts.riding():
		mounts.toggle()
	await _ride(world, found["horse"])
	var woods: Node3D = world.landscape
	var start: Vector2 = world.absolute_ground(world.player_position)
	var trunk := Vector2.INF
	var approach := Vector2.ZERO
	var key := Vector2i(floori(start.x / woods.CHUNK), floori(start.y / woods.CHUNK))
	for z in range(key.y - 2, key.y + 3):
		for x in range(key.x - 2, key.x + 3):
			for tree in woods._ensure_nature(Vector2i(x, z))["trees"]:
				var t := Vector2(tree.x, tree.y)
				for angle in 8:
					var dir := Vector2.from_angle(angle * TAU / 8.0)
					var clear := true
					for d in [1.3, 1.8, 2.4, 3.0]:
						clear = clear and woods.can_walk(t + dir * d - woods.origin, 0.6)
					if clear and trunk == Vector2.INF:
						trunk = t
						approach = dir
	assert(trunk != Vector2.INF, "A tree with open ground before it")
	await _travel(world, trunk + approach * 3.0)
	assert(mounts.riding())
	for i in 60:
		world._try_move(-approach * 6.0)
	var rider: Vector2 = world.absolute_ground(world.player_position)
	assert(rider.distance_to(trunk) < 2.5, "She rode up to the tree (%.2f m)" % rider.distance_to(trunk))
	assert(woods.can_walk(rider - approach * mounts.nose("horse") - woods.origin, mounts.NOSE_RADIUS), "The horse's nose stays out of the tree")
	var ridden_horse := _live(world, found["horse"])
	var beast := -1
	for id in world._animals.size():
		if world._animals[id]["alive"] and world._animals[id]["kind"] != world.VILLAGER:
			beast = id
	assert(beast >= 0)
	world._animals[beast]["position"] = world.player_position + Vector2(300, 0)
	world._refresh_visible()
	assert(world._active_animals.has(beast), "A creature is near")
	var beast_at: Vector2 = world.absolute_ground(world._animals[beast]["position"])
	var goal: Vector2 = beast_at + Vector2(10, 0)
	assert(not mounts._fits(ridden_horse, beast_at + Vector2(0.3, 0), beast_at + Vector2(5, 0), goal) or not woods.can_walk(beast_at + Vector2(0.3, 0) - woods.origin, mounts.RADIUS), "A mount never walks into a creature")
	assert(world.clear_of_creatures(beast_at + Vector2(0.4, 0), beast_at + Vector2(0.3, 0), mounts.RADIUS) and not world.clear_of_creatures(beast_at + Vector2(0.2, 0), beast_at + Vector2(0.3, 0), mounts.RADIUS), "Inside one, it may step away but never further in")
	# Protects: a mount walking home that stays stuck in a pocket in her sight,
	# or jumps home instead of walking out and around (#104). A U of walls
	# opens away from its tether, so walking straight at it never gets out.
	if mounts.riding():
		mounts.toggle()
	var donkey_spec: Dictionary = found["donkey"]
	var tether: Vector2 = donkey_spec["tether"]
	var pocket := Vector2.INF
	for offset in [Vector2(-8, 0), Vector2(8, 0), Vector2(0, -8), Vector2(0, 8), Vector2(-10, 0), Vector2(10, 0)]:
		var ok := true
		for t in 9:
			var probe: Vector2 = tether + offset * (0.2 + 0.1 * t)
			for side in [-4.0, 0.0, 4.0]:
				ok = ok and woods.can_walk(probe + offset.orthogonal().normalized() * side - woods.origin, mounts.RADIUS) and not woods.is_water(probe - woods.origin, 1.0)
		if ok and pocket == Vector2.INF:
			pocket = tether + offset
	assert(pocket != Vector2.INF, "Open ground beside the tether for the pocket")
	var toward: Vector2 = pocket.direction_to(tether)
	var across: Vector2 = toward.orthogonal()
	var added: Array[Rect2] = []
	for piece in [[toward * 2.0, across * 6.0 + toward * 0.4], [toward * 0.2 + across * 3.0, toward * 4.4 + across * 0.4], [toward * 0.2 - across * 3.0, toward * 4.4 + across * 0.4]]:
		var a: Vector2 = pocket + piece[0] - piece[1] * 0.5
		added.append(Rect2(a, Vector2.ZERO).expand(a + piece[1]).abs())
	for wall in added:
		woods.walls.append(wall)
	await _travel(world, pocket.lerp(tether, 0.5) + across * 6.0)
	var walker := _live(world, donkey_spec)
	walker["state"] = "returning"
	walker["at"] = pocket
	walker["stuck"] = 0.0
	walker["route"] = PackedVector2Array()
	var largest := 0.0
	for i in 900:
		var was: Vector2 = walker["at"]
		mounts.update(0.1)
		if walker["state"] == "tethered":
			break
		largest = maxf(largest, was.distance_to(walker["at"]))
	for wall in added:
		woods.walls.erase(wall)
	assert(walker["state"] == "tethered", "It got out of the pocket and home")
	assert(largest < 0.5, "It walked all the way (largest step %.2f m)" % largest)
	print("Mount smoke test passed: ", hamlets, " hamlets seeded with ", tally, ", identical revisits, aura requirement prompt and refusal, T / controller Y / touch button, speed x1.3/1.5/1.8 without sprint, donkey-halved stuns, horse throws on a real bump, panic dismount, aura decay dismount with the mount walking home, cave mouth wait (hidden underground, still there after), rebasing without drift or duplicates, save/load of a ride and a waiting mount, older saves and invalid records")
	quit()
