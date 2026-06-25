extends Node3D

const LEVEL_EDITOR_SCENE := "res://scenes/level_editor.tscn"
const DIFFICULTIES := ["easy", "medium", "hard"]
const EDITOR_CONTROLS_Y := 124.0
const BOARD_INITIAL_ROTATION_DEGREES := Vector3(0.0, -10.0, 0.0)
const LEVEL_COMPLETE_MENU_DELAY := 0.9
const ROTATION_BUTTON_FADE_DURATION := 0.22
const ROTATION_BUTTON_MOBILE_ASPECT := 5.0 / 7.0
const ROTATION_BUTTON_DESKTOP_ASPECT := 16.0 / 9.0
const ROTATION_BUTTON_DESKTOP_SCALE := 2.25
const ROTATION_BUTTON_BASE_SIDE_MARGIN := 25.0
const TIMER_PORTRAIT_SCALE := 1.5
const TIMER_DESKTOP_SCALE := 2.5
const LEVEL_COMPLETE_OVERLAY_FADE_IN_DURATION := 0.3
const LEVEL_COMPLETE_OVERLAY_FADE_OUT_DURATION := 0.2
const NEXT_LEVEL_BUTTON_HOVER_SCALE := 1.025
const GAME_OVER_BUTTON_HOVER_SCALE := 1.05
const NEXT_LEVEL_BG_PATHS := {
	"easy": "res://assets/images/bg_next_level_easy.png",
	"medium": "res://assets/images/bg_next_level_medium.png",
}
const BTN_PLAY_HARD_PATH := "res://assets/images/buttons/btn_play_hard.png"
const NEXT_LEVEL_BUTTON_HARD_DOWN_OFFSET := 70.0
const SPLASH_SCENE := "res://scenes/splash_scene.tscn"

@export var level_id := 20

@onready var camera: Camera3D = $Camera3D
@onready var board_container: Node3D = $BoardContainer
@onready var board_manager: Node = $BoardManager
@onready var gui: Control = $GUI/Control
@onready var timer_container: Control = $GUI/Control/TimerContainer
@onready var right_arrow_btn: TextureButton = $GUI/Control/RightArrowBtn
@onready var left_arrow_btn: TextureButton = $GUI/Control/LeftArrowBtn
@onready var shuffle_btn: TextureButton = $GUI/Control/ShuffleBtn
@onready var level_complete_overlay: ColorRect = $GUI/Control/LevelCompleteOverlay
@onready var next_level_menu: Control = $GUI/Control/NextLevelMenu
@onready var next_level_panel: TextureRect = $GUI/Control/NextLevelMenu/Panel
@onready var next_level_button: TextureButton = $GUI/Control/NextLevelMenu/Panel/PlayNextLevelBtn
@onready var next_level_button_label: Label = $GUI/Control/NextLevelMenu/Panel/PlayNextLevelBtn/ButtonLabel
@onready var game_over_menu: Control = $GUI/Control/GameOverMenu
@onready var game_over_home_button: TextureButton = $GUI/Control/GameOverMenu/Panel/HomeButton
@onready var game_over_replay_button: TextureButton = $GUI/Control/GameOverMenu/Panel/ReplayButton
@onready var challenge_completed_menu: Control = $GUI/Control/ChallengeCompletedMenu
@onready
var challenge_completed_home_button: TextureButton = $GUI/Control/ChallengeCompletedMenu/Panel/HomeButton
@onready
var challenge_completed_play_again_button: TextureButton = $GUI/Control/ChallengeCompletedMenu/Panel/PlayAgainButton

