class_name ChallengeCompleteMenuComponent
extends BaseComponent

signal home_requested
signal replay_requested

@export var menu: Control
@export var home_button: BaseButton
@export var replay_button: BaseButton
@export_file("*.tscn") var splash_scene_path: String
@export_file("*.mp3", "*.wav", "*.ogg") var popup_sfx_path: String

var _session: GameSession
var _builder: BoardBuilderComponent
var _timer: GameTimerComponent


func _ready() -> void:
	home_button.pressed.connect(_request_home)
	replay_button.pressed.connect(_request_replay)
	_initialize.call_deferred()


func _initialize() -> void:
	var session_component := CurrentGameSessionComponent.of_as(self)
	var interaction := BoardInteractionComponent.of_as(self)
	_builder = BoardBuilderComponent.of_as(self)
	_timer = GameTimerComponent.of_as(self)
	if session_component == null or session_component.session == null or interaction == null:
		return
	_session = session_component.session
	interaction.level_completed.connect(_on_level_completed)


func _on_level_completed() -> void:
	if _session == null or _session.has_next_level():
		return
	_timer.pause()
	_session.status = GameSession.Status.COMPLETED
	show_menu()


func _request_home() -> void:
	GameDB.current_session = null
	SceneSwitcherComponent.of_as(self).switch_scene(splash_scene_path)
	home_requested.emit()


func _request_replay() -> void:
	hide_menu()
	_session.reset()
	_session.status = GameSession.Status.PLAYING
	_builder.build_level(_session.get_current_level())
	_timer.reset()
	replay_requested.emit()


func show_menu() -> void:
	SoundManager.play_sfx(popup_sfx_path)
	menu.show()


func hide_menu() -> void:
	menu.hide()


static func of_as(node: Node) -> ChallengeCompleteMenuComponent:
	return BaseComponent.of(node, ChallengeCompleteMenuComponent) as ChallengeCompleteMenuComponent
