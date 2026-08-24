class_name LevelEditorComponent
extends BaseComponent

const GRID_SIZE := 7
const GRID_CENTER := 3.0
const VIEW_Y_OFFSET := -3.0
const DIFFICULTIES: Array[String] = ["easy", "medium", "hard"]

@export_file("*.json") var levels_path := "res://data/levels_new.json"
@export_file("*.tscn") var game_scene_path := "res://game/scenes/game/game.tscn"
@export var view_root: Node3D
@export var tiles_root: Node3D
@export var layer_grid_root: Node3D
@export var hover_root: MeshInstance3D
@export var camera: Camera3D
@export var ui_layer: CanvasLayer
@export var panel: VBoxContainer
@export var spacing := 1.03
@export var orbit_sensitivity := 0.18
@export var zoom_sensitivity := 0.002
@export var pan_sensitivity := 1.0
@export var minimum_camera_size := 6.0
@export var maximum_camera_size := 18.0
@export var ui_reference_height := 900.0
@export var minimum_ui_scale := 1.35
@export var maximum_ui_scale := 2.0
@export var random_blocks_per_click := 2

var _document: Dictionary = {"version": 1, "levels": []}
var _occupied: Dictionary = {}
var _tile_nodes: Dictionary = {}
var _icon_by_position: Dictionary = {}
var _icon_materials: Dictionary = {}
var _layer_clipboard: Array[Vector2i] = []
var _editing_icons := false
var _preview_shape := false
var _active_layer := 0
var _hovered_coordinate := Vector3i(-1, -1, -1)
var _drag_button := MOUSE_BUTTON_NONE
var _last_pointer := Vector2.ZERO
var _orbit_target := Vector3.ZERO
var _pan_offset := Vector2.ZERO
var _current_level_id := -1
var _pending_level: Dictionary = {}

var _file_dialog: FileDialog
var _file_label: Label
var _difficulty: OptionButton
var _levels: OptionButton
var _layer_label: Label
var _count_label: Label
var _status_label: Label
var _simulate_button: Button
var _icon_mode_button: Button
var _preview_shape_button: Button
var _icon_buttons: Array[Button] = []
var _selected_icon := 0
var _pairs_per_icon: SpinBox
var _show_all_icon_labels: CheckBox
var _delete_dialog: ConfirmationDialog
var _delete_slot := -1
var _blank_material: StandardMaterial3D
var _dim_material: StandardMaterial3D
var _remove_material: StandardMaterial3D
var _add_material: StandardMaterial3D


func _ready() -> void:
	_make_materials()
	_orbit_target = view_root.to_global(Vector3.ZERO)
	_build_controls()
	_build_layer_grid()
	_read_levels(levels_path)
	_refresh_level_dropdown()
	_update_layer_visuals()
	get_viewport().size_changed.connect(_update_ui_scale)
	_update_ui_scale()


