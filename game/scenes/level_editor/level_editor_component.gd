class_name LevelEditorComponent
extends BaseComponent

const GRID_SIZE := 7
const GRID_CENTER := float(GRID_SIZE - 1) * 0.5
const VIEW_Y_OFFSET := -3.0
const TOP_VIEW_CELL_SIZE := 34.0
const TOP_VIEW_MARGIN := 20.0
const DIFFICULTIES: Array[String] = ["easy", "medium", "hard"]

@export_file("*.json") var levels_path := "res://data/levels.json"
@export_file("*.tscn") var game_scene_path := "res://game/scenes/game/game.tscn"
@export var tile_scene: PackedScene
@export var view_root: Node3D
@export var grid_root: Node3D
@export var tiles_root: Node3D
@export var layer_grid_root: Node3D
@export var camera: Camera3D
@export var ui_layer: CanvasLayer
@export var panel: VBoxContainer
@export var spacing := 1.03
@export var ui_reference_height := 900.0
@export var maximum_ui_scale := 2.0

var _occupied: Dictionary = {}
var _tile_nodes: Dictionary = {}
var _cell_nodes: Dictionary = {}
var _layer_lines: Array[MeshInstance3D] = []
var _top_view_root: Control
var _top_view_cells: Dictionary = {}
var _active_layer := 0
var _difficulty: OptionButton
var _slot: SpinBox
var _layer: SpinBox
var _count_label: Label
var _status_label: Label


func _ready() -> void:
	_build_controls()
	_build_top_view()
	_build_grid()
	_build_layer_grid()
	_load_selected_level()
	get_viewport().size_changed.connect(_update_ui_scale)
	_update_ui_scale()


func _build_controls() -> void:
	panel.add_theme_constant_override("separation", 8)
	_add_label("Level Editor 7×7×7")

	_difficulty = OptionButton.new()
	for value in DIFFICULTIES:
		_difficulty.add_item(value.capitalize())
	panel.add_child(_difficulty)
	_difficulty.item_selected.connect(func(_index: int): _load_selected_level())

	_slot = SpinBox.new()
	_slot.min_value = 1
	_slot.max_value = 10
	_slot.step = 1
	_slot.prefix = "Slot "
	panel.add_child(_slot)
	_slot.value_changed.connect(func(_value: float): _load_selected_level())

	_layer = SpinBox.new()
	_layer.min_value = 0
	_layer.max_value = GRID_SIZE - 1
	_layer.step = 1
	_layer.prefix = "Layer Y "
	panel.add_child(_layer)
	_layer.value_changed.connect(func(value: float): _set_active_layer(int(value)))

	var rotate_row := HBoxContainer.new()
	panel.add_child(rotate_row)
	_add_button(rotate_row, "Rotate −90°", func(): _rotate_view(-90.0))
	_add_button(rotate_row, "Rotate +90°", func(): _rotate_view(90.0))

	_add_button(panel, "Save Level", _save_selected_level)
	_add_button(panel, "Reload Level", _load_selected_level)
	_add_button(panel, "Clear", _clear_level)
	_add_button(panel, "Save and Play", _play_selected_level)

	_count_label = _add_label("")
	_status_label = _add_label("Ready")
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_update_count()


func _add_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	panel.add_child(label)
	return label


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _build_top_view() -> void:
	_top_view_root = VBoxContainer.new()
	_top_view_root.name = "TopViewEditor"
	_top_view_root.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(_top_view_root)

	var title := Label.new()
	title.text = "TOP VIEW — ACTIVE Y LAYER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top_view_root.add_child(title)

	var grid := GridContainer.new()
	grid.columns = GRID_SIZE
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	_top_view_root.add_child(grid)

	for z in GRID_SIZE:
		for x in GRID_SIZE:
			var coordinate_2d := Vector2i(x, z)
			var cell := Button.new()
			cell.custom_minimum_size = Vector2.ONE * TOP_VIEW_CELL_SIZE
			cell.focus_mode = Control.FOCUS_NONE
			cell.tooltip_text = "X %d, Z %d" % [x, z]
			cell.pressed.connect(_on_top_view_cell_pressed.bind(coordinate_2d))
			grid.add_child(cell)
			_top_view_cells[coordinate_2d] = cell
	_refresh_top_view()


func _on_top_view_cell_pressed(coordinate_2d: Vector2i) -> void:
	_toggle_tile(Vector3i(coordinate_2d.x, _active_layer, coordinate_2d.y))


func _update_ui_scale() -> void:
	if _top_view_root == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var scale_factor := clampf(viewport_size.y / ui_reference_height, 1.0, maximum_ui_scale)
	panel.get_parent().scale = Vector2.ONE * scale_factor
	_top_view_root.scale = Vector2.ONE * scale_factor
	_top_view_root.position = Vector2(
		viewport_size.x - TOP_VIEW_MARGIN - GRID_SIZE * TOP_VIEW_CELL_SIZE * scale_factor,
		TOP_VIEW_MARGIN
	)


