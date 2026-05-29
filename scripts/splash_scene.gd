extends Control

const BOARD_SCENE := "res://scenes/board_scene.tscn"

@onready var start_button: Button = %StartButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_button_pressed)

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file(BOARD_SCENE)
