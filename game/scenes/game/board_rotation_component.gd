class_name BoardRotationComponent
extends BaseComponent

@export var board: Node3D
@export var rotation_duration := 0.4
@export var layer_rotation_duration := 0.35
@export var shuffle_step_count := 7

var _rotating := false
var _counter_rotated_tiles: Array[Node3D] = []
var _last_layer_angle := 0.0


func rotate(right: bool) -> void:
	if _rotating:
		return
	_rotating = true
	var direction := 90.0 if right else -90.0
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(board, "rotation_degrees:y", board.rotation_degrees.y + direction, rotation_duration)
	tween.tween_callback(func() -> void: _rotating = false)


func shuffle() -> void:
	if _rotating:
		return
	var builder := BoardBuilderComponent.of_as(self)
	var interaction := BoardInteractionComponent.of_as(self)
	if builder == null or interaction == null or builder.get_tiles().is_empty():
		return
	_rotating = true
	interaction.begin_shuffle()
	for _step in shuffle_step_count:
		var axis := ["x", "y", "z"].pick_random() as String
		var layers := _get_occupied_layers(builder.get_tiles(), axis)
		if layers.is_empty():
			continue
		var angle := 180
		if axis == "y":
			angle = [90, 180, -90].pick_random()
		await _rotate_layer(builder, axis, layers.pick_random(), angle)
	interaction.finish_shuffle()
	_rotating = false


func _rotate_layer(
	builder: BoardBuilderComponent,
	axis: String,
	layer: int,
	angle_degrees: int
) -> void:
	var layer_tiles: Array[Node3D] = []
	for tile in builder.get_tiles():
		var component := MahjongTileComponent.of_as(tile)
		if component != null and _axis_value(component.grid_position, axis) == layer:
			layer_tiles.append(tile)
	if layer_tiles.is_empty():
		return

	var pivot := Node3D.new()
	board.add_child(pivot)
	pivot.position = _layer_center(builder, axis, layer)
	for tile in layer_tiles:
		tile.reparent(pivot, true)

	_counter_rotated_tiles.clear()
	if axis != "y":
		_counter_rotated_tiles.assign(layer_tiles)
	_last_layer_angle = 0.0
	var tween := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(pivot, "rotation_degrees:%s" % axis, float(angle_degrees), layer_rotation_duration)
	if axis != "y":
		tween.parallel().tween_method(_counter_rotate_icons, 0.0, float(angle_degrees), layer_rotation_duration)
	await tween.finished
	_counter_rotated_tiles.clear()

	for tile in layer_tiles:
		var component := MahjongTileComponent.of_as(tile)
		var next_position := _transform_grid_position(
			component.grid_position,
			axis,
			angle_degrees,
			builder.rotation_bounds
		)
		component.grid_position = next_position
		tile.reparent(board, true)
		tile.position = _grid_to_board_position(builder, next_position)
	pivot.queue_free()


func _counter_rotate_icons(current_angle: float) -> void:
	var delta := deg_to_rad(current_angle - _last_layer_angle)
	_last_layer_angle = current_angle
	for tile in _counter_rotated_tiles:
		if is_instance_valid(tile):
			var visual := MahjongTileVisualComponent.of_as(tile)
			if visual != null:
				visual.counter_rotate_icons(-delta)


func _get_occupied_layers(tiles: Array[Node3D], axis: String) -> Array[int]:
	var result: Array[int] = []
	for tile in tiles:
		var component := MahjongTileComponent.of_as(tile)
		if component == null:
			continue
		var value := _axis_value(component.grid_position, axis)
		if value not in result:
			result.append(value)
	return result


func _axis_value(position: Vector3i, axis: String) -> int:
	match axis:
		"x": return position.x
		"y": return position.y
		_: return position.z


func _layer_center(builder: BoardBuilderComponent, axis: String, layer: int) -> Vector3:
	var bounds := builder.rotation_bounds
	var center := Vector3(
		(float(bounds.min_x) + float(bounds.max_x)) * 0.5,
		(float(bounds.min_y) + float(bounds.max_y)) * 0.5,
		(float(bounds.min_z) + float(bounds.max_z)) * 0.5
	)
	match axis:
		"x": center.x = layer
		"y": center.y = layer
		"z": center.z = layer
	return _grid_to_board_position(builder, center)


func _grid_to_board_position(builder: BoardBuilderComponent, position: Vector3) -> Vector3:
	var center := float(builder.grid_size - 1) * 0.5
	return Vector3(
		(position.x - center + builder.visual_offset.x) * builder.tile_spacing,
		(position.y + BoardBuilderComponent.BOARD_Y_OFFSET) * builder.tile_spacing,
		(position.z - center + builder.visual_offset.z) * builder.tile_spacing
	)


func _transform_grid_position(
	position: Vector3i,
	axis: String,
	angle: int,
	bounds: Dictionary
) -> Vector3i:
	var x := position.x
	var y := position.y
	var z := position.z
	match axis:
		"x":
			match angle:
				90: return Vector3i(x, int(bounds.min_y) + int(bounds.max_z) - z, int(bounds.min_z) + y - int(bounds.min_y))
				-90: return Vector3i(x, int(bounds.min_y) + z - int(bounds.min_z), int(bounds.min_z) + int(bounds.max_y) - y)
				_: return Vector3i(x, int(bounds.min_y) + int(bounds.max_y) - y, int(bounds.min_z) + int(bounds.max_z) - z)
		"y":
			match angle:
				90: return Vector3i(int(bounds.min_x) + z - int(bounds.min_z), y, int(bounds.min_z) + int(bounds.max_x) - x)
				-90: return Vector3i(int(bounds.min_x) + int(bounds.max_z) - z, y, int(bounds.min_z) + x - int(bounds.min_x))
				_: return Vector3i(int(bounds.min_x) + int(bounds.max_x) - x, y, int(bounds.min_z) + int(bounds.max_z) - z)
		_:
			match angle:
				90: return Vector3i(int(bounds.min_x) + int(bounds.max_y) - y, int(bounds.min_y) + x - int(bounds.min_x), z)
				-90: return Vector3i(int(bounds.min_x) + y - int(bounds.min_y), int(bounds.min_y) + int(bounds.max_x) - x, z)
				_: return Vector3i(int(bounds.min_x) + int(bounds.max_x) - x, int(bounds.min_y) + int(bounds.max_y) - y, z)
	return position


static func of_as(node: Node) -> BoardRotationComponent:
	return BaseComponent.of(node, BoardRotationComponent) as BoardRotationComponent
