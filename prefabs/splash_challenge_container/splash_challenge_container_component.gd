class_name SplashChallengeContainerComponent
extends BaseComponent

@export_file("*.tscn") var game_scene_path: String
@export var play_button: TextureButton
@export var spinner_speed_degrees := 240.0

var _loading_control: Control
var _spinner: TextureRect
var _is_loading := false


func _ready() -> void:
	play_button.pressed.connect(_on_play_button_pressed)
	_loading_control = _find_loading_control()
	if _loading_control != null:
		_spinner = _loading_control.find_child("TextureRect", true, false) as TextureRect


func _process(delta: float) -> void:
	if _is_loading and _spinner != null:
		_spinner.rotation += deg_to_rad(spinner_speed_degrees) * delta


func _on_play_button_pressed() -> void:
	if _is_loading:
		return

	GameDB.current_session = GameDB.create_challenge_session(
		DailyChallengeService.get_today_key()
	)
	if GameDB.current_session == null:
		push_error("SplashChallengeContainerComponent: Could not create challenge session.")
		return

	_is_loading = true
	play_button.disabled = true
	if _loading_control != null:
		_loading_control.show()
		_loading_control.move_to_front()

	# Wait until the overlay is actually presented before the synchronous web load begins.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var scene_switcher := SceneSwitcherComponent.of_as(self)
	if scene_switcher == null:
		push_error("SplashChallengeContainerComponent: SceneSwitcherComponent was not found.")
		_finish_failed_load()
		return

	var switched := await scene_switcher.switch_scene_async(game_scene_path)
	if not switched:
		_finish_failed_load()


func _find_loading_control() -> Control:
	var current := get_parent()
	while current != null:
		var loading := current.get_node_or_null("UI/Loading") as Control
		if loading != null:
			return loading
		current = current.get_parent()
	return null


func _finish_failed_load() -> void:
	_is_loading = false
	play_button.disabled = false
	if _loading_control != null:
		_loading_control.hide()
