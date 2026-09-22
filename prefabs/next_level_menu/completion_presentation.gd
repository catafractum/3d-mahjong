extends Control
## Shared celebration for intermediate and final challenge completion.

@export var reveal_duration := 0.5
@export var rise_distance := 40.0
@export var panel: Control
@export var title1: Label
@export var title_format := "%s"
@export var buttons: Array[BaseButton] = []

var _reveal: Tween
var _panel_top: float
var _panel_bottom: float
var _bursts: Array[CPUParticles2D] = []


func _ready() -> void:
	if not _references_connected():
		push_error("CompletionPresentation: Assign panel, title1, and buttons in the Inspector.")
		return
	_panel_top = panel.offset_top
	_panel_bottom = panel.offset_bottom


func present(difficulty: String, delay := 1.0) -> void:
	if not _references_connected():
		return
	dismiss()
	title1.text = title_format % difficulty.to_upper()
	panel.modulate.a = 0.0
	panel.offset_top = _panel_top + rise_distance
	panel.offset_bottom = _panel_bottom + rise_distance
	_set_buttons_disabled(true)
	show()
	_pop_confetti()
	_reveal = create_tween()
	_reveal.tween_interval(maxf(delay, 0.0))
	_reveal.tween_property(panel, "modulate:a", 1.0, reveal_duration)
	(
		_reveal
		. parallel()
		. tween_property(panel, "offset_top", _panel_top, reveal_duration)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_reveal
		. parallel()
		. tween_property(panel, "offset_bottom", _panel_bottom, reveal_duration)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	_reveal.tween_callback(_set_buttons_disabled.bind(false))


func dismiss() -> void:
	if _reveal != null:
		_reveal.kill()
	for burst in _bursts:
		if is_instance_valid(burst):
			burst.queue_free()
	_bursts.clear()
	hide()


func _references_connected() -> bool:
	if not is_instance_valid(panel) or not is_instance_valid(title1) or buttons.is_empty():
		return false
	for button in buttons:
		if not is_instance_valid(button):
			return false
	return true


func _set_buttons_disabled(value: bool) -> void:
	for button in buttons:
		if is_instance_valid(button):
			button.disabled = value


func _pop_confetti() -> void:
	var palette := Gradient.new()
	palette.colors = PackedColorArray(
		[Color("ffcf40"), Color("ff62bc"), Color("61dfff"), Color("a277ff"), Color("74ff9b")]
	)
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.65, 1.0])
	fade.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	for side in [-1.0, 1.0]:
		var burst := CPUParticles2D.new()
		burst.emitting = false
		burst.amount = 65
		burst.lifetime = 2.8
		burst.one_shot = true
		burst.explosiveness = 1.0
		burst.direction = Vector2(-side * 0.35, -1.0)
		burst.spread = 32.0
		burst.gravity = Vector2(0, 650)
		burst.initial_velocity_min = 1850.0
		burst.initial_velocity_max = 2250.0
		burst.angular_velocity_min = -360.0
		burst.angular_velocity_max = 360.0
		burst.scale_amount_min = 7.0
		burst.scale_amount_max = 13.0
		burst.color_initial_ramp = palette
		burst.color_ramp = fade
		burst.position = Vector2(size.x * (0.5 + side * 0.4), size.y * 0.85)
		add_child(burst)
		_bursts.append(burst)
		burst.emitting = true
