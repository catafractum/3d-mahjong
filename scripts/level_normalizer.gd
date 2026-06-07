extends RefCounted

static func normalize(tile_coords: Array, grid_size: int, y_offset := 0.0) -> Dictionary:
	var coords: Array[Vector3i] = []
	for coord in tile_coords:
		if coord is Array and coord.size() >= 3:
			coords.append(Vector3i(int(coord[0]), int(coord[1]), int(coord[2])))

	var default_bounds := {
		"min_x": 0,
		"max_x": grid_size - 1,
		"min_y": 0,
		"max_y": grid_size - 1,
		"min_z": 0,
		"max_z": grid_size - 1
	}
	if coords.is_empty():
		return {
			"coords": coords,
			"visual_offset": Vector3(0.0, y_offset, 0.0),
			"rotation_visual_offset": Vector3(0.0, y_offset, 0.0),
			"rotation_bounds": default_bounds
		}

	var bounds := _get_bounds(coords)
	var max_dimension := _max_dimension(bounds, grid_size)
	var centered_min := int(round((float(grid_size - 1) * 0.5) - (float(max_dimension - 1) * 0.5)))
	var centered_max := centered_min + max_dimension - 1

	var shift_x := _center_axis_shift(bounds.min_x, bounds.max_x, grid_size)
	var shift_z := _center_axis_shift(bounds.min_z, bounds.max_z, grid_size)

	var normalized: Array[Vector3i] = []
	for coord in coords:
		normalized.append(Vector3i(coord.x + shift_x, coord.y - int(bounds.min_y), coord.z + shift_z))

	return {
		"coords": normalized,
		"visual_offset": Vector3(
			_center_axis_visual_offset(int(bounds.min_x) + shift_x, int(bounds.max_x) + shift_x, grid_size),
			y_offset,
			_center_axis_visual_offset(int(bounds.min_z) + shift_z, int(bounds.max_z) + shift_z, grid_size)
		),
		"rotation_visual_offset": Vector3(
			_center_axis_visual_offset(centered_min, centered_max, grid_size),
			y_offset,
			_center_axis_visual_offset(centered_min, centered_max, grid_size)
		),
		"rotation_bounds": {
			"min_x": centered_min,
			"max_x": centered_max,
			"min_y": 0,
			"max_y": max_dimension - 1,
			"min_z": centered_min,
			"max_z": centered_max
		}
	}

static func is_inside_grid(coord: Vector3i, grid_size: int) -> bool:
	return coord.x >= 0 and coord.x < grid_size \
		and coord.y >= 0 and coord.y < grid_size \
		and coord.z >= 0 and coord.z < grid_size

static func _get_bounds(coords: Array[Vector3i]) -> Dictionary:
	var min_x := coords[0].x
	var max_x := coords[0].x
	var min_y := coords[0].y
	var max_y := coords[0].y
	var min_z := coords[0].z
	var max_z := coords[0].z

	for coord in coords:
		min_x = mini(min_x, coord.x)
		max_x = maxi(max_x, coord.x)
		min_y = mini(min_y, coord.y)
		max_y = maxi(max_y, coord.y)
		min_z = mini(min_z, coord.z)
		max_z = maxi(max_z, coord.z)

	return {
		"min_x": min_x,
		"max_x": max_x,
		"min_y": min_y,
		"max_y": max_y,
		"min_z": min_z,
		"max_z": max_z
	}

static func _max_dimension(bounds: Dictionary, grid_size: int) -> int:
	var width_x := int(bounds.max_x) - int(bounds.min_x) + 1
	var height_y := int(bounds.max_y) - int(bounds.min_y) + 1
	var depth_z := int(bounds.max_z) - int(bounds.min_z) + 1
	return clampi(maxi(width_x, maxi(height_y, depth_z)), 1, grid_size)

static func _center_axis_shift(min_value: int, max_value: int, grid_size: int) -> int:
	var grid_max := grid_size - 1
	var current_center := (float(min_value) + float(max_value)) * 0.5
	var target_center := float(grid_max) * 0.5
	var shift := int(round(target_center - current_center))

	if min_value + shift < 0:
		shift -= min_value + shift
	if max_value + shift > grid_max:
		shift -= max_value + shift - grid_max
	return shift

static func _center_axis_visual_offset(min_value: int, max_value: int, grid_size: int) -> float:
	var current_center := (float(min_value) + float(max_value)) * 0.5
	var target_center := float(grid_size - 1) * 0.5
	return target_center - current_center
