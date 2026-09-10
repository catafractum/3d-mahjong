class_name SplashChallengeContainerComponent
extends BaseComponent

@export var play_button: TextureButton
@export var time_label: Label


func _ready() -> void:
	play_button.pressed.connect(_on_play_button_pressed)
	var times := PackedStringArray()
	for difficulty in GameDB.challenge_difficulties:
		var seconds := int(GameDB.get_difficulty_time_limit_seconds(difficulty))
		times.append("%02d:%02d" % [seconds / 60, seconds % 60])
	if time_label != null:
		time_label.text = " / ".join(times)


func _on_play_button_pressed() -> void:
	var launcher := SplashChallengeLauncherComponent.of_as(self)
	if launcher != null:
		launcher.start_challenge(DailyChallengeService.get_today_key())
