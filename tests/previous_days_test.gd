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
	var popup := splash.get_node("UI/PreviousDaysPopup") as Control
	var component := PreviousDaysPopupComponent.of_as(popup)
	_check(not popup.visible, "Popup should start closed")
	var opener := splash.get_node("UI/PortraitUI/SplashDaysCarousel/PreviousDaysButton/Button") as Button
	opener.pressed.emit()
	_check(popup.visible, "Previous days entry point did not open popup")
	_check(component._rows.size() == 6, "Popup must have six rows")
	for index in 6:
		_check(component._rows[index].date_key == past[index], "Rows are not newest first")
	_check(component._rows[1].completion_tick.visible and component._rows[1].play_label.text == "PLAY AGAIN", "Completed row not replayable")
	_check(not component._rows[0].completion_tick.visible and component._rows[0].play_label.text == "PLAY", "Unplayed row incorrect")
	component.close_button.pressed.emit()
	_check(not popup.visible, "Close did not hide popup")
	component.show_menu()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	component._unhandled_input(escape)
	_check(not popup.visible, "Escape did not close popup")
	component.show_menu()
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	get_viewport().push_input(tab, true)
	_check(get_viewport().gui_get_focus_owner() == component._rows[0].play_button, "Keyboard focus escaped the popup")
	component._today_key = "stale"
	component._process(0.0)
	_check(component._today_key == DailyChallengeService.get_today_key(), "Popup did not refresh on date change")

	var launcher := SplashChallengeLauncherComponent.of_as(splash)
	launcher.start_challenge("1900-01-01")
	_check(GameDB.current_session == null, "Out-of-window date was playable")

	if "--capture" in OS.get_cmdline_user_args():
		for window_size in [Vector2i(540, 1080), Vector2i(1280, 720)]:
			get_window().size = window_size
			for frame in 4:
				await get_tree().process_frame
			_click(component.close_button)
			_check(not popup.visible, "Pointer click did not close popup")
			var layout := "PortraitUI" if window_size.x < window_size.y else "LandscapeUI/Section"
			var visible_opener := splash.get_node("UI/%s/SplashDaysCarousel/PreviousDaysButton/Button" % layout) as Control
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/previous-days-menu-%s.png" % window_size.x)
			_click(visible_opener)
			_check(popup.visible, "Pointer click did not open popup")
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("/tmp/previous-days-%s.png" % window_size.x)

	if "--capture" in OS.get_cmdline_user_args():
		_click(component._rows[0].play_button)
	else:
		component._rows[0].play_button.pressed.emit()
	_check(GameDB.current_session != null and GameDB.current_session.challenge_date_key == past[0], "Row launched wrong date")
	_check(GameDB.current_session.is_catch_up, "Past session missing catch-up flag")
	_check(GameDB.current_session.time_limit_seconds == GameDB.easy_time_limit_seconds, "Past challenge has wrong timer")
	var original_session := GameDB.current_session
	component._rows[2].play_button.pressed.emit()
	_check(GameDB.current_session == original_session, "Double click started a second session")
	if "--capture" in OS.get_cmdline_user_args():
		for frame in 4:
			await get_tree().process_frame
		_check(switcher.requested_path == "res://game/scenes/game/game.tscn", "Catch-up did not request game scene")
	_check(not GameDB.create_challenge_session().is_catch_up, "Today marked as catch-up")
	SaveLoadManager.data.set_from_dict(original_data)
	SaveLoadManager.storage_provider = original_storage
	GameDB.current_session = null
	print("Previous days regression checks: ", "PASS" if failures == 0 else "FAIL")
	get_tree().quit(0 if failures == 0 else 1)
