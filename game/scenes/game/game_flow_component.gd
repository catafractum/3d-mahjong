class_name GameFlowComponent
extends BaseComponent

@export_file("*.tscn") var splash_scene_path: String
@export var settings_menu_node: CanvasLayer
@export var next_level_menu_node: CanvasLayer
@export var game_over_menu_node: CanvasLayer
@export var challenge_complete_menu_node: CanvasLayer

var session: GameSession
var builder: BoardBuilderComponent
var timer: GameTimerComponent
var settings_menu: GameSettingsMenuComponent
var next_level_menu: NextLevelMenuComponent
var game_over_menu: GameOverMenuComponent
var challenge_complete_menu: ChallengeCompleteMenuComponent


func _ready() -> void:
	_initialize.call_deferred()


func _initialize() -> void:
	var session_component := CurrentGameSessionComponent.of_as(self)
	builder = BoardBuilderComponent.of_as(self)
	timer = GameTimerComponent.of_as(self)
	settings_menu = GameSettingsMenuComponent.of_as(settings_menu_node)
	next_level_menu = NextLevelMenuComponent.of_as(next_level_menu_node)
	game_over_menu = GameOverMenuComponent.of_as(game_over_menu_node)
	challenge_complete_menu = ChallengeCompleteMenuComponent.of_as(challenge_complete_menu_node)
	if session_component == null or session_component.session == null \
		or builder == null or timer == null or settings_menu == null \
		or next_level_menu == null or game_over_menu == null or challenge_complete_menu == null:
		push_error("GameFlowComponent: Required game or menu components were not found.")
		return
	session = session_component.session
	var interaction := BoardInteractionComponent.of_as(self)
	interaction.level_completed.connect(_on_level_completed)
	timer.timer_finished.connect(_on_timer_finished)
	settings_menu.reset_requested.connect(_reset_current_level)
	settings_menu.home_requested.connect(_go_home)
	next_level_menu.play_requested.connect(_play_next_level)
	game_over_menu.home_requested.connect(_go_home)
	game_over_menu.replay_requested.connect(_replay_current_level)
	challenge_complete_menu.home_requested.connect(_go_home)
	challenge_complete_menu.replay_requested.connect(_replay_challenge)


func _on_level_completed() -> void:
	timer.pause()
	Soundmanager.play_popup_sfx()
	if session.has_next_level():
		var next_level := session.levels[session.current_level_index + 1]
		next_level_menu.show_menu(str(next_level.get("difficulty", "next")))
	else:
		session.status = GameSession.Status.COMPLETED
		challenge_complete_menu.show_menu()


func _on_timer_finished() -> void:
	session.status = GameSession.Status.FAILED
	Soundmanager.play_popup_sfx()
	game_over_menu.show_menu()


func _play_next_level() -> void:
	if not session.advance_to_next_level():
		return
	next_level_menu.hide_menu()
	builder.build_level(session.get_current_level())
	timer.resume()


func _reset_current_level() -> void:
	builder.build_level(session.get_current_level())
	timer.resume()


func _replay_current_level() -> void:
	game_over_menu.hide_menu()
	session.status = GameSession.Status.PLAYING
	builder.build_level(session.get_current_level())
	timer.reset()


func _replay_challenge() -> void:
	challenge_complete_menu.hide_menu()
	session.reset()
	session.status = GameSession.Status.PLAYING
	builder.build_level(session.get_current_level())
	timer.reset()


func _go_home() -> void:
	GameDB.current_session = null
	SceneSwitcherComponent.of_as(self).switch_scene(splash_scene_path)