func _process(_delta: float) -> void:
	_update_hover()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_set_active_layer(_active_layer + 1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_set_active_layer(_active_layer - 1)
			get_viewport().set_input_as_handled()
		elif event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_drag_button = event.button_index if event.pressed else MOUSE_BUTTON_NONE
			_last_pointer = event.position
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _is_pointer_over_viewport():
			_toggle_hovered_tile()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _drag_button != MOUSE_BUTTON_NONE:
		var delta: Vector2 = event.position - _last_pointer
		_last_pointer = event.position
		if _drag_button == MOUSE_BUTTON_RIGHT:
			camera.size = clampf(
				camera.size * exp(delta.y * zoom_sensitivity),
				minimum_camera_size,
				maximum_camera_size
			)
		elif event.shift_pressed:
			_pan_camera(delta)
		else:
			_orbit_camera(delta)
		get_viewport().set_input_as_handled()


func _make_materials() -> void:
	_blank_material = _material(Color(0.72, 0.75, 0.8, 1.0))
	_dim_material = _material(Color(0.32, 0.35, 0.4, 0.34), true)
	_remove_material = _material(Color(1.0, 0.2, 0.16, 0.78), true)
	_add_material = _material(Color(0.2, 1.0, 0.48, 0.38), true)


func _material(color: Color, transparent := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _build_controls() -> void:
	panel.add_theme_constant_override("separation", 8)
	_add_label("3D LEVEL EDITOR — 7×7×7")
	var file_row := HBoxContainer.new()
	panel.add_child(file_row)
	_add_button(file_row, "Open JSON…", _show_file_dialog)
	_file_label = Label.new()
	_file_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_file_label.custom_minimum_size.x = 150
	file_row.add_child(_file_label)
	_difficulty = OptionButton.new()
	for value in DIFFICULTIES:
		_difficulty.add_item(value.capitalize())
	panel.add_child(_difficulty)
	_difficulty.item_selected.connect(func(_index: int): _refresh_level_dropdown())
	_levels = OptionButton.new()
	panel.add_child(_levels)
	_levels.item_selected.connect(_on_level_selected)
	_layer_label = _add_label("")
	_add_label("Wheel: change Y layer  •  Left click: add/remove\nMiddle drag: orbit  •  Shift+middle: pan  •  Right drag: zoom")
	var row_one := HBoxContainer.new()
	panel.add_child(row_one)
	_add_button(row_one, "Create Icons", _create_icons)
	_add_button(row_one, "Add Blocks", _add_random_blocks)
	_add_button(row_one, "Save", _save_selected_level)
	_add_button(row_one, "Reload", _load_selected_level)
	_add_button(row_one, "Clear", _clear_level)
	var row_two := HBoxContainer.new()
	panel.add_child(row_two)
	_add_button(row_two, "Play", _play_selected_level)
	_simulate_button = _add_button(row_two, "Simulate 100×", _simulate_selected_level)
	var layer_row := HBoxContainer.new()
	panel.add_child(layer_row)
	_add_button(layer_row, "Copy Layer", _copy_layer)
	_add_button(layer_row, "Paste Layer", _paste_layer)
	_preview_shape_button = _add_button(layer_row, "Preview Shape: Off", _toggle_preview_shape)
	var icon_row := HBoxContainer.new()
	panel.add_child(icon_row)
	_icon_mode_button = _add_button(icon_row, "Edit Icons: Off", _toggle_icon_mode)
	var icon_palette := GridContainer.new()
	icon_palette.columns = 4
	for icon in 16:
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(30, 30)
		swatch.focus_mode = Control.FOCUS_NONE
		swatch.text = _icon_label(icon)
		swatch.tooltip_text = "Icon %s (ID %02d)" % [_icon_label(icon), icon]
		swatch.pressed.connect(_select_icon.bind(icon))
		icon_palette.add_child(swatch)
		_icon_buttons.append(swatch)
	icon_row.add_child(icon_palette)
	_refresh_icon_palette()
	var icon_settings_row := HBoxContainer.new()
	panel.add_child(icon_settings_row)
	var pairs_label := Label.new()
	pairs_label.text = "Target pairs/icon"
	icon_settings_row.add_child(pairs_label)
	_pairs_per_icon = SpinBox.new()
	_pairs_per_icon.min_value = 1
	_pairs_per_icon.max_value = 8
	_pairs_per_icon.step = 1
	_pairs_per_icon.value = 2
	icon_settings_row.add_child(_pairs_per_icon)
	_show_all_icon_labels = CheckBox.new()
	_show_all_icon_labels.text = "Labels on all layers"
	_show_all_icon_labels.button_pressed = true
	_show_all_icon_labels.toggled.connect(func(_enabled: bool): _refresh_all_tile_materials())
	icon_settings_row.add_child(_show_all_icon_labels)
	var set_row := HBoxContainer.new()
	panel.add_child(set_row)
	_add_button(set_row, "+ Level Set", _add_level_set)
	_add_button(set_row, "Delete Level Set…", _request_delete_level_set)
	_count_label = _add_label("")
	_status_label = _add_label("Ready")
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_file_dialog.filters = PackedStringArray(["*.json ; JSON level files"])
	_file_dialog.file_selected.connect(_on_file_selected)
	ui_layer.add_child(_file_dialog)
	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = "Delete Level Set"
	_delete_dialog.confirmed.connect(_delete_level_set)
	ui_layer.add_child(_delete_dialog)


func _add_label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	panel.add_child(label)
	return label


func _add_button(parent: Control, value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _show_file_dialog() -> void:
	_file_dialog.current_path = levels_path
	_file_dialog.popup_centered_ratio(0.75)


func _update_ui_scale() -> void:
	if panel == null:
		return
	var viewport_height := get_viewport().get_visible_rect().size.y
	var scale_factor := clampf(viewport_height / ui_reference_height, minimum_ui_scale, maximum_ui_scale)
	var panel_container := panel.get_parent()
	panel_container.scale = Vector2.ONE * scale_factor
	panel_container.position = Vector2(16.0, 16.0)


func _orbit_camera(delta: Vector2) -> void:
	var current_pan := (
		camera.global_basis.x * _pan_offset.x
		+ camera.global_basis.y * _pan_offset.y
	)
	var base_camera_position := camera.global_position - current_pan
	var offset := base_camera_position - _orbit_target
	var radius := offset.length()
	if radius < 0.001:
		return
	var yaw := atan2(offset.x, offset.z) - deg_to_rad(delta.x * orbit_sensitivity)
	var pitch := asin(clampf(offset.y / radius, -1.0, 1.0)) - deg_to_rad(delta.y * orbit_sensitivity)
	pitch = clampf(pitch, deg_to_rad(-75.0), deg_to_rad(75.0))
	var horizontal_radius := cos(pitch) * radius
	offset = Vector3(
		sin(yaw) * horizontal_radius,
		sin(pitch) * radius,
		cos(yaw) * horizontal_radius
	)
	# Establish the unpanned orbit orientation first, then express the saved pan
	# in that new camera basis. Translating both camera and look target preserves
	# the panned composition while the underlying orbit stays grid-centered.
	camera.global_position = _orbit_target + offset
	camera.look_at(_orbit_target, Vector3.UP)
	var reapplied_pan := (
		camera.global_basis.x * _pan_offset.x
		+ camera.global_basis.y * _pan_offset.y
	)
	camera.global_position += reapplied_pan
	camera.look_at(_orbit_target + reapplied_pan, Vector3.UP)


func _pan_camera(delta: Vector2) -> void:
	var viewport_height := maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var world_per_pixel := camera.size / viewport_height * pan_sensitivity
	var movement := (
		-camera.global_basis.x * delta.x
		+ camera.global_basis.y * delta.y
	) * world_per_pixel
	_pan_offset += Vector2(-delta.x, delta.y) * world_per_pixel
	camera.global_position += movement


func _on_file_selected(path: String) -> void:
	_read_levels(path)
	_refresh_level_dropdown()


func _read_levels(path: String) -> void:
	if not FileAccess.file_exists(path):
		_set_status("File does not exist: %s" % path)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("levels", []) is Array:
		_set_status("Invalid levels JSON: %s" % path)
		return
	for level in parsed.get("levels", []):
		if not level is Dictionary or not level.get("tiles", []) is Array \
			or not level.get("tile_icons", []) is Array \
			or level.get("tile_icons", []).size() != level.get("tiles", []).size():
			_set_status("Strict schema error: every level must contain one tile_icon per tile")
			return
	levels_path = path
	_document = parsed
	_file_label.text = path.get_file()
	_file_label.tooltip_text = path
	_pending_level.clear()
	_set_status("Opened %s" % path.get_file())


func _refresh_level_dropdown() -> void:
	if _levels == null:
		return
	_levels.clear()
	var difficulty := _selected_difficulty()
	var matching: Array[Dictionary] = []
	for level in _document.get("levels", []):
		if level is Dictionary and str(level.get("difficulty", "")) == difficulty:
			matching.append(level)
	matching.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("slot", 0)) < int(b.get("slot", 0)))
	for level in matching:
		_levels.add_item("%02d — %s" % [int(level.get("slot", 0)) + 1, str(level.get("name", "unnamed"))])
		_levels.set_item_metadata(_levels.item_count - 1, int(level.get("id", -1)))
	if _levels.item_count == 0:
		_current_level_id = -1
		_clear_level()
		_set_status("No %s levels in this file; click Create" % difficulty)
	else:
		_levels.select(0)
		_on_level_selected(0)


func _on_level_selected(index: int) -> void:
	if index < 0 or index >= _levels.item_count:
		return
	_current_level_id = int(_levels.get_item_metadata(index))
	_pending_level.clear()
	_load_selected_level()


func _add_level_set() -> void:
	var levels: Array = _document.get("levels", [])
	var next_slot := 0
	var next_id := 0
	for level: Dictionary in levels:
		next_slot = maxi(next_slot, int(level.get("slot", -1)) + 1)
		next_id = maxi(next_id, int(level.get("id", -1)) + 1)
	var created_id := -1
	for difficulty in DIFFICULTIES:
		var source: Dictionary = {}
		for level: Dictionary in levels:
			if str(level.get("difficulty", "")) == difficulty and (source.is_empty() or int(level.get("slot", -1)) > int(source.get("slot", -1))):
				source = level
		if source.is_empty():
			_set_status("Cannot add a set because %s has no source level to duplicate" % difficulty)
			return
		var duplicate := source.duplicate(true)
		duplicate["id"] = next_id
		duplicate["slot"] = next_slot
		duplicate["name"] = "%s_%02d" % [difficulty, next_slot + 1]
		if difficulty == _selected_difficulty():
			created_id = next_id
		next_id += 1
		levels.append(duplicate)
	_document["levels"] = levels
	if not _write_document():
		return
	_refresh_level_dropdown_preserving(created_id)
	_set_status("Added level set %02d to Easy, Medium, and Hard by duplicating the previous set" % (next_slot + 1))


func _request_delete_level_set() -> void:
	var level := _find_current_level()
	if level.is_empty():
		_set_status("Select a level set to delete")
		return
	_delete_slot = int(level.get("slot", -1))
	_delete_dialog.dialog_text = "Delete slot %02d from Easy, Medium, and Hard?\nThis permanently removes all three levels from the open JSON file." % (_delete_slot + 1)
	_delete_dialog.popup_centered()


func _delete_level_set() -> void:
	if _delete_slot < 0:
		return
	var remaining: Array = []
	var removed := 0
	for level: Dictionary in _document.get("levels", []):
		if int(level.get("slot", -1)) == _delete_slot:
			removed += 1
		else:
			remaining.append(level)
	if removed != DIFFICULTIES.size():
		_set_status("Delete cancelled: slot %02d is not a complete three-difficulty set" % (_delete_slot + 1))
		return
	_document["levels"] = remaining
	if not _write_document():
		return
	var deleted_number := _delete_slot + 1
	_delete_slot = -1
	_refresh_level_dropdown()
	_set_status("Deleted level set %02d from all three difficulties" % deleted_number)


func _create_icons() -> void:
	if _occupied.is_empty() or _occupied.size() % 2 != 0:
		_set_status("Create Icons needs a non-zero, even number of blocks")
		return
	var builder := BoardBuilderComponent.of_as(self)
	var solver := MahjongSolverComponent.of_as(self)
	if builder == null or solver == null:
		_set_status("Icon creation components unavailable")
		return
	var pair_count := int(_occupied.size() / 2.0)
	var target_pairs := maxi(int(_pairs_per_icon.value), 1)
	var requested_icons := clampi(int(ceil(float(pair_count) / float(target_pairs))), 1, 16)
	var assignment := builder.assign_solvable_icons(
		_occupied.keys(), GRID_SIZE, 16, _selected_difficulty(), requested_icons
	)
	if assignment.size() != _occupied.size() or not solver.is_solvable(assignment, GRID_SIZE):
		_set_status("Could not create a verified solvable icon assignment")
		return
	_icon_by_position = assignment
	_refresh_all_tile_materials()
	var used_icons: Dictionary = {}
	for icon in _icon_by_position.values():
		used_icons[int(icon)] = true
	var capacity_note := " (16-icon limit; target cannot be exact)" if pair_count > target_pairs * 16 else ""
	_set_status("Created a global solvable assignment using %d symbols across %d blocks%s" % [used_icons.size(), _icon_by_position.size(), capacity_note])


func _add_random_blocks() -> void:
	var available: Array[Vector3i] = []
	for x in GRID_SIZE:
		for y in GRID_SIZE:
			for z in GRID_SIZE:
				var coordinate := Vector3i(x, y, z)
				if not _occupied.has(coordinate):
					available.append(coordinate)
	if available.is_empty():
		_set_status("The 7×7×7 grid is full")
		return
	available.shuffle()
	var amount := mini(random_blocks_per_click, available.size())
	if amount % 2 != 0 and available.size() >= 2:
		amount -= 1
	if amount <= 0:
		_set_status("Only one empty slot remains; remove a block before adding a pair")
		return
	for index in amount:
		_add_tile(available[index])
	_invalidate_icons()
	_set_status("Added %d random blocks across the full 7×7×7 volume" % amount)


func _toggle_icon_mode() -> void:
	_editing_icons = not _editing_icons
	_icon_mode_button.text = "Edit Icons: On" if _editing_icons else "Edit Icons: Off"
	if _tile_nodes.has(_hovered_coordinate):
		_update_tile_material(_hovered_coordinate)
	_refresh_hover_material()
	_set_status(
		"Icon mode: click an existing block to apply the selected icon"
		if _editing_icons
		else "Shape mode: click to add or remove blocks"
	)


func _toggle_preview_shape() -> void:
	_preview_shape = not _preview_shape
	_preview_shape_button.text = "Preview Shape: On" if _preview_shape else "Preview Shape: Off"
	_refresh_all_tile_materials()
	_refresh_hover_material()
	_set_status(
		"Preview Shape is on: all layers are shown at full brightness"
		if _preview_shape
		else "Preview Shape is off: inactive layers are dimmed"
	)


func _select_icon(icon: int) -> void:
	_selected_icon = clampi(icon, 0, 15)
	_refresh_icon_palette()
	_refresh_hover_material()
	_set_status("Selected Icon %s; click a block to apply it" % _icon_label(_selected_icon))


func _refresh_icon_palette() -> void:
	for icon in _icon_buttons.size():
		var swatch := _icon_buttons[icon]
		var style := StyleBoxFlat.new()
		style.bg_color = _icon_material(icon).albedo_color
		style.border_color = Color.WHITE if icon == _selected_icon else Color(0.08, 0.09, 0.11)
		style.set_border_width_all(3 if icon == _selected_icon else 1)
		style.set_corner_radius_all(4)
		swatch.add_theme_stylebox_override("normal", style)
		var color := style.bg_color
		var luminance := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
		var text_color := Color.BLACK if luminance > 0.58 else Color.WHITE
		swatch.add_theme_color_override("font_color", text_color)
		swatch.add_theme_color_override("font_hover_color", text_color)
		swatch.add_theme_color_override("font_pressed_color", text_color)
		swatch.add_theme_font_size_override("font_size", 18)
		var hover := style.duplicate()
		hover.bg_color = style.bg_color.lightened(0.18)
		swatch.add_theme_stylebox_override("hover", hover)
		swatch.add_theme_stylebox_override("pressed", hover)


func _load_selected_level() -> void:
	var level := _find_current_level()
	_clear_level()
	if level.is_empty():
		_set_status("Choose or create a level")
		return
	for value in level.get("tiles", []):
		if value is Array and value.size() >= 3:
			var coordinate := Vector3i(int(value[0]), int(value[1]), int(value[2]))
			if _inside_grid(coordinate):
				_add_tile(coordinate)
	var sorted_positions := _sorted_positions()
	var saved_icons = level.get("tile_icons", [])
	if saved_icons is Array and saved_icons.size() == sorted_positions.size():
		for index in sorted_positions.size():
			_icon_by_position[sorted_positions[index]] = int(saved_icons[index])
		_refresh_all_tile_materials()
	_set_status("Loaded %s" % str(level.get("name", "unnamed")))


func _save_selected_level() -> bool:
	if _occupied.is_empty() or _occupied.size() % 2 != 0:
		_set_status("A level needs a non-zero, even number of blocks")
		return false
	if _icon_by_position.size() != _occupied.size():
		_set_status("Click Create Icons after editing the shape, then Save")
		return false
	var solver := MahjongSolverComponent.of_as(self)
	if solver == null or not solver.is_solvable(_icon_by_position, GRID_SIZE):
		_set_status("Cannot save: the current icon assignment is not solvable")
		return false
	var saved := _find_current_level()
	if saved.is_empty():
		saved = _pending_level.duplicate(true)
	if saved.is_empty():
		_set_status("Choose or create a level first")
		return false
	saved["tiles"] = _sorted_coordinate_arrays()
	saved["tile_icons"] = _sorted_icon_array()
	saved["grid_size"] = GRID_SIZE
	var levels: Array = _document.get("levels", [])
	var replaced := false
	for index in levels.size():
		if int(levels[index].get("id", -1)) == _current_level_id:
			levels[index] = saved
			replaced = true
			break
	if not replaced:
		levels.append(saved)
	levels.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("id", 0)) < int(b.get("id", 0)))
	_document["levels"] = levels
	if not _write_document():
		return false
	_pending_level.clear()
	_set_status("Saved %s with %d blocks and its verified icon assignment" % [saved.name, _occupied.size()])
	_refresh_level_dropdown_preserving(_current_level_id)
	return true


