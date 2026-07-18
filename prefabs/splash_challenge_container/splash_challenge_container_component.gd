class_name SplashChallengeContainerComponent
extends BaseComponent

@export_file("*.tscn") var game_scene_path: String
@export var play_button: TextureButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_button_pressed)
	play_button.mouse_entered.connect(_on_play_button_mouse_entered)
	play_button.mouse_exited.connect(_on_play_button_mouse_exited)


func _on_play_button_pressed() -> void:
	SceneSwitcherComponent.of_as(self).switch_scene(game_scene_path)


func _on_play_button_mouse_entered() -> void:
	play_button.scale = Vector2.ONE * 1.025


func _on_play_button_mouse_exited() -> void:
	play_button.scale = Vector2.ONE
