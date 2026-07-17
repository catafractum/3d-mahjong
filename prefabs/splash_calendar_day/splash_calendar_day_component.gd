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
	var current_date := Time.get_datetime_dict_from_system()
	month_label.text = MONTH_NAMES[current_date.month - 1]
	weekday_label.text = WEEKDAY_NAMES[current_date.weekday]
	day_number_label.text = str(current_date.day)