func _refresh_top_view() -> void:
	if _top_view_cells.is_empty():
		return
	for coordinate_2d: Vector2i in _top_view_cells:
		var cell: Button = _top_view_cells[coordinate_2d]
		var active_coordinate := Vector3i(coordinate_2d.x, _active_layer, coordinate_2d.y)
		var occupied_on_active_layer := _occupied.has(active_coordinate)
		var occupied_on_other_layers := false
		for y in GRID_SIZE:
			if y != _active_layer and _occupied.has(Vector3i(coordinate_2d.x, y, coordinate_2d.y)):
				occupied_on_other_layers = true
				break
		var color := Color("272b30")
		if occupied_on_other_layers:
			color = Color("4b4030")
		if occupied_on_active_layer:
			color = Color("f2b632")
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.border_color = Color("e53935")
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		cell.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate()
		hover.bg_color = color.lightened(0.18)
		cell.add_theme_stylebox_override("hover", hover)
		cell.add_theme_stylebox_override("pressed", hover)


func _build_grid() -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.35, 0.8, 1.0, 0.05)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for x in GRID_SIZE:
		for y in GRID_SIZE:
			for z in GRID_SIZE:
				var coordinate := Vector3i(x, y, z)
				var cell := StaticBody3D.new()
				cell.position = _coordinate_to_position(coordinate)
				cell.set_meta("grid_position", coordinate)
				grid_root.add_child(cell)
				_cell_nodes[coordinate] = cell

				var collision := CollisionShape3D.new()
				var shape := BoxShape3D.new()
				shape.size = Vector3.ONE * 0.92
				collision.shape = shape
				cell.add_child(collision)

				var mesh_instance := MeshInstance3D.new()
				var mesh := BoxMesh.new()
				mesh.size = Vector3.ONE * 0.92
				mesh_instance.mesh = mesh
				mesh_instance.material_override = material
				cell.add_child(mesh_instance)
	_set_active_layer(_active_layer)


func _build_layer_grid() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.15, 0.1)
	var start := -GRID_CENTER * spacing - spacing * 0.5
	var end := start + GRID_SIZE * spacing
	for index in GRID_SIZE + 1:
		var value := start + index * spacing
		_layer_lines.append(_make_line(Vector3(start, 0, value), Vector3(end, 0, value), material))
		_layer_lines.append(_make_line(Vector3(value, 0, start), Vector3(value, 0, end), material))


func _make_line(from: Vector3, to: Vector3, material: Material) -> MeshInstance3D:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
	mesh.surface_end()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	layer_grid_root.add_child(instance)
	return instance


func _toggle_tile(coordinate: Vector3i) -> void:
	if _occupied.has(coordinate):
		_remove_tile(coordinate)
	else:
		_add_tile(coordinate)
	_set_status("Edited")


func _add_tile(coordinate: Vector3i) -> void:
	if tile_scene == null or _occupied.has(coordinate):
		return
	var tile := tile_scene.instantiate() as Node3D
	tiles_root.add_child(tile)
	tile.position = _coordinate_to_position(coordinate)
	tile.name = "Tile_%d_%d_%d" % [coordinate.x, coordinate.y, coordinate.z]
	var component := MahjongTileComponent.of_as(tile)
	if component != null:
		component.configure(_tile_nodes.size(), coordinate, _tile_nodes.size() % 16)
	var body := tile.get_node_or_null("StaticBody3D") as StaticBody3D
	if body != null:
		body.collision_layer = 0
	_occupied[coordinate] = true
	_tile_nodes[coordinate] = tile
	_set_tile_dimmed(tile, coordinate.y != _active_layer)
	_update_count()
	_refresh_top_view()


func _remove_tile(coordinate: Vector3i) -> void:
	_occupied.erase(coordinate)
	if _tile_nodes.has(coordinate):
		_tile_nodes[coordinate].queue_free()
		_tile_nodes.erase(coordinate)
	_update_count()
	_refresh_top_view()


func _set_active_layer(value: int) -> void:
	_active_layer = clampi(value, 0, GRID_SIZE - 1)
	for coordinate: Vector3i in _cell_nodes:
		var cell: StaticBody3D = _cell_nodes[coordinate]
		cell.visible = coordinate.y == _active_layer
		cell.collision_layer = 0
	for coordinate: Vector3i in _tile_nodes:
		_set_tile_dimmed(_tile_nodes[coordinate], coordinate.y != _active_layer)
	layer_grid_root.position.y = (float(_active_layer) + VIEW_Y_OFFSET + 0.48) * spacing
	_refresh_top_view()
	_set_status("Layer Y %d" % _active_layer)


