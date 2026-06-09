extends RefCounted

const VERTICAL_SIDE_DIRECTIONS: Array[Vector3i] = [
	Vector3i(1, 0, 0),
	Vector3i(-1, 0, 0),
	Vector3i(0, 0, 1),
	Vector3i(0, 0, -1)
]

static func make_occupancy(coords: Array) -> Dictionary:
	var occupancy := {}
	for coord in coords:
		occupancy[_to_vector3i(coord)] = true
	return occupancy

static func is_tile_free(pos: Vector3i, occupancy: Dictionary, grid_size: int) -> bool:
	if not occupancy.has(pos):
		return false

	var free_sides := free_vertical_sides(pos, occupancy, grid_size)
	return free_sides.size() >= 2 and has_adjacent_sides(free_sides)

static func free_vertical_sides(pos: Vector3i, occupancy: Dictionary, grid_size: int) -> Array[Vector3i]:
	var free_sides: Array[Vector3i] = []
	for direction: Vector3i in VERTICAL_SIDE_DIRECTIONS:
		var neighbor := pos + direction
		if not is_inside_grid(neighbor, grid_size) or not occupancy.has(neighbor):
			free_sides.append(direction)
	return free_sides

static func has_adjacent_sides(sides: Array[Vector3i]) -> bool:
	for i in range(sides.size()):
		for j in range(i + 1, sides.size()):
			if sides[i] + sides[j] != Vector3i.ZERO:
				return true
	return false

static func get_free_positions(occupancy: Dictionary, grid_size: int) -> Array[Vector3i]:
	var free_positions: Array[Vector3i] = []
	for pos: Vector3i in occupancy.keys():
		if is_tile_free(pos, occupancy, grid_size):
			free_positions.append(pos)
	return free_positions

static func is_inside_grid(pos: Vector3i, grid_size: int) -> bool:
	return pos.x >= 0 and pos.x < grid_size \
		and pos.y >= 0 and pos.y < grid_size \
		and pos.z >= 0 and pos.z < grid_size

static func _to_vector3i(value) -> Vector3i:
	if value is Vector3i:
		return value
	if value is Vector3:
		return Vector3i(int(value.x), int(value.y), int(value.z))
	if value is Array and value.size() >= 3:
		return Vector3i(int(value[0]), int(value[1]), int(value[2]))
	return Vector3i.ZERO
