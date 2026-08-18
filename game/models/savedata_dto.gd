class_name SavedataDTO
extends BaseDTO

var first_time: bool = true
var completed_daily_challenges: Array[String] = []


func _get_current_version() -> int:
	return 1


func _get_migrations() -> Dictionary:
	return {
		1: func(data: Dictionary) -> Dictionary:
			if not data.has("completed_daily_challenges"):
				data["completed_daily_challenges"] = []
			return data,
	}


func _apply_dict(dict: Dictionary) -> void:
	first_time = dict.get("first_time", true)
	completed_daily_challenges.clear()
	for value in dict.get("completed_daily_challenges", []):
		if value is String and value not in completed_daily_challenges:
			completed_daily_challenges.append(value)
	completed_daily_challenges.sort()


func _to_dict() -> Dictionary:
	return {
		"first_time": first_time,
		"completed_daily_challenges": completed_daily_challenges,
	}
