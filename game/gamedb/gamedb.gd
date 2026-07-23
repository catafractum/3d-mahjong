extends Node

@export var use_development_levels := true
@export_file("*.json") var original_levels_path: String
@export_file("*.json") var development_levels_path: String
@export var challenge_difficulties: Array[String] = ["easy", "medium", "hard"]
@export_range(0.0, 3600.0, 1.0, "or_greater") var challenge_time_limit_seconds := 900.0

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

	return GameSession.new(
		levels, GameSession.Mode.CHALLENGE, challenge_time_limit_seconds, date_key
	)


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
			result.append(level.duplicate(true))
	return result


func _stable_date_seed(date_key: String) -> int:
	var result := 2166136261
	for byte in date_key.to_utf8_buffer():
		result = (result ^ int(byte)) * 16777619
		result &= 0x7fffffff
	return result
