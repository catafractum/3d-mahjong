class_name NextLevelMenuComponent
extends BaseComponent

signal play_requested

@export var menu: Control
@export var home_button: BaseButton
@export var play_button: BaseButton
@export var button_label: Label
@export var completion_image: TextureRect
@export var easy_completion_texture: Texture2D
@export var medium_completion_texture: Texture2D
@export var hard_completion_texture: Texture2D
@export_file("*.mp3", "*.wav", "*.ogg") var popup_sfx_path: String
@export var show_delay := 1.0

var _session: GameSession
var _builder: BoardBuilderComponent
var _timer: GameTimerComponent


func _ready() -> void:
	play_button.pressed.connect(_request_play)
	home_button.pressed.connect(_request_home)
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
	if _session == null or not _session.has_next_level():
		return
	_timer.pause()
	var next_level := _session.levels[_session.current_level_index + 1]
	show_menu(str(next_level.get("difficulty", "next")))


func _request_home() -> void:
	GameDB.current_session = null
	SceneSwitcherComponent.of_as(self).switch_scene("res://game/scenes/splash/splash.tscn")


func _request_play() -> void:
	if _session != null and _session.advance_to_next_level():
		hide_menu()
		_builder.build_level(_session.get_current_level())
		_timer.reset()
	play_requested.emit()


func show_menu(next_difficulty: String) -> void:
	SoundManager.play_sfx(popup_sfx_path)
	button_label.text = "PLAY %s" % next_difficulty.to_upper()
	var difficulty := (
		str(_session.get_current_level().get("difficulty", "easy")) if _session != null else "easy"
	)
	completion_image.texture = (
		hard_completion_texture
		if difficulty.to_lower() == "hard"
		else (
			medium_completion_texture
			if difficulty.to_lower() == "medium"
			else easy_completion_texture
		)
	)
	menu.present(difficulty, show_delay)


func hide_menu() -> void:
	menu.dismiss()


static func of_as(node: Node) -> NextLevelMenuComponent:
	return BaseComponent.of(node, NextLevelMenuComponent) as NextLevelMenuComponent