func _write_document() -> bool:
	var file := FileAccess.open(levels_path, FileAccess.WRITE)
	if file == null:
		_set_status("Could not write %s" % levels_path)
		return false
	file.store_string(JSON.stringify(_document, "\t") + "\n")
	file.close()
	return true


func _refresh_level_dropdown_preserving(id: int) -> void:
	_refresh_level_dropdown()
	for index in _levels.item_count:
		if int(_levels.get_item_metadata(index)) == id:
			_levels.select(index)
			_on_level_selected(index)
			return


func _clear_level() -> void:
	for tile: Node in _tile_nodes.values():
		tile.queue_free()
	_occupied.clear()
	_tile_nodes.clear()
	_icon_by_position.clear()
	_hovered_coordinate = Vector3i(-1, -1, -1)
	if hover_root != null:
		hover_root.visible = false
	_update_count()


func _play_selected_level() -> void:
	if not _save_selected_level():
		return
	var level := _find_current_level()
	GameDB.current_session = GameSession.new([level], GameSession.Mode.CHALLENGE, 0.0)
	get_tree().change_scene_to_file(game_scene_path)


func _simulate_selected_level() -> void:
	if _occupied.is_empty() or _occupied.size() % 2 != 0:
		_set_status("Simulation needs a non-zero, even number of blocks")
		return
	var solver := MahjongSolverComponent.of_as(self)
	if solver == null or _icon_by_position.size() != _occupied.size():
		_set_status("Click Create Icons before simulating")
		return
	if not solver.is_solvable(_icon_by_position, GRID_SIZE):
		_set_status("Simulation: current icons are not solvable — FAILED")
		return
	if solver == null:
		_set_status("Simulation components unavailable")
		return
	_simulate_button.disabled = true
	var positions: Array = _occupied.keys()
	var passed := 0
	for _run in 100:
		if _icon_by_position.size() == positions.size() and solver.is_solvable(_icon_by_position, GRID_SIZE):
			passed += 1
		else:
			break
	_simulate_button.disabled = false
	_set_status("Simulation: %d/100 solvable assignments%s" % [passed, " ✓" if passed == 100 else " — FAILED"])


