class_name GameUIComponent
extends BaseComponent

const MOBILE_ASPECT := 5.0 / 7.0
const DESKTOP_ASPECT := 16.0 / 9.0
const ROTATION_DESKTOP_SCALE := 2.25
const TIMER_PORTRAIT_SCALE := 1.5
const TIMER_DESKTOP_SCALE := 2.5
const HUD_DESKTOP_SCALE := 2.25
const BASE_SIDE_MARGIN := 25.0

@export var minutes_label: Label
@export var seconds_label: Label
@export var selected_tile: Control
@export var selected_tile_icon: TextureRect
@export var rotate_left_button: BaseButton
@export var rotate_right_button: BaseButton
@export var shuffle_button: BaseButton
@export var remove_pair_button: BaseButton

var _session: GameSession
var _displayed_selected_tile: Node3D
var _base_scales: Dictionary = {}
var _selected_tile_base_position := Vector2.ZERO
var _rotation_layouts: Dictionary = {}
var _base_shuffle_settings_gap := 0.0
var _shuffle_base_right_offset := 0.0
var _shuffle_alignment_initialized := false


func _ready() -> void:
	rotate_left_button.pressed.connect(_rotate_board.bind(false))
	rotate_right_button.pressed.connect(_rotate_board.bind(true))
	shuffle_button.pressed.connect(_shuffle_board)
	remove_pair_button.visible = GameDB.enable_remove_pair_button
	remove_pair_button.pressed.connect(_remove_pair_for_testing)
	set_selected_tile_texture(null)
	_initialize.call_deferred()
	_setup_responsive_ui.call_deferred()


func _initialize() -> void:
	var session_component := CurrentGameSessionComponent.of_as(self)
	if session_component != null:
		_session = session_component.session


func _process(_delta: float) -> void:
	if _session == null:
		return
	set_remaining_seconds(_session.get_remaining_seconds())
	_refresh_selected_tile()


func _rotate_board(right: bool) -> void:
	var rotation := BoardRotationComponent.of_as(self)
	if rotation != null:
		rotation.rotate(right)


func _shuffle_board() -> void:
	var rotation := BoardRotationComponent.of_as(self)
	if rotation != null:
		rotation.shuffle()


func _remove_pair_for_testing() -> void:
	var interaction := BoardInteractionComponent.of_as(self)
	if interaction != null:
		interaction.remove_matching_pair_for_testing()


func _refresh_selected_tile() -> void:
	var current := _session.selected_tile if is_instance_valid(_session.selected_tile) else null
	if current == _displayed_selected_tile:
		return
	_displayed_selected_tile = current
	var texture: Texture2D
	if current != null:
		var tile := MahjongTileComponent.of_as(current)
		if tile != null:
			texture = tile.get_icon_texture()
	set_selected_tile_texture(texture)


func set_remaining_seconds(value: float) -> void:
	var total_seconds := maxi(int(ceil(value)), 0)
	minutes_label.text = "%02d" % int(total_seconds / 60.0)
	seconds_label.text = "%02d" % (total_seconds % 60)


func set_selected_tile_texture(texture: Texture2D) -> void:
	selected_tile_icon.texture = texture
	selected_tile.visible = texture != null


func _setup_responsive_ui() -> void:
	# The initial viewport size and Control layout settle after the first frame.
	# Waiting here makes startup use the real window aspect, just like a resize.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var timer := minutes_label.get_parent() as Control
	for control in [timer, selected_tile, rotate_left_button, rotate_right_button, shuffle_button, remove_pair_button]:
		_base_scales[control] = control.scale
	_selected_tile_base_position = selected_tile.position
	# These normalized corner pivots match the legacy layout while remaining
	# correct if texture-driven button sizes settle after _ready().
	shuffle_button.pivot_offset_ratio = Vector2(1.0, 0.0)
	_shuffle_base_right_offset = (
		shuffle_button.position.x
		+ shuffle_button.size.x
		- shuffle_button.get_parent_control().size.x
	)
	for button in [rotate_left_button, rotate_right_button]:
		_rotation_layouts[button] = {"size": button.size, "bottom": button.offset_bottom}
	rotate_left_button.pivot_offset_ratio = Vector2(0.0, 1.0)
	rotate_right_button.pivot_offset_ratio = Vector2(1.0, 1.0)
	var settings := _get_settings_component()
	if settings != null:
		_base_shuffle_settings_gap = (
			settings.settings_button.position.x
			- (shuffle_button.position.x + shuffle_button.size.x)
		)
		if not settings.responsive_layout_changed.is_connected(_align_shuffle_to_settings):
			settings.responsive_layout_changed.connect(_align_shuffle_to_settings)
	if not get_viewport().size_changed.is_connected(_update_responsive_ui):
		get_viewport().size_changed.connect(_update_responsive_ui)
	_update_responsive_ui()


