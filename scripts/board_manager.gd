extends Node

const GRID_SIZE := 7
const GRID_MAX := GRID_SIZE - 1
const GRID_CENTER_OFFSET := float(GRID_MAX) * 0.5

var _grid := []
var _selected_tile = null
var _rotation_bounds := {
	"min_x": 0,
	"max_x": GRID_MAX,
	"min_y": 0,
	"max_y": GRID_MAX,
	"min_z": 0,
	"max_z": GRID_MAX
}

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
	_update_rotation_bounds(tiles)
	for tile in tiles:
		var gp: Vector3 = tile.tile_data.grid_pos
		_grid[int(gp.x)][int(gp.y)][int(gp.z)] = tile

func on_layer_rotated(axis_name: String, layer_value: float, angle_degrees: float, spacing: int, visual_offset := Vector3.ZERO) -> void:
	var layer_index := _layer_to_grid_index(axis_name, layer_value, spacing, visual_offset)
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

	match axis:
		"x":
			var min_y := int(_rotation_bounds.min_y)
			var max_y := int(_rotation_bounds.max_y)
			var min_z := int(_rotation_bounds.min_z)
			var max_z := int(_rotation_bounds.max_z)
			match angle:
				90:        return Vector3i(x, min_y + (max_z - z), min_z + (y - min_y))
				-90, 270:  return Vector3i(x, min_y + (z - min_z), min_z + (max_y - y))
				180, -180: return Vector3i(x, min_y + (max_y - y), min_z + (max_z - z))
		"y":
			var min_x := int(_rotation_bounds.min_x)
			var max_x := int(_rotation_bounds.max_x)
			var min_z := int(_rotation_bounds.min_z)
			var max_z := int(_rotation_bounds.max_z)
			match angle:
				90:        return Vector3i(min_x + (z - min_z), y, min_z + (max_x - x))
				-90, 270:  return Vector3i(min_x + (max_z - z), y, min_z + (x - min_x))
				180, -180: return Vector3i(min_x + (max_x - x), y, min_z + (max_z - z))
		"z":
			var min_x := int(_rotation_bounds.min_x)
			var max_x := int(_rotation_bounds.max_x)
			var min_y := int(_rotation_bounds.min_y)
			var max_y := int(_rotation_bounds.max_y)
			match angle:
				90:        return Vector3i(min_x + (max_y - y), min_y + (x - min_x), z)
				-90, 270:  return Vector3i(min_x + (y - min_y), min_y + (max_x - x), z)
				180, -180: return Vector3i(min_x + (max_x - x), min_y + (max_y - y), z)
	return pos

func _update_rotation_bounds(tiles: Array[Node3D]) -> void:
	if tiles.is_empty():
		return

	var first_gp: Vector3 = tiles[0].tile_data.grid_pos
	var min_x := int(first_gp.x)
	var max_x := min_x
	var min_y := int(first_gp.y)
	var max_y := min_y
	var min_z := int(first_gp.z)
	var max_z := min_z

	for tile in tiles:
		var gp: Vector3 = tile.tile_data.grid_pos
		min_x = mini(min_x, int(gp.x))
		max_x = maxi(max_x, int(gp.x))
		min_y = mini(min_y, int(gp.y))
		max_y = maxi(max_y, int(gp.y))
		min_z = mini(min_z, int(gp.z))
		max_z = maxi(max_z, int(gp.z))

	var max_dimension := maxi(max_x - min_x + 1, maxi(max_y - min_y + 1, max_z - min_z + 1))
	max_dimension = clampi(max_dimension, 1, GRID_SIZE)
	var centered_min := int(round(GRID_CENTER_OFFSET - (float(max_dimension - 1) * 0.5)))
	var centered_max := centered_min + max_dimension - 1

	_rotation_bounds = {
		"min_x": centered_min,
		"max_x": centered_max,
		"min_y": 0,
		"max_y": max_dimension - 1,
		"min_z": centered_min,
		"max_z": centered_max
	}

func _layer_to_grid_index(axis: String, layer_value: float, spacing: int, visual_offset: Vector3) -> int:
	match axis:
		"x": return int(round(layer_value / spacing + GRID_CENTER_OFFSET - visual_offset.x))
		"y": return int(round(layer_value / spacing - visual_offset.y))
		"z": return int(round(layer_value / spacing + GRID_CENTER_OFFSET - visual_offset.z))
	return 0
