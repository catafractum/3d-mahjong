extends Node3D

@export var tile_scene: PackedScene
@export var tile_icons: Array[Texture2D]

signal tile_selected(tile: Node3D)

@onready var camera: Camera3D = get_viewport().get_camera_3d()

var spacing := 1
var _rotating := false
const LAYER_ROTATION_DURATION := 0.35
var _sync_tiles: Array[Node3D] = []
var _last_sync_angle := 0.0

func _ready() -> void:
	_create_cube_board()
	rotate_y(-10 * PI / 180)

func _process(_delta: float) -> void:
	pass

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
	pivot.global_position = _average_global_position(layer_tiles)

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
		var snapped_value: float = round(_axis_value(tile.position, axis_name) / snap_step) * snap_step
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

func _axis_value(v: Vector3, axis_name: String) -> float:
	match axis_name:
		"x": return v.x
		"y": return v.y
		"z": return v.z
		_: return 0.0

func _average_global_position(nodes: Array[Node3D]) -> Vector3:
	var acc := Vector3.ZERO
	for n in nodes:
		acc += n.global_position
	return acc / float(nodes.size())

func _snap_position(p: Vector3) -> Vector3:
	var snap_step := spacing / 2.0
	return Vector3(
		round(p.x / snap_step) * snap_step,
		round(p.y / snap_step) * snap_step,
		round(p.z / snap_step) * snap_step
	)

func _snap_rotation_degrees(rot: Vector3) -> Vector3:
	return Vector3(
		round(rot.x / 90.0) * 90.0,
		round(rot.y / 90.0) * 90.0,
		round(rot.z / 90.0) * 90.0
	)

func _create_cube_board() -> void:
	var count := 0
	for x in range(4):
		for y in range(4):
			for z in range(4):
				var tile = tile_scene.instantiate()
				add_child(tile)
				tile.position = Vector3((x - 1.5) * spacing, y * spacing, (z - 1.5) * spacing)
				tile.name = "Tile_%d" % count
				if tile_icons.size() > 0:
					tile.set_icon(tile_icons[randi() % tile_icons.size()])
				count += 1

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			pick_tile(event.position)

func pick_tile(mouse_pos: Vector2) -> void:
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	if result:
		tile_selected.emit(result.collider.get_parent())
