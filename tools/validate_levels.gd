extends Node

const RUNS_PER_LEVEL := 100


func _ready() -> void:
	if "--editor-only" in OS.get_cmdline_user_args():
		await _validate_editor_path()
		return
	var saved_only := "--saved-only" in OS.get_cmdline_user_args()
	var owner_node := Node.new()
	add_child(owner_node)
	var rules := TileRulesComponent.new()
	var solver := MahjongSolverComponent.new()
	var builder := BoardBuilderComponent.new()
	builder.build_on_ready = false
	owner_node.add_child(rules)
	owner_node.add_child(solver)
	owner_node.add_child(builder)

	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels_new.json"))
	if not parsed is Dictionary:
		_fail("levels_new.json is not a JSON object")
		return
	if "--randomness-only" in OS.get_cmdline_user_args():
		var level: Dictionary = parsed.levels[1]
		var positions: Array[Vector3i] = []
		for value: Array in level.tiles:
			positions.append(Vector3i(int(value[0]), int(value[1]), int(value[2])))
		var signatures: Dictionary = {}
		for run in 20:
			var assignment := builder.assign_solvable_icons(positions, 7, 16, "easy", 16)
			if not solver.is_solvable(assignment, 7):
				_fail("random assignment %d was not solvable" % (run + 1))
				return
			var parts: Array[String] = []
			for position in positions:
				parts.append("%s:%d" % [position, assignment[position]])
			signatures["|".join(parts)] = true
		if signatures.size() < 15:
			_fail("icon creation produced only %d unique assignments in 20 runs" % signatures.size())
			return
		print("PASS: %d unique global assignments in 20 Create Icons runs" % signatures.size())
		get_tree().quit(0)
		return
	for level: Dictionary in parsed.get("levels", []):
		var positions: Array[Vector3i] = []
		for value: Array in level.get("tiles", []):
			positions.append(Vector3i(int(value[0]), int(value[1]), int(value[2])))
		if positions.is_empty() or positions.size() % 2 != 0:
			_fail("%s has an invalid tile count" % level.get("name", "unnamed"))
			return
		var saved_icons: Array = level.get("tile_icons", [])
		if saved_icons.size() != positions.size():
			_fail("%s has no complete saved icon assignment" % level.get("name", "unnamed"))
			return
		var saved_assignment: Dictionary = {}
		for index in positions.size():
			saved_assignment[positions[index]] = int(saved_icons[index])
		if not solver.is_solvable(saved_assignment, int(level.get("grid_size", 7))):
			_fail("%s has an unsolvable saved icon assignment" % level.get("name", "unnamed"))
			return
		if saved_only:
			print("PASS %s saved icons" % level.get("name", "unnamed"))
			continue
		for run in RUNS_PER_LEVEL:
			var assignment := builder.assign_solvable_icons(
				positions, int(level.get("grid_size", 7)), 16, str(level.get("difficulty", "easy"))
			)
			if assignment.size() != positions.size() or not solver.is_solvable(assignment, 7):
				_fail("%s failed simulation %d" % [level.get("name", "unnamed"), run + 1])
				return
		print("PASS %s (%d tiles × %d runs)" % [level.get("name", "unnamed"), positions.size(), RUNS_PER_LEVEL])

	# Exercise the editor's exact component lookup and validation path too. This
	# catches cases where the solver works in isolation but Save and Play cannot
	# discover its sibling components.
	if not await _validate_editor_path(false):
		return
	print("PASS: all saved icon assignments validated" if saved_only else "PASS: all levels completed %d simulations" % RUNS_PER_LEVEL)
	get_tree().quit(0)


func _validate_editor_path(quit_when_done := true) -> bool:
	var editor = load("res://game/scenes/level_editor/level_editor.tscn").instantiate()
	add_child(editor)
	await get_tree().process_frame
	var editor_component = editor.get_node("Components/LevelEditorComponent")
	if not editor_component.call("_layout_has_removal_sequence"):
		_fail("Level editor rejected its loaded level geometry")
		return false
	print("PASS: level editor Save and Play geometry check")
	editor_component.call("_simulate_selected_level")
	var status_label = editor_component.get("_status_label")
	if status_label == null or not str(status_label.text).begins_with("Simulation: 100/100"):
		_fail("Level editor simulation failed: %s" % (status_label.text if status_label != null else "no status"))
		return false
	print("PASS: level editor Simulate 100× check")
	if quit_when_done:
		get_tree().quit(0)
	return true


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
