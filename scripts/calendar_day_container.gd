extends Control

const MONTH_NAMES := [
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

const WEEKDAY_NAMES := [
	"MONDAY",
	"TUESDAY",
	"WEDNESDAY",
	"THURSDAY",
	"FRIDAY",
	"SATURDAY",
	"SUNDAY",
]

@onready var month_label: Label = %MonthLabel
@onready var week_day_label: Label = %WeekDayLabel
@onready var day_number_label: Label = %DayNumberLabel

var current_year: int
var current_month: int
var current_day: int

func _ready() -> void:
	if current_year == 0:
		var date := Time.get_datetime_dict_from_system()
		set_calendar_date(date.year, date.month, date.day, false)

func set_calendar_date(year: int, month: int, day: int, animated: bool = true) -> void:
	var previous_month := current_month
	var previous_year := current_year

	current_year = year
	current_month = month
	current_day = day

	var labels: Array[Label] = [week_day_label, day_number_label]
	if previous_month != month or previous_year != year:
		labels = [month_label, week_day_label, day_number_label]

	if animated:
		_transition_date_labels(labels)
	else:
		_refresh_date_labels()

func _refresh_date_labels() -> void:
	month_label.text = MONTH_NAMES[clampi(current_month - 1, 0, MONTH_NAMES.size() - 1)]
	week_day_label.text = WEEKDAY_NAMES[_get_monday_based_weekday(current_year, current_month, current_day)]
	day_number_label.text = str(current_day)

func _transition_date_labels(labels: Array[Label]) -> void:
	for label in [month_label, week_day_label, day_number_label]:
		if label != null:
			var tween := label.get_meta("date_tween", null) as Tween
			if tween != null:
				tween.kill()

	var fade_out := create_tween()
	for label in labels:
		fade_out.parallel().tween_property(label, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	fade_out.finished.connect(func() -> void:
		_refresh_date_labels()

		var fade_in := create_tween()
		for label in labels:
			fade_in.parallel().tween_property(label, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			label.set_meta("date_tween", fade_in)
	)

	for label in labels:
		label.set_meta("date_tween", fade_out)

func _get_monday_based_weekday(year: int, month: int, day: int) -> int:
	var adjusted_month := month
	var adjusted_year := year
	if adjusted_month < 3:
		adjusted_month += 12
		adjusted_year -= 1

	var k := adjusted_year % 100
	var j := int(adjusted_year / 100.0)
	var h := (day + int((13 * (adjusted_month + 1)) / 5.0) + k + int(k / 4.0) + int(j / 4.0) + (5 * j)) % 7
	var sunday_based := (h + 6) % 7
	return (sunday_based + 6) % 7
