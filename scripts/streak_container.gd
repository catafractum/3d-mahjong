extends Control

@export var current_streak: int = 0
@export var best_streak: int = 0

@onready var current_streak_value: Label = %CurrentStreakValue
@onready var best_streak_value: Label = %BestStreakValue

func _ready() -> void:
	_refresh_streak_values()

func set_streak_values(current: int, best: int) -> void:
	current_streak = current
	best_streak = best
	_refresh_streak_values()

func _refresh_streak_values() -> void:
	if current_streak_value == null or best_streak_value == null:
		return

	current_streak_value.text = str(current_streak)
	best_streak_value.text = str(best_streak)
