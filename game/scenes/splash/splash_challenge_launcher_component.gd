class_name SplashChallengeLauncherComponent
extends BaseComponent

@export_file("*.tscn") var game_scene_path: String
@export var loading_control: Control
@export var spinner: TextureRect
@export var previous_days_popup: Control
@export var spinner_speed_degrees := 240.0

var _is_loading := false


func _process(delta: float) -> void:
	if _is_loading and spinner != null:
		spinner.rotation += deg_to_rad(spinner_speed_degrees) * delta


func show_previous_days() -> void:
	if not _is_loading:
		PreviousDaysPopupComponent.of_as(previous_days_popup).show_menu()


func start_challenge(date_key: String) -> void:
	if _is_loading:
		return
	if date_key != DailyChallengeService.get_today_key() and date_key not in DailyChallengeService.get_previous_date_keys():
		return
	GameDB.current_session = GameDB.create_challenge_session(date_key)
	if GameDB.current_session == null:
		return
	_is_loading = true
	loading_control.show()
	loading_control.move_to_front()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var switcher := SceneSwitcherComponent.of_as(self)
	if switcher == null or not await switcher.switch_scene_async(game_scene_path):
		push_error("SplashChallengeLauncherComponent: Could not open the challenge.")
		GameDB.current_session = null
		_is_loading = false
		loading_control.hide()


static func of_as(node: Node) -> SplashChallengeLauncherComponent:
	return BaseComponent.of(node, SplashChallengeLauncherComponent) as SplashChallengeLauncherComponent
