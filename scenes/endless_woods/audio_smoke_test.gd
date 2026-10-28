extends SceneTree

## Ambience loops and nearby, bounded animal calls (#23). Headless checks cover
## wiring and limits only; listening quality needs real playback.

const SETTINGS := "user://settings.cfg"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var had_settings := FileAccess.file_exists(SETTINGS)
	var previous := FileAccess.get_file_as_string(SETTINGS) if had_settings else ""
	if had_settings:
		DirAccess.remove_absolute(SETTINGS)
	var world = load("res://scenes/endless_woods/woods.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	await process_frame
	var audio = world.audio
	assert(audio != null and audio._ambience.size() == 2)
	var players: Array = audio._ambience.duplicate()
	assert(audio.ambience_started)
	for player in players:
		assert(player.bus == "Ambience" and player.stream != null)
		assert(player.playing != audio.silent, "Ambience plays wherever audio is audible")
		assert(player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Ambience must loop seamlessly")
	assert(players[0].stream.get_length() != players[1].stream.get_length(), "Layers with different periods vary the mix")
	assert(audio.listener.is_current())
	# Six animals right beside Oravitsa: at most two calls at once, spaced out.
	for sprite in world._active_animals.values():
		sprite.queue_free()
	world._active_animals.clear()
	world._sync_animal_lifecycle()
	world._animals.clear()
	for kind in [world.WOLF, world.LYNX, world.BOAR, world.DEER, world.FOX, world.HARE]:
		world._add_animal(kind, world.START + Vector2i(4, 0))
	world._add_animal(world.WOLF, world.START + Vector2i(4, 0))
	world._animals[6]["position"] = world.player_position + Vector2(world.METRE * 20, 0)
	world._refresh_visible()
	assert(world._active_animals.has(6), "The far wolf is simulated but out of earshot")
	world._sync_presentation(0.0)
	for data in world._animals:
		data["call_timer"] = 0.0
	audio.update(0.016)
	assert(audio.active_calls() == 1, "Calls are spaced by a minimum gap")
	audio._gap = 0.0
	for data in world._animals:
		data["call_timer"] = 0.0
	audio.update(0.016)
	assert(audio.active_calls() == audio.MAX_CALLS)
	audio._gap = 0.0
	for data in world._animals:
		data["call_timer"] = 0.0
	audio.update(0.016)
	assert(audio.active_calls() == audio.MAX_CALLS, "Crowds never exceed the voice limit")
	assert(6 not in audio._voice_owner, "Distant animals stay silent")
	assert(not audio.call_now(6))
	for data in world._animals:
		assert(data["call_timer"] > 5.0, "Each animal waits a while before calling again")
	# Voices follow their animal across a floating-origin rebase, and the
	# ambience keeps playing on the same players.
	var owner: int = audio._voice_owner[0]
	world._shift_origin(Vector2i(512, 0))
	world._sync_presentation(0.0)
	var voice: AudioStreamPlayer3D = audio._voices[0]
	assert(voice.global_position.distance_to(world.to_world(world._animals[owner]["position"]) + Vector3.UP * 0.5) < 0.01)
	assert(audio.listener.global_position.distance_to(world.heroine.global_position + Vector3.UP * 1.2) < 0.01)
	assert(audio._ambience == players and audio.ambience_started, "Rebasing must not recreate the ambience")
	# A call stops when its animal despawns or leaves the active area.
	world._animals[owner]["alive"] = false
	world._sync_presentation(0.0)
	assert(owner not in audio._voice_owner)
	# A finished call frees its voice.
	var busy: int = audio.active_calls()
	audio.update(3.0)
	assert(audio.active_calls() < busy or busy == 0, "Calls end after their clip length")
	world._animals[owner]["alive"] = true
	# Volume and mute controls cycle 100/60/30/Off and persist.
	assert(audio.level_text(audio.animal_level) == "100%")
	for step in 3:
		audio.cycle_animals()
	assert(audio.level_text(audio.animal_level) == "Off" and AudioServer.is_bus_mute(AudioServer.get_bus_index("Animals")))
	audio.release_voices()
	audio._gap = 0.0
	assert(not audio.call_now(0), "Muted animal sounds start no calls")
	audio.cycle_animals()
	assert(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Animals")))
	audio.cycle_ambience()
	assert(audio.level_text(audio.ambience_level) == "60%")
	assert(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambience")), linear_to_db(0.6)))
	var config := ConfigFile.new()
	assert(config.load(SETTINGS) == OK and config.get_value("audio", "ambience") == 1)
	world._toggle_instructions()
	assert(world._ambience_button.visible and "60%" in world._ambience_button.text)
	var key := InputEventKey.new()
	key.keycode = KEY_9
	key.pressed = true
	world._unhandled_key_input(key)
	assert(audio.level_text(audio.ambience_level) == "30%" and "30%" in world._ambience_button.text)
	# An angry animal calls immediately as part of its warning.
	audio.release_voices()
	audio._gap = 0.0
	var wolf: Dictionary = world._animals[0]
	wolf["position"] = world.player_position + Vector2(180, 0)
	wolf["aggro_rolls"] = 0
	for rolls in 200:
		if world._hash(0, rolls + 1, 1701) < world.AGGRO_CHANCE:
			wolf["aggro_rolls"] = rolls
			break
	wolf["provoke"] = world.AGGRO_DWELL
	world._update_aggression(0.01)
	assert(wolf["aggro"] == world.AGGRO_WARN and 0 in audio._voice_owner, "The warning is audible")
	DirAccess.remove_absolute(SETTINGS)
	if had_settings:
		var restore := FileAccess.open(SETTINGS, FileAccess.WRITE)
		restore.store_string(previous)
		restore.close()
	print("Audio smoke test passed: two looping ambience layers, listener on Oravitsa, spaced calls, two-voice limit, earshot limit, call intervals, voices follow rebases, ambience survives rebases, despawn stops calls, 100/60/30/Off levels and mute persist, warning call")
	quit()
