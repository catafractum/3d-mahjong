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
	var completed: Array = SaveLoadManager.data.completed_challenge_difficulties.get(date_key, [])
	for level in session.levels:
		get_node("../../Background/Content/%s/CompletionSlot/Completed" % str(level.difficulty).capitalize()).visible = level.difficulty in completed
		var seconds := int(level.time_limit_seconds)
		var minutes := int(ceil(float(seconds) / 60.0))
		get_node("../../Background/Content/%s/Details/Time" % str(level.difficulty).capitalize()).text = "Complete in %d min." % minutes


func _play(difficulty: String) -> void:
	_launcher.start_challenge(_launcher.selected_date_key, difficulty)