var _level_label: Label
var _next_level_id := 0
var _menu_tween: Tween
var _game_over_menu_tween: Tween
var _challenge_completed_menu_tween: Tween
var _level_complete_overlay_tween: Tween
var _rotation_buttons_tween: Tween
var _rotation_button_layouts: Dictionary = {}
var _timer_layout: Dictionary = {}
var _next_level_button_base_scale := Vector2.ONE
var _next_level_button_scale_tween: Tween
var _next_level_button_hovered := false
var _next_level_button_default_texture: Texture2D
var _next_level_button_default_offset_top := 0.0
var _next_level_button_default_offset_bottom := 0.0
var _game_over_home_button_base_scale := Vector2.ONE
var _game_over_replay_button_base_scale := Vector2.ONE
var _game_over_home_button_scale_tween: Tween
var _game_over_replay_button_scale_tween: Tween
var _challenge_completed_home_button_base_scale := Vector2.ONE
var _challenge_completed_play_again_button_base_scale := Vector2.ONE
var _challenge_completed_home_button_scale_tween: Tween
var _challenge_completed_play_again_button_scale_tween: Tween
var _level_complete_token := 0
var _is_game_over := false
var _is_challenge_completed := false


func _enter_tree() -> void:
	level_id = GameState.selected_level_id


func _ready() -> void:
	_build_editor_controls()
	board_container.tile_selected.connect(board_manager.on_tile_selected)
	board_container.board_ready.connect(board_manager.on_board_ready)
	board_manager.on_board_ready(board_container.get_tiles())
	board_manager.level_completed.connect(_on_level_completed)
	board_container.layer_rotated.connect(
		func(axis, value, angle, visual_offset):
			board_manager.on_layer_rotated(
				axis, value, angle, board_container.spacing, visual_offset
			)
	)
	right_arrow_btn.pressed.connect(_on_rotate_right)
	left_arrow_btn.pressed.connect(_on_rotate_left)
	_setup_responsive_rotation_buttons()
	shuffle_btn.pressed.connect(_on_shuffle)
	timer_container.timer_finished.connect(_on_timer_finished)
	_setup_responsive_timer()
	_next_level_button_base_scale = next_level_button.scale
	next_level_button.pivot_offset = next_level_button.size * 0.5
	_next_level_button_default_texture = next_level_button.texture_normal
	_next_level_button_default_offset_top = next_level_button.offset_top
	_next_level_button_default_offset_bottom = next_level_button.offset_bottom
	next_level_button.pressed.connect(_on_play_next_level)
	next_level_button.mouse_entered.connect(_on_next_level_button_hover.bind(true))
	next_level_button.mouse_exited.connect(_on_next_level_button_hover.bind(false))
	_game_over_home_button_base_scale = game_over_home_button.scale
	_game_over_replay_button_base_scale = game_over_replay_button.scale
	game_over_home_button.pivot_offset = game_over_home_button.size * 0.5
	game_over_replay_button.pivot_offset = game_over_replay_button.size * 0.5
	game_over_home_button.mouse_entered.connect(
		_on_game_over_button_hover.bind(game_over_home_button, true)
	)
	game_over_home_button.mouse_exited.connect(
		_on_game_over_button_hover.bind(game_over_home_button, false)
	)
	game_over_replay_button.mouse_entered.connect(
		_on_game_over_button_hover.bind(game_over_replay_button, true)
	)
	game_over_replay_button.mouse_exited.connect(
		_on_game_over_button_hover.bind(game_over_replay_button, false)
	)
	game_over_home_button.pressed.connect(_on_game_over_home)
	game_over_replay_button.pressed.connect(_on_game_over_replay)
	_challenge_completed_home_button_base_scale = challenge_completed_home_button.scale
	_challenge_completed_play_again_button_base_scale = challenge_completed_play_again_button.scale
	challenge_completed_home_button.pivot_offset = challenge_completed_home_button.size * 0.5
	challenge_completed_play_again_button.pivot_offset = (
		challenge_completed_play_again_button.size * 0.5
	)
	challenge_completed_home_button.mouse_entered.connect(
		_on_challenge_completed_button_hover.bind(challenge_completed_home_button, true)
	)
	challenge_completed_home_button.mouse_exited.connect(
		_on_challenge_completed_button_hover.bind(challenge_completed_home_button, false)
	)
	challenge_completed_play_again_button.mouse_entered.connect(
		_on_challenge_completed_button_hover.bind(challenge_completed_play_again_button, true)
	)
	challenge_completed_play_again_button.mouse_exited.connect(
		_on_challenge_completed_button_hover.bind(challenge_completed_play_again_button, false)
	)
	challenge_completed_home_button.pressed.connect(_on_challenge_completed_home)
	challenge_completed_play_again_button.pressed.connect(_on_challenge_completed_play_again)
	gui.home_pressed.connect(_on_home)
	gui.reset_pressed.connect(_on_reset)
	gui.sfx_toggled.connect(_on_sfx_toggled)
	gui.soundtrack_toggled.connect(_on_soundtrack_toggled)
	level_complete_overlay.visible = false
	level_complete_overlay.modulate.a = 0.0
	next_level_menu.visible = false
	next_level_menu.modulate.a = 0.0
	game_over_menu.visible = false
	game_over_menu.modulate.a = 0.0
	challenge_completed_menu.visible = false
	challenge_completed_menu.modulate.a = 0.0


