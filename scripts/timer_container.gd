extends Control

signal timer_finished

@export var starts_paused: bool = false

@onready var minutes_label: Label = %MinutesLabel
@onready var seconds_label: Label = %SecondsLabel

const PAUSE_BLINK_ALPHA := 0.5
const PAUSE_BLINK_DURATION := 0.7

var remaining_seconds: float
var duration_seconds: float
var is_paused: bool
var is_finished: bool
var pause_tweens: Array[Tween] = []

func _ready() -> void:
	duration_seconds = GameState.TIMER_DURATION_SECONDS
	remaining_seconds = duration_seconds
	is_paused = starts_paused
	_update_time_label()

func _process(delta: float) -> void:
	update(delta)

func update(delta: float) -> void:
	if is_paused or is_finished:
		return

	remaining_seconds = maxf(remaining_seconds - delta, 0.0)
	_update_time_label()

	if remaining_seconds <= 0.0:
		is_finished = true
		timer_finished.emit()

func pause() -> void:
	is_paused = true
	_start_pause_tweens()

func resume() -> void:
	_stop_pause_tweens()
	if not is_finished:
		is_paused = false

func reset(seconds: float = -1.0) -> void:
	_stop_pause_tweens()

	if seconds < 0.0:
		seconds = duration_seconds

	duration_seconds = seconds
	remaining_seconds = duration_seconds
	is_finished = false
	is_paused = starts_paused
	_update_time_label()

	if is_paused:
		_start_pause_tweens()

func _update_time_label() -> void:
	if minutes_label == null or seconds_label == null:
		return

	var total_seconds := int(ceil(remaining_seconds))
	var minutes := int(total_seconds / 60.0)
	var seconds := total_seconds % 60
	minutes_label.text = "%02d" % minutes
	seconds_label.text = "%02d" % seconds

func _start_pause_tweens() -> void:
	_stop_pause_tweens()

	for label in [minutes_label, seconds_label]:
		if label == null:
			continue

		label.modulate.a = 1.0
		var tween := create_tween()
		tween.set_loops()
		tween.tween_property(label, "modulate:a", PAUSE_BLINK_ALPHA, PAUSE_BLINK_DURATION)
		tween.tween_property(label, "modulate:a", 1.0, PAUSE_BLINK_DURATION)
		pause_tweens.append(tween)

func _stop_pause_tweens() -> void:
	for tween in pause_tweens:
		if tween != null and tween.is_valid():
			tween.kill()

	pause_tweens.clear()

	if minutes_label != null:
		minutes_label.modulate.a = 1.0
	if seconds_label != null:
		seconds_label.modulate.a = 1.0