func _layout_has_removal_sequence() -> bool:
	var builder := BoardBuilderComponent.of_as(self)
	return builder != null and builder.assign_solvable_icons(_occupied.keys(), GRID_SIZE, 16, _selected_difficulty()).size() == _occupied.size()


func _build_layer_grid() -> void:
	var material := _material(Color(0.25, 0.78, 1.0, 0.42), true)
	var start := -GRID_CENTER * spacing - spacing * 0.5
	var end := start + GRID_SIZE * spacing
	for index in GRID_SIZE + 1:
		var value := start + index * spacing
		layer_grid_root.add_child(_line(Vector3(start, 0, value), Vector3(end, 0, value), material))
		layer_grid_root.add_child(_line(Vector3(value, 0, start), Vector3(value, 0, end), material))


func _line(from: Vector3, to: Vector3, material: Material) -> MeshInstance3D:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
	mesh.surface_end()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	return instance


func _update_hover() -> void:
	if _preview_shape or camera == null or hover_root == null or not _is_pointer_over_viewport() or _drag_button != MOUSE_BUTTON_NONE:
		_set_hover_coordinate(Vector3i(-1, -1, -1))
		return
	var pointer := get_viewport().get_mouse_position()
	var origin := view_root.to_local(camera.project_ray_origin(pointer))
	var direction := view_root.global_transform.basis.inverse() * camera.project_ray_normal(pointer)
	if absf(direction.y) < 0.0001:
		_set_hover_coordinate(Vector3i(-1, -1, -1))
		return
	var plane_y := (float(_active_layer) + VIEW_Y_OFFSET) * spacing
	var distance := (plane_y - origin.y) / direction.y
	if distance < 0.0:
		_set_hover_coordinate(Vector3i(-1, -1, -1))
		return
	var hit := origin + direction * distance
	var coordinate := Vector3i(roundi(hit.x / spacing + GRID_CENTER), _active_layer, roundi(hit.z / spacing + GRID_CENTER))
	_set_hover_coordinate(coordinate if _inside_grid(coordinate) else Vector3i(-1, -1, -1))


