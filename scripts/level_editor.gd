extends Node3D

const TileDataRes = preload("res://scripts/tile_data.gd")
const LevelNormalizer = preload("res://scripts/level_normalizer.gd")
const LEVELS_PATH := "res://data/levels.json"
const GRID_SIZE := 7
const GRID_CENTER := float(GRID_SIZE - 1) * 0.5
const VIEW_Y_OFFSET := -3.0
const DIFFICULTIES := ["easy", "medium", "hard"]

@export var tile_scene: PackedScene
@export var spacing := 1.0
@export var cell_alpha := 0.04

@onready var view_root: Node3D = $ViewRoot
@onready var grid_root: Node3D = $ViewRoot/GridRoot
@onready var tiles_root: Node3D = $ViewRoot/TilesRoot
@onready var layer_grid_root: Node3D = $ViewRoot/LayerGridRoot
@onready var camera: Camera3D = $Camera3D
@onready var panel: VBoxContainer = $UI/PanelContainer/Panel

var _occupied: Dictionary = {}
var _tile_nodes: Dictionary = {}
var _cell_nodes: Dictionary = {}
var _layer_grid_lines: Array[MeshInstance3D] = []
var _visual_offset := Vector3.ZERO
var _active_layer := 0
var _difficulty_option: OptionButton
var _slot_spin: SpinBox
var _layer_spin: SpinBox
var _count_label: Label
var _status_label: Label

func _ready() -> void:
	_build_ui()
	_build_grid()
	_build_layer_grid()
	_load_selected_slot()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_pick_cell(event.position)

func _build_ui() -> void:
	panel.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "Level Editor 7x7x7"
	panel.add_child(title)

	_difficulty_option = OptionButton.new()
	for difficulty in DIFFICULTIES:
		_difficulty_option.add_item(difficulty.capitalize())
	panel.add_child(_difficulty_option)
	_difficulty_option.item_selected.connect(func(_index: int): _load_selected_slot())

	_slot_spin = SpinBox.new()
	_slot_spin.min_value = 1
	_slot_spin.max_value = 10
	_slot_spin.step = 1
	_slot_spin.value = 1
	panel.add_child(_slot_spin)
	_slot_spin.value_changed.connect(func(_value: float): _load_selected_slot())

	_layer_spin = SpinBox.new()
	_layer_spin.min_value = 0
	_layer_spin.max_value = GRID_SIZE - 1
	_layer_spin.step = 1
	_layer_spin.value = 0
	_layer_spin.prefix = "Y "
	panel.add_child(_layer_spin)
	_layer_spin.value_changed.connect(func(value: float): _set_active_layer(int(value)))

	var rotate_row := HBoxContainer.new()
	panel.add_child(rotate_row)

	var rotate_left := Button.new()
	rotate_left.text = "Y -90"
	rotate_row.add_child(rotate_left)
	rotate_left.pressed.connect(func(): _rotate_view(-90.0))

	var rotate_right := Button.new()
	rotate_right.text = "Y +90"
	rotate_row.add_child(rotate_right)
	rotate_right.pressed.connect(func(): _rotate_view(90.0))

	var save_button := Button.new()
	save_button.text = "Save Slot"
	panel.add_child(save_button)
	save_button.pressed.connect(_save_selected_slot)

	var load_button := Button.new()
	load_button.text = "Reload Slot"
	panel.add_child(load_button)
	load_button.pressed.connect(_load_selected_slot)

	var clear_button := Button.new()
	clear_button.text = "Clear Slot"
	panel.add_child(clear_button)
	clear_button.pressed.connect(_clear_level)

	_count_label = Label.new()
	panel.add_child(_count_label)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_status_label)
	_update_status("Ready")

func _build_grid() -> void:
	var grid_mat := StandardMaterial3D.new()
	grid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid_mat.albedo_color = Color(0.35, 0.8, 1.0, cell_alpha)
	grid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			for z in range(GRID_SIZE):
				var coord := Vector3i(x, y, z)
				var body := StaticBody3D.new()
				body.name = "Cell_%d_%d_%d" % [x, y, z]
				body.position = _coord_to_position(coord)
				body.set_meta("coord", coord)
				grid_root.add_child(body)
				_cell_nodes[coord] = body

				var collision := CollisionShape3D.new()
				var shape := BoxShape3D.new()
				shape.size = Vector3.ONE * 0.9
				collision.shape = shape
				body.add_child(collision)

				var mesh_instance := MeshInstance3D.new()
				var mesh := BoxMesh.new()
				mesh.size = Vector3.ONE * 0.9
				mesh_instance.mesh = mesh
				mesh_instance.material_override = grid_mat
				body.add_child(mesh_instance)
	_set_active_layer(_active_layer)

