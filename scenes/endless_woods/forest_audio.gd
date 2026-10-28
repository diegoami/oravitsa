extends Node

## Quiet looping forest ambience plus occasional, distance-attenuated animal
## calls near Oravitsa. Audio only observes the simulation: streaming, despawns
## and origin rebases move or stop voices but never restart the ambience.
const AUDIO := "res://scenes/endless_woods/audio/"
const SETTINGS_PATH := "user://settings.cfg"
const AUDIBLE := 14.0 # metres from Oravitsa; farther animals stay silent.
const MAX_CALLS := 2
const MIN_GAP := 1.2
const LEVELS := [1.0, 0.6, 0.3, 0.0]
const AMBIENCE := {"ambience_wind": -15.0, "ambience_birds": -19.0}
var forest: Node2D
var listener: AudioListener3D
var ambience_level := 0
var animal_level := 0
var calls_played := 0
var _ambience: Array[AudioStreamPlayer] = []
var _voices: Array[AudioStreamPlayer3D] = []
var _voice_owner: Array[int] = []
var _voice_left: Array[float] = []
# Headless runs use the silent Dummy driver, which can still hold playbacks at
# exit. Nothing is audible there, so the same logic runs without playback.
var silent := AudioServer.get_driver_name() == "Dummy"
var ambience_started := false
var _calls: Dictionary = {}
var _volume: Dictionary = {}
var _interval: Dictionary = {}
var _gap := 0.0


