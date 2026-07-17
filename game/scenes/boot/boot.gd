extends Node2D

@export_file("*.tscn") var splash_scene_path: String


func _ready() -> void:
	var scene_switcher := SceneSwitcherComponent.of_as(self)
	if scene_switcher == null:
		push_error("Boot: SceneSwitcherComponent was not found.")
		return

	SaveLoadManager.load_game()
	await SaveLoadManager.loaded

	scene_switcher.switch_scene(splash_scene_path)
