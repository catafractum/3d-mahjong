class_name GameOverMenuComponent
extends BaseComponent

signal home_requested
signal replay_requested

@export var menu: Control
@export var home_button: BaseButton
@export var replay_button: BaseButton


func _ready() -> void:
	home_button.pressed.connect(home_requested.emit)
	replay_button.pressed.connect(replay_requested.emit)


func show_menu() -> void:
	menu.show()


func hide_menu() -> void:
	menu.hide()


static func of_as(node: Node) -> GameOverMenuComponent:
	return BaseComponent.of(node, GameOverMenuComponent) as GameOverMenuComponent
