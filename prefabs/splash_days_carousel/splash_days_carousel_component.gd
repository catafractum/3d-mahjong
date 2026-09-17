class_name SplashDaysCarouselComponent
extends BaseComponent

const DAY_COUNT := 7
const SECONDS_PER_DAY := 86400
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
	var selected := DailyChallengeService._date_key_to_unix(date_key)
	for index in DAY_COUNT:
		var date := Time.get_date_dict_from_unix_time(selected - (DAY_COUNT - 1 - index) * SECONDS_PER_DAY)
		var day := _row.get_child(index)
		day.get_node("Date").text = str(date.day)
		day.get_node("Weekday").text = WEEKDAYS[date.weekday]
		day.get_node("Badge/Tick").visible = is_challenge_completed(date)
	_right.disabled = date_key >= DailyChallengeService.get_today_key()


func is_challenge_completed(date: Dictionary) -> bool:
	return DailyChallengeService.is_completed(DailyChallengeService.date_key_from_dict(date))


func _scroll(direction: int) -> void:
	if _animating:
		return
	var next := DailyChallengeService._unix_to_date_key(DailyChallengeService._date_key_to_unix(_launcher.selected_date_key) + direction * SECONDS_PER_DAY)
	if next > DailyChallengeService.get_today_key():
		return
	_animating = true
	var origin := _row.position
	var step := (_row.size.x + _row.get_theme_constant("separation")) / DAY_COUNT
	if direction < 0:
		_launcher.select_date(next)
		_row.position.x = origin.x - step
	var target_x := origin.x if direction < 0 else origin.x - step
	var tween := create_tween()
	tween.tween_property(_row, "position:x", target_x, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	if direction > 0:
		_launcher.select_date(next)
	_row.position = origin
	_animating = false