func _setup_responsive_rotation_buttons() -> void:
	for button in [left_arrow_btn, right_arrow_btn]:
		_rotation_button_layouts[button] = {
			"scale": button.scale,
			"size": button.size,
			"bottom_offset": button.offset_bottom
		}
	left_arrow_btn.pivot_offset = Vector2(0.0, left_arrow_btn.size.y)
	right_arrow_btn.pivot_offset = right_arrow_btn.size
	get_viewport().size_changed.connect(_update_rotation_button_sizes)
	_update_rotation_button_sizes()


func _update_rotation_button_sizes() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.y <= 0.0:
		return

	var aspect_ratio := viewport_size.x / viewport_size.y
	var aspect_progress := clampf(
		inverse_lerp(
			ROTATION_BUTTON_MOBILE_ASPECT,
			ROTATION_BUTTON_DESKTOP_ASPECT,
			aspect_ratio
		),
		0.0,
		1.0
	)
	var size_multiplier := lerpf(
		1.0, ROTATION_BUTTON_DESKTOP_SCALE, aspect_progress
	)

	for button in [left_arrow_btn, right_arrow_btn]:
		var layout: Dictionary = _rotation_button_layouts[button]
		var base_scale: Vector2 = layout.scale
		var base_size: Vector2 = layout.size
		var bottom_offset: float = layout.bottom_offset
		var side_margin := ROTATION_BUTTON_BASE_SIDE_MARGIN * size_multiplier

		gui.set_button_base_scale(button, base_scale * size_multiplier)
		button.offset_top = bottom_offset - base_size.y
		button.offset_bottom = bottom_offset

		if button == right_arrow_btn:
			button.offset_left = -side_margin - base_size.x
			button.offset_right = -side_margin
		else:
			button.offset_left = side_margin
			button.offset_right = button.offset_left + base_size.x


func _setup_responsive_timer() -> void:
	_timer_layout = {"scale": timer_container.scale}
	timer_container.pivot_offset = Vector2.ZERO
	get_viewport().size_changed.connect(_update_timer_size)
	_update_timer_size()


func _update_timer_size() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.y <= 0.0:
		return
	var aspect_ratio := viewport_size.x / viewport_size.y
	var aspect_progress := clampf(
		inverse_lerp(
			ROTATION_BUTTON_MOBILE_ASPECT,
			ROTATION_BUTTON_DESKTOP_ASPECT,
			aspect_ratio
		),
		0.0,
		1.0
	)
	var scale_multiplier := lerpf(TIMER_PORTRAIT_SCALE, TIMER_DESKTOP_SCALE, aspect_progress)
	timer_container.scale = _timer_layout.scale * scale_multiplier


func _process(_delta: float) -> void:
	_update_next_level_button_hover()


