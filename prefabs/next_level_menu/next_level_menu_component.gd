class_name NextLevelMenuComponent
extends BaseComponent

signal play_requested

@export var menu: Control
@export var play_button: BaseButton
@export var button_label: Label


func _ready() -> void:
	play_button.pressed.connect(play_requested.emit)


func show_menu(next_difficulty: String) -> void:
	button_label.text = "PLAY %s" % next_difficulty.to_upper()
	menu.show()


func hide_menu() -> void:
	menu.hide()


static func of_as(node: Node) -> NextLevelMenuComponent:
	return BaseComponent.of(node, NextLevelMenuComponent) as NextLevelMenuComponent
