extends Control

signal timer_finished

@export var duration_seconds: float = 15.0 * 60.0
@export var starts_paused: bool = false

@onready var minutes_label: Label = %MinutesLabel
@onready var seconds_label: Label = %SecondsLabel

var remaining_seconds: float
var is_paused: bool
var is_finished: bool

func _ready() -> void:
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

func resume() -> void:
	if not is_finished:
		is_paused = false

func reset(seconds: float = -1.0) -> void:
	if seconds < 0.0:
		seconds = duration_seconds

	duration_seconds = seconds
	remaining_seconds = duration_seconds
	is_finished = false
	is_paused = starts_paused
	_update_time_label()

func _update_time_label() -> void:
	if minutes_label == null or seconds_label == null:
		return

	var total_seconds := int(ceil(remaining_seconds))
	var minutes := int(total_seconds / 60.0)
	var seconds := total_seconds % 60
	minutes_label.text = "%02d" % minutes
	seconds_label.text = "%02d" % seconds