func _build_editor_controls() -> void:
	var editor_button := Button.new()
	editor_button.text = "Editor"
	editor_button.custom_minimum_size = Vector2(128, 56)
	editor_button.anchors_preset = Control.PRESET_TOP_LEFT
	editor_button.offset_left = 24.0
	editor_button.offset_top = EDITOR_CONTROLS_Y
	editor_button.offset_right = 152.0
	editor_button.offset_bottom = EDITOR_CONTROLS_Y + 56.0
	editor_button.pressed.connect(_on_editor)
	gui.add_child(editor_button)

	_level_label = Label.new()
	_level_label.text = _get_level_label()
	_level_label.anchors_preset = Control.PRESET_TOP_LEFT
	_level_label.offset_left = 168.0
	_level_label.offset_top = EDITOR_CONTROLS_Y + 8.0
	_level_label.offset_right = 440.0
	_level_label.offset_bottom = EDITOR_CONTROLS_Y + 48.0
	gui.add_child(_level_label)


func _get_level_label() -> String:
	var difficulty_index := clampi(int(level_id / 10), 0, DIFFICULTIES.size() - 1)
	var order := level_id % 10 + 1
	return "%02d  %s  id %d" % [order, DIFFICULTIES[difficulty_index], level_id]


func _on_rotate_right() -> void:
	Soundmanager.play_click_sfx()
	board_container.rotate_board(true)


func _on_rotate_left() -> void:
	Soundmanager.play_click_sfx()
	board_container.rotate_board(false)


func _on_shuffle() -> void:
	Soundmanager.play_click_sfx()
	board_container.shuffle()


func _on_home() -> void:
	Soundmanager.play_click_sfx()
	get_tree().change_scene_to_file(SPLASH_SCENE)


func _on_editor() -> void:
	get_tree().change_scene_to_file(LEVEL_EDITOR_SCENE)


func _on_reset() -> void:
	Soundmanager.play_click_sfx()
	_level_complete_token += 1
	_is_game_over = false
	_is_challenge_completed = false
	_hide_next_level_menu()
	_hide_game_over_menu()
	_hide_challenge_completed_menu()
	_fade_level_complete_overlay(false)
	_next_level_button_hovered = false
	_on_next_level_button_hover(false)
	board_container.rotation_degrees = BOARD_INITIAL_ROTATION_DEGREES
	board_container.load_level(level_id)
	timer_container.resume()
	_fade_rotation_buttons(true)


func _on_sfx_toggled(is_on: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not is_on)


func _on_soundtrack_toggled(is_on: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not is_on)


func _on_level_completed() -> void:
	if _is_game_over or _is_challenge_completed:
		return
	_level_complete_token += 1
	var complete_token := _level_complete_token
	timer_container.pause()
	_fade_rotation_buttons(false)
	_fade_level_complete_overlay(true)
	await get_tree().create_timer(LEVEL_COMPLETE_MENU_DELAY).timeout
	if complete_token != _level_complete_token:
		return
	if _is_final_level(level_id):
		_show_challenge_completed_menu()
		return
	_show_next_level_menu()


func _on_timer_finished() -> void:
	_level_complete_token += 1
	_is_game_over = true
	_is_challenge_completed = false
	_hide_next_level_menu()
	_hide_challenge_completed_menu()
	_next_level_button_hovered = false
	_on_next_level_button_hover(false)
	_fade_rotation_buttons(false)
	_fade_level_complete_overlay(true)
	_show_game_over_menu()


func _show_game_over_menu() -> void:
	Soundmanager.play_popup_sfx()

	_on_game_over_button_hover(game_over_home_button, false)
	_on_game_over_button_hover(game_over_replay_button, false)
	game_over_menu.visible = true
	game_over_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	if _game_over_menu_tween != null:
		_game_over_menu_tween.kill()
	_game_over_menu_tween = create_tween()
	_game_over_menu_tween.set_ease(Tween.EASE_OUT)
	_game_over_menu_tween.set_trans(Tween.TRANS_CUBIC)
	_game_over_menu_tween.tween_property(game_over_menu, "modulate:a", 1.0, 0.22)