func _set_hover_coordinate(coordinate: Vector3i) -> void:
	if coordinate == _hovered_coordinate:
		return
	if _tile_nodes.has(_hovered_coordinate):
		_update_tile_material(_hovered_coordinate)
	_hovered_coordinate = coordinate
	hover_root.visible = _inside_grid(coordinate) and not _occupied.has(coordinate)
	if hover_root.visible:
		hover_root.position = _coordinate_to_position(coordinate)
		hover_root.material_override = _add_material
	if _tile_nodes.has(coordinate):
		_refresh_hover_material()


func _refresh_hover_material() -> void:
	if not _tile_nodes.has(_hovered_coordinate):
		return
	if _preview_shape:
		_update_tile_material(_hovered_coordinate)
		return
	var tile: MeshInstance3D = _tile_nodes[_hovered_coordinate]
	tile.material_override = _icon_material(_selected_icon) if _editing_icons else _remove_material


func _toggle_hovered_tile() -> void:
	if _preview_shape:
		_set_status("Preview Shape is view-only; turn it off to edit")
		return
	if not _inside_grid(_hovered_coordinate):
		return
	if _editing_icons:
		if not _occupied.has(_hovered_coordinate):
			_set_status("Icon mode only edits existing blocks")
			return
		var icon := _selected_icon
		_icon_by_position[_hovered_coordinate] = icon
		_update_tile_material(_hovered_coordinate)
		_set_status("Applied Icon %s; run Simulate 100× before Save" % _icon_label(icon))
		return
	if _occupied.has(_hovered_coordinate):
		_remove_tile(_hovered_coordinate)
	else:
		_add_tile(_hovered_coordinate)
	_invalidate_icons()
	_set_status("Edited layer Y %d" % _active_layer)


