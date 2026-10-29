extends RefCounted

## One versioned save slot in user://. A new save is written to a temporary
## file and read back before it replaces the slot; the replaced save is kept
## as a backup. Failures never delete or overwrite the existing valid save.
const FORMAT := "oravitsa-save"
## Version 2 adds aura, how well fed Oravitsa is, cave progress and saving
## underground; version 1 saves still load.
const VERSION := 2
const OLDEST_VERSION := 1
const PATH := "user://oravitsa_save.json"


static func write(data: Dictionary, path: String = PATH) -> String:
	var temp := path + ".tmp"
	var backup := path + ".bak"
	var text := JSON.stringify(data, "", false, true)
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return "could not write (%s)" % error_string(FileAccess.get_open_error())
	file.store_string(text)
	file.close()
	var check := read(temp)
	if not check["ok"]:
		DirAccess.remove_absolute(temp)
		return "verification failed: " + check["error"]
	# Renames replace their destination in one step, and a failed rename leaves
	# both files as they were. Only a readable slot is rotated into the backup,
	# so a corrupt slot never displaces a valid backup.
	var rotated := false
	if read(path)["ok"]:
		var moved := DirAccess.rename_absolute(path, backup)
		if moved != OK:
			DirAccess.remove_absolute(temp)
			return "could not keep the previous save (%s)" % error_string(moved)
		rotated = true
	var replaced := DirAccess.rename_absolute(temp, path)
	if replaced != OK:
		DirAccess.remove_absolute(temp)
		if rotated:
			# Put the previous save back in the slot it came from.
			DirAccess.rename_absolute(backup, path)
		return "could not replace the save (%s)" % error_string(replaced)
	return ""


## Returns {ok, data, error, missing}. The file is never modified here.
static func read(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "missing": true, "error": "no saved game", "data": {}}
	var text := FileAccess.get_file_as_string(path)
	# A JSON instance reports bad input quietly; parse_string logs an error.
	var json := JSON.new()
	var parsed = json.data if json.parse(text) == OK else null
	if not parsed is Dictionary:
		return {"ok": false, "missing": false, "error": "the save file is unreadable", "data": {}}
	var problem := validate(parsed)
	return {"ok": problem.is_empty(), "missing": false, "error": problem, "data": parsed if problem.is_empty() else {}}


static func _number(value, low: float, high: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= low and float(value) <= high


static func _point(value) -> bool:
	return value is Array and value.size() == 2 and _number(value[0], -1e8, 1e8) and _number(value[1], -1e8, 1e8)


## Checks every field before anything is applied; returns "" when valid.
static func validate(data: Dictionary) -> String:
	if data.get("format") != FORMAT:
		return "this is not an Oravitsa save"
	if not _number(data.get("version"), 0, 1e6) or int(data["version"]) < OLDEST_VERSION or int(data["version"]) > VERSION:
		return "the save comes from an incompatible version"
	for section in ["player", "inventory", "clock"]:
		if not data.get(section) is Dictionary:
			return "the save is missing its %s data" % section
	if not data.get("world") is String or not data.get("harvested") is Array or not data.get("animals") is Array:
		return "the save is incomplete"
	var player: Dictionary = data["player"]
	if not _point(player.get("ground")):
		return "the saved position is invalid"
	for field in ["stun", "shoo_cooldown", "sling_cooldown"]:
		if not _number(player.get(field), 0, 3600):
			return "the saved player state is invalid"
	if not _number(player.get("active_skill"), 0, 1):
		return "the saved player state is invalid"
	for field in ["mushrooms", "berries", "raw_meat"]:
		if not _number(data["inventory"].get(field), 0, 1e9):
			return "the saved inventory is invalid"
	for field in ["food", "population_tick", "fight_tick"]:
		if not _number(data["clock"].get(field), 0, 1e12):
			return "the saved clock is invalid"
	if data["harvested"].size() > 50000 or data["animals"].size() > 208:
		return "the save is larger than the game allows"
	for record in data["harvested"]:
		if not record is Array or record.size() != 3 or not _number(record[0], -2e9, 2e9) or not _number(record[1], -2e9, 2e9) or not _number(record[2], 0, 1e12):
			return "a saved food record is invalid"
	for animal in data["animals"]:
		if not animal is Dictionary or not _number(animal.get("kind"), 0, 5):
			return "a saved animal is invalid"
		for field in ["position", "home", "target"]:
			if not _point(animal.get(field)):
				return "a saved animal position is invalid"
		if not animal.get("alive") is bool or not animal.get("gone") is bool or not animal.get("state") is String:
			return "a saved animal is invalid"
		for field in ["respawn", "stun", "shoo", "hunger", "feeding", "burst_cooldown", "hunt_rest", "aggro_cooldown", "fight_cooldown", "timeout"]:
			if not _number(animal.get(field), -1e6, 1e6):
				return "a saved animal timer is invalid"
		for field in ["turn", "hunt_attempts", "aggro_rolls"]:
			if not _number(animal.get(field), 0, 1e12):
				return "a saved animal counter is invalid"
	if int(data["version"]) >= 2:
		if not _number(data.get("aura"), -1e9, 1e9):
			return "the saved aura is invalid"
		var feeding = data.get("fed")
		if not feeding is Dictionary or not _number(feeding.get("level"), 0, 100) or not _number(feeding.get("meal_timer"), 0, 3600):
			return "the saved feeding is invalid"
		var caves = data.get("caves", {})
		if not caves is Dictionary or caves.size() > 5000:
			return "the saved cave progress is invalid"
		for key in caves:
			var cave = caves[key]
			if not key is String or not cave is Dictionary or not cave.get("checkpoints") is Array or not cave.get("killed") is Array or cave["checkpoints"].size() > 16 or cave["killed"].size() > 64:
				return "the saved cave progress is invalid"
			for value in cave["checkpoints"] + cave["killed"]:
				if not _number(value, 0, 63):
					return "the saved cave progress is invalid"
		if data.has("underground"):
			var underground = data["underground"]
			if not underground is Dictionary or not underground.get("cave") is String or not caves.has(underground["cave"]) or not RegEx.create_from_string("^-?\\d{1,9},-?\\d{1,9}$").search(underground["cave"]):
				return "the saved cave is invalid"
			var offset = underground.get("offset")
			if not offset is Array or offset.size() != 2 or not _number(offset[0], -200, 200) or not _number(offset[1], -200, 200):
				return "the saved cave position is invalid"
			var monsters = underground.get("monsters")
			if not monsters is Array or monsters.size() > 64:
				return "the saved cave monsters are invalid"
			for monster in monsters:
				if not monster is Array or monster.size() != 4 or not _number(monster[0], 0, 63) or not _number(monster[1], -200, 200) or not _number(monster[2], -200, 200) or not _number(monster[3], 0, 60):
					return "the saved cave monsters are invalid"
	return ""