func _build_layer_grid() -> void:
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(1.0, 0.05, 0.04, 1.0)

	var grid_span := float(GRID_SIZE) * spacing
	var start := -GRID_CENTER * spacing - spacing * 0.5
	var end := start + grid_span
	var line_y_offset := spacing * 0.48

	for i in range(GRID_SIZE + 1):
		var value := start + float(i) * spacing
		_layer_grid_lines.append(_make_line(Vector3(start, line_y_offset, value), Vector3(end, line_y_offset, value), line_mat))
		_layer_grid_lines.append(_make_line(Vector3(value, line_y_offset, start), Vector3(value, line_y_offset, end), line_mat))

func _make_line(from: Vector3, to: Vector3, material: Material) -> MeshInstance3D:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
	mesh.surface_end()

	var line := MeshInstance3D.new()
	line.mesh = mesh
	line.material_override = material
	layer_grid_root.add_child(line)
	return line

func _pick_cell(screen_position: Vector2) -> void:
	var from := camera.project_ray_origin(screen_position)
	var to := from + camera.project_ray_normal(screen_position) * 1000.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return

	var collider = result.get("collider")
	if collider == null:
		return

	if collider.has_meta("coord"):
		var coord: Vector3i = collider.get_meta("coord")
		if coord.y == _active_layer:
			_toggle_cell(coord)
		return

	var tile = collider.get_parent()
	if tile != null and tile.get("tile_data") != null:
		var grid_pos: Vector3 = tile.tile_data.grid_pos
		var coord := Vector3i(int(grid_pos.x), int(grid_pos.y), int(grid_pos.z))
		if coord.y == _active_layer:
			_toggle_cell(coord)

func _toggle_cell(coord: Vector3i) -> void:
	if _occupied.has(coord):
		_remove_tile(coord)
	else:
		_add_tile(coord)
	_update_status("Edited")

func _add_tile(coord: Vector3i) -> void:
	_occupied[coord] = true

	var tile := tile_scene.instantiate()
	tile.name = "Tile_%d_%d_%d" % [coord.x, coord.y, coord.z]
	tile.position = _coord_to_position(coord)
	tiles_root.add_child(tile)

	var data := TileDataRes.new()
	data.grid_pos = Vector3(coord.x, coord.y, coord.z)
	data.icon_type = _tile_nodes.size() % 16
	tile.id = _tile_nodes.size()
	tile.set_tile_data(data, data.icon_type)
	_tile_nodes[coord] = tile
	_set_tile_collision(tile, coord.y == _active_layer)
	_update_count_label()

func _remove_tile(coord: Vector3i) -> void:
	_occupied.erase(coord)
	if _tile_nodes.has(coord):
		_tile_nodes[coord].queue_free()
		_tile_nodes.erase(coord)
	_update_count_label()

func _clear_level() -> void:
	for tile in _tile_nodes.values():
		tile.queue_free()
	_occupied.clear()
	_tile_nodes.clear()
	_visual_offset = Vector3.ZERO
	_update_count_label()
	_update_status("Cleared")

func _rotate_view(delta_degrees: float) -> void:
	view_root.rotation_degrees.y = round((view_root.rotation_degrees.y + delta_degrees) / 90.0) * 90.0

func _set_active_layer(layer: int) -> void:
	_active_layer = clampi(layer, 0, GRID_SIZE - 1)
	for coord: Vector3i in _cell_nodes.keys():
		var cell: StaticBody3D = _cell_nodes[coord]
		var is_active := coord.y == _active_layer
		cell.visible = is_active
		cell.collision_layer = 1 if is_active else 0
	for coord: Vector3i in _tile_nodes.keys():
		_set_tile_collision(_tile_nodes[coord], coord.y == _active_layer)
	layer_grid_root.position.y = (float(_active_layer) + VIEW_Y_OFFSET) * spacing
	_update_status("Layer Y %d" % _active_layer)