func _set_tile_dimmed(tile: Node, is_dimmed: bool) -> void:
	var visual := MahjongTileVisualComponent.of_as(tile)
	if visual != null:
		visual.set_editor_dimmed(is_dimmed)


func _rotate_view(degrees: float) -> void:
	view_root.rotation_degrees.y = snappedf(view_root.rotation_degrees.y + degrees, 90.0)


func _clear_level() -> void:
	for tile: Node in _tile_nodes.values():
		tile.queue_free()
	_occupied.clear()
	_tile_nodes.clear()
	_update_count()
	_refresh_top_view()
	_set_status("Cleared")


func _load_selected_level() -> void:
	_clear_level()
	var level := _find_level(_selected_level_id())
	if level.is_empty():
		_set_status("Empty slot")
		return
	for value in level.get("tiles", []):
		if value is Array and value.size() >= 3:
			var coordinate := Vector3i(int(value[0]), int(value[1]), int(value[2]))
			if _is_inside_grid(coordinate):
				_add_tile(coordinate)
	_set_status("Loaded %s" % _selected_level_name())


func _save_selected_level() -> bool:
	if _occupied.is_empty():
		_set_status("Cannot save an empty level")
		return false
	if _occupied.size() % 2 != 0:
		_set_status("Tile count must be even")
		return false

	var document := _read_levels()
	var levels: Array = document.get("levels", [])
	var saved := {
		"id": _selected_level_id(),
		"name": _selected_level_name(),
		"difficulty": _selected_difficulty(),
		"slot": _selected_slot(),
		"grid_size": GRID_SIZE,
		"tiles": _sorted_coordinate_arrays(),
	}
	var replaced := false
	for index in levels.size():
		if levels[index] is Dictionary and int(levels[index].get("id", -1)) == saved.id:
			levels[index] = saved
			replaced = true
			break
	if not replaced:
		levels.append(saved)
	levels.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.id) < int(b.id))
	document["version"] = int(document.get("version", 1))
	document["levels"] = levels

	var file := FileAccess.open(levels_path, FileAccess.WRITE)
	if file == null:
		_set_status("Could not write %s" % levels_path)
		return false
	file.store_string(JSON.stringify(document, "\t"))
	file.close()
	_set_status("Saved %s (%d tiles)" % [_selected_level_name(), _occupied.size()])
	return true


func _play_selected_level() -> void:
	if not _save_selected_level():
		return
	var level := _find_level(_selected_level_id())
	if level.is_empty():
		_set_status("Saved level could not be loaded")
		return
	var preview_levels: Array[Dictionary] = [level]
	GameDB.current_session = GameSession.new(preview_levels, GameSession.Mode.CHALLENGE, 0.0)
	get_tree().change_scene_to_file(game_scene_path)


func _read_levels() -> Dictionary:
	if not FileAccess.file_exists(levels_path):
		return {"version": 1, "levels": []}
	var file := FileAccess.open(levels_path, FileAccess.READ)
	if file == null:
		return {"version": 1, "levels": []}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.get("levels", []) is Array:
		return parsed
	return {"version": 1, "levels": []}


func _find_level(id: int) -> Dictionary:
	for level in _read_levels().get("levels", []):
		if level is Dictionary and int(level.get("id", -1)) == id:
			return level.duplicate(true)
	return {}


func _sorted_coordinate_arrays() -> Array:
	var coordinates: Array = _occupied.keys()
	coordinates.sort_custom(func(a: Vector3i, b: Vector3i):
		if a.y != b.y:
			return a.y < b.y
		if a.z != b.z:
			return a.z < b.z
		return a.x < b.x
	)
	var result := []
	for coordinate: Vector3i in coordinates:
		result.append([coordinate.x, coordinate.y, coordinate.z])
	return result


func _selected_difficulty() -> String:
	return DIFFICULTIES[_difficulty.selected]


func _selected_slot() -> int:
	return int(_slot.value) - 1


func _selected_level_id() -> int:
	return _difficulty.selected * 10 + _selected_slot()


func _selected_level_name() -> String:
	return "%s_%02d" % [_selected_difficulty(), _selected_slot() + 1]


func _coordinate_to_position(coordinate: Vector3i) -> Vector3:
	return Vector3(
		(coordinate.x - GRID_CENTER) * spacing,
		(coordinate.y + VIEW_Y_OFFSET) * spacing,
		(coordinate.z - GRID_CENTER) * spacing
	)


func _is_inside_grid(coordinate: Vector3i) -> bool:
	return coordinate.x >= 0 and coordinate.x < GRID_SIZE \
		and coordinate.y >= 0 and coordinate.y < GRID_SIZE \
		and coordinate.z >= 0 and coordinate.z < GRID_SIZE


func _update_count() -> void:
	if _count_label != null:
		_count_label.text = "Tiles: %d" % _occupied.size()


func _set_status(value: String) -> void:
	if _status_label != null:
		_status_label.text = value
