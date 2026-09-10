extends Node

@export var use_development_levels := true
@export var enable_remove_pair_button := false
@export_file("*.json") var original_levels_path: String
@export_file("*.json") var development_levels_path: String
@export var challenge_difficulties: Array[String] = ["easy", "medium", "hard"]
@export_group("Challenge timing (seconds per pair)")
@export_range(0.1, 60.0, 0.1, "or_greater") var easy_seconds_per_pair := 7.0
@export_range(0.1, 60.0, 0.1, "or_greater") var medium_seconds_per_pair := 5.0
@export_range(0.1, 60.0, 0.1, "or_greater") var hard_seconds_per_pair := 3.0

var current_session: GameSession = null
var levels_path: String:
	get:
		return development_levels_path if use_development_levels else original_levels_path


func create_challenge_session(date_key := "") -> GameSession:
	if date_key.is_empty():
		date_key = DailyChallengeService.get_today_key()
	var levels := _select_daily_levels(date_key)
	if levels.size() != challenge_difficulties.size():
		push_error("GameDB: Could not select every daily challenge level from %s." % levels_path)
		return null

	for level in levels:
		level["time_limit_seconds"] = get_level_time_limit_seconds(level)
	var session := GameSession.new(
		levels, GameSession.Mode.CHALLENGE, float(levels[0].time_limit_seconds), date_key
	)
	session.is_catch_up = date_key != DailyChallengeService.get_today_key()
	return session


func get_seconds_per_pair(difficulty: String) -> float:
	match difficulty:
		"easy": return easy_seconds_per_pair
		"medium": return medium_seconds_per_pair
		"hard": return hard_seconds_per_pair
	push_error("GameDB: Unknown challenge difficulty: %s" % difficulty)
	return easy_seconds_per_pair


func get_level_time_limit_seconds(level: Dictionary) -> float:
	# Use the original board size once; removing pairs does not change the budget.
	var tiles: Array = level.get("tiles", [])
	var pair_count := tiles.size() / 2.0
	var seconds := pair_count * get_seconds_per_pair(str(level.get("difficulty", "easy")))
	return ceilf(seconds / 60.0) * 60.0


func _select_daily_levels(date_key: String) -> Array[Dictionary]:
	var all_levels := _load_all_levels()
	var result: Array[Dictionary] = []
	var date_seed := _stable_date_seed(date_key)
	for difficulty_index in challenge_difficulties.size():
		var difficulty := challenge_difficulties[difficulty_index]
		var pool: Array[Dictionary] = []
		for level in all_levels:
			if str(level.get("difficulty", "")) == difficulty:
				pool.append(level)
		if pool.is_empty():
			push_error("GameDB: No %s levels are available in %s." % [difficulty, levels_path])
			return []
		pool.sort_custom(
			func(a: Dictionary, b: Dictionary): return int(a.get("id", 0)) < int(b.get("id", 0))
		)
		var selected_index := posmod(date_seed + difficulty_index * 104729, pool.size())
		result.append(pool[selected_index].duplicate(true))
	return result


func _load_all_levels() -> Array[Dictionary]:
	var file := FileAccess.open(levels_path, FileAccess.READ)
	if file == null:
		push_error("GameDB: Could not open %s." % levels_path)
		return []

	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("GameDB: Invalid levels JSON in %s." % levels_path)
		return []

	var result: Array[Dictionary] = []
	for level in parsed.get("levels", []):
		if level is Dictionary:
			var tiles = level.get("tiles", [])
			var icons = level.get("tile_icons", [])
			if not tiles is Array or not icons is Array or icons.size() != tiles.size():
				push_error(
					(
						"GameDB: Level %s has invalid or missing tile_icons in %s."
						% [level.get("name", "unnamed"), levels_path]
					)
				)
				return []
			result.append(level.duplicate(true))
	return result


func _stable_date_seed(date_key: String) -> int:
	var result := 2166136261
	for byte in date_key.to_utf8_buffer():
		result = (result ^ int(byte)) * 16777619
		result &= 0x7fffffff
	return result
