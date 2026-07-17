@abstract class_name BaseDTO
extends RefCounted


func to_json() -> String:
	return JSON.stringify(to_dict())


func to_dict() -> Dictionary:
	var dict = _to_dict().duplicate(true)
	dict["version"] = _get_current_version()
	return dict


func set_from_json(json: String) -> void:
	var result = JSON.parse_string(json)
	if result is Dictionary:
		set_from_dict(result)


func set_from_dict(dict: Dictionary) -> void:
	var migrated_dict = _run_migrations(dict)
	_apply_dict(migrated_dict)


func _run_migrations(dict: Dictionary) -> Dictionary:
	var data_version = dict.get("version", 0)
	var target_version = _get_current_version()
	var migrations = _get_migrations()

	while data_version < target_version:
		data_version += 1
		if migrations.has(data_version):
			dict = migrations[data_version].call(dict)
			dict["version"] = data_version  # Ensure version updates in the dict
		else:
			push_warning("Missing migration for version: ", data_version)
			break
	return dict



@abstract
func _get_current_version() -> int

@abstract
func _get_migrations() -> Dictionary


@abstract
func _apply_dict(dict: Dictionary) -> void

@abstract
func _to_dict() -> Dictionary
