class_name SplashDaysCarouselComponent
extends BaseComponent

const DAY_COUNT := 7
const SECONDS_PER_DAY := 86400
const WEEKDAY_ABBREVIATIONS: Array[String] = [
	"SUN",
	"MON",
	"TUE",
	"WED",
	"THU",
	"FRI",
	"SAT",
]

@export var weekday_labels: Array[Label]
@export var completion_ticks: Array[TextureRect]


func _ready() -> void:
	var today := Time.get_date_dict_from_system()
	var today_unix := Time.get_unix_time_from_datetime_dict({
		"year": today.year,
		"month": today.month,
		"day": today.day,
		"hour": 0,
		"minute": 0,
		"second": 0,
	})

	for index in mini(DAY_COUNT, weekday_labels.size()):
		var days_before_today := DAY_COUNT - 1 - index
		var date := Time.get_date_dict_from_unix_time(
			today_unix - days_before_today * SECONDS_PER_DAY
		)
		weekday_labels[index].text = WEEKDAY_ABBREVIATIONS[date.weekday]
		if index < completion_ticks.size():
			completion_ticks[index].visible = is_challenge_completed(date)


func is_challenge_completed(_date: Dictionary) -> bool:
	return true
