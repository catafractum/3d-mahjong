extends RefCounted

const TileRules = preload("res://scripts/solver/tile_rules.gd")
const MahjongSolver = preload("res://scripts/solver/mahjong_solver.gd")
const MAX_SEQUENCE_ATTEMPTS := 80

static func assign_solvable_icons(coords: Array, grid_size: int, max_icon_count: int, difficulty := "easy") -> Dictionary:
	var positions := _to_positions(coords)
	var icon_by_pos := {}
	if positions.is_empty():
		return icon_by_pos

	if positions.size() % 2 != 0:
		push_warning("SymbolAssigner: level has %d tiles; solvable assignment needs an even tile count." % positions.size())
		return _assign_pair_icons(positions, max_icon_count, difficulty)

	var removal_pairs := _make_removal_sequence(positions, grid_size)
	if removal_pairs.is_empty():
		push_error("SymbolAssigner: could not build a solvable removal sequence for this level.")
		return _assign_pair_icons(positions, max_icon_count, difficulty)

	var icons := _make_icon_sequence(removal_pairs.size(), positions.size(), max_icon_count, difficulty)
	for i in range(removal_pairs.size()):
		var icon_type := icons[i]
		var pair: Array = removal_pairs[i]
		icon_by_pos[pair[0]] = icon_type
		icon_by_pos[pair[1]] = icon_type

	if not MahjongSolver.is_solvable(icon_by_pos, grid_size):
		push_error("SymbolAssigner: generated icon assignment did not pass solver verification.")

	return icon_by_pos

static func _make_removal_sequence(positions: Array[Vector3i], grid_size: int) -> Array[Array]:
	for attempt in range(MAX_SEQUENCE_ATTEMPTS):
		var occupancy := TileRules.make_occupancy(positions)
		var sequence: Array[Array] = []

		while not occupancy.is_empty():
			var free_positions := TileRules.get_free_positions(occupancy, grid_size)
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

static func _assign_pair_icons(positions: Array[Vector3i], max_icon_count: int, difficulty: String) -> Dictionary:
	var icon_by_pos := {}
	var shuffled := positions.duplicate()
	shuffled.shuffle()
	var pair_count := int(floor(float(shuffled.size()) * 0.5))
	var icons := _make_icon_sequence(pair_count, shuffled.size(), max_icon_count, difficulty)

	for i in range(pair_count):
		var icon_type := icons[i]
		icon_by_pos[shuffled[i * 2]] = icon_type
		icon_by_pos[shuffled[i * 2 + 1]] = icon_type

	if shuffled.size() % 2 != 0:
		icon_by_pos[shuffled[shuffled.size() - 1]] = 0

	return icon_by_pos

static func _make_icon_sequence(pair_count: int, tile_count: int, max_icon_count: int, difficulty: String) -> Array[int]:
	var pool_size := _get_icon_pool_size(tile_count, max_icon_count, difficulty)
	var icons: Array[int] = []
	for i in range(pair_count):
		icons.append(i % pool_size)
	icons.shuffle()
	return icons

static func _get_icon_pool_size(tile_count: int, max_icon_count: int, difficulty: String) -> int:
	if max_icon_count <= 0:
		return 1

	var desired := int(floor(float(tile_count) / 4.0))
	match difficulty:
		"easy":
			desired = clampi(desired, 4, 8)
		"normal":
			desired = clampi(desired, 6, 12)
		_:
			desired = clampi(desired, 8, 16)

	return clampi(desired, 1, max_icon_count)

static func _to_positions(coords: Array) -> Array[Vector3i]:
	var positions: Array[Vector3i] = []
	for coord in coords:
		if coord is Vector3i:
			positions.append(coord)
		elif coord is Vector3:
			positions.append(Vector3i(int(coord.x), int(coord.y), int(coord.z)))
		elif coord is Array and coord.size() >= 3:
			positions.append(Vector3i(int(coord[0]), int(coord[1]), int(coord[2])))
	return positions