func _add_tile(coordinate: Vector3i) -> void:
	if _occupied.has(coordinate):
		return
	var tile := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.92
	tile.mesh = mesh
	var label := Label3D.new()
	label.name = "IconLabel"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.font_size = 48
	label.outline_size = 12
	label.modulate = Color.WHITE
	label.outline_modulate = Color(0.03, 0.03, 0.04, 0.95)
	label.visible = false
	tile.add_child(label)
	tile.position = _coordinate_to_position(coordinate)
	tiles_root.add_child(tile)
	_occupied[coordinate] = true
	_tile_nodes[coordinate] = tile
	_update_tile_material(coordinate)
	_update_count()


func _remove_tile(coordinate: Vector3i) -> void:
	_occupied.erase(coordinate)
	if _tile_nodes.has(coordinate):
		_tile_nodes[coordinate].queue_free()
		_tile_nodes.erase(coordinate)
	_update_count()


func _set_active_layer(value: int) -> void:
	_active_layer = clampi(value, 0, GRID_SIZE - 1)
	_update_layer_visuals()
	_update_hover()


func _update_layer_visuals() -> void:
	if _layer_label != null:
		_layer_label.text = "ACTIVE LAYER Y: %d / 6" % _active_layer
	if layer_grid_root != null:
		layer_grid_root.position.y = (float(_active_layer) + VIEW_Y_OFFSET) * spacing
	for coordinate: Vector3i in _tile_nodes:
		_update_tile_material(coordinate)


