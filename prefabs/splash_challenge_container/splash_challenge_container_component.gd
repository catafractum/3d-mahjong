class_name SplashChallengeContainerComponent
extends BaseComponent

const SHORT_MONTH_NAMES: Array[String] = [
	"JAN", "FEB", "MAR", "APR", "MAY", "JUNE",
	"JULY", "AUG", "SEPT", "OCT", "NOV", "DEC",
]

var _launcher: SplashChallengeLauncherComponent


func _ready() -> void:
	_launcher = SplashChallengeLauncherComponent.of_as(self)
	for difficulty in GameDB.challenge_difficulties:
		get_node("../../Background/Content/%s/PlayButton" % difficulty.capitalize()).pressed.connect(_play.bind(difficulty))
	_launcher.selected_date_changed.connect(_update_date)
	_update_date(_launcher.selected_date_key)


func _update_date(date_key: String) -> void:
	get_node("../../Background/Content/TitleContainer/Title").text = _get_challenge_title(date_key)
	var session := GameDB.create_challenge_session(date_key)
	if session == null:
		return
	var completed: Array = SaveLoadManager.data.completed_challenge_difficulties.get(date_key, [])
	for level in session.levels:
		get_node("../../Background/Content/%s/CompletionSlot/Completed" % str(level.difficulty).capitalize()).visible = level.difficulty in completed
		var seconds := int(level.time_limit_seconds)
		var minutes := int(ceil(float(seconds) / 60.0))
		get_node("../../Background/Content/%s/Details/Time" % str(level.difficulty).capitalize()).text = "Complete in %d min." % minutes


func _get_challenge_title(date_key: String) -> String:
	if date_key == DailyChallengeService.get_today_key():
		return "TODAY'S CHALLENGE"
	var date := Time.get_date_dict_from_unix_time(DailyChallengeService._date_key_to_unix(date_key))
	return "%s %d - CHALLENGE" % [SHORT_MONTH_NAMES[date.month - 1], int(date.day)]


func _play(difficulty: String) -> void:
	_launcher.start_challenge(_launcher.selected_date_key, difficulty)
