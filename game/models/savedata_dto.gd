class_name SavedataDTO
extends BaseDTO

var first_time: bool = true
var completed_daily_challenges: Array[String] = []
var streak_daily_challenges: Array[String] = []


func _get_current_version() -> int:
	return 2


func _get_migrations() -> Dictionary:
	return {
		1: func(data: Dictionary) -> Dictionary:
			if not data.has("completed_daily_challenges"):
				data["completed_daily_challenges"] = []
			return data,
		# Before catch-up was available, every recorded completion earned streak credit.
		2: func(data: Dictionary) -> Dictionary:
			data["streak_daily_challenges"] = data.get("completed_daily_challenges", []).duplicate()
			return data,
	}


func _apply_dict(dict: Dictionary) -> void:
	first_time = dict.get("first_time", true)
	completed_daily_challenges.clear()
	for value in dict.get("completed_daily_challenges", []):
		if value is String and value not in completed_daily_challenges:
			completed_daily_challenges.append(value)
	completed_daily_challenges.sort()
	streak_daily_challenges.clear()
	for value in dict.get("streak_daily_challenges", []):
		if value is String and value in completed_daily_challenges and value not in streak_daily_challenges:
			streak_daily_challenges.append(value)
	streak_daily_challenges.sort()


func _to_dict() -> Dictionary:
	return {
		"first_time": first_time,
		"completed_daily_challenges": completed_daily_challenges,
		"streak_daily_challenges": streak_daily_challenges,
	}