func _update_responsive_ui() -> void:
	if _base_scales.is_empty():
		return
	var timer := minutes_label.get_parent() as Control
	timer.scale = Vector2(_base_scales[timer]) * _responsive_multiplier(
		TIMER_PORTRAIT_SCALE, TIMER_DESKTOP_SCALE
	)

	var hud_multiplier := _responsive_multiplier(1.0, HUD_DESKTOP_SCALE)
	_apply_button_scale(shuffle_button, Vector2(_base_scales[shuffle_button]) * hud_multiplier)
	_apply_button_scale(remove_pair_button, Vector2(_base_scales[remove_pair_button]) * hud_multiplier)
	_align_shuffle_to_settings.call_deferred()
	selected_tile.position = _selected_tile_base_position * hud_multiplier
	selected_tile.scale = Vector2(_base_scales[selected_tile]) * hud_multiplier

	var rotation_multiplier := _responsive_multiplier(1.0, ROTATION_DESKTOP_SCALE)
	for button in [rotate_left_button, rotate_right_button]:
		_apply_button_scale(button, Vector2(_base_scales[button]) * rotation_multiplier)
		var layout: Dictionary = _rotation_layouts[button]
		var base_size: Vector2 = layout.size
		var bottom: float = layout.bottom
		var margin := BASE_SIDE_MARGIN * rotation_multiplier
		button.offset_top = bottom - base_size.y
		button.offset_bottom = bottom
		if button == rotate_right_button:
			button.offset_left = -margin - base_size.x
			button.offset_right = -margin
		else:
			button.offset_left = margin
			button.offset_right = margin + base_size.x


func _apply_button_scale(button: BaseButton, value: Vector2) -> void:
	var helper := ButtonHelperComponent.of_as(button)
	if helper != null:
		helper.set_base_scale(value)
	else:
		button.scale = value


func _responsive_multiplier(portrait: float, desktop: float) -> float:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.y <= 0.0:
		return portrait
	var progress := clampf(
		inverse_lerp(MOBILE_ASPECT, DESKTOP_ASPECT, viewport_size.x / viewport_size.y),
		0.0,
		1.0
	)
	return lerpf(portrait, desktop, progress)


func _align_shuffle_to_settings() -> void:
	var settings := _get_settings_component()
	if settings == null:
		return
	var settings_button := settings.settings_button
	if not _shuffle_alignment_initialized:
		var settings_left_offset := (
			settings_button.position.x
			- settings_button.get_parent_control().size.x
		)
		_base_shuffle_settings_gap = settings_left_offset - _shuffle_base_right_offset
		_shuffle_alignment_initialized = true
		if not settings.responsive_layout_changed.is_connected(_align_shuffle_to_settings):
			settings.responsive_layout_changed.connect(_align_shuffle_to_settings)
	var settings_scale := settings.get_settings_base_scale()
	var settings_visual_left := (
		settings_button.position.x
		+ settings_button.size.x
		- settings_button.size.x * settings_scale.x
	)
	var multiplier := _responsive_multiplier(1.0, HUD_DESKTOP_SCALE)
	var shuffle_right := settings_visual_left - _base_shuffle_settings_gap * multiplier
	shuffle_button.position.x = shuffle_right - shuffle_button.size.x


func _get_settings_component() -> GameSettingsMenuComponent:
	var game_root := get_owner_node().get_parent()
	if game_root == null:
		return null
	return game_root.get_node_or_null(
		"GameSettingsMenu/Components/GameSettingsMenuComponent"
	) as GameSettingsMenuComponent


static func of_as(node: Node) -> GameUIComponent:
	return BaseComponent.of(node, GameUIComponent) as GameUIComponent
