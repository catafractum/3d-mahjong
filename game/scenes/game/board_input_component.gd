class_name BoardInputComponent
extends BaseComponent

signal tile_pressed(tile: Node3D, hit_normal: Vector3)

@export var camera: Camera3D
@export var ray_length := 1000.0
@export var maximum_tap_distance := 16.0

var _press_position := Vector2.ZERO
var _tracking_pointer := false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
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
	if _press_position.distance_to(position) > maximum_tap_distance:
		return
	_pick_tile(position)


func _pick_tile(screen_position: Vector2) -> void:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * ray_length)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var tile := _find_tile(hit.collider as Node)
	if tile != null:
		tile_pressed.emit(tile, hit.get("normal", Vector3.ZERO))


func _find_tile(node: Node) -> Node3D:
	var current := node
	while current != null:
		var tile_component := MahjongTileComponent.of_as(current)
		if tile_component != null:
			return tile_component.get_owner_node() as Node3D
		current = current.get_parent()
	return null


static func of_as(node: Node) -> BoardInputComponent:
	return BaseComponent.of(node, BoardInputComponent) as BoardInputComponent
