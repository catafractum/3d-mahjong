extends Control

const DAY_COUNT := 7
const WEEKDAY_ABBREVIATIONS := [
	"MON",
	"TUE",
	"WED",
	"THU",
	"FRI",
	"SAT",
	"SUN",
]
const DAY_LABEL_COLOR := Color(0.768627, 0.623529, 0.933333, 1.0)
const DAY_LABEL_FONT_SIZE := 18
const BADGE_EMPTY_TEXTURE: Texture2D = preload("res://assets/images/splash/badge_empty.png")
const DAY_LABEL_FONT: FontFile = preload("res://assets/fonts/Montserrat-SemiBold.ttf")

@onready var days_row: HBoxContainer = %DaysRow

func _ready() -> void:
	_refresh_days()

func _refresh_days() -> void:
	for child in days_row.get_children():
		days_row.remove_child(child)
		child.free()

	var today := Time.get_datetime_dict_from_system()
	var today_julian := _date_to_julian(today.year, today.month, today.day)

	for index in DAY_COUNT:
		var days_before_today := DAY_COUNT - 1 - index
		var date := _date_from_julian(today_julian - days_before_today)
		var weekday_index := _get_monday_based_weekday(date.year, date.month, date.day)
		days_row.add_child(_create_day_slot(WEEKDAY_ABBREVIATIONS[weekday_index]))

func _create_day_slot(weekday: String) -> VBoxContainer:
	var slot := VBoxContainer.new()
	slot.custom_minimum_size = Vector2(50, 82)
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.alignment = BoxContainer.ALIGNMENT_CENTER
	slot.add_theme_constant_override("separation", 4)

	var weekday_label := Label.new()
	weekday_label.custom_minimum_size = Vector2(50, 24)
	weekday_label.text = weekday
	weekday_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weekday_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	weekday_label.label_settings = _create_day_label_settings()
	slot.add_child(weekday_label)

	var badge := TextureRect.new()
	badge.custom_minimum_size = Vector2(46, 47)
	badge.texture = BADGE_EMPTY_TEXTURE
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.add_child(badge)

	return slot

func _create_day_label_settings() -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font = DAY_LABEL_FONT
	settings.font_size = DAY_LABEL_FONT_SIZE
	settings.font_color = DAY_LABEL_COLOR
	return settings

func _date_to_julian(year: int, month: int, day: int) -> int:
	var adjusted_year := year
	var adjusted_month := month
	if adjusted_month <= 2:
		adjusted_year -= 1
		adjusted_month += 12

	var century := int(adjusted_year / 100.0)
	var leap_correction := 2 - century + int(century / 4.0)
	return int(365.25 * float(adjusted_year + 4716)) + int(30.6001 * float(adjusted_month + 1)) + day + leap_correction - 1524

func _date_from_julian(julian_day: int) -> Dictionary:
	var a := julian_day + 32044
	var b := int((4 * a + 3) / 146097.0)
	var c := a - int((146097 * b) / 4.0)
	var d := int((4 * c + 3) / 1461.0)
	var e := c - int((1461 * d) / 4.0)
	var m := int((5 * e + 2) / 153.0)

	var day := e - int((153 * m + 2) / 5.0) + 1
	var month := m + 3 - 12 * int(m / 10.0)
	var year := 100 * b + d - 4800 + int(m / 10.0)

	return {
		"year": year,
		"month": month,
		"day": day,
	}

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
