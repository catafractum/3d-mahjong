extends Control

signal home_pressed
signal sfx_toggled(is_on: bool)
signal soundtrack_toggled(is_on: bool)

@onready var settings_btn: TextureButton = $SettingsBtn
@onready var sfx_on_btn: TextureButton = $AudioSfxBtn_on
@onready var sfx_off_btn: TextureButton = $AudioSfxBtn_off
@onready var soundtrack_on_btn: TextureButton = $AudioSoundtrackBtn_on
@onready var soundtrack_off_btn: TextureButton = $AudioSoundtrackBtn_off
@onready var home_btn: TextureButton = $HomeBtn

var _settings_open: bool = false
var _sfx_on: bool = true
var _soundtrack_on: bool = true

var _sfx_slot_y: float
var _st_slot_y: float
var _home_slot_y: float
var _hidden_y: float

func _ready() -> void:
	_hidden_y = settings_btn.position.y

	# Guardar Y destino de cada slot desde los botones _on (referencia del editor)
	_sfx_slot_y = sfx_on_btn.position.y
	_st_slot_y = soundtrack_on_btn.position.y
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
	home_btn.pressed.connect(func(): home_pressed.emit())

func _align_x(btn: TextureButton) -> void:
	btn.position.x = settings_btn.position.x

func _all_deployable() -> Array[TextureButton]:
	return [sfx_on_btn, sfx_off_btn, soundtrack_on_btn, soundtrack_off_btn, home_btn]

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

	for btn in [sfx_btn, st_btn, home_btn]:
		_align_x(btn)
		btn.position.y = _hidden_y
		btn.visible = true

	var tween := create_tween()
	tween.parallel().tween_property(sfx_btn, "position:y", _sfx_slot_y, 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(st_btn, "position:y", _st_slot_y, 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(home_btn, "position:y", _home_slot_y, 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _collapse() -> void:
	_settings_open = false
	var sfx_btn := _current_sfx_btn()
	var st_btn := _current_soundtrack_btn()

	var tween := create_tween()
	tween.parallel().tween_property(sfx_btn, "position:y", _hidden_y, 0.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(st_btn, "position:y", _hidden_y, 0.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(home_btn, "position:y", _hidden_y, 0.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(func():
		for btn in [sfx_btn, st_btn, home_btn]:
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
