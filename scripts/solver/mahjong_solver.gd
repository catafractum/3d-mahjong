extends RefCounted

const TileRules = preload("res://scripts/solver/tile_rules.gd")
const DEFAULT_MAX_SEARCH_NODES := 50000

static func is_solvable(icon_by_pos: Dictionary, grid_size: int, max_search_nodes := DEFAULT_MAX_SEARCH_NODES) -> bool:
	var state := icon_by_pos.duplicate()
	var memo := {}
	var search_nodes := [0]
	return _can_solve(state, grid_size, memo, search_nodes, max_search_nodes)

static func has_any_move(icon_by_pos: Dictionary, grid_size: int) -> bool:
	return not get_available_pairs(icon_by_pos, grid_size).is_empty()

static func get_available_pairs(icon_by_pos: Dictionary, grid_size: int) -> Array[Dictionary]:
	var occupancy := TileRules.make_occupancy(icon_by_pos.keys())
	var free_by_icon := {}

	for pos: Vector3i in icon_by_pos.keys():
		if not TileRules.is_tile_free(pos, occupancy, grid_size):
			continue

		var icon_type := int(icon_by_pos[pos])
		if not free_by_icon.has(icon_type):
			free_by_icon[icon_type] = []
		free_by_icon[icon_type].append(pos)

	var pairs: Array[Dictionary] = []
	for icon_type: int in free_by_icon.keys():
		var positions: Array = free_by_icon[icon_type]
		if positions.size() < 2:
			continue

		for i in range(positions.size()):
			for j in range(i + 1, positions.size()):
				pairs.append({
					"a": positions[i],
					"b": positions[j],
					"icon_type": icon_type
				})

	return pairs

static func _can_solve(state: Dictionary, grid_size: int, memo: Dictionary, search_nodes: Array, max_search_nodes: int) -> bool:
	if state.is_empty():
		return true
	if search_nodes[0] >= max_search_nodes:
		return false

	var key := _state_key(state)
	if memo.has(key):
		return bool(memo[key])

	search_nodes[0] += 1
	var pairs := get_available_pairs(state, grid_size)
	for pair in pairs:
		var next_state := state.duplicate()
		next_state.erase(pair.a)
		next_state.erase(pair.b)
		if _can_solve(next_state, grid_size, memo, search_nodes, max_search_nodes):
			memo[key] = true
			return true

	memo[key] = false
	return false

static func _state_key(state: Dictionary) -> String:
	var parts: Array[String] = []
	for pos: Vector3i in state.keys():
		parts.append("%d,%d,%d:%d" % [pos.x, pos.y, pos.z, int(state[pos])])
	parts.sort()
	return "|".join(parts)
