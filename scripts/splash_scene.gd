extends Control

const BOARD_SCENE := "res://scenes/board_scene.tscn"

@onready var challenge_container: Control = %ChallengeContainer

func _ready() -> void:
	challenge_container.play_pressed.connect(_on_play_pressed)

func _on_play_pressed() -> void:
	GameState.selected_level_id = 0
	GameState.has_selected_level = false
	get_tree().change_scene_to_file(BOARD_SCENE)
