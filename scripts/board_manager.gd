extends Node

const GRID_SIZE := 4
const GRID_MAX := GRID_SIZE - 1

var _grid := []
var _selected_tile = null

func _ready() -> void:
	_init_grid()

func _init_grid() -> void:
	_grid = []
	for x in range(GRID_SIZE):
		var plane := []
		for y in range(GRID_SIZE):
			var row := []
			for z in range(GRID_SIZE):
				row.append(null)
			plane.append(row)
		_grid.append(plane)

func on_board_ready(tiles: Array[Node3D]) -> void:
	_init_grid()
	for tile in tiles:
		var gp: Vector3 = tile.tile_data.grid_pos
		_grid[int(gp.x)][int(gp.y)][int(gp.z)] = tile

func on_layer_rotated(axis_name: String, layer_value: float, angle_degrees: float, spacing: int) -> void:
	var layer_index := _layer_to_grid_index(axis_name, layer_value, spacing)
	var angle := int(round(angle_degrees))

	var affected: Dictionary = {}
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			for z in range(GRID_SIZE):
				if _grid[x][y][z] == null:
					continue
				var in_layer := false
				match axis_name:
					"x": in_layer = (x == layer_index)
					"y": in_layer = (y == layer_index)
					"z": in_layer = (z == layer_index)
				if in_layer:
					affected[Vector3i(x, y, z)] = _grid[x][y][z]

	for pos in affected:
		_grid[pos.x][pos.y][pos.z] = null

	for pos: Vector3i in affected:
		var tile = affected[pos]
		var new_pos := _transform_pos(pos, axis_name, angle)
		_grid[new_pos.x][new_pos.y][new_pos.z] = tile
		tile.tile_data.grid_pos = Vector3(new_pos.x, new_pos.y, new_pos.z)

func on_tile_selected(tile: Node3D) -> void:
	if _selected_tile == null:
		_selected_tile = tile
		tile.select()
		return

	if _selected_tile == tile:
		tile.deselect()
		_selected_tile = null
		return

	if _selected_tile.tile_data.icon_type == tile.tile_data.icon_type:
		var p1 := Vector3i(int(_selected_tile.tile_data.grid_pos.x), int(_selected_tile.tile_data.grid_pos.y), int(_selected_tile.tile_data.grid_pos.z))
		var p2 := Vector3i(int(tile.tile_data.grid_pos.x), int(tile.tile_data.grid_pos.y), int(tile.tile_data.grid_pos.z))
		_grid[p1.x][p1.y][p1.z] = null
		_grid[p2.x][p2.y][p2.z] = null
		_selected_tile.remove_tile()
		tile.remove_tile()
		_selected_tile = null
	else:
		_selected_tile.deselect()
		_selected_tile = tile
		tile.select()

func _transform_pos(pos: Vector3i, axis: String, angle: int) -> Vector3i:
	var x := pos.x
	var y := pos.y
	var z := pos.z
	var M := GRID_MAX

	match axis:
		"x":
			match angle:
				90:        return Vector3i(x, M - z, y)
				-90, 270:  return Vector3i(x, z, M - y)
				180, -180: return Vector3i(x, M - y, M - z)
		"y":
			match angle:
				90:        return Vector3i(z, y, M - x)
				-90, 270:  return Vector3i(M - z, y, x)
				180, -180: return Vector3i(M - x, y, M - z)
		"z":
			match angle:
				90:        return Vector3i(M - y, x, z)
				-90, 270:  return Vector3i(y, M - x, z)
				180, -180: return Vector3i(M - x, M - y, z)
	return pos

func _layer_to_grid_index(axis: String, layer_value: float, spacing: int) -> int:
	match axis:
		"x": return int(round(layer_value / spacing + 1.5))
		"y": return int(round(layer_value / spacing))
		"z": return int(round(layer_value / spacing + 1.5))
	return 0
