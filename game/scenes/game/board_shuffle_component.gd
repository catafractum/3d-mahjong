class_name BoardShuffleComponent
extends BaseComponent

signal shuffle_completed
signal shuffle_failed

@export var game_ui: GameUIComponent


func _ready() -> void:
	game_ui.shuffle_requested.connect(shuffle)


func shuffle() -> void:
	var builder := BoardBuilderComponent.of_as(self)
	var matching := TileMatchingComponent.of_as(self)
	var assigner := SymbolAssignerComponent.of_as(self)
	var solver := MahjongSolverComponent.of_as(self)
	var session_component := CurrentGameSessionComponent.of_as(self)
	if builder == null or matching == null or assigner == null or solver == null:
		shuffle_failed.emit()
		return

	var tiles := builder.get_tiles()
	var current_state := matching.get_icon_state()
	var coordinates: Array[Vector3i] = []
	for coordinate in current_state:
		coordinates.append(Vector3i(coordinate))
	if coordinates.is_empty():
		shuffle_failed.emit()
		return

	var difficulty := "easy"
	if session_component != null and session_component.session != null:
		difficulty = str(session_component.session.get_current_level().get("difficulty", "easy"))
	var assignment := assigner.assign_solvable_icons(
		coordinates,
		builder.grid_size,
		builder.icon_type_count,
		difficulty
	)
	if assignment.size() != coordinates.size() or not solver.is_solvable(assignment, builder.grid_size):
		shuffle_failed.emit()
		return

	matching.clear_selection()
	for tile in tiles:
		var component := MahjongTileComponent.of_as(tile)
		if component != null and assignment.has(component.grid_position):
			component.set_icon_type(int(assignment[component.grid_position]))
	shuffle_completed.emit()


static func of_as(node: Node) -> BoardShuffleComponent:
	return BaseComponent.of(node, BoardShuffleComponent) as BoardShuffleComponent
