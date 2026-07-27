class_name BoardBuilderComponent
extends BaseComponent

const BOARD_Y_OFFSET := -0.25
const BOARD_INITIAL_ROTATION := Vector3(0.0, -10.0, 0.0)
const LEVEL_SCALE_BY_HEIGHT := {
	6: 0.875,
	7: 0.775,
}

signal board_built(tiles: Array[Node3D])
signal board_cleared

@export var board: Node3D
@export var tile_scene: PackedScene
@export var icon_type_count := 16
@export var default_grid_size := 7
@export var tile_spacing := 1.03
@export var maximum_sequence_attempts := 80

var grid_size := 7
var visual_offset := Vector3.ZERO
var rotation_visual_offset := Vector3.ZERO
var rotation_bounds: Dictionary = {}


func _ready() -> void:
	_build_current_level.call_deferred()


func _build_current_level() -> void:
	var session_component := CurrentGameSessionComponent.of_as(self)
	if session_component == null or session_component.session == null:
		push_error("BoardBuilderComponent: No current game session is available.")
		return
	build_level(session_component.session.get_current_level())


func build_level(level: Dictionary) -> void:
	clear_board()
	if level.is_empty():
		push_error("BoardBuilderComponent: Cannot build an empty level.")
		return

	var tile_coordinates: Array = level.get("tiles", [])
	if tile_coordinates.is_empty():
		push_error("BoardBuilderComponent: Level has no tiles.")
		return

	grid_size = int(level.get("grid_size", default_grid_size))
	var normalized_level := _normalize_level(
		tile_coordinates,
		grid_size,
		BOARD_Y_OFFSET
	)
	var coordinates: Array = normalized_level.coordinates
	visual_offset = normalized_level.visual_offset
	rotation_visual_offset = normalized_level.rotation_visual_offset
	rotation_bounds = normalized_level.rotation_bounds

	board.rotation_degrees = BOARD_INITIAL_ROTATION
	board.scale = Vector3.ONE * _get_level_scale(_get_height(coordinates))

	var icon_assignment := assign_solvable_icons(
		coordinates,
		grid_size,
		icon_type_count,
		str(level.get("difficulty", "easy"))
	)
	var center := float(grid_size - 1) * 0.5
	var tiles: Array[Node3D] = []

	for coordinate: Vector3i in coordinates:
		if not _is_inside_grid(coordinate, grid_size):
			push_warning("BoardBuilderComponent: Skipping tile outside the grid: ", coordinate)
			continue

		var tile := tile_scene.instantiate() as Node3D
		board.add_child(tile)
		tile.position = Vector3(
			(coordinate.x - center + visual_offset.x) * tile_spacing,
			(coordinate.y + BOARD_Y_OFFSET) * tile_spacing,
			(coordinate.z - center + visual_offset.z) * tile_spacing
		)
		tile.name = "Tile_%d" % tiles.size()
		var tile_component := MahjongTileComponent.of_as(tile)
		if tile_component == null:
			push_error("BoardBuilderComponent: Tile prefab has no MahjongTileComponent.")
			tile.queue_free()
			continue
		tile_component.configure(tiles.size(), coordinate, int(icon_assignment.get(coordinate, 0)))
		tiles.append(tile)

	board_built.emit(tiles)


func clear_board() -> void:
	for child in board.get_children():
		if child is Node3D:
			board.remove_child(child)
			child.queue_free()
	board_cleared.emit()


func get_tiles() -> Array[Node3D]:
	var tiles: Array[Node3D] = []
	for child in board.get_children():
		if child is Node3D and MahjongTileComponent.of_as(child) != null:
			tiles.append(child)
	return tiles


func _get_level_scale(height: int) -> float:
	return float(LEVEL_SCALE_BY_HEIGHT.get(height, 1.0))


func _get_height(coordinates: Array) -> int:
	if coordinates.is_empty():
		return 0
	var minimum := int(coordinates[0].y)
	var maximum := minimum
	for coordinate in coordinates:
		minimum = mini(minimum, int(coordinate.y))
		maximum = maxi(maximum, int(coordinate.y))
	return maximum - minimum + 1


func assign_solvable_icons(
	coordinates: Array,
	assignment_grid_size: int,
	maximum_icon_count: int,
	difficulty := "easy"
) -> Dictionary:
	var positions: Array[Vector3i] = []
	for coordinate in coordinates:
		positions.append(Vector3i(coordinate))
	if positions.is_empty():
		return {}

	var removal_pairs := _make_removal_sequence(positions, assignment_grid_size)
	if removal_pairs.is_empty():
		return _assign_pair_icons(positions, maximum_icon_count, difficulty)

	var result: Dictionary = {}
	var icons := _make_icon_sequence(removal_pairs.size(), positions.size(), maximum_icon_count, difficulty)
	for index in removal_pairs.size():
		var pair: Array = removal_pairs[index]
		result[pair[0]] = icons[index]
		result[pair[1]] = icons[index]

	var solver := MahjongSolverComponent.of_as(self)
	if solver != null and not solver.is_solvable(result, assignment_grid_size):
		push_error("BoardBuilderComponent: Generated assignment is not solvable.")
	return result


