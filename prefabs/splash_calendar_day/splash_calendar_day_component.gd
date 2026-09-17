class_name SplashCalendarDayComponent
extends BaseComponent

const MONTH_NAMES: Array[String] = [
	"JANUARY",
	"FEBRUARY",
	"MARCH",
	"APRIL",
	"MAY",
	"JUNE",
	"JULY",
	"AUGUST",
	"SEPTEMBER",
	"OCTOBER",
	"NOVEMBER",
	"DECEMBER",
]

const WEEKDAY_NAMES: Array[String] = [
	"SUNDAY",
	"MONDAY",
	"TUESDAY",
	"WEDNESDAY",
	"THURSDAY",
	"FRIDAY",
	"SATURDAY",
]

@export var month_label: Label
@export var weekday_label: Label
@export var day_number_label: Label


func _ready() -> void:
	var launcher := SplashChallengeLauncherComponent.of_as(self)
	launcher.selected_date_changed.connect(_update_date)
	_update_date(launcher.selected_date_key)


func _update_date(date_key: String) -> void:
	var current_date := Time.get_date_dict_from_unix_time(DailyChallengeService._date_key_to_unix(date_key))
	month_label.text = MONTH_NAMES[current_date.month - 1]
	weekday_label.text = WEEKDAY_NAMES[current_date.weekday]
	day_number_label.text = str(current_date.day)
