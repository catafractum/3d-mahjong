class_name SplashStreakComponent
extends BaseComponent

@export var current_streak_label: Label
@export var best_streak_label: Label


func _ready() -> void:
	current_streak_label.text = str(get_current_streak())
	best_streak_label.text = str(get_best_streak())


func get_current_streak() -> int:
	return DailyChallengeService.get_current_streak()


func get_best_streak() -> int:
	return DailyChallengeService.get_best_streak()
