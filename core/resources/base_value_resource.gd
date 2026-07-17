@abstract class_name BaseValueResource
extends Resource

signal value_changed(old_value, new_value)

@export var debug: bool = false


func _emit_value_changed(old_value, new_value) -> void:
	value_changed.emit(old_value, new_value)
	if debug:
		prints("Value changed from", old_value, " to ", new_value)
