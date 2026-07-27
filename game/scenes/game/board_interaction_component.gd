class_name BoardInteractionComponent
extends BaseComponent

signal selection_changed(previous_tile: Node3D, selected_tile: Node3D)
signal blocked_tile_pressed(tile: Node3D, hit_normal: Vector3)
signal match_succeeded(first_tile: Node3D, second_tile: Node3D)
signal level_completed
signal shuffle_completed

@export var camera: Camera3D
@export var ray_length := 1000.0
@export var maximum_tap_distance := 16.0
@export_file("*.mp3", "*.wav", "*.ogg") var correct_sfx_path: String
@export_file("*.mp3", "*.wav", "*.ogg") var wrong_sfx_path: String
@export_file("*.mp3", "*.wav", "*.ogg") var tile_click_sfx_path: String

var _grid: Dictionary = {}
var _selected_tile: Node3D
var _grid_size := 7
var _completed := false
var _press_position := Vector2.ZERO
var _tracking_pointer := false
var _session: GameSession
var _hovered_tile: Node3D
var _input_locked := false


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
	if _input_locked:
		return
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


func _process(_delta: float) -> void:
	_update_hovered_tile()


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
		SoundManager.play_sfx(wrong_sfx_path)
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
		SoundManager.play_sfx(correct_sfx_path)
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
		SoundManager.play_sfx(tile_click_sfx_path)


func _clear_state() -> void:
	_set_hovered_tile(null)
	var previous := _selected_tile
	_selected_tile = null
	if _session != null:
		_session.selected_tile = null
	_grid.clear()
	_completed = false
	if previous != null:
		selection_changed.emit(previous, null)


func begin_shuffle() -> void:
	_input_locked = true
	_tracking_pointer = false
	_set_hovered_tile(null)
	_set_selected_tile(null)


func finish_shuffle() -> void:
	_grid.clear()
	var builder := BoardBuilderComponent.of_as(self)
	if builder != null:
		for tile in builder.get_tiles():
			_grid[_tile_position(tile)] = tile
	_input_locked = false
	shuffle_completed.emit()


func _update_hovered_tile() -> void:
	if (
		_input_locked
		or _tracking_pointer
		or camera == null
		or get_viewport().gui_get_hovered_control() != null
	):
		_set_hovered_tile(null)
		return
	var origin := camera.project_ray_origin(get_viewport().get_mouse_position())
	var direction := camera.project_ray_normal(get_viewport().get_mouse_position())
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * ray_length)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	_set_hovered_tile(_find_tile(hit.collider as Node) if not hit.is_empty() else null)


func _set_hovered_tile(tile: Node3D) -> void:
	if tile == _hovered_tile:
		return
	if is_instance_valid(_hovered_tile):
		MahjongTileVisualComponent.of_as(_hovered_tile).set_hovered(false)
	_hovered_tile = tile
	if is_instance_valid(_hovered_tile):
		MahjongTileVisualComponent.of_as(_hovered_tile).set_hovered(true)


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
