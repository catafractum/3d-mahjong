class_name TileMatchingComponent
extends BaseComponent

signal selection_changed(previous_tile: Node3D, selected_tile: Node3D)
signal blocked_tile_pressed(tile: Node3D, hit_normal: Vector3)
signal match_succeeded(first_tile: Node3D, second_tile: Node3D)
signal level_completed

var _grid: Dictionary = {}
var _selected_tile: Node3D
var _grid_size := 7
var _completed := false


func _ready() -> void:
	var input := BoardInputComponent.of_as(self)
	var builder := BoardBuilderComponent.of_as(self)
	if input == null or builder == null:
		push_error("TileMatchingComponent: Required board components were not found.")
		return
	input.tile_pressed.connect(_on_tile_pressed)
	builder.board_built.connect(_on_board_built.bind(builder))
	builder.board_cleared.connect(_clear_state)


func _on_board_built(tiles: Array[Node3D], builder: BoardBuilderComponent) -> void:
	_clear_state()
	_grid_size = builder.grid_size
	for tile in tiles:
		_grid[_tile_position(tile)] = tile


func _on_tile_pressed(tile: Node3D, hit_normal: Vector3) -> void:
	var tile_position := _tile_position(tile)
	if not _grid.has(tile_position) or _grid[tile_position] != tile:
		return
	var rules := TileRulesComponent.of_as(self)
	if rules == null:
		return
	if not rules.is_tile_free(tile_position, _make_occupancy(), _grid_size):
		blocked_tile_pressed.emit(tile, hit_normal)
		_set_selected_tile(null)
		return

	if _selected_tile == null:
		_set_selected_tile(tile)
		return
	if _selected_tile == tile:
		_set_selected_tile(null)
		return

	var first_position := _tile_position(_selected_tile)
	var first_is_free := rules.is_tile_free(first_position, _make_occupancy(), _grid_size)
	if first_is_free and _icon_type(_selected_tile) == _icon_type(tile):
		var first_tile := _selected_tile
		_grid.erase(first_position)
		_grid.erase(tile_position)
		_set_selected_tile(null)
		match_succeeded.emit(first_tile, tile)
		if not _completed and _grid.is_empty():
			_completed = true
			level_completed.emit()
		return
	_set_selected_tile(tile)


func _set_selected_tile(tile: Node3D) -> void:
	if _selected_tile == tile:
		return
	var previous := _selected_tile
	_selected_tile = tile
	selection_changed.emit(previous, _selected_tile)


func _clear_state() -> void:
	var previous := _selected_tile
	_selected_tile = null
	_grid.clear()
	_completed = false
	if previous != null:
		selection_changed.emit(previous, null)


func _make_occupancy() -> Dictionary:
	var occupancy: Dictionary = {}
	for position in _grid:
		occupancy[position] = true
	return occupancy


func clear_selection() -> void:
	_set_selected_tile(null)


func get_icon_state() -> Dictionary:
	var result: Dictionary = {}
	for position in _grid:
		result[position] = _icon_type(_grid[position])
	return result


func _tile_position(tile: Node3D) -> Vector3i:
	return MahjongTileComponent.of_as(tile).grid_position


func _icon_type(tile: Node3D) -> int:
	return MahjongTileComponent.of_as(tile).icon_type


static func of_as(node: Node) -> TileMatchingComponent:
	return BaseComponent.of(node, TileMatchingComponent) as TileMatchingComponent
