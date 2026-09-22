class_name SplashDaysCarouselComponent
extends BaseComponent

const DAY_COUNT := 7
const SECONDS_PER_DAY := 86400
const SCROLL_DURATION := 0.75
const SELECTION_MOVE_DURATION := 0.2
const SELECTION_PAUSE_DURATION := 0.3
const WEEKDAYS := ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
var _launcher: SplashChallengeLauncherComponent
var _row: HBoxContainer
var _selection_rect: Control
var _left: BaseButton
var _right: BaseButton
var _today: BaseButton
var _animating := false


func _ready() -> void:
	var root := get_node("../..")
	_row = root.get_node("DaysRow")
	_selection_rect = root.get_node("SelectionRect")
	_left = root.get_node("LeftArrow")
	_right = root.get_node("RightArrow")
	_today = root.get_node("Today")
	_launcher = SplashChallengeLauncherComponent.of_as(self)
	_left.pressed.connect(_scroll.bind(-1))
	_right.pressed.connect(_scroll.bind(1))
	_today.pressed.connect(_scroll_to_today)
	for index in DAY_COUNT:
		var day := _row.get_child(index) as Control
		day.mouse_filter = Control.MOUSE_FILTER_STOP
		day.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for child in day.find_children("*", "Control", true, false):
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		day.gui_input.connect(_on_day_gui_input.bind(index))
	_launcher.selected_date_changed.connect(_refresh)
	_refresh(_launcher.selected_date_key)


func _refresh(date_key: String) -> void:
	_update_arrow_visibility(date_key)
	# Preserve the outgoing dates while selection feedback is playing.
	if not _animating:
		_set_days(date_key)


func _set_days(date_key: String) -> void:
	var selected := DailyChallengeService._date_key_to_unix(date_key)
	for index in DAY_COUNT:
		var date := Time.get_date_dict_from_unix_time(
			selected - (DAY_COUNT - 1 - index) * SECONDS_PER_DAY
		)
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
	_today.visible = date_key != today_key
	var selected := DailyChallengeService._date_key_to_unix(date_key)
	_left.visible = DailyChallengeService._unix_to_date_key(selected - SECONDS_PER_DAY) <= today_key
	_right.visible = (
		DailyChallengeService._unix_to_date_key(selected + SECONDS_PER_DAY) <= today_key
	)


func is_challenge_completed(date: Dictionary) -> bool:
	return DailyChallengeService.is_completed(DailyChallengeService.date_key_from_dict(date))


func _on_day_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		(_row.get_child(index) as Control).accept_event()
		_scroll(index - (DAY_COUNT - 1), index)


func _scroll_to_today() -> void:
	var today := DailyChallengeService._date_key_to_unix(DailyChallengeService.get_today_key())
	var selected := DailyChallengeService._date_key_to_unix(_launcher.selected_date_key)
	_scroll(int((today - selected) / SECONDS_PER_DAY))


func _scroll(direction: int, clicked_index: int = -1) -> void:
	if _animating or direction == 0:
		return
	var next := DailyChallengeService._unix_to_date_key(
		(
			DailyChallengeService._date_key_to_unix(_launcher.selected_date_key)
			+ direction * SECONDS_PER_DAY
		)
	)
	if next > DailyChallengeService.get_today_key():
		return
	# Limit visual travel to one row when jumping back from a distant date.
	direction = clampi(direction, -DAY_COUNT, DAY_COUNT)
	_animating = true
	_launcher.select_date(next)
	var selection_home_x := _selection_rect.position.x
	if clicked_index >= 0:
		var clicked_day := _row.get_child(clicked_index) as Control
		var selected_day := _row.get_child(DAY_COUNT - 1) as Control
		var clicked_x := selection_home_x + clicked_day.position.x - selected_day.position.x
		var selection_tween := create_tween()
		(
			selection_tween
			. tween_property(_selection_rect, "position:x", clicked_x, SELECTION_MOVE_DURATION)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_OUT)
		)
		selection_tween.tween_interval(SELECTION_PAUSE_DURATION)
		await selection_tween.finished
	# Keep outgoing dates alive while the incoming dates fade in.
	# Free-standing copies avoid HBoxContainer relayout during the transition.
	var layer := Control.new()
	layer.name = "DayTransition"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.get_parent().add_child(layer)
	layer.position = _row.position
	layer.size = _row.size
	layer.clip_contents = true
	var step: Vector2 = _row.get_child(1).position - _row.get_child(0).position
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)
	if clicked_index >= 0:
		tween.tween_property(_selection_rect, "position:x", selection_home_x, SCROLL_DURATION)
	for index in DAY_COUNT:
		var source := _row.get_child(index) as Control
		var copy := source.duplicate(0) as Control
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var next_unix := DailyChallengeService._date_key_to_unix(next)
	for index in DAY_COUNT:
		var source_index := index + direction
		if source_index >= 0 and source_index < DAY_COUNT:
			continue
		var slot := _row.get_child(index) as Control
		var incoming := slot.duplicate(0) as Control
		incoming.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(incoming)
		incoming.position = slot.position + step * direction
		incoming.size = slot.size
		var incoming_unix := next_unix - (DAY_COUNT - 1 - index) * SECONDS_PER_DAY
		_configure_day(incoming, Time.get_date_dict_from_unix_time(incoming_unix))
		_set_alpha(incoming, 0.0)
		tween.tween_property(incoming, "position", slot.position, SCROLL_DURATION)
		tween.tween_property(incoming, "modulate:a", 1.0, SCROLL_DURATION)
	_row.hide()
	await tween.finished
	_set_days(_launcher.selected_date_key)
	_row.show()
	layer.hide()
	layer.queue_free()
	_animating = false
