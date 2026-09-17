class_name SplashChallengeContainerComponent
extends BaseComponent

var _launcher: SplashChallengeLauncherComponent


func _ready() -> void:
	_launcher = SplashChallengeLauncherComponent.of_as(self)
	for difficulty in GameDB.challenge_difficulties:
		get_node("../../Background/Content/%s/PlayButton" % difficulty.capitalize()).pressed.connect(_play.bind(difficulty))
	_launcher.selected_date_changed.connect(_update_date)
	_update_date(_launcher.selected_date_key)


func _update_date(date_key: String) -> void:
	var session := GameDB.create_challenge_session(date_key)
	if session == null:
		return
	for level in session.levels:
		var seconds := int(level.time_limit_seconds)
		get_node("../../Background/Content/%s/Details/Time" % str(level.difficulty).capitalize()).text = "Complete in %d:%02d" % [seconds / 60, seconds % 60]


func _play(difficulty: String) -> void:
	_launcher.start_challenge(_launcher.selected_date_key, difficulty)
