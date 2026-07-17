class_name Vector2Resource
extends BaseValueResource

var value: Vector2 = Vector2.ZERO:
	set(new_value):
		if value != new_value:
			var old_value = value
			value = new_value
			_emit_value_changed(old_value, new_value)
	get:
		return value
