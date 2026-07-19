class_name BoardRotationComponent
extends BaseComponent

@export var board: Node3D
@export var game_ui: GameUIComponent
@export var rotation_duration := 0.4

var _rotating := false


func _ready() -> void:
	game_ui.rotate_requested.connect(rotate)


func rotate(right: bool) -> void:
	if _rotating:
		return
	_rotating = true
	var direction := 90.0 if right else -90.0
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(board, "rotation_degrees:y", board.rotation_degrees.y + direction, rotation_duration)
	tween.tween_callback(func() -> void: _rotating = false)