func _update_tile_material(coordinate: Vector3i) -> void:
	var tile: MeshInstance3D = _tile_nodes.get(coordinate)
	if tile != null:
		var label := tile.get_node_or_null("IconLabel") as Label3D
		if _preview_shape:
			tile.material_override = _icon_material(int(_icon_by_position[coordinate])) if _icon_by_position.has(coordinate) else _blank_material
			if label != null:
				label.visible = false
			return
		if coordinate.y != _active_layer and not _preview_shape:
			tile.material_override = _dim_material
			if label != null:
				label.visible = _show_all_icon_labels != null \
					and _show_all_icon_labels.button_pressed \
					and _icon_by_position.has(coordinate)
				if label.visible:
					label.text = _icon_label(int(_icon_by_position[coordinate]))
					label.modulate = Color(1.0, 1.0, 1.0, 0.38)
		elif _icon_by_position.has(coordinate):
			var icon := int(_icon_by_position[coordinate])
			tile.material_override = _icon_material(icon)
			if label != null:
				label.text = _icon_label(icon)
				label.modulate = Color.WHITE
				label.visible = true
		else:
			tile.material_override = _blank_material
			if label != null:
				label.visible = false


func _icon_material(icon: int) -> StandardMaterial3D:
	if not _icon_materials.has(icon):
		_icon_materials[icon] = _material(Color.from_hsv(fmod(float(icon) * 0.61803398875, 1.0), 0.62, 0.95))
	return _icon_materials[icon]