func _set_tile_collision(tile: Node, enabled: bool) -> void:
	var body := tile.get_node_or_null("StaticBody3D") as StaticBody3D
	if body != null:
		body.collision_layer = 1 if enabled else 0

func _load_selected_slot() -> void:
	_clear_level()
	var level := _find_level(_selected_level_id())
	if level.is_empty():
		_update_status("Empty slot")
		return

	var normalized_level := LevelNormalizer.normalize(level.get("tiles", []), GRID_SIZE)
	_visual_offset = normalized_level.visual_offset
	for coord in normalized_level.coords:
		if _is_valid_coord(coord):
			_add_tile(coord)
	_update_status("Loaded %s" % _selected_level_name())

func _save_selected_slot() -> void:
	var levels_data := _read_levels_file()
	var levels: Array = levels_data.get("levels", [])
	var level_id := _selected_level_id()
	var saved_level := {
		"id": level_id,
		"name": _selected_level_name(),
		"difficulty": _selected_difficulty(),
		"slot": _selected_slot(),
		"grid_size": GRID_SIZE,
		"tiles": _coords_to_arrays()
	}

	var replaced := false
	for i in range(levels.size()):
		var level = levels[i]
		if level is Dictionary and int(level.get("id", -1)) == level_id:
			levels[i] = saved_level
			replaced = true
			break
	if not replaced:
		levels.append(saved_level)

	levels.sort_custom(func(a, b): return int(a.get("id", 0)) < int(b.get("id", 0)))
	levels_data["version"] = int(levels_data.get("version", 1))
	levels_data["levels"] = levels

	var file := FileAccess.open(LEVELS_PATH, FileAccess.WRITE)
	if file == null:
		_update_status("Save failed: %s" % LEVELS_PATH)
		return
	file.store_string(JSON.stringify(levels_data, "\t"))
	_update_status("Saved %s (%d tiles)" % [_selected_level_name(), _occupied.size()])

func _read_levels_file() -> Dictionary:
	if not FileAccess.file_exists(LEVELS_PATH):
		return {"version": 1, "levels": []}

	var file := FileAccess.open(LEVELS_PATH, FileAccess.READ)
	if file == null:
		return {"version": 1, "levels": []}

	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		if not parsed.has("levels") or not (parsed["levels"] is Array):
			parsed["levels"] = []
		return parsed
	return {"version": 1, "levels": []}

func _find_level(level_id: int) -> Dictionary:
	for level in _read_levels_file().get("levels", []):
		if level is Dictionary and int(level.get("id", -1)) == level_id:
			return level
	return {}

func _coords_to_arrays() -> Array:
	var coords: Array = _occupied.keys()
	coords.sort_custom(func(a: Vector3i, b: Vector3i):
		if a.y != b.y:
			return a.y < b.y
		if a.z != b.z:
			return a.z < b.z
		return a.x < b.x
	)

	var arrays := []
	for coord: Vector3i in coords:
		arrays.append([coord.x, coord.y, coord.z])
	return arrays

func _coord_to_position(coord: Vector3i) -> Vector3:
	return Vector3(
		(float(coord.x) - GRID_CENTER + _visual_offset.x) * spacing,
		(float(coord.y) + VIEW_Y_OFFSET) * spacing,
		(float(coord.z) - GRID_CENTER + _visual_offset.z) * spacing
	)

func _selected_difficulty() -> String:
	return DIFFICULTIES[_difficulty_option.selected]

func _selected_slot() -> int:
	return int(_slot_spin.value) - 1

func _selected_level_id() -> int:
	return _difficulty_option.selected * 10 + _selected_slot()

func _selected_level_name() -> String:
	return "%s_%02d" % [_selected_difficulty(), _selected_slot() + 1]

func _is_valid_coord(coord: Vector3i) -> bool:
	return coord.x >= 0 and coord.x < GRID_SIZE and coord.y >= 0 and coord.y < GRID_SIZE and coord.z >= 0 and coord.z < GRID_SIZE

func _update_count_label() -> void:
	if _count_label != null:
		_count_label.text = "Tiles: %d" % _occupied.size()

func _update_status(text: String) -> void:
	_update_count_label()
	if _status_label != null:
		_status_label.text = text
