extends Node


func _ready() -> void:
	var component_owner := Node.new()
	add_child(component_owner)
	var rules := TileRulesComponent.new()
	var solver := MahjongSolverComponent.new()
	var builder := BoardBuilderComponent.new()
	builder.build_on_ready = false
	component_owner.add_child(rules)
	component_owner.add_child(solver)
	component_owner.add_child(builder)

	var paths := OS.get_cmdline_user_args()
	if paths.is_empty():
		paths = ["res://data/levels.json", "res://data/levels_dev.json", "res://data/levels_new.json"]
	for path in paths:
		if not _migrate_file(str(path), builder, solver):
			get_tree().quit(1)
			return
	get_tree().quit(0)


func _migrate_file(path: String, builder: BoardBuilderComponent, solver: MahjongSolverComponent) -> bool:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("levels", []) is Array:
		push_error("Invalid levels JSON: %s" % path)
		return false
	for level: Dictionary in parsed.levels:
		var positions: Array[Vector3i] = []
		for value: Array in level.get("tiles", []):
			positions.append(Vector3i(int(value[0]), int(value[1]), int(value[2])))
		var assignment := builder.assign_solvable_icons(
			positions,
			int(level.get("grid_size", 7)),
			16,
			str(level.get("difficulty", "easy"))
		)
		if assignment.size() != positions.size() or not solver.is_solvable(assignment, int(level.get("grid_size", 7))):
			push_error("Could not migrate a verified assignment for %s in %s" % [level.get("name", "unnamed"), path])
			return false
		var icons: Array[int] = []
		for position in positions:
			icons.append(int(assignment[position]))
		level["tile_icons"] = icons
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % path)
		return false
	file.store_string(JSON.stringify(parsed, "\t") + "\n")
	file.close()
	print("MIGRATED %s (%d levels)" % [path, parsed.levels.size()])
	return true
