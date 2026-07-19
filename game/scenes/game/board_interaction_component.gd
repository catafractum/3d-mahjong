class_name BoardInteractionComponent
extends BaseComponent

signal selection_changed(previous_tile: Node3D, selected_tile: Node3D)
signal blocked_tile_pressed(tile: Node3D, hit_normal: Vector3)
signal match_succeeded(first_tile: Node3D, second_tile: Node3D)
signal level_completed
signal shuffle_completed
signal shuffle_failed

@export var camera: Camera3D
@export var ray_length := 1000.0
@export var maximum_tap_distance := 16.0

var _grid: Dictionary = {}
var _selected_tile: Node3D
var _grid_size := 7
var _completed := false
var _press_position := Vector2.ZERO
var _tracking_pointer := false
var _session: GameSession


func _ready() -> void:
	var builder := BoardBuilderComponent.of_as(self)
	if builder == null:
		push_error("BoardInteractionComponent: BoardBuilderComponent was not found.")
		return
	builder.board_built.connect(_on_board_built.bind(builder))
	builder.board_cleared.connect(_clear_state)
	var session_component := CurrentGameSessionComponent.of_as(self)
	if session_component != null:
		_session = session_component.session


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_pointer(event.position)
		else:
			_end_pointer(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_begin_pointer(event.position)
		else:
			_end_pointer(event.position)


func _begin_pointer(position: Vector2) -> void:
	_press_position = position
	_tracking_pointer = true


func _end_pointer(position: Vector2) -> void:
	if not _tracking_pointer:
		return
	_tracking_pointer = false
	if _press_position.distance_to(position) <= maximum_tap_distance:
		_pick_tile(position)


func _pick_tile(screen_position: Vector2) -> void:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * ray_length)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var tile := _find_tile(hit.collider as Node)
	if tile != null:
		_on_tile_pressed(tile, hit.get("normal", Vector3.ZERO))


func _find_tile(node: Node) -> Node3D:
	var current := node
	while current != null:
		var tile_component := MahjongTileComponent.of_as(current)
		if tile_component != null:
			return tile_component.get_owner_node() as Node3D
		current = current.get_parent()
	return null


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
		MahjongTileVisualComponent.of_as(tile).shake(hit_normal)
		Soundmanager.play_move_wrong_sfx()
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
		MahjongTileVisualComponent.of_as(first_tile).remove()
		MahjongTileVisualComponent.of_as(tile).remove()
		Soundmanager.play_move_correct_sfx()
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
	if _session != null:
		_session.selected_tile = tile
	selection_changed.emit(previous, _selected_tile)
	if is_instance_valid(previous):
		MahjongTileVisualComponent.of_as(previous).deselect()
	if is_instance_valid(_selected_tile):
		MahjongTileVisualComponent.of_as(_selected_tile).select()
		Soundmanager.play_tile_click_sfx()


func _clear_state() -> void:
	var previous := _selected_tile
	_selected_tile = null
	if _session != null:
		_session.selected_tile = null
	_grid.clear()
	_completed = false
	if previous != null:
		selection_changed.emit(previous, null)


func shuffle() -> void:
	var builder := BoardBuilderComponent.of_as(self)
	var solver := MahjongSolverComponent.of_as(self)
	var session_component := CurrentGameSessionComponent.of_as(self)
	if builder == null or solver == null:
		shuffle_failed.emit()
		return

	var coordinates: Array[Vector3i] = []
	for coordinate in _grid:
		coordinates.append(Vector3i(coordinate))
	if coordinates.is_empty():
		shuffle_failed.emit()
		return

	var difficulty := "easy"
	if session_component != null and session_component.session != null:
		difficulty = str(session_component.session.get_current_level().get("difficulty", "easy"))
	var assignment := builder.assign_solvable_icons(coordinates, builder.grid_size, builder.icon_type_count, difficulty)
	if assignment.size() != coordinates.size() or not solver.is_solvable(assignment, builder.grid_size):
		shuffle_failed.emit()
		return

	_set_selected_tile(null)
	for coordinate in _grid:
		var component := MahjongTileComponent.of_as(_grid[coordinate])
		component.set_icon_type(int(assignment[coordinate]))
	shuffle_completed.emit()


func _make_occupancy() -> Dictionary:
	var occupancy: Dictionary = {}
	for position in _grid:
		occupancy[position] = true
	return occupancy


func _tile_position(tile: Node3D) -> Vector3i:
	return MahjongTileComponent.of_as(tile).grid_position


func _icon_type(tile: Node3D) -> int:
	return MahjongTileComponent.of_as(tile).icon_type


static func of_as(node: Node) -> BoardInteractionComponent:
	return BaseComponent.of(node, BoardInteractionComponent) as BoardInteractionComponent
