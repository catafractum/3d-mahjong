extends Node3D

const TileDataRes = preload("res://scripts/tile_data.gd")
const LevelNormalizer = preload("res://scripts/level_normalizer.gd")
const LEVELS_PATH := "res://data/levels.json"
const DEFAULT_GRID_SIZE := 7
const BOARD_Y_OFFSET := -0.25
const LEVEL_SCALE_BY_HEIGHT := {
	6: 0.875,
	7: 0.775
}

@export var tile_scene: PackedScene
@export var icon_type_count: int = 16
@export var grid_size: int = DEFAULT_GRID_SIZE
@export var level_id := 20

signal tile_selected(tile: Node3D, hit_normal: Vector3)
signal board_ready(tiles: Array[Node3D])
signal layer_rotated(axis_name: String, layer_value: float, angle_degrees: float, visual_offset: Vector3)

@onready var camera: Camera3D = get_viewport().get_camera_3d()

var spacing := 1
var _rotating := false
const LAYER_ROTATION_DURATION := 0.35
const TAP_MAX_DISTANCE := 16.0
const SWIPE_MIN_DISTANCE := 80.0
const SWIPE_VERTICAL_TOLERANCE := 0.6
var _sync_tiles: Array[Node3D] = []
var _visual_offset := Vector3(0.0, BOARD_Y_OFFSET, 0.0)
var _rotation_visual_offset := Vector3(0.0, BOARD_Y_OFFSET, 0.0)
var _rotation_bounds := {
	"min_x": 0,
	"max_x": DEFAULT_GRID_SIZE - 1,
	"min_y": 0,
	"max_y": DEFAULT_GRID_SIZE - 1,
	"min_z": 0,
	"max_z": DEFAULT_GRID_SIZE - 1
}
var _last_sync_angle := 0.0
var _press_position := Vector2.ZERO
var _tracking_pointer := false

func _ready() -> void:
	level_id = GameState.selected_level_id
	rotate_y(-10 * PI / 180)
	_create_cube_board(level_id)
	board_ready.emit(_get_tiles())

func rotate_board(right: bool) -> void:
	if _rotating:
		return
	_rotating = true
	var direction = 90 if right else -90
	var target = rotation_degrees.y + direction
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "rotation_degrees:y", target, 0.4)
	tween.tween_callback(func(): _rotating = false)

func shuffle_z_outer(angle_degrees: float) -> void:
	if _rotating:
		return
	_rotating = true
	var z_layers := _get_axis_layers("z")
	if not z_layers.is_empty():
		await _rotate_layer("z", z_layers[z_layers.size() - 1], angle_degrees)
	_rotating = false

func shuffle_y_top(angle_degrees: float) -> void:
	if _rotating:
		return
	_rotating = true
	var y_layers := _get_axis_layers("y")
	if not y_layers.is_empty():
		await _rotate_layer("y", y_layers[y_layers.size() - 1], angle_degrees)
	_rotating = false

func shuffle() -> void:
	if _rotating:
		return
	_rotating = true

	var x_layers := _get_axis_layers("x")
	var y_layers := _get_axis_layers("y")
	var z_layers := _get_axis_layers("z")
	var y_angles := [90.0, 180.0, -90.0]

	for i in range(7):
		var axis: String = ["x", "y", "z"][randi() % 3]
		var layers: Array[float]
		var angle: float

		match axis:
			"x":
				layers = x_layers
				angle = 180.0
			"y":
				layers = y_layers
				angle = y_angles[randi() % y_angles.size()]
			"z":
				layers = z_layers
				angle = 180.0

		if layers.is_empty():
			continue

		var layer_value: float = layers[randi() % layers.size()]
		await _rotate_layer(axis, layer_value, angle)

	_rotating = false