func setup(owner_forest: Node2D) -> void:
	forest = owner_forest
	name = "ForestAudio"
	_calls = {forest.WOLF: "wolf_howl", forest.LYNX: "lynx_growl", forest.BOAR: "boar_grunt", forest.DEER: "deer_bark", forest.FOX: "fox_yip", forest.HARE: "hare_thump"}
	_volume = {forest.WOLF: -5.0, forest.LYNX: -6.0, forest.BOAR: -6.0, forest.DEER: -8.0, forest.FOX: -8.0, forest.HARE: -12.0}
	# Seconds between one animal's calls; rare predators call least often.
	_interval = {forest.WOLF: Vector2(28, 55), forest.LYNX: Vector2(30, 60), forest.BOAR: Vector2(12, 26), forest.DEER: Vector2(18, 40), forest.FOX: Vector2(15, 35), forest.HARE: Vector2(20, 45)}
	for bus in ["Ambience", "Animals"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	_load_settings()
	for sound in AMBIENCE:
		# Looping is set in the .import files (forward, whole file).
		var stream: AudioStreamWAV = load(AUDIO + sound + ".wav")
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.bus = "Ambience"
		player.volume_db = AMBIENCE[sound]
		add_child(player)
		if not silent:
			player.play()
		_ambience.append(player)
	ambience_started = true
	listener = AudioListener3D.new()
	listener.name = "OravitsaEars"
	forest.stage.add_child(listener)
	listener.make_current()
	for i in MAX_CALLS:
		var voice := AudioStreamPlayer3D.new()
		voice.bus = "Animals"
		voice.unit_size = 4.0
		voice.max_distance = AUDIBLE
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		voice.panning_strength = 0.6
		voice.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		forest.stage.add_child(voice)
		_voices.append(voice)
		_voice_owner.append(-1)
		_voice_left.append(0.0)
	_apply_levels()


func _exit_tree() -> void:
	# Release playbacks before shutdown, or the engine reports streams in use.
	for player in _ambience:
		player.stop()
		player.stream = null
	for voice in _voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null


func first_delay(kind: int, id: int) -> float:
	var limits: Vector2 = _interval.get(kind, Vector2(20, 40))
	return lerpf(limits.x * 0.3, limits.y, forest._hash(id, 0, 1901))


func update(delta: float) -> void:
	# Ears sit on Oravitsa, oriented like the fixed camera so panning matches
	# the screen. Both follow rebases because they derive from local positions.
	listener.global_position = forest.heroine.global_position + Vector3.UP * 1.2
	listener.global_basis = forest.view.global_basis
	for i in _voices.size():
		var id := _voice_owner[i]
		if id < 0:
			continue
		_voice_left[i] -= delta
		if _voice_left[i] <= 0 or id >= forest._animals.size() or not forest._animals[id]["alive"] or not forest._active_animals.has(id):
			_voices[i].stop()
			_voice_owner[i] = -1
		else:
			_voices[i].global_position = forest.to_world(forest._animals[id]["position"]) + Vector3.UP * 0.5
	_gap = maxf(0.0, _gap - delta)
	for id in forest._active_animals:
		var data: Dictionary = forest._animals[id]
		data["call_timer"] = float(data.get("call_timer", first_delay(data["kind"], id))) - delta
		if data["call_timer"] > 0:
			continue
		var limits: Vector2 = _interval.get(data["kind"], Vector2(20, 40))
		data["call_timer"] = lerpf(limits.x, limits.y, forest._hash(id, calls_played + int(data["kind"]), 1902))
		if data["stun"] <= 0:
			call_now(id)


func audible(id: int) -> bool:
	var data: Dictionary = forest._animals[id]
	return data["alive"] and forest.to_ground(data["position"]).distance_to(forest.to_ground(forest.player_position)) <= AUDIBLE


## Plays one call for an animal if it is near, a voice is free and calls are
## not crowding each other. Returns whether it played.
func call_now(id: int) -> bool:
	if _gap > 0 or not audible(id) or LEVELS[animal_level] <= 0.0 or id in _voice_owner:
		return false
	var slot := _voice_owner.find(-1)
	if slot < 0:
		return false
	var kind: int = forest._animals[id]["kind"]
	var voice := _voices[slot]
	voice.stream = load(AUDIO + _calls[kind] + ".wav")
	voice.volume_db = _volume[kind]
	voice.pitch_scale = lerpf(0.9, 1.1, forest._hash(id, calls_played, 1903))
	voice.global_position = forest.to_world(forest._animals[id]["position"]) + Vector3.UP * 0.5
	if not silent:
		voice.play()
	_voice_owner[slot] = id
	_voice_left[slot] = voice.stream.get_length() / voice.pitch_scale
	_gap = MIN_GAP
	calls_played += 1
	return true


func release_voices() -> void:
	for i in _voices.size():
		_voices[i].stop()
		_voice_owner[i] = -1
		_voice_left[i] = 0.0


func active_calls() -> int:
	var count := 0
	for id in _voice_owner:
		count += 1 if id >= 0 else 0
	return count


func cycle_ambience() -> void:
	ambience_level = wrapi(ambience_level + 1, 0, LEVELS.size())
	_apply_levels()
	_save_settings()


func cycle_animals() -> void:
	animal_level = wrapi(animal_level + 1, 0, LEVELS.size())
	_apply_levels()
	_save_settings()


func level_text(level: int) -> String:
	return "Off" if LEVELS[level] <= 0.0 else "%d%%" % roundi(LEVELS[level] * 100)


func _apply_levels() -> void:
	for pair in [["Ambience", ambience_level], ["Animals", animal_level]]:
		var bus := AudioServer.get_bus_index(pair[0])
		var level: float = LEVELS[pair[1]]
		AudioServer.set_bus_mute(bus, level <= 0.0)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(level, 0.001)))


func _load_settings() -> void:
	var config := ConfigFile.new()
	if FileAccess.file_exists(SETTINGS_PATH) and config.load(SETTINGS_PATH) == OK:
		ambience_level = clampi(int(config.get_value("audio", "ambience", 0)), 0, LEVELS.size() - 1)
		animal_level = clampi(int(config.get_value("audio", "animals", 0)), 0, LEVELS.size() - 1)


func _save_settings() -> void:
	var config := ConfigFile.new()
	if FileAccess.file_exists(SETTINGS_PATH):
		config.load(SETTINGS_PATH)
	config.set_value("audio", "ambience", ambience_level)
	config.set_value("audio", "animals", animal_level)
	config.save(SETTINGS_PATH)