func _icon_label(icon: int) -> String:
	return String.chr(65 + clampi(icon, 0, 15))


func _refresh_all_tile_materials() -> void:
	for coordinate: Vector3i in _tile_nodes:
		_update_tile_material(coordinate)


func _invalidate_icons() -> void:
	if _icon_by_position.is_empty():
		return
	_icon_by_position.clear()
	_refresh_all_tile_materials()
	_set_status("Shape changed; click Create Icons before Save or Play")


func _copy_layer() -> void:
	_layer_clipboard.clear()
	for coordinate: Vector3i in _occupied:
		if coordinate.y == _active_layer:
			_layer_clipboard.append(Vector2i(coordinate.x, coordinate.z))
	_layer_clipboard.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y if a.y != b.y else a.x < b.x)
	_set_status("Copied %d blocks from layer Y %d" % [_layer_clipboard.size(), _active_layer])


func _paste_layer() -> void:
	if _layer_clipboard.is_empty():
		_set_status("Copy a non-empty layer first")
		return
	var added := 0
	for cell in _layer_clipboard:
		var coordinate := Vector3i(cell.x, _active_layer, cell.y)
		if not _occupied.has(coordinate):
			_add_tile(coordinate)
			added += 1
	if added > 0:
		_invalidate_icons()
	_set_status("Pasted %d new blocks onto layer Y %d" % [added, _active_layer])


func _is_pointer_over_viewport() -> bool:
	return get_viewport().gui_get_hovered_control() == null


func _find_current_level() -> Dictionary:
	if not _pending_level.is_empty() and int(_pending_level.get("id", -1)) == _current_level_id:
		return _pending_level.duplicate(true)
	for level in _document.get("levels", []):
		if level is Dictionary and int(level.get("id", -1)) == _current_level_id:
			return level.duplicate(true)
	return {}


func _selected_difficulty() -> String:
	return DIFFICULTIES[maxi(_difficulty.selected, 0)]


func _sorted_coordinate_arrays() -> Array:
	var coordinates := _sorted_positions()
	var result := []
	for coordinate: Vector3i in coordinates:
		result.append([coordinate.x, coordinate.y, coordinate.z])
	return result


func _sorted_positions() -> Array:
	var coordinates: Array = _occupied.keys()
	coordinates.sort_custom(func(a: Vector3i, b: Vector3i):
		if a.y != b.y: return a.y < b.y
		if a.z != b.z: return a.z < b.z
		return a.x < b.x
	)
	return coordinates


func _sorted_icon_array() -> Array[int]:
	var result: Array[int] = []
	for coordinate: Vector3i in _sorted_positions():
		result.append(int(_icon_by_position[coordinate]))
	return result


func _coordinate_to_position(coordinate: Vector3i) -> Vector3:
	return Vector3((coordinate.x - GRID_CENTER) * spacing, (coordinate.y + VIEW_Y_OFFSET) * spacing, (coordinate.z - GRID_CENTER) * spacing)


func _inside_grid(coordinate: Vector3i) -> bool:
	return coordinate.x >= 0 and coordinate.x < GRID_SIZE and coordinate.y >= 0 and coordinate.y < GRID_SIZE and coordinate.z >= 0 and coordinate.z < GRID_SIZE


func _update_count() -> void:
	if _count_label != null:
		_count_label.text = "Blocks: %d%s" % [_occupied.size(), " (needs one more)" if _occupied.size() % 2 else ""]


func _set_status(value: String) -> void:
	if _status_label != null:
		_status_label.text = value
