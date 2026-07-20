class_name SplashChallengeContainerComponent
extends BaseComponent

@export_file("*.tscn") var game_scene_path: String
@export var play_button: TextureButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_button_pressed)


func _on_play_button_pressed() -> void:
	GameDB.current_session = GameDB.create_challenge_session(
		DailyChallengeService.get_today_key()
	)
	if GameDB.current_session == null:
		push_error("SplashChallengeContainerComponent: Could not create challenge session.")
		return
	SceneSwitcherComponent.of_as(self).switch_scene(game_scene_path)
