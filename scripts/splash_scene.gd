extends Node2D

const BOARD_SCENE := "res://scenes/board_scene.tscn"

@export var challenge_container_landscape: Control
@export var challenge_container_portrait: Control
@export_file("*.mp3", "*.wav", "*.ogg") var music_path: String
@export_file("*.mp3", "*.wav", "*.ogg") var click_sfx_path: String


func _ready() -> void:
	SoundManager.play_music(music_path)
	challenge_container_landscape.play_pressed.connect(_on_play_pressed)
	challenge_container_portrait.play_pressed.connect(_on_play_pressed)
	%OrientationListenerToggler.on_size_changed.connect(_on_size_changed)


func _exit_tree() -> void:
	%OrientationListenerToggler.on_size_changed.disconnect(_on_size_changed)


func _on_size_changed(_is_portrait: bool) -> void:
	var l = %LandscapeContent
	l.custom_minimum_size = Vector2.ZERO
	l.anchor_left = 0
	l.anchor_right = 1.0
	l.anchor_top = 0
	l.anchor_bottom = 1.0
	l.offset_left = 0
	l.offset_right = 0
	l.offset_top = 0
	l.offset_bottom = 0


func _on_play_pressed() -> void:
	SoundManager.play_sfx(click_sfx_path)
	GameState.selected_level_id = 0
	GameState.has_selected_level = false
	get_tree().change_scene_to_file(BOARD_SCENE)
