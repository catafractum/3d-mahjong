extends Node

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	seed(20260922)
	var owner_node := Node.new()
	add_child(owner_node)
	var builder := BoardBuilderComponent.new()
	builder.build_on_ready = false
	owner_node.add_child(builder)
	var solver := MahjongSolverComponent.new()
	owner_node.add_child(solver)
	assert(not builder.icon_quality_issues({Vector3i.ZERO: 0, Vector3i.UP: 0}).is_empty())
	assert(not builder.icon_quality_issues({Vector3i.ZERO: 0, Vector3i.RIGHT: 1, Vector3i(2, 0, 0): 0, Vector3i(3, 0, 0): 1}).is_empty())
	assert(builder.assign_solvable_icons([Vector3i.ZERO, Vector3i.RIGHT], 7, 16).is_empty())
	var mirrored: Dictionary = {}
	for x in 4:
		for z in 4:
			mirrored[Vector3i(x, 0, z)] = mini(x, 3 - x) * 4 + z
	assert(str(builder.icon_quality_issues(mirrored)).contains("Mirrored"))
	var document = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels_new.json"))
	for level in document.levels:
		var positions: Array = []
		for p in level.tiles:
			positions.append(Vector3i(p[0], p[1], p[2]))
		for run in 5:
			var requested := mini(16, int(ceil(positions.size() / 4.0)))
			var assignment := builder.assign_solvable_icons(positions, 7, 16, level.difficulty, requested)
			if assignment.size() != positions.size() or not builder.icon_quality_issues(assignment).is_empty() or not solver.is_solvable(assignment, 7):
				push_error("FAIL %s run %d" % [level.name, run])
				get_tree().quit(1)
				return
			var reloaded: Dictionary = {}
			for position in positions:
				reloaded[position] = assignment[position]
			assert(solver.is_solvable(reloaded, 7), "Saved coordinate order must remain verifiably solvable")
		print("PASS ", level.name)
	print("PASS: all 36 layouts, five generations each; adjacency, pattern and solvability checks")
	var editor = load("res://game/scenes/level_editor/level_editor.tscn").instantiate()
	add_child(editor)
	await get_tree().process_frame
	var component = editor.get_node("Components/LevelEditorComponent")
	component.call("_create_icons")
	component.call("_simulate_selected_level")
	assert(str(component.get("_status_label").text).begins_with("Validation passed:"))
	component.set("_occupied", {Vector3i.ZERO: true, Vector3i.RIGHT: true})
	component.set("_icon_by_position", {Vector3i.ZERO: 0, Vector3i.RIGHT: 0})
	assert(component.call("_save_selected_level") == false)
	assert(str(component.get("_status_label").text).begins_with("Cannot save:"))
	print("PASS: editor generation, validation and save rejection; no level files written")
	get_tree().quit()
