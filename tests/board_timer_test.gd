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
	var session := GameDB.create_challenge_session("2026-09-10")
	_check(session != null, "Daily challenge could not be created")
	if session == null:
		get_tree().quit(1)
		return
	_check(session.get_remaining_seconds() == 180.0, "Easy must start with three minutes")
	var timer := GameTimerComponent.new()
	timer.session = session
	timer.reset()
	var builder := BuilderProbe.new()
	var next_menu := NextLevelMenuComponent.new()
	next_menu.menu = Control.new()
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
		_check(session.get_remaining_seconds() == (120.0 if difficulty == "medium" else 90.0), "Next board has the wrong difficulty timer")
		_check(not timer.paused and not timer.finished, "Next board timer did not start")
	timer._process(91.0)
	_check(timer.finished and timer.paused and session.get_remaining_seconds() == 0.0, "Hard did not time out at 90 seconds")
	timer.reset()
	_check(session.get_remaining_seconds() == 90.0 and not timer.finished, "Retry did not restore hard timer")
	session.reset()
	timer.reset()
	_check(session.get_remaining_seconds() == 180.0, "Challenge replay did not restore easy timer")
	var original_medium := GameDB.medium_time_limit_seconds
	GameDB.medium_time_limit_seconds = 135.0
	var custom := GameDB.create_challenge_session("2026-09-10")
	custom.advance_to_next_level()
	_check(custom.time_limit_seconds == 135.0, "GameDB property did not configure medium timer")
	var splash := preload("res://prefabs/splash_challenge_container/splash_challenge_container.tscn").instantiate()
	add_child(splash)
	var label := splash.get_node("Background/Content/TimerContainer/Time") as Label
	_check(label.text == "03:00 / 02:15 / 01:30", "Menu did not use GameDB timer properties")
	GameDB.medium_time_limit_seconds = original_medium
	splash.queue_free()
	next_menu.menu.free()
	next_menu.free()
	builder.free()
	timer.free()
	print("Per-board timer regression checks: ", "PASS" if failures == 0 else "FAIL")
	get_tree().quit(0 if failures == 0 else 1)
