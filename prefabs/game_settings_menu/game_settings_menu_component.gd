class_name GameSettingsMenuComponent
extends BaseComponent

const MOBILE_ASPECT := 5.0 / 7.0
const DESKTOP_ASPECT := 16.0 / 9.0
const DESKTOP_SCALE := 2.25

signal reset_requested
signal home_requested
signal settings_pressed
signal sfx_toggled(is_enabled: bool)
signal music_toggled(is_enabled: bool)
signal responsive_layout_changed

@export var settings_button: BaseButton
@export var sfx_on_button: Control
@export var sfx_off_button: Control
@export var music_on_button: Control
@export var music_off_button: Control
@export var reset_button: BaseButton
@export var home_button: BaseButton
@export_file("*.tscn") var splash_scene_path: String
@export var hidden_y := 16.0
@export var sfx_y := 119.0
@export var music_y := 185.0
@export var reset_y := 252.0
@export var home_y := 320.0

var _open := false
var _sfx_enabled := true
var _music_enabled := true
var _tween: Tween
var _base_scales: Dictionary = {}
var _base_positions_y: Dictionary = {}
var _current_responsive_multiplier := 1.0


func _ready() -> void:
	set_toggle_states(_is_bus_enabled("SFX"), _is_bus_enabled("Music"))
	settings_button.pressed.connect(_toggle)
	(sfx_on_button as BaseButton).pressed.connect(_set_sfx.bind(false))
	(sfx_off_button as BaseButton).pressed.connect(_set_sfx.bind(true))
	(music_on_button as BaseButton).pressed.connect(_set_music.bind(false))
	(music_off_button as BaseButton).pressed.connect(_set_music.bind(true))
	reset_button.pressed.connect(_request_reset)
	home_button.pressed.connect(_request_home)
	_hide_deployable_buttons()
	_setup_responsive_ui.call_deferred()


func _setup_responsive_ui() -> void:
	for control in _all_controls():
		_base_scales[control] = control.scale
		_base_positions_y[control] = control.position.y
		# These controls are right-anchored. Scaling from the top-right keeps their
		# right edge and top position fixed instead of pushing them off-screen.
		control.pivot_offset_ratio = Vector2(1.0, 0.0)
	if not get_viewport().size_changed.is_connected(_update_responsive_ui):
		get_viewport().size_changed.connect(_update_responsive_ui)
	_update_responsive_ui()


func _update_responsive_ui() -> void:
	if _base_scales.is_empty():
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var progress := clampf(inverse_lerp(MOBILE_ASPECT, DESKTOP_ASPECT, aspect), 0.0, 1.0)
	var multiplier := lerpf(1.0, DESKTOP_SCALE, progress)
	_current_responsive_multiplier = multiplier
	for control in _all_controls():
		var scale := Vector2(_base_scales[control]) * multiplier
		var helper := ButtonHelperComponent.of_as(control)
		if helper != null:
			helper.set_base_scale(scale)
		else:
			control.scale = scale
	hidden_y = float(_base_positions_y[settings_button])
	sfx_y = hidden_y + (float(_base_positions_y[sfx_on_button]) - hidden_y) * multiplier
	music_y = hidden_y + (float(_base_positions_y[music_on_button]) - hidden_y) * multiplier
	reset_y = hidden_y + (float(_base_positions_y[reset_button]) - hidden_y) * multiplier
	home_y = hidden_y + (float(_base_positions_y[home_button]) - hidden_y) * multiplier
	if not _open:
		_hide_deployable_buttons()
	responsive_layout_changed.emit()


func get_settings_base_scale() -> Vector2:
	return (
		Vector2(_base_scales.get(settings_button, settings_button.scale))
		* _current_responsive_multiplier
	)


func _all_controls() -> Array[Control]:
	return [
		settings_button,
		sfx_on_button,
		sfx_off_button,
		music_on_button,
		music_off_button,
		reset_button,
		home_button,
	]


func _toggle() -> void:
	settings_pressed.emit()
	_open = not _open
	if _open:
		_deploy()
	else:
		_collapse()


func _deploy() -> void:
	_kill_tween()
	var controls := _visible_controls()
	var targets := [sfx_y, music_y, reset_y, home_y]
	for control in controls:
		control.position.y = hidden_y
		control.show()
	_tween = create_tween().set_parallel(true)
	for index in controls.size():
		_tween.tween_property(controls[index], "position:y", targets[index], 0.25).set_ease(
			Tween.EASE_OUT
		).set_trans(Tween.TRANS_BACK)


func _collapse() -> void:
	_kill_tween()
	var controls := _visible_controls()
	_tween = create_tween().set_parallel(true)
	for control in controls:
		_tween.tween_property(control, "position:y", hidden_y, 0.2).set_ease(
			Tween.EASE_IN
		).set_trans(Tween.TRANS_BACK)
	_tween.chain().tween_callback(_hide_deployable_buttons)


func _set_sfx(enabled: bool) -> void:
	_sfx_enabled = enabled
	_set_bus_enabled("SFX", enabled)
	_refresh_toggle_buttons()
	sfx_toggled.emit(enabled)


func _set_music(enabled: bool) -> void:
	_music_enabled = enabled
	_set_bus_enabled("Music", enabled)
	_refresh_toggle_buttons()
	music_toggled.emit(enabled)


func set_toggle_states(sfx_enabled: bool, music_enabled: bool) -> void:
	_sfx_enabled = sfx_enabled
	_music_enabled = music_enabled
	_refresh_toggle_buttons()


func _refresh_toggle_buttons() -> void:
	sfx_on_button.visible = _open and _sfx_enabled
	sfx_off_button.visible = _open and not _sfx_enabled
	music_on_button.visible = _open and _music_enabled
	music_off_button.visible = _open and not _music_enabled


func _visible_controls() -> Array[Control]:
	return [
		sfx_on_button if _sfx_enabled else sfx_off_button,
		music_on_button if _music_enabled else music_off_button,
		reset_button,
		home_button,
	]


func _hide_deployable_buttons() -> void:
	for control in [sfx_on_button, sfx_off_button, music_on_button, music_off_button, reset_button, home_button]:
		control.hide()


func _kill_tween() -> void:
	if _tween != null:
		_tween.kill()


func _set_bus_enabled(bus_name: StringName, is_enabled: bool) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus >= 0:
		AudioServer.set_bus_mute(bus, not is_enabled)


func _is_bus_enabled(bus_name: StringName) -> bool:
	var bus := AudioServer.get_bus_index(bus_name)
	return bus < 0 or not AudioServer.is_bus_mute(bus)


func _request_reset() -> void:
	var session_component := CurrentGameSessionComponent.of_as(self)
	var builder := BoardBuilderComponent.of_as(self)
	var timer := GameTimerComponent.of_as(self)
	if session_component != null and session_component.session != null and builder != null and timer != null:
		builder.build_level(session_component.session.get_current_level())
		timer.resume()
	reset_requested.emit()


func _request_home() -> void:
	GameDB.current_session = null
	SceneSwitcherComponent.of_as(self).switch_scene(splash_scene_path)
	home_requested.emit()


static func of_as(node: Node) -> GameSettingsMenuComponent:
	return BaseComponent.of(node, GameSettingsMenuComponent) as GameSettingsMenuComponent