func _hide_game_over_menu() -> void:
	_on_game_over_button_hover(game_over_home_button, false)
	_on_game_over_button_hover(game_over_replay_button, false)
	game_over_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _game_over_menu_tween != null:
		_game_over_menu_tween.kill()
	_game_over_menu_tween = create_tween()
	_game_over_menu_tween.set_ease(Tween.EASE_IN)
	_game_over_menu_tween.set_trans(Tween.TRANS_CUBIC)
	_game_over_menu_tween.tween_property(game_over_menu, "modulate:a", 0.0, 0.18)
	_game_over_menu_tween.tween_callback(func(): game_over_menu.visible = false)


func _on_game_over_home() -> void:
	Soundmanager.play_click_sfx()
	get_tree().change_scene_to_file(SPLASH_SCENE)


func _on_game_over_replay() -> void:
	Soundmanager.play_click_sfx()
	_level_complete_token += 1
	_is_game_over = false
	_hide_game_over_menu()
	_fade_level_complete_overlay(false)
	_next_level_button_hovered = false
	_on_next_level_button_hover(false)
	board_container.rotation_degrees = BOARD_INITIAL_ROTATION_DEGREES
	board_container.load_level(level_id)
	timer_container.reset(GameState.TIMER_DURATION_SECONDS)
	timer_container.resume()
	_fade_rotation_buttons(true)


func _on_game_over_button_hover(button: TextureButton, is_hovered: bool) -> void:
	var base_scale := _game_over_home_button_base_scale
	var tween := _game_over_home_button_scale_tween
	if button == game_over_replay_button:
		base_scale = _game_over_replay_button_base_scale
		tween = _game_over_replay_button_scale_tween
	if tween != null:
		tween.kill()
	var target_scale := base_scale * (GAME_OVER_BUTTON_HOVER_SCALE if is_hovered else 1.0)
	tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(button, "scale", target_scale, 0.08)
	if button == game_over_replay_button:
		_game_over_replay_button_scale_tween = tween
	else:
		_game_over_home_button_scale_tween = tween


func _show_challenge_completed_menu() -> void:
	Soundmanager.play_popup_sfx()

	_is_challenge_completed = true
	_on_challenge_completed_button_hover(challenge_completed_home_button, false)
	_on_challenge_completed_button_hover(challenge_completed_play_again_button, false)
	challenge_completed_menu.visible = true
	challenge_completed_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	if _challenge_completed_menu_tween != null:
		_challenge_completed_menu_tween.kill()
	_challenge_completed_menu_tween = create_tween()
	_challenge_completed_menu_tween.set_ease(Tween.EASE_OUT)
	_challenge_completed_menu_tween.set_trans(Tween.TRANS_CUBIC)
	_challenge_completed_menu_tween.tween_property(
		challenge_completed_menu, "modulate:a", 1.0, 0.22
	)


func _hide_challenge_completed_menu() -> void:
	_on_challenge_completed_button_hover(challenge_completed_home_button, false)
	_on_challenge_completed_button_hover(challenge_completed_play_again_button, false)
	challenge_completed_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _challenge_completed_menu_tween != null:
		_challenge_completed_menu_tween.kill()
	_challenge_completed_menu_tween = create_tween()
	_challenge_completed_menu_tween.set_ease(Tween.EASE_IN)
	_challenge_completed_menu_tween.set_trans(Tween.TRANS_CUBIC)
	_challenge_completed_menu_tween.tween_property(
		challenge_completed_menu, "modulate:a", 0.0, 0.18
	)
	_challenge_completed_menu_tween.tween_callback(func(): challenge_completed_menu.visible = false)


func _on_challenge_completed_home() -> void:
	Soundmanager.play_click_sfx()
	get_tree().change_scene_to_file(SPLASH_SCENE)


func _on_challenge_completed_play_again() -> void:
	Soundmanager.play_click_sfx()
	_level_complete_token += 1
	_is_challenge_completed = false
	_hide_challenge_completed_menu()
	_fade_level_complete_overlay(false)
	GameState.selected_level_id = 0
	GameState.has_selected_level = true
	level_id = 0
	if _level_label != null:
		_level_label.text = _get_level_label()
	board_container.rotation_degrees = BOARD_INITIAL_ROTATION_DEGREES
	board_container.load_level(level_id)
	timer_container.reset(GameState.TIMER_DURATION_SECONDS)
	timer_container.resume()
	_fade_rotation_buttons(true)


