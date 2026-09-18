class_name SplashDaysCarouselComponent
extends BaseComponent

const DAY_COUNT := 7
const SECONDS_PER_DAY := 86400
const SCROLL_DURATION := 0.35
const WEEKDAYS := ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
var _launcher: SplashChallengeLauncherComponent
var _row: HBoxContainer
var _left: BaseButton
var _right: BaseButton
var _animating := false


func _ready() -> void:
	var root := get_node("../..")
	_row = root.get_node("DaysRow")
	_left = root.get_node("LeftArrow")
	_right = root.get_node("RightArrow")
	_launcher = SplashChallengeLauncherComponent.of_as(self)
	_left.pressed.connect(_scroll.bind(-1))
	_right.pressed.connect(_scroll.bind(1))
	_launcher.selected_date_changed.connect(_refresh)
	_refresh(_launcher.selected_date_key)


func _refresh(date_key: String) -> void:
	_update_arrow_visibility(date_key)
	_set_days(date_key)


func _set_days(date_key: String) -> void:
	var selected := DailyChallengeService._date_key_to_unix(date_key)
	for index in DAY_COUNT:
		var date := Time.get_date_dict_from_unix_time(selected - (DAY_COUNT - 1 - index) * SECONDS_PER_DAY)
		var day := _row.get_child(index)
		_configure_day(day, date)


func _configure_day(day: Control, date: Dictionary) -> void:
	day.get_node("Date").text = str(date.day)
	day.get_node("Weekday").text = WEEKDAYS[date.weekday]
	day.get_node("Badge/Tick").visible = is_challenge_completed(date)


func _set_alpha(control: Control, alpha: float) -> void:
	var color := control.modulate
	color.a = alpha
	control.modulate = color


func _update_arrow_visibility(date_key: String) -> void:
	var today_key := DailyChallengeService.get_today_key()
	var selected := DailyChallengeService._date_key_to_unix(date_key)
	_left.visible = DailyChallengeService._unix_to_date_key(selected - SECONDS_PER_DAY) <= today_key
	_right.visible = DailyChallengeService._unix_to_date_key(selected + SECONDS_PER_DAY) <= today_key


func is_challenge_completed(date: Dictionary) -> bool:
	return DailyChallengeService.is_completed(DailyChallengeService.date_key_from_dict(date))


func _scroll(direction: int) -> void:
	if _animating:
		return
	var next := DailyChallengeService._unix_to_date_key(DailyChallengeService._date_key_to_unix(_launcher.selected_date_key) + direction * SECONDS_PER_DAY)
	if next > DailyChallengeService.get_today_key():
		return
	_animating = true
	# Keep the outgoing date alive while the eighth (incoming) date fades in.
	# Free-standing copies avoid HBoxContainer relayout during the transition.
	var layer := Control.new()
	layer.name = "DayTransition"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.get_parent().add_child(layer)
	layer.position = _row.position
	var step: Vector2 = _row.get_child(1).position - _row.get_child(0).position
	var tween := create_tween().set_parallel(true)
	for index in DAY_COUNT:
		var source := _row.get_child(index) as Control
		var copy := source.duplicate() as Control
		layer.add_child(copy)
		copy.position = source.position
		copy.size = source.size
		var destination := index - direction
		var target := source.position - step * direction
		if destination >= 0 and destination < DAY_COUNT:
			target = (_row.get_child(destination) as Control).position
		tween.tween_property(copy, "position", target, SCROLL_DURATION)
		if destination < 0 or destination >= DAY_COUNT:
			tween.tween_property(copy, "modulate:a", 0.0, SCROLL_DURATION)
	var incoming_index := 0 if direction < 0 else DAY_COUNT - 1
	var slot := _row.get_child(incoming_index) as Control
	var incoming := slot.duplicate() as Control
	layer.add_child(incoming)
	incoming.position = slot.position + step * direction
	incoming.size = slot.size
	var incoming_unix := DailyChallengeService._date_key_to_unix(next)
	if direction < 0:
		incoming_unix -= (DAY_COUNT - 1) * SECONDS_PER_DAY
	_configure_day(incoming, Time.get_date_dict_from_unix_time(incoming_unix))
	_set_alpha(incoming, 0.0)
	tween.tween_property(incoming, "position", slot.position, SCROLL_DURATION)
	tween.tween_property(incoming, "modulate:a", 1.0, SCROLL_DURATION)
	_row.hide()
	await tween.finished
	_launcher.select_date(next)
	_row.show()
	layer.hide()
	layer.queue_free()
	_animating = false
