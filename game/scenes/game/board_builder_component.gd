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
	var normalizer := LevelNormalizerComponent.of_as(self)
	var symbol_assigner := SymbolAssignerComponent.of_as(self)
	if normalizer == null or symbol_assigner == null:
		push_error("BoardBuilderComponent: Required authoring components are missing.")
		return
	var normalized_level := normalizer.normalize(
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

	var icon_assignment := symbol_assigner.assign_solvable_icons(
		coordinates,
		grid_size,
		icon_type_count,
		str(level.get("difficulty", "easy"))
	)
	var center := float(grid_size - 1) * 0.5
	var tiles: Array[Node3D] = []

	for coordinate: Vector3i in coordinates:
		if not normalizer.is_inside_grid(coordinate, grid_size):
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
		if child is Node3D:
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


static func of_as(node: Node) -> BoardBuilderComponent:
	return BaseComponent.of(node, BoardBuilderComponent) as BoardBuilderComponent