func _rotate_layer(axis_name: String, layer_value: float, angle_degrees: float) -> void:
	var tiles := _get_tiles()
	if tiles.is_empty():
		return

	var layer_tiles: Array[Node3D] = []
	for tile in tiles:
		if abs(_axis_value(tile.position, axis_name) - layer_value) <= 0.05:
			layer_tiles.append(tile)

	if layer_tiles.is_empty():
		return

	var pivot := Node3D.new()
	add_child(pivot)
	pivot.global_position = to_global(_get_layer_center(axis_name, layer_value))

	for tile in layer_tiles:
		tile.reparent(pivot, true)

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(pivot, "rotation_degrees:%s" % axis_name, angle_degrees, LAYER_ROTATION_DURATION)

	if axis_name != "y":
		_sync_tiles = layer_tiles.duplicate()
		_last_sync_angle = 0.0
		tween.parallel().tween_method(_on_sync_angle, 0.0, angle_degrees, LAYER_ROTATION_DURATION)

	await tween.finished

	_sync_tiles.clear()

	for tile in layer_tiles:
		tile.reparent(self, true)
		tile.position = _snap_position(tile.position)

	pivot.queue_free()
	layer_rotated.emit(axis_name, layer_value, angle_degrees, _visual_offset)

func _on_sync_angle(current_angle: float) -> void:
	var delta_rad := deg_to_rad(current_angle - _last_sync_angle)
	_last_sync_angle = current_angle
	for tile in _sync_tiles:
		if is_instance_valid(tile):
			tile.counter_rotate_icons(-delta_rad)

func _get_axis_layers(axis_name: String) -> Array[float]:
	var tiles := _get_tiles()
	var layers: Array[float] = []
	var snap_step: float = spacing / 2.0
	for tile in tiles:
		var offset := _axis_snap_offset(axis_name)
		var snapped_value: float = round((_axis_value(tile.position, axis_name) - offset) / snap_step) * snap_step + offset
		var exists := false
		for v in layers:
			if abs(v - snapped_value) <= 0.05:
				exists = true
				break
		if not exists:
			layers.append(snapped_value)
	layers.sort()
	return layers

func _get_tiles() -> Array[Node3D]:
	var tiles: Array[Node3D] = []
	for child in get_children():
		if child is Node3D and str(child.name).begins_with("Tile_"):
			tiles.append(child)
	return tiles

func get_tiles() -> Array[Node3D]:
	return _get_tiles()

func _axis_value(v: Vector3, axis_name: String) -> float:
	match axis_name:
		"x": return v.x
		"y": return v.y
		"z": return v.z
		_: return 0.0

func _get_layer_center(axis_name: String, layer_value: float) -> Vector3:
	var center_x := _axis_center_world("x")
	var center_y := _axis_center_world("y")
	var center_z := _axis_center_world("z")
	match axis_name:
		"x": return Vector3(layer_value, center_y, center_z)
		"y": return Vector3(center_x, layer_value, center_z)
		"z": return Vector3(center_x, center_y, layer_value)
	return Vector3.ZERO

func _axis_center_world(axis_name: String) -> float:
	match axis_name:
		"x":
			return _coord_center_to_world(float(_rotation_bounds.min_x), float(_rotation_bounds.max_x), _rotation_visual_offset.x)
		"y":
			return (((float(_rotation_bounds.min_y) + float(_rotation_bounds.max_y)) * 0.5) + _rotation_visual_offset.y) * spacing
		"z":
			return _coord_center_to_world(float(_rotation_bounds.min_z), float(_rotation_bounds.max_z), _rotation_visual_offset.z)
	return 0.0

func _coord_center_to_world(min_value: float, max_value: float, axis_visual_offset: float) -> float:
	var grid_center := float(grid_size - 1) * 0.5
	return (((min_value + max_value) * 0.5) - grid_center + axis_visual_offset) * spacing

func _snap_position(p: Vector3) -> Vector3:
	var snap_step := spacing / 2.0
	return Vector3(
		round((p.x - _axis_snap_offset("x")) / snap_step) * snap_step + _axis_snap_offset("x"),
		round((p.y - _axis_snap_offset("y")) / snap_step) * snap_step + _axis_snap_offset("y"),
		round((p.z - _axis_snap_offset("z")) / snap_step) * snap_step + _axis_snap_offset("z")
	)

