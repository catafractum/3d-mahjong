extends Node

@export_file("*.json") var levels_path := "res://data/levels_dev.json"
@export var challenge_level_ids: Array[int] = [0, 10, 20]
@export_range(0.0, 3600.0, 1.0, "or_greater")
var challenge_time_limit_seconds := 900.0

var current_session: GameSession = null


func create_challenge_session() -> GameSession:
	var levels := _load_levels(challenge_level_ids)
	if levels.size() != challenge_level_ids.size():
		push_error("GameDB: Could not load every challenge level from %s." % levels_path)
		return null

	return GameSession.new(
		levels,
		GameSession.Mode.CHALLENGE,
		challenge_time_limit_seconds
	)


func _load_levels(level_ids: Array[int]) -> Array[Dictionary]:
	var file := FileAccess.open(levels_path, FileAccess.READ)
	if file == null:
		push_error("GameDB: Could not open %s." % levels_path)
		return []

	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("GameDB: Invalid levels JSON in %s." % levels_path)
		return []

	var levels_by_id: Dictionary = {}
	for level in parsed.get("levels", []):
		if level is Dictionary:
			levels_by_id[int(level.get("id", -1))] = level

	var result: Array[Dictionary] = []
	for level_id in level_ids:
		if levels_by_id.has(level_id):
			result.append(levels_by_id[level_id].duplicate(true))
	return result
