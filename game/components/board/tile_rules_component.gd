class_name TileRulesComponent
extends BaseComponent

const SIDE_DIRECTIONS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]


func make_occupancy(coordinates: Array) -> Dictionary:
	var occupancy: Dictionary = {}
	for coordinate in coordinates:
		occupancy[Vector3i(coordinate)] = true
	return occupancy


func is_tile_free(position: Vector3i, occupancy: Dictionary, grid_size: int) -> bool:
	if not occupancy.has(position):
		return false
	var free_sides := free_sides(position, occupancy, grid_size)
	for first in range(free_sides.size()):
		for second in range(first + 1, free_sides.size()):
			if free_sides[first] + free_sides[second] != Vector3i.ZERO:
				return true
	return false


func free_sides(position: Vector3i, occupancy: Dictionary, grid_size: int) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for direction in SIDE_DIRECTIONS:
		var neighbor := position + direction
		if not _inside_grid(neighbor, grid_size) or not occupancy.has(neighbor):
			result.append(direction)
	return result


func get_free_positions(occupancy: Dictionary, grid_size: int) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for position: Vector3i in occupancy:
		if is_tile_free(position, occupancy, grid_size):
			result.append(position)
	return result


func _inside_grid(position: Vector3i, grid_size: int) -> bool:
	return position.x >= 0 and position.x < grid_size \
		and position.y >= 0 and position.y < grid_size \
		and position.z >= 0 and position.z < grid_size


static func of_as(node: Node) -> TileRulesComponent:
	return BaseComponent.of(node, TileRulesComponent) as TileRulesComponent
