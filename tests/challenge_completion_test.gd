extends Node

class MemoryStorage extends StorageProvider:
	func save_as_string(_data: String) -> void:
		on_saved.emit()

	func load_as_string() -> void:
		on_loaded.emit("")

	func clear_data() -> void:
		on_cleared.emit()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# Exercise real persistence logic without writing the player's saved game.
	SaveLoadManager.storage_provider = MemoryStorage.new()
	var next_popup := preload("res://prefabs/next_level_menu/next_level_menu.tscn").instantiate()
	var final_popup := preload("res://prefabs/challenge_complete_menu/challenge_complete_menu.tscn").instantiate()
	add_child(next_popup)
	add_child(final_popup)
	await get_tree().process_frame
	var next_menu := NextLevelMenuComponent.of_as(next_popup)
	var final_menu := ChallengeCompleteMenuComponent.of_as(final_popup)
	var timer := GameTimerComponent.new()
	next_menu._timer = timer
	final_menu._timer = timer
	var orders := [
		["easy", "medium", "hard"], ["easy", "hard", "medium"],
		["medium", "easy", "hard"], ["medium", "hard", "easy"],
		["hard", "easy", "medium"], ["hard", "medium", "easy"],
	]
	for order in orders:
		SaveLoadManager.data.completed_challenge_difficulties.clear()
		SaveLoadManager.data.completed_daily_challenges.clear()
		for index in order.size():
			# Return home and choose a difficulty each time, including Easy last.
			var session := GameDB.create_challenge_session("2026-09-20", order[index])
			assert(session.levels.size() == 3 - index)
			next_menu._session = session
			final_menu._session = session
			next_menu._on_level_completed()
			final_menu._on_level_completed()
			assert(next_menu.menu.visible == (index < 2))
			assert(final_menu.menu.visible == (index == 2))
			assert(DailyChallengeService.is_completed("2026-09-20") == (index == 2))
			if index < 2:
				assert(next_menu.menu.title1.text == order[index].to_upper())
				var textures := {
					"easy": next_menu.easy_completion_texture,
					"medium": next_menu.medium_completion_texture,
					"hard": next_menu.hard_completion_texture,
				}
				assert(next_menu.completion_image.texture == textures[order[index]])
			else:
				assert(final_menu.menu.title1.text == "CHALLENGE COMPLETE")
				assert(final_menu.menu.panel.texture.resource_path == "res://assets/images/bg_challenge_completed_level.png")
			next_menu.hide_menu()
			final_menu.hide_menu()
	timer.free()
	next_popup.queue_free()
	final_popup.queue_free()
	await get_tree().create_timer(1.1).timeout
	print("Challenge completion: all six difficulty orders PASS")
	get_tree().quit()
