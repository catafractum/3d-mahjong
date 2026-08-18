class_name BoardCameraFramingComponent
extends BaseComponent

signal framing_settled

@export var camera: Camera3D
@export var board: Node3D
@export_range(1.0, 2.0, 0.01) var shuffle_zoom_multiplier := 1.18
@export_range(0.0, 5.0, 0.05) var shuffle_zoom_duration := 1.1
@export_range(0.0, 5.0, 0.05) var settle_duration := 0.7
@export_range(0.0, 5.0, 0.05) var frame_padding := 0.8

var _tween: Tween
var _default_camera_position := Vector3.ZERO
var _default_camera_size := 0.0
var _level_start_camera_size := 0.0
var _shuffle_in_progress := false
var _viewport_refit_pending := false


func _ready() -> void:
	_default_camera_position = camera.global_position
	_default_camera_size = camera.size
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	var builder := BoardBuilderComponent.of_as(self)
	if builder != null:
		builder.board_built.connect(_on_board_built)


func begin_shuffle() -> void:
	_kill_tween()
	_shuffle_in_progress = true
	var target_size := camera.size * shuffle_zoom_multiplier
	_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(camera, "size", target_size, shuffle_zoom_duration)


func settle_on_board() -> void:
	_shuffle_in_progress = false
	var tiles := _get_tiles()
	if tiles.is_empty():
		return
	var target := _calculate_target(tiles, _level_start_camera_size)
	_kill_tween()
	_tween = create_tween().set_parallel(true)
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(camera, "global_position", target.position, settle_duration)
	_tween.tween_property(camera, "size", target.size, settle_duration)
	_tween.chain().tween_callback(framing_settled.emit)


func _on_board_built(tiles: Array[Node3D]) -> void:
	_kill_tween()
	_shuffle_in_progress = false
	camera.global_position = _default_camera_position
	camera.size = _default_camera_size
	if tiles.is_empty():
		_level_start_camera_size = 0.0
		return
	var target := _calculate_target(tiles, _default_camera_size)
	camera.global_position = target.position
	camera.size = target.size
	_level_start_camera_size = target.size


func _on_viewport_size_changed() -> void:
	if _viewport_refit_pending:
		return
	_viewport_refit_pending = true
	_refit_after_viewport_change.call_deferred()


func _refit_after_viewport_change() -> void:
	_viewport_refit_pending = false
	if _shuffle_in_progress:
		return
	var tiles := _get_tiles()
	if tiles.is_empty():
		return
	var target := _calculate_target(tiles, _level_start_camera_size)
	_kill_tween()
	camera.global_position = target.position
	camera.size = target.size


func _calculate_target(tiles: Array[Node3D], closest_camera_size := 0.0) -> Dictionary:
	var camera_inverse := camera.global_transform.affine_inverse()
	var first_view_position: Vector3 = camera_inverse * tiles[0].global_position
	var minimum := Vector2(first_view_position.x, first_view_position.y)
	var maximum := minimum
	for tile in tiles:
		var view_position: Vector3 = camera_inverse * tile.global_position
		var point := Vector2(view_position.x, view_position.y)
		minimum = minimum.min(point)
		maximum = maximum.max(point)

	var center := (minimum + maximum) * 0.5
	var span := maximum - minimum + Vector2.ONE * frame_padding * 2.0
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var target_size := maxf(span.y, span.x / maxf(aspect, 0.01))
	target_size = maxf(target_size, closest_camera_size)

	var camera_plane_offset := camera.global_transform.basis * Vector3(center.x, center.y, 0.0)
	return {
		"position": camera.global_position + camera_plane_offset,
		"size": target_size,
	}


func _get_tiles() -> Array[Node3D]:
	var builder := BoardBuilderComponent.of_as(self)
	return builder.get_tiles() if builder != null else []


func _kill_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null


static func of_as(node: Node) -> BoardCameraFramingComponent:
	return BaseComponent.of(node, BoardCameraFramingComponent) as BoardCameraFramingComponent