func _on_challenge_completed_button_hover(button: TextureButton, is_hovered: bool) -> void:
	var base_scale := _challenge_completed_home_button_base_scale
	var tween := _challenge_completed_home_button_scale_tween
	if button == challenge_completed_play_again_button:
		base_scale = _challenge_completed_play_again_button_base_scale
		tween = _challenge_completed_play_again_button_scale_tween
	if tween != null:
		tween.kill()
	var target_scale := base_scale * (GAME_OVER_BUTTON_HOVER_SCALE if is_hovered else 1.0)
	tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(button, "scale", target_scale, 0.08)
	if button == challenge_completed_play_again_button:
		_challenge_completed_play_again_button_scale_tween = tween
	else:
		_challenge_completed_home_button_scale_tween = tween


func _show_next_level_menu() -> void:
	Soundmanager.play_popup_sfx()

	_next_level_id = _get_next_level_id(level_id)
	var current_difficulty := _difficulty_for_level_id(level_id)
	var unlocked_difficulty := _difficulty_for_level_id(_next_level_id)
	_apply_next_level_panel_texture(current_difficulty)
	if unlocked_difficulty == "hard":
		next_level_button.texture_normal = load(BTN_PLAY_HARD_PATH)
		next_level_button_label.add_theme_color_override("font_color", Color.WHITE)
		next_level_button.offset_top = _next_level_button_default_offset_top + NEXT_LEVEL_BUTTON_HARD_DOWN_OFFSET
		next_level_button.offset_bottom = _next_level_button_default_offset_bottom + NEXT_LEVEL_BUTTON_HARD_DOWN_OFFSET
	else:
		next_level_button.texture_normal = _next_level_button_default_texture
		next_level_button_label.remove_theme_color_override("font_color")
		next_level_button.offset_top = _next_level_button_default_offset_top
		next_level_button.offset_bottom = _next_level_button_default_offset_bottom
	next_level_button.visible = not _is_final_level(level_id)
	next_level_button.disabled = _is_final_level(level_id)
	_next_level_button_hovered = false
	_on_next_level_button_hover(false)
	if not _is_final_level(level_id):
		next_level_button_label.text = "PLAY %s" % unlocked_difficulty.to_upper()
	next_level_menu.visible = true
	next_level_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	if _menu_tween != null:
		_menu_tween.kill()
	_menu_tween = create_tween()
	_menu_tween.set_ease(Tween.EASE_OUT)
	_menu_tween.set_trans(Tween.TRANS_CUBIC)
	_menu_tween.tween_property(next_level_menu, "modulate:a", 1.0, 0.22)


func _on_play_next_level() -> void:
	Soundmanager.play_click_sfx()
	if _is_final_level(level_id):
		return
	_level_complete_token += 1
	GameState.selected_level_id = _next_level_id
	GameState.has_selected_level = true
	level_id = _next_level_id
	if _level_label != null:
		_level_label.text = _get_level_label()
	_hide_next_level_menu()
	_fade_level_complete_overlay(false)
	board_container.load_level(level_id)
	timer_container.resume()
	_fade_rotation_buttons(true)


func _on_next_level_button_hover(is_hovered: bool) -> void:
	if _next_level_button_scale_tween != null:
		_next_level_button_scale_tween.kill()
	var target_scale := (
		_next_level_button_base_scale * (NEXT_LEVEL_BUTTON_HOVER_SCALE if is_hovered else 1.0)
	)
	_next_level_button_scale_tween = create_tween()
	_next_level_button_scale_tween.set_ease(Tween.EASE_OUT)
	_next_level_button_scale_tween.set_trans(Tween.TRANS_CUBIC)
	_next_level_button_scale_tween.tween_property(next_level_button, "scale", target_scale, 0.08)


