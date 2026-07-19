class_name SymbolAssignerComponent
extends BaseComponent

@export var maximum_sequence_attempts := 80


func assign_solvable_icons(
	coordinates: Array,
	grid_size: int,
	maximum_icon_count: int,
	difficulty := "easy"
) -> Dictionary:
	var positions: Array[Vector3i] = []
	for coordinate in coordinates:
		positions.append(Vector3i(coordinate))
	if positions.is_empty():
		return {}

	var removal_pairs := _make_removal_sequence(positions, grid_size)
	if removal_pairs.is_empty():
		return _assign_pair_icons(positions, maximum_icon_count, difficulty)

	var result: Dictionary = {}
	var icons := _make_icon_sequence(removal_pairs.size(), positions.size(), maximum_icon_count, difficulty)
	for index in removal_pairs.size():
		var pair: Array = removal_pairs[index]
		result[pair[0]] = icons[index]
		result[pair[1]] = icons[index]

	var solver := MahjongSolverComponent.of_as(self)
	if solver != null and not solver.is_solvable(result, grid_size):
		push_error("SymbolAssignerComponent: Generated assignment is not solvable.")
	return result


func _make_removal_sequence(positions: Array[Vector3i], grid_size: int) -> Array[Array]:
	var rules := TileRulesComponent.of_as(self)
	for _attempt in maximum_sequence_attempts:
		var occupancy := rules.make_occupancy(positions)
		var sequence: Array[Array] = []
		while not occupancy.is_empty():
			var free_positions := rules.get_free_positions(occupancy, grid_size)
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


func _assign_pair_icons(
	positions: Array[Vector3i],
	maximum_icon_count: int,
	difficulty: String
) -> Dictionary:
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


func _make_icon_sequence(
	pair_count: int,
	tile_count: int,
	maximum_icon_count: int,
	difficulty: String
) -> Array[int]:
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


static func of_as(node: Node) -> SymbolAssignerComponent:
	return BaseComponent.of(node, SymbolAssignerComponent) as SymbolAssignerComponent
