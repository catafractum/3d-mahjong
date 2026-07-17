class_name RectangleResource
extends BaseValueResource

var value: Rect2 = Rect2(Vector2.ZERO, Vector2(400, 200)):
	set(new_value):
		if value != new_value:
			var old_value = value
			value = new_value
			_emit_value_changed(old_value, new_value)
	get:
		return value
