class_name ChallengeCompleteMenuComponent
extends BaseComponent

signal home_requested
signal replay_requested

@export var menu: Control
@export var home_button: BaseButton
@export var replay_button: BaseButton


func _ready() -> void:
	home_button.pressed.connect(_request_home)
	replay_button.pressed.connect(_request_replay)


func _request_home() -> void:
	home_requested.emit()


func _request_replay() -> void:
	replay_requested.emit()


func show_menu() -> void:
	menu.show()


func hide_menu() -> void:
	menu.hide()


static func of_as(node: Node) -> ChallengeCompleteMenuComponent:
	return BaseComponent.of(node, ChallengeCompleteMenuComponent) as ChallengeCompleteMenuComponent