func _update_next_level_button_hover() -> void:
	var should_hover := (
		next_level_menu.visible
		and next_level_button.visible
		and not next_level_button.disabled
		and next_level_button.get_global_rect().has_point(get_viewport().get_mouse_position())
	)
	if should_hover == _next_level_button_hovered:
		return
	_next_level_button_hovered = should_hover
	_on_next_level_button_hover(_next_level_button_hovered)


func _hide_next_level_menu() -> void:
	next_level_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _menu_tween != null:
		_menu_tween.kill()
	_menu_tween = create_tween()
	_menu_tween.set_ease(Tween.EASE_IN)
	_menu_tween.set_trans(Tween.TRANS_CUBIC)
	_menu_tween.tween_property(next_level_menu, "modulate:a", 0.0, 0.18)
	_menu_tween.tween_callback(func(): next_level_menu.visible = false)


func _fade_level_complete_overlay(show_overlay: bool) -> void:
	if _level_complete_overlay_tween != null:
		_level_complete_overlay_tween.kill()
	var target_alpha := 1.0 if show_overlay else 0.0
	var duration := (
		LEVEL_COMPLETE_OVERLAY_FADE_IN_DURATION
		if show_overlay
		else LEVEL_COMPLETE_OVERLAY_FADE_OUT_DURATION
	)
	if show_overlay:
		level_complete_overlay.visible = true
	_level_complete_overlay_tween = create_tween()
	_level_complete_overlay_tween.set_ease(Tween.EASE_OUT if show_overlay else Tween.EASE_IN)
	_level_complete_overlay_tween.set_trans(Tween.TRANS_CUBIC)
	_level_complete_overlay_tween.tween_property(
		level_complete_overlay, "modulate:a", target_alpha, duration
	)
	if not show_overlay:
		_level_complete_overlay_tween.tween_callback(func(): level_complete_overlay.visible = false)


func _fade_rotation_buttons(show_buttons: bool) -> void:
	if _rotation_buttons_tween != null:
		_rotation_buttons_tween.kill()
	var target_alpha := 1.0 if show_buttons else 0.0
	for button in _gameplay_action_buttons():
		button.disabled = not show_buttons
		if show_buttons:
			button.visible = true
	_rotation_buttons_tween = create_tween()
	_rotation_buttons_tween.set_parallel(true)
	_rotation_buttons_tween.set_ease(Tween.EASE_OUT)
	_rotation_buttons_tween.set_trans(Tween.TRANS_CUBIC)
	for button in _gameplay_action_buttons():
		_rotation_buttons_tween.tween_property(
			button, "modulate:a", target_alpha, ROTATION_BUTTON_FADE_DURATION
		)
	if not show_buttons:
		_rotation_buttons_tween.chain().tween_callback(
			func():
				for button in _gameplay_action_buttons():
					button.visible = false
		)


func _gameplay_action_buttons() -> Array[TextureButton]:
	return [right_arrow_btn, left_arrow_btn, shuffle_btn]


func _get_next_level_id(current_level_id: int) -> int:
	var difficulty_index := clampi(int(current_level_id / 10), 0, DIFFICULTIES.size() - 1)
	var next_difficulty_index := mini(difficulty_index + 1, DIFFICULTIES.size() - 1)
	return next_difficulty_index * 10


func _difficulty_for_level_id(current_level_id: int) -> String:
	var difficulty_index := clampi(int(current_level_id / 10), 0, DIFFICULTIES.size() - 1)
	return DIFFICULTIES[difficulty_index]


func _is_final_level(current_level_id: int) -> bool:
	var difficulty_index := clampi(int(current_level_id / 10), 0, DIFFICULTIES.size() - 1)
	return difficulty_index >= DIFFICULTIES.size() - 1


func _apply_next_level_panel_texture(difficulty: String) -> void:
	var path: String = NEXT_LEVEL_BG_PATHS.get(difficulty, "")
	if path != "" and ResourceLoader.exists(path):
		next_level_panel.texture = load(path)
	else:
		push_warning("BoardScene: missing next level background for difficulty '%s'" % difficulty)
