class_name DayRowComponent
extends BaseComponent

signal play_requested(date_key: String)

@export var date_label: Label
@export var weekday_label: Label
@export var completion_tick: TextureRect
@export var play_button: BaseButton
@export var play_label: Label

var date_key := ""


func _ready() -> void:
	play_button.pressed.connect(func(): play_requested.emit(date_key))


func configure(key: String) -> void:
	date_key = key
	var date := Time.get_date_dict_from_unix_time(Time.get_unix_time_from_datetime_string(key + "T00:00:00"))
	date_label.text = "%s %02d" % [SplashCalendarDayComponent.MONTH_NAMES[date.month - 1].capitalize(), date.day]
	weekday_label.text = SplashCalendarDayComponent.WEEKDAY_NAMES[date.weekday].capitalize()
	var completed := DailyChallengeService.is_completed(key)
	completion_tick.visible = completed
	play_label.text = "PLAY AGAIN" if completed else "PLAY"


static func of_as(node: Node) -> DayRowComponent:
	return BaseComponent.of(node, DayRowComponent) as DayRowComponent