func _axis_snap_offset(axis_name: String) -> float:
	match axis_name:
		"x": return _visual_offset.x * spacing
		"y": return _visual_offset.y * spacing
		"z": return _visual_offset.z * spacing
	return 0.0

func _create_cube_board(level_id: int) -> void:
	var level := _get_level_data(level_id)
	if level.is_empty():
		push_error("BoardContainer: level id %d not found" % level_id)
		return

	var tile_coords: Array = level.get("tiles", [])
	if tile_coords.is_empty():
		push_error("BoardContainer: level id %d has no tiles" % level_id)
		return

	grid_size = int(level.get("grid_size", DEFAULT_GRID_SIZE))
	var normalized_level := LevelNormalizer.normalize(tile_coords, grid_size, BOARD_Y_OFFSET)
	tile_coords = normalized_level.coords
	_visual_offset = normalized_level.visual_offset
	_rotation_visual_offset = normalized_level.rotation_visual_offset
	_rotation_bounds = normalized_level.rotation_bounds
	scale = Vector3.ONE * _get_level_scale(_get_y_height(tile_coords))
	var center_x: float = float(grid_size - 1) * 0.5
	var center_z: float = float(grid_size - 1) * 0.5
	var count := 0
	for coord in tile_coords:
		var x := int(coord.x)
		var y := int(coord.y)
		var z := int(coord.z)
		if not LevelNormalizer.is_inside_grid(Vector3i(x, y, z), grid_size):
			push_warning("BoardContainer: skipping out-of-grid tile coordinate in level %d" % level_id)
			continue

		var tile = tile_scene.instantiate()
		add_child(tile)
		tile.position = Vector3(
			(x - center_x + _visual_offset.x) * spacing,
			(y + BOARD_Y_OFFSET) * spacing,
			(z - center_z + _visual_offset.z) * spacing
		)
		tile.name = "Tile_%d" % count
		tile.id = count
		var data := TileDataRes.new()
		data.grid_pos = Vector3(x, y, z)
		data.icon_type = randi() % icon_type_count
		tile.set_tile_data(data, data.icon_type)
		count += 1

func _get_level_scale(y_height: int) -> float:
	return float(LEVEL_SCALE_BY_HEIGHT.get(y_height, 1.0))

func _get_y_height(coords: Array) -> int:
	if coords.is_empty():
		return 0

	var min_y := int(coords[0].y)
	var max_y := min_y
	for coord in coords:
		min_y = mini(min_y, int(coord.y))
		max_y = maxi(max_y, int(coord.y))
	return max_y - min_y + 1

func _get_level_data(level_id: int) -> Dictionary:
	var file := FileAccess.open(LEVELS_PATH, FileAccess.READ)
	if file == null:
		push_error("BoardContainer: could not open %s" % LEVELS_PATH)
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("BoardContainer: invalid levels JSON")
		return {}

	for level in parsed.get("levels", []):
		if level is Dictionary and int(level.get("id", -1)) == level_id:
			return level
	return {}

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
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
	var delta := position - _press_position
	var abs_delta := delta.abs()

	if abs_delta.x >= SWIPE_MIN_DISTANCE and abs_delta.y <= abs_delta.x * SWIPE_VERTICAL_TOLERANCE:
		rotate_board(delta.x > 0.0)
		get_viewport().set_input_as_handled()
	elif delta.length() <= TAP_MAX_DISTANCE:
		pick_tile(position)

func pick_tile(mouse_pos: Vector2) -> void:
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	if result:
		var tile := _tile_from_collider(result.collider)
		if tile != null:
			tile_selected.emit(tile, result.normal)

func _tile_from_collider(collider: Object) -> Node3D:
	if collider == null or not (collider is Node):
		return null
	var candidate := (collider as Node).get_parent()
	if candidate is Node3D \
			and str(candidate.name).begins_with("Tile_") \
			and candidate.get("tile_data") != null:
		return candidate
	return null
