class_name SplashChallengeContainerComponent
extends BaseComponent

@export var play_button: TextureButton
@export var time_label: Label


func _ready() -> void:
	play_button.pressed.connect(_on_play_button_pressed)
	var times := PackedStringArray()
	for difficulty in GameDB.challenge_difficulties:
		var seconds := GameDB.get_seconds_per_pair(difficulty)
		times.append(str(seconds).trim_suffix(".0") + "s")
	if time_label != null:
		time_label.text = " / ".join(times)


func _on_play_button_pressed() -> void:
	var launcher := SplashChallengeLauncherComponent.of_as(self)
	if launcher != null:
		launcher.start_challenge(DailyChallengeService.get_today_key())