func _make_removal_sequence(positions: Array[Vector3i], assignment_grid_size: int) -> Array[Array]:
	var rules := TileRulesComponent.of_as(self)
	if rules == null:
		return []
	for _attempt in maximum_sequence_attempts:
		var occupancy := rules.make_occupancy(positions)
		var sequence: Array[Array] = []
		while not occupancy.is_empty():
			var free_positions := rules.get_free_positions(occupancy, assignment_grid_size)
			if free_positions.size() < 2:
				break
			free_positions.shuffle()
			var pair := [free_positions[0], free_positions[1]]
			occupancy.erase(pair[0])
			occupancy.erase(pair[1])
			sequence.append(pair)
		if occupancy.is_empty():
			return sequence
	return []


func _assign_pair_icons(positions: Array[Vector3i], maximum_icon_count: int, difficulty: String) -> Dictionary:
	var result: Dictionary = {}
	var shuffled := positions.duplicate()
	shuffled.shuffle()
	var pair_count := int(shuffled.size() / 2.0)
	var icons := _make_icon_sequence(pair_count, shuffled.size(), maximum_icon_count, difficulty)
	for index in pair_count:
		result[shuffled[index * 2]] = icons[index]
		result[shuffled[index * 2 + 1]] = icons[index]
	if shuffled.size() % 2 != 0:
		result[shuffled.back()] = 0
	return result


func _make_icon_sequence(pair_count: int, tile_count: int, maximum_icon_count: int, difficulty: String) -> Array[int]:
	var pool_size := _icon_pool_size(tile_count, maximum_icon_count, difficulty)
	var result: Array[int] = []
	for index in pair_count:
		result.append(index % pool_size)
	result.shuffle()
	return result


func _icon_pool_size(tile_count: int, maximum: int, difficulty: String) -> int:
	if maximum <= 0:
		return 1
	var desired := int(tile_count / 4.0)
	match difficulty:
		"easy": desired = clampi(desired, 4, 8)
		"medium": desired = clampi(desired, 6, 12)
		_: desired = clampi(desired, 8, 16)
	return clampi(desired, 1, maximum)


func _normalize_level(tile_coordinates: Array, normalized_grid_size: int, y_offset := 0.0) -> Dictionary:
	var coordinates: Array[Vector3i] = []
	for coordinate in tile_coordinates:
		if coordinate is Array and coordinate.size() >= 3:
			coordinates.append(Vector3i(int(coordinate[0]), int(coordinate[1]), int(coordinate[2])))
	var default_bounds := _bounds_for_grid(normalized_grid_size)
	if coordinates.is_empty():
		return {"coordinates": coordinates, "visual_offset": Vector3(0.0, y_offset, 0.0), "rotation_visual_offset": Vector3(0.0, y_offset, 0.0), "rotation_bounds": default_bounds}

	var bounds := _get_bounds(coordinates)
	var maximum_dimension := _maximum_dimension(bounds, normalized_grid_size)
	var centered_minimum := int(round((float(normalized_grid_size - 1) - float(maximum_dimension - 1)) * 0.5))
	var centered_maximum := centered_minimum + maximum_dimension - 1
	var shift_x := _center_axis_shift(bounds.min_x, bounds.max_x, normalized_grid_size)
	var shift_z := _center_axis_shift(bounds.min_z, bounds.max_z, normalized_grid_size)
	var normalized: Array[Vector3i] = []
	for coordinate in coordinates:
		normalized.append(Vector3i(coordinate.x + shift_x, coordinate.y - int(bounds.min_y), coordinate.z + shift_z))
	return {
		"coordinates": normalized,
		"visual_offset": Vector3(_center_axis_visual_offset(bounds.min_x + shift_x, bounds.max_x + shift_x, normalized_grid_size), y_offset, _center_axis_visual_offset(bounds.min_z + shift_z, bounds.max_z + shift_z, normalized_grid_size)),
		"rotation_visual_offset": Vector3(_center_axis_visual_offset(centered_minimum, centered_maximum, normalized_grid_size), y_offset, _center_axis_visual_offset(centered_minimum, centered_maximum, normalized_grid_size)),
		"rotation_bounds": {"min_x": centered_minimum, "max_x": centered_maximum, "min_y": 0, "max_y": maximum_dimension - 1, "min_z": centered_minimum, "max_z": centered_maximum},
	}


func _bounds_for_grid(size: int) -> Dictionary:
	return {"min_x": 0, "max_x": size - 1, "min_y": 0, "max_y": size - 1, "min_z": 0, "max_z": size - 1}


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


func _maximum_dimension(bounds: Dictionary, size: int) -> int:
	var width := int(bounds.max_x) - int(bounds.min_x) + 1
	var height := int(bounds.max_y) - int(bounds.min_y) + 1
	var depth := int(bounds.max_z) - int(bounds.min_z) + 1
	return clampi(maxi(width, maxi(height, depth)), 1, size)


func _center_axis_shift(minimum: int, maximum: int, size: int) -> int:
	var shift := int(round(float(size - 1) * 0.5 - (float(minimum + maximum) * 0.5)))
	if minimum + shift < 0:
		shift -= minimum + shift
	if maximum + shift >= size:
		shift -= maximum + shift - (size - 1)
	return shift


func _center_axis_visual_offset(minimum: int, maximum: int, size: int) -> float:
	return float(size - 1) * 0.5 - float(minimum + maximum) * 0.5


func _is_inside_grid(coordinate: Vector3i, size: int) -> bool:
	return coordinate.x >= 0 and coordinate.x < size \
		and coordinate.y >= 0 and coordinate.y < size \
		and coordinate.z >= 0 and coordinate.z < size


static func of_as(node: Node) -> BoardBuilderComponent:
	return BaseComponent.of(node, BoardBuilderComponent) as BoardBuilderComponent
