extends Control

signal home_pressed
signal reset_pressed
signal sfx_toggled(is_on: bool)
signal soundtrack_toggled(is_on: bool)

var _settings_open: bool = false
var _sfx_on: bool = true
var _soundtrack_on: bool = true

var _sfx_slot_y: float
var _st_slot_y: float
var _reset_slot_y: float
var _home_slot_y: float
var _hidden_y: float
var _button_base_scales: Dictionary = {}
var _button_scale_tweens: Dictionary = {}

@onready var settings_btn: TextureButton = $SettingsBtn
@onready var sfx_on_btn: TextureButton = $AudioSfxBtn_on
@onready var sfx_off_btn: TextureButton = $AudioSfxBtn_off
@onready var soundtrack_on_btn: TextureButton = $AudioSoundtrackBtn_on
@onready var soundtrack_off_btn: TextureButton = $AudioSoundtrackBtn_off
@onready var reset_btn: TextureButton = $ResetBtn
@onready var home_btn: TextureButton = $HomeBtn


func _ready() -> void:
	%OrientationListenerToggler.on_size_changed.connect(_on_size_changed)

	_hidden_y = settings_btn.position.y
	for btn in _all_buttons():
		_setup_button_scale_feedback(btn)

	# Guardar Y destino de cada slot desde los botones _on (referencia del editor)
	_sfx_slot_y = sfx_on_btn.position.y
	_st_slot_y = soundtrack_on_btn.position.y
	_reset_slot_y = reset_btn.position.y
	_home_slot_y = home_btn.position.y

	# Forzar X del settings, z_index por debajo de settings, y ocultar
	settings_btn.z_index = 1
	for btn in _all_deployable():
		_align_x(btn)
		btn.position.y = _hidden_y
		btn.z_index = 0
		btn.visible = false

	settings_btn.pressed.connect(_on_settings_pressed)
	sfx_on_btn.pressed.connect(_on_sfx_pressed.bind(true))
	sfx_off_btn.pressed.connect(_on_sfx_pressed.bind(false))
	soundtrack_on_btn.pressed.connect(_on_soundtrack_pressed.bind(true))
	soundtrack_off_btn.pressed.connect(_on_soundtrack_pressed.bind(false))
	reset_btn.pressed.connect(func(): reset_pressed.emit())
	home_btn.pressed.connect(func(): home_pressed.emit())


func _on_size_changed(_is_portrait: bool) -> void:
	pass


func _align_x(btn: TextureButton) -> void:
	var settings_center_x := settings_btn.position.x + _visual_width(settings_btn) * 0.5
	btn.position.x = settings_center_x - _visual_width(btn) * 0.5


func _all_deployable() -> Array[TextureButton]:
	return [sfx_on_btn, sfx_off_btn, soundtrack_on_btn, soundtrack_off_btn, reset_btn, home_btn]


func _all_buttons() -> Array[TextureButton]:
	var buttons: Array[TextureButton] = []
	for child in get_children():
		if child is TextureButton:
			buttons.append(child)
	return buttons


func _base_scale(btn: TextureButton) -> Vector2:
	return _button_base_scales.get(btn, btn.scale)


func _visual_width(btn: TextureButton) -> float:
	if btn.texture_normal != null:
		return btn.texture_normal.get_width() * _base_scale(btn).x
	return btn.size.x * _base_scale(btn).x


func _setup_button_scale_feedback(btn: TextureButton) -> void:
	_button_base_scales[btn] = btn.scale
	btn.pivot_offset = btn.size * 0.5
	btn.mouse_entered.connect(func(): _tween_button_scale(btn, 1.05))
	btn.mouse_exited.connect(func(): _tween_button_scale(btn, 1.0))
	btn.button_down.connect(func(): _tween_button_scale(btn, 1.05))
	btn.button_up.connect(func(): _tween_button_scale(btn, 1.05 if btn.is_hovered() else 1.0))


func _tween_button_scale(btn: TextureButton, multiplier: float) -> void:
	var existing_tween: Tween = _button_scale_tweens.get(btn)
	if existing_tween != null:
		existing_tween.kill()
	var tween := create_tween()
	_button_scale_tweens[btn] = tween
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(btn, "scale", _base_scale(btn) * multiplier, 0.08)


func _current_sfx_btn() -> TextureButton:
	return sfx_on_btn if _sfx_on else sfx_off_btn


func _current_soundtrack_btn() -> TextureButton:
	return soundtrack_on_btn if _soundtrack_on else soundtrack_off_btn


func _on_settings_pressed() -> void:
	if _settings_open:
		_collapse()
	else:
		_deploy()


func _deploy() -> void:
	_settings_open = true
	var sfx_btn := _current_sfx_btn()
	var st_btn := _current_soundtrack_btn()

	for btn in [sfx_btn, st_btn, reset_btn, home_btn]:
		_align_x(btn)
		btn.position.y = _hidden_y
		btn.visible = true

	var tween := create_tween()
	(
		tween
		. parallel()
		. tween_property(sfx_btn, "position:y", _sfx_slot_y, 0.25)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_BACK)
	)
	(
		tween
		. parallel()
		. tween_property(st_btn, "position:y", _st_slot_y, 0.25)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_BACK)
	)
	(
		tween
		. parallel()
		. tween_property(reset_btn, "position:y", _reset_slot_y, 0.25)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_BACK)
	)
	(
		tween
		. parallel()
		. tween_property(home_btn, "position:y", _home_slot_y, 0.25)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_BACK)
	)


func _collapse() -> void:
	_settings_open = false
	var sfx_btn := _current_sfx_btn()
	var st_btn := _current_soundtrack_btn()

	var tween := create_tween()
	(
		tween
		. parallel()
		. tween_property(sfx_btn, "position:y", _hidden_y, 0.2)
		. set_ease(Tween.EASE_IN)
		. set_trans(Tween.TRANS_BACK)
	)
	(
		tween
		. parallel()
		. tween_property(st_btn, "position:y", _hidden_y, 0.2)
		. set_ease(Tween.EASE_IN)
		. set_trans(Tween.TRANS_BACK)
	)
	(
		tween
		. parallel()
		. tween_property(reset_btn, "position:y", _hidden_y, 0.2)
		. set_ease(Tween.EASE_IN)
		. set_trans(Tween.TRANS_BACK)
	)
	(
		tween
		. parallel()
		. tween_property(home_btn, "position:y", _hidden_y, 0.2)
		. set_ease(Tween.EASE_IN)
		. set_trans(Tween.TRANS_BACK)
	)
	tween.tween_callback(
		func():
			for btn in [sfx_btn, st_btn, reset_btn, home_btn]:
				btn.visible = false
	)


func _on_sfx_pressed(was_on: bool) -> void:
	_sfx_on = not was_on
	sfx_on_btn.visible = false
	sfx_off_btn.visible = false
	var next := _current_sfx_btn()
	_align_x(next)
	next.position.y = _sfx_slot_y
	next.visible = true
	sfx_toggled.emit(_sfx_on)


func _on_soundtrack_pressed(was_on: bool) -> void:
	_soundtrack_on = not was_on
	soundtrack_on_btn.visible = false
	soundtrack_off_btn.visible = false
	var next := _current_soundtrack_btn()
	_align_x(next)
	next.position.y = _st_slot_y
	next.visible = true
	soundtrack_toggled.emit(_soundtrack_on)
