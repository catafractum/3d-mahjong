extends Node2D

@export_file("*.tscn") var splash_scene_path: String
@export_file("*.tscn") var game_scene_path: String
@export_file("*.tscn") var tile_scene_path: String
@export_file("*.tscn") var particles_scene_path: String
@export var spinner: TextureRect
@export var warmup_root: Node3D
@export var spinner_speed_degrees := 240.0

var _cached_resources: Array[Resource] = []
var _is_loading := true


func _process(delta: float) -> void:
	if _is_loading and spinner != null:
		spinner.rotation += deg_to_rad(spinner_speed_degrees) * delta


func _ready() -> void:
	# Present the project-owned boot screen before any synchronous web loading.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var scene_switcher := SceneSwitcherComponent.of_as(self)
	if scene_switcher == null:
		push_error("Boot: SceneSwitcherComponent was not found.")
		return

	SaveLoadManager.load_game()
	await SaveLoadManager.loaded
	await _cache_game_resources()
	await _warm_up_game_rendering()

	_is_loading = false
	scene_switcher.switch_scene(splash_scene_path)
	$BootUI.hide()


func _cache_game_resources() -> void:
	for path in [tile_scene_path, particles_scene_path, game_scene_path]:
		if path.is_empty():
			continue
		var resource := load(path)
		if resource == null:
			push_error("Boot: Could not preload resource: ", path)
			continue
		_cached_resources.append(resource)
		# Give the browser a frame between synchronous resource groups.
		await get_tree().process_frame


func _warm_up_game_rendering() -> void:
	if warmup_root == null:
		return
	for resource in _cached_resources:
		if not resource is PackedScene:
			continue
		var packed_scene := resource as PackedScene
		if resource.resource_path not in [tile_scene_path, particles_scene_path]:
			continue
		var instance := packed_scene.instantiate() as Node3D
		if instance != null:
			warmup_root.add_child(instance)

	# Rendering, rather than loading alone, is what warms WebGL shader variants.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	for child in warmup_root.get_children():
		child.queue_free()
