extends Node

class BuilderProbe extends BoardBuilderComponent:
	var built_difficulty := ""

	func build_level(level: Dictionary) -> void:
		built_difficulty = str(level.difficulty)

var failures := 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _ready() -> void:
	for difficulty in ["easy", "medium", "hard"]:
		var unit_time: float = {"easy": 7.0, "medium": 5.0, "hard": 3.0}[difficulty]
		for pairs in [1, 12, 30]:
			var tiles: Array = []
			tiles.resize(pairs * 2)
			_check(GameDB.get_level_time_limit_seconds({"difficulty": difficulty, "tiles": tiles}) == ceilf(pairs * unit_time / 60.0) * 60.0, "Pair-based budget incorrect")
	# Hard: just below, exactly on, and just above a minute boundary.
	for example in [[19, 60.0], [20, 60.0], [21, 120.0]]:
		var tiles: Array = []
		tiles.resize(int(example[0]) * 2)
		_check(GameDB.get_level_time_limit_seconds({"difficulty": "hard", "tiles": tiles}) == example[1], "Minute rounding boundary incorrect")
	var session := GameDB.create_challenge_session("2026-09-10")
	_check(session != null, "Daily challenge could not be created")
	if session == null:
		get_tree().quit(1)
		return
	var easy_budget: float = ceilf(session.levels[0].tiles.size() / 2.0 * 7.0 / 60.0) * 60.0
	_check(session.get_remaining_seconds() == easy_budget, "Easy must use its pair-based budget")
	var timer := GameTimerComponent.new()
	timer.session = session
	timer.reset()
	var builder := BuilderProbe.new()
	var next_menu := NextLevelMenuComponent.new()
	next_menu.menu = preload("res://prefabs/next_level_menu/completion_presentation.gd").new()
	next_menu._session = session
	next_menu._timer = timer
	next_menu._builder = builder
	for difficulty in ["medium", "hard"]:
		var remaining := session.time_limit_seconds - 25.0
		timer._process(25.0)
		_check(session.get_remaining_seconds() == remaining, "Board countdown is incorrect")
		timer.pause()
		timer._process(30.0)
		_check(session.get_remaining_seconds() == remaining, "Inter-board pause consumed time")
		next_menu._request_play()
		_check(builder.built_difficulty == difficulty, "Wrong next difficulty")
		_check(session.get_remaining_seconds() == ceilf(session.get_current_level().tiles.size() / 2.0 * (5.0 if difficulty == "medium" else 3.0) / 60.0) * 60.0, "Next board has the wrong difficulty timer")
		_check(not timer.paused and not timer.finished, "Next board timer did not start")
	var hard_budget: float = ceilf(session.get_current_level().tiles.size() / 2.0 * 3.0 / 60.0) * 60.0
	timer._process(hard_budget + 1.0)
	_check(timer.finished and timer.paused and session.get_remaining_seconds() == 0.0, "Hard did not time out at its calculated limit")
	timer.reset()
	_check(session.get_remaining_seconds() == hard_budget and not timer.finished, "Retry did not restore hard timer")
	session.reset()
	timer.reset()
	_check(session.get_remaining_seconds() == easy_budget, "Challenge replay did not restore easy timer")
	var original_medium := GameDB.medium_seconds_per_pair
	GameDB.medium_seconds_per_pair = 6.5
	var custom := GameDB.create_challenge_session("2026-09-10")
	custom.advance_to_next_level()
	_check(custom.time_limit_seconds == ceilf(custom.get_current_level().tiles.size() / 2.0 * 6.5 / 60.0) * 60.0, "GameDB property did not configure medium timer")
	var splash := preload("res://prefabs/splash_challenge_container/splash_challenge_container.tscn").instantiate()
	add_child(splash)
	var label := splash.get_node("Background/Content/TimerContainer/Time") as Label
	_check(label.text == "7s / 6.5s / 3s", "Menu did not use GameDB timer properties")
	GameDB.medium_seconds_per_pair = original_medium
	splash.queue_free()
	next_menu.menu.free()
	next_menu.free()
	builder.free()
	timer.free()
	print("Per-board timer regression checks: ", "PASS" if failures == 0 else "FAIL")
	get_tree().quit(0 if failures == 0 else 1)
