class_name BoardRotationComponent
extends BaseComponent

@export var board: Node3D
@export var rotation_duration := 0.4

var _rotating := false


func rotate(right: bool) -> void:
	if _rotating:
		return
	_rotating = true
	var direction := 90.0 if right else -90.0
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(board, "rotation_degrees:y", board.rotation_degrees.y + direction, rotation_duration)
	tween.tween_callback(func() -> void: _rotating = false)


static func of_as(node: Node) -> BoardRotationComponent:
	return BaseComponent.of(node, BoardRotationComponent) as BoardRotationComponent
