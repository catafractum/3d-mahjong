class_name GameSession
extends RefCounted

enum Mode {
	STANDARD,
	CHALLENGE,
}

enum Status {
	READY,
	PLAYING,
	COMPLETED,
	FAILED,
}

var mode: Mode = Mode.STANDARD
var levels: Array[Dictionary] = []
var current_level_index: int = 0
var time_limit_seconds: float = 0.0
var elapsed_seconds: float = 0.0
var status: Status = Status.READY
var selected_tile: Node3D
var challenge_date_key := ""


func _init(
	session_levels: Array[Dictionary] = [],
	session_mode: Mode = Mode.STANDARD,
	session_time_limit_seconds: float = 0.0,
	session_challenge_date_key := ""
) -> void:
	levels = session_levels.duplicate(true)
	mode = session_mode
	time_limit_seconds = maxf(session_time_limit_seconds, 0.0)
	challenge_date_key = session_challenge_date_key


func get_current_level() -> Dictionary:
	if current_level_index < 0 or current_level_index >= levels.size():
		return {}
	return levels[current_level_index]


func has_next_level() -> bool:
	return current_level_index + 1 < levels.size()


func advance_to_next_level() -> bool:
	if not has_next_level():
		return false
	current_level_index += 1
	return true


func reset() -> void:
	current_level_index = 0
	elapsed_seconds = 0.0
	status = Status.READY
	selected_tile = null


func get_remaining_seconds() -> float:
	return maxf(time_limit_seconds - elapsed_seconds, 0.0)
