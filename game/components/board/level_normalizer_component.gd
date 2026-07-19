class_name LevelNormalizerComponent
extends BaseComponent


func normalize(tile_coordinates: Array, grid_size: int, y_offset := 0.0) -> Dictionary:
	var coordinates: Array[Vector3i] = []
	for coordinate in tile_coordinates:
		if coordinate is Array and coordinate.size() >= 3:
			coordinates.append(Vector3i(int(coordinate[0]), int(coordinate[1]), int(coordinate[2])))

	var default_bounds := _bounds_for_grid(grid_size)
	if coordinates.is_empty():
		return {
			"coordinates": coordinates,
			"visual_offset": Vector3(0.0, y_offset, 0.0),
			"rotation_visual_offset": Vector3(0.0, y_offset, 0.0),
			"rotation_bounds": default_bounds,
		}

	var bounds := _get_bounds(coordinates)
	var maximum_dimension := _maximum_dimension(bounds, grid_size)
	var centered_minimum := int(round(
		(float(grid_size - 1) - float(maximum_dimension - 1)) * 0.5
	))
	var centered_maximum := centered_minimum + maximum_dimension - 1
	var shift_x := _center_axis_shift(bounds.min_x, bounds.max_x, grid_size)
	var shift_z := _center_axis_shift(bounds.min_z, bounds.max_z, grid_size)
	var normalized: Array[Vector3i] = []
	for coordinate in coordinates:
		normalized.append(Vector3i(
			coordinate.x + shift_x,
			coordinate.y - int(bounds.min_y),
			coordinate.z + shift_z
		))

	return {
		"coordinates": normalized,
		"visual_offset": Vector3(
			_center_axis_visual_offset(bounds.min_x + shift_x, bounds.max_x + shift_x, grid_size),
			y_offset,
			_center_axis_visual_offset(bounds.min_z + shift_z, bounds.max_z + shift_z, grid_size)
		),
		"rotation_visual_offset": Vector3(
			_center_axis_visual_offset(centered_minimum, centered_maximum, grid_size),
			y_offset,
			_center_axis_visual_offset(centered_minimum, centered_maximum, grid_size)
		),
		"rotation_bounds": {
			"min_x": centered_minimum,
			"max_x": centered_maximum,
			"min_y": 0,
			"max_y": maximum_dimension - 1,
			"min_z": centered_minimum,
			"max_z": centered_maximum,
		},
	}


func is_inside_grid(coordinate: Vector3i, grid_size: int) -> bool:
	return coordinate.x >= 0 and coordinate.x < grid_size \
		and coordinate.y >= 0 and coordinate.y < grid_size \
		and coordinate.z >= 0 and coordinate.z < grid_size


func _bounds_for_grid(grid_size: int) -> Dictionary:
	return {"min_x": 0, "max_x": grid_size - 1, "min_y": 0, "max_y": grid_size - 1, "min_z": 0, "max_z": grid_size - 1}


func _get_bounds(coordinates: Array[Vector3i]) -> Dictionary:
	var result := {"min_x": coordinates[0].x, "max_x": coordinates[0].x, "min_y": coordinates[0].y, "max_y": coordinates[0].y, "min_z": coordinates[0].z, "max_z": coordinates[0].z}
	for coordinate in coordinates:
		result.min_x = mini(result.min_x, coordinate.x)
		result.max_x = maxi(result.max_x, coordinate.x)
		result.min_y = mini(result.min_y, coordinate.y)
		result.max_y = maxi(result.max_y, coordinate.y)
		result.min_z = mini(result.min_z, coordinate.z)
		result.max_z = maxi(result.max_z, coordinate.z)
	return result


func _maximum_dimension(bounds: Dictionary, grid_size: int) -> int:
	var width := int(bounds.max_x) - int(bounds.min_x) + 1
	var height := int(bounds.max_y) - int(bounds.min_y) + 1
	var depth := int(bounds.max_z) - int(bounds.min_z) + 1
	return clampi(maxi(width, maxi(height, depth)), 1, grid_size)


func _center_axis_shift(minimum: int, maximum: int, grid_size: int) -> int:
	var shift := int(round(float(grid_size - 1) * 0.5 - (float(minimum + maximum) * 0.5)))
	if minimum + shift < 0:
		shift -= minimum + shift
	if maximum + shift >= grid_size:
		shift -= maximum + shift - (grid_size - 1)
	return shift


func _center_axis_visual_offset(minimum: int, maximum: int, grid_size: int) -> float:
	return float(grid_size - 1) * 0.5 - float(minimum + maximum) * 0.5


static func of_as(node: Node) -> LevelNormalizerComponent:
	return BaseComponent.of(node, LevelNormalizerComponent) as LevelNormalizerComponent
