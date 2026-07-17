class_name SavedataDTO
extends BaseDTO

var first_time: bool = true


func _get_current_version() -> int:
	return 0


func _get_migrations() -> Dictionary:
	return {}


func _apply_dict(dict: Dictionary) -> void:
	first_time = dict.get("first_time", true)


func _to_dict() -> Dictionary:
	return {
		"first_time": first_time,
	}
