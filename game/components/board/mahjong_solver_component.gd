class_name MahjongSolverComponent
extends BaseComponent

@export var maximum_search_nodes := 50000


func is_solvable(icon_by_position: Dictionary, grid_size: int) -> bool:
	return _can_solve(icon_by_position.duplicate(), grid_size, {}, [0])


func get_available_pairs(icon_by_position: Dictionary, grid_size: int) -> Array[Dictionary]:
	var rules := TileRulesComponent.of_as(self)
	var occupancy := rules.make_occupancy(icon_by_position.keys())
	var free_by_icon: Dictionary = {}
	for position: Vector3i in icon_by_position:
		if not rules.is_tile_free(position, occupancy, grid_size):
			continue
		var icon := int(icon_by_position[position])
		if not free_by_icon.has(icon):
			free_by_icon[icon] = []
		free_by_icon[icon].append(position)
	var result: Array[Dictionary] = []
	for icon in free_by_icon:
		var positions: Array = free_by_icon[icon]
		for first in range(positions.size()):
			for second in range(first + 1, positions.size()):
				result.append({"a": positions[first], "b": positions[second], "icon_type": icon})
	return result


func _can_solve(state: Dictionary, grid_size: int, memo: Dictionary, searched: Array) -> bool:
	if state.is_empty():
		return true
	if searched[0] >= maximum_search_nodes:
		return false
	var key := _state_key(state)
	if memo.has(key):
		return memo[key]
	searched[0] += 1
	for pair in get_available_pairs(state, grid_size):
		var next := state.duplicate()
		next.erase(pair.a)
		next.erase(pair.b)
		if _can_solve(next, grid_size, memo, searched):
			memo[key] = true
			return true
	memo[key] = false
	return false


func _state_key(state: Dictionary) -> String:
	var parts: Array[String] = []
	for position: Vector3i in state:
		parts.append("%d,%d,%d:%d" % [position.x, position.y, position.z, state[position]])
	parts.sort()
	return "|".join(parts)


static func of_as(node: Node) -> MahjongSolverComponent:
	return BaseComponent.of(node, MahjongSolverComponent) as MahjongSolverComponent
