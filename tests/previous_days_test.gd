extends Node

class MemoryStorage extends StorageProvider:
	var saved_json := ""
	func save_as_string(data: String) -> void:
		saved_json = data
		on_saved.emit()
	func load_as_string() -> void:
		on_loaded.emit(saved_json)
	func clear_data() -> void:
		saved_json = ""
		on_cleared.emit()

class TestDates extends "res://game/daily_challenge/daily_challenge_service.gd":
	var today := "2026-03-01"
	func get_today_key() -> String:
		return today

class SwitcherProbe extends SceneSwitcherComponent:
	var requested_path := ""
	func switch_scene_async(path: String) -> bool:
		requested_path = path
		return true

var failures := 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _click(control: Control) -> void:
	var position := control.get_global_transform() * (control.size * 0.5)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.pressed = pressed
		get_viewport().push_input(event, true)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	# All persistence is isolated from the player's real saved game.
	var original_data := SaveLoadManager.data.to_dict()
	var original_storage := SaveLoadManager.storage_provider
	var memory := MemoryStorage.new()
	SaveLoadManager.storage_provider = memory
	var dates := TestDates.new()
	SaveLoadManager.data.set_from_dict({"version": 1, "completed_daily_challenges": ["2026-02-27", "2026-02-28"]})
	_check(dates.get_current_streak() == 2 and dates.get_best_streak() == 2, "Legacy streak migration failed")
	_check(dates.get_previous_date_keys() == ["2026-02-28", "2026-02-27", "2026-02-26", "2026-02-25", "2026-02-24", "2026-02-23"], "Month boundary dates incorrect")
	_check(dates.complete_challenge("2026-02-26", false), "Catch-up completion failed")
	_check(dates.is_completed("2026-02-26"), "Catch-up completion tick missing")
	_check(dates.get_current_streak() == 2 and dates.get_best_streak() == 2, "Catch-up extended streak")
	_check(not dates.complete_challenge("2026-02-26", false), "Replay duplicated completion")
	SaveLoadManager.data.set_from_json(memory.saved_json)
	_check(dates.is_completed("2026-02-26") and dates.get_best_streak() == 2, "Catch-up persistence changed streak")
	_check(dates.complete_challenge("2026-03-01"), "Today's completion failed")
	_check(dates.get_current_streak() == 3 and dates.get_best_streak() == 3, "Today did not award streak credit")
	dates.today = "2026-03-03"
	_check(dates.complete_challenge("2026-03-02"), "Overnight completion was lost")
	_check(dates.get_current_streak() == 0 and dates.get_best_streak() == 3, "Overnight completion repaired streak")
	dates.today = "2024-03-01"
	_check(dates.get_previous_date_keys()[0] == "2024-02-29", "Leap day missing")
	dates.today = "2026-01-01"
	_check(dates.get_previous_date_keys()[0] == "2025-12-31", "Year boundary incorrect")
	dates.free()

	SaveLoadManager.data.set_from_dict({"version": 2})
	var past := DailyChallengeService.get_previous_date_keys()
	DailyChallengeService.complete_challenge(past[1], false)
	var switcher := SwitcherProbe.new()
	switcher.owner_node_path = NodePath("..")
	switcher.scene_parent_path = NodePath("..")
	add_child(switcher)
	var splash := preload("res://game/scenes/splash/splash.tscn").instantiate()
	add_child(splash)
	await get_tree().process_frame
	await get_tree().process_frame
	var launcher := SplashChallengeLauncherComponent.of_as(splash)
	var carousel := splash.get_node("UI/PortraitUI/SplashDaysCarousel/Components/SplashDaysCarouselComponent") as SplashDaysCarouselComponent
	_check(launcher.selected_date_key == DailyChallengeService.get_today_key(), "Default date is not today")
	_check(carousel._right.disabled, "Future navigation should be disabled")
	carousel._left.pressed.emit()
	await get_tree().create_timer(0.4).timeout
	_check(launcher.selected_date_key == past[0], "Left arrow must move one day")
	var calendar := splash.get_node("UI/PortraitUI/SplashCalendarDay/Components/SplashCalendarDayComponent") as SplashCalendarDayComponent
	var selected := Time.get_date_dict_from_unix_time(DailyChallengeService._date_key_to_unix(past[0]))
	_check(calendar.day_number_label.text == str(selected.day), "Calendar did not follow carousel")
	_check(carousel._row.get_child(6).get_node("Date").text == str(selected.day), "Rightmost day differs from selection")
	carousel._right.pressed.emit()
	await get_tree().create_timer(0.4).timeout
	_check(launcher.selected_date_key == DailyChallengeService.get_today_key(), "Right arrow must return to today")
	for difficulty in GameDB.challenge_difficulties:
		var session := GameDB.create_challenge_session(past[0], difficulty)
		_check(session.levels.size() == 1 and session.get_current_level().difficulty == difficulty, "Wrong difficulty selected")
		_check(session.challenge_date_key == past[0] and session.is_catch_up, "Wrong session date")
		_check(session.time_limit_seconds == GameDB.get_level_time_limit_seconds(session.get_current_level()), "Wrong time limit")
	SaveLoadManager.data.set_from_dict({"version": 2})
	DailyChallengeService.complete_difficulty(past[0], "easy", false)
	_check(not DailyChallengeService.is_completed(past[0]), "One difficulty completed the whole day")
	DailyChallengeService.complete_difficulty(past[0], "medium", false)
	SaveLoadManager.data.set_from_json(memory.saved_json)
	DailyChallengeService.complete_difficulty(past[0], "hard", false)
	_check(DailyChallengeService.is_completed(past[0]), "All difficulties did not complete the day")
	launcher.select_date(past[0])
	var play := splash.get_node("UI/PortraitUI/SplashChallengeContainer/Background/Content/Hard/PlayButton") as BaseButton
	play.pressed.emit()
	_check(GameDB.current_session != null and GameDB.current_session.challenge_date_key == past[0] and GameDB.current_session.get_current_level().difficulty == "hard", "Play launched wrong game")
	var original_session := GameDB.current_session
	play.pressed.emit()
	_check(GameDB.current_session == original_session, "Double click started a second session")
	SaveLoadManager.data.set_from_dict(original_data)
	SaveLoadManager.storage_provider = original_storage
	GameDB.current_session = null
	print("Previous days regression checks: ", "PASS" if failures == 0 else "FAIL")
	get_tree().quit(0 if failures == 0 else 1)
