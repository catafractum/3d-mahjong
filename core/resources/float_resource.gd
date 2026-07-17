class_name FloatResource
extends BaseValueResource

@export var value: float = 0.0:
	set(new_value):
		if value != new_value:
			var old_value = value
			value = new_value
			_emit_value_changed(old_value, new_value)
	get:
		return value
