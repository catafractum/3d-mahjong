extends Node

signal completion_changed(date_key: String)

const SECONDS_PER_DAY := 86400


func get_today_key() -> String:
	return date_key_from_dict(Time.get_date_dict_from_system())


func date_key_from_dict(date: Dictionary) -> String:
	return "%04d-%02d-%02d" % [
		int(date.get("year", 0)),
		int(date.get("month", 0)),
		int(date.get("day", 0)),
	]


func is_completed(date_key: String) -> bool:
	return date_key in SaveLoadManager.data.completed_daily_challenges


func complete_challenge(date_key: String) -> bool:
	if not _is_valid_date_key(date_key) or is_completed(date_key):
		return false
	SaveLoadManager.data.completed_daily_challenges.append(date_key)
	SaveLoadManager.data.completed_daily_challenges.sort()
	SaveLoadManager.save_game()
	completion_changed.emit(date_key)
	return true


func get_current_streak() -> int:
	var completed := _completed_date_set()
	if completed.is_empty():
		return 0
	var today_unix := _date_key_to_unix(get_today_key())
	var cursor := today_unix
	if not completed.has(get_today_key()):
		cursor -= SECONDS_PER_DAY
	var streak := 0
	while completed.has(_unix_to_date_key(cursor)):
		streak += 1
		cursor -= SECONDS_PER_DAY
	return streak


func get_best_streak() -> int:
	var timestamps: Array[int] = []
	for date_key in _completed_date_set():
		timestamps.append(_date_key_to_unix(date_key))
	if timestamps.is_empty():
		return 0
	timestamps.sort()
	var best := 1
	var current := 1
	for index in range(1, timestamps.size()):
		if timestamps[index] - timestamps[index - 1] == SECONDS_PER_DAY:
			current += 1
		else:
			current = 1
		best = maxi(best, current)
	return best


func _completed_date_set() -> Dictionary:
	var result: Dictionary = {}
	for date_key in SaveLoadManager.data.completed_daily_challenges:
		if _is_valid_date_key(date_key):
			result[date_key] = true
	return result


func _date_key_to_unix(date_key: String) -> int:
	var parts := date_key.split("-")
	return int(Time.get_unix_time_from_datetime_dict({
		"year": int(parts[0]),
		"month": int(parts[1]),
		"day": int(parts[2]),
		"hour": 0,
		"minute": 0,
		"second": 0,
	}))


func _unix_to_date_key(unix_time: int) -> String:
	return date_key_from_dict(Time.get_date_dict_from_unix_time(unix_time))


func _is_valid_date_key(date_key: String) -> bool:
	var parts := date_key.split("-")
	if parts.size() != 3 or parts[0].length() != 4 or parts[1].length() != 2 or parts[2].length() != 2:
		return false
	for part in parts:
		if not part.is_valid_int():
			return false
	var date := {
		"year": int(parts[0]),
		"month": int(parts[1]),
		"day": int(parts[2]),
	}
	if date.month < 1 or date.month > 12 or date.day < 1 or date.day > 31:
		return false
	return date_key_from_dict(Time.get_date_dict_from_unix_time(_date_key_to_unix(date_key))) == date_key

