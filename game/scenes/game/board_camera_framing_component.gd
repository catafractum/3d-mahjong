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
	_tween_to_target(target)


func _on_board_built(tiles: Array[Node3D]) -> void:
	_kill_tween()
	_shuffle_in_progress = false
	camera.global_position = _default_camera_position
	camera.size = _default_camera_size
	if tiles.is_empty():
		_level_start_camera_size = 0.0
		return
	var target := _calculate_target(tiles, _default_camera_size)
	_level_start_camera_size = target.size
	_tween_to_target(target)


func _tween_to_target(target: Dictionary) -> void:
	_kill_tween()
	_tween = create_tween().set_parallel(true)
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_property(camera, "global_position", target.position, settle_duration)
	_tween.tween_property(camera, "size", target.size, settle_duration)
	_tween.chain().tween_callback(framing_settled.emit)


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
	var board_inverse := board.global_transform.affine_inverse()
	var board_to_view := camera_inverse * board.global_transform
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for tile in tiles:
		var corners: Array[Vector3] = []
		_collect_mesh_corners(tile, board_inverse, corners)
		if corners.is_empty():
			corners.append(board_inverse * tile.global_position)
		for corner in corners:
			# The board rotates around Y with uniform scale. Each corner sweeps
			# a circle; its projection on either camera axis is a sinusoid.
			# Its exact extrema cover intermediate animation angles as well.
			var radius := Vector2(corner.x, corner.z).length()
			var orbit_center := board_to_view * Vector3(0.0, corner.y, 0.0)
			var extent := radius * Vector2(
				Vector2(board_to_view.basis.x.x, board_to_view.basis.z.x).length(),
				Vector2(board_to_view.basis.x.y, board_to_view.basis.z.y).length()
			)
			var point := Vector2(orbit_center.x, orbit_center.y)
			minimum = minimum.min(point - extent)
			maximum = maximum.max(point + extent)

	var center := (minimum + maximum) * 0.5
	var span := maximum - minimum + Vector2.ONE * frame_padding * 2.0
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var target_size := maxf(span.y, span.x / maxf(aspect, 0.01))
	if camera.keep_aspect == Camera3D.KEEP_WIDTH:
		target_size = maxf(span.x, span.y * aspect)
	target_size = maxf(target_size, closest_camera_size)

	var camera_plane_offset := camera.global_transform.basis * Vector3(center.x, center.y, 0.0)
	return {
		"position": camera.global_position + camera_plane_offset,
		"size": target_size,
	}


func _collect_mesh_corners(node: Node, board_inverse: Transform3D, corners: Array[Vector3]) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null and mesh_instance.is_visible_in_tree():
			var bounds := mesh_instance.get_aabb()
			var mesh_to_board := board_inverse * mesh_instance.global_transform
			for index in 8:
				corners.append(mesh_to_board * bounds.get_endpoint(index))
	for child in node.get_children():
		_collect_mesh_corners(child, board_inverse, corners)


func _get_tiles() -> Array[Node3D]:
	var builder := BoardBuilderComponent.of_as(self)
	if builder != null:
		return builder.get_tiles()
	return []


func _kill_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null


static func of_as(node: Node) -> BoardCameraFramingComponent:
	return BaseComponent.of(node, BoardCameraFramingComponent) as BoardCameraFramingComponent
