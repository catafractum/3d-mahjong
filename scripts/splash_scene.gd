extends Node2D

const BOARD_SCENE := "res://scenes/board_scene.tscn"

@export var challenge_container_landscape: Control
@export var challenge_container_portrait: Control


func _ready() -> void:
	challenge_container_landscape.play_pressed.connect(_on_play_pressed)
	challenge_container_portrait.play_pressed.connect(_on_play_pressed)


func _on_play_pressed() -> void:
	GameState.selected_level_id = 0
	GameState.has_selected_level = false
	get_tree().change_scene_to_file(BOARD_SCENE)
