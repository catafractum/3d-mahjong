extends Node3D

@export var tile_scene: PackedScene

signal tile_selected(tile: Node3D)

@onready var camera: Camera3D = get_viewport().get_camera_3d()

var spacing := 1.08

func _ready() -> void:
	create_cube_board()

func _process(delta: float) -> void:
	rotate_y(delta * 0.6)

func create_cube_board() -> void:
	var count := 0
	for x in range(3):
		for y in range(3):
			for z in range(3):
				var tile = tile_scene.instantiate()
				add_child(tile)
				tile.position = Vector3((x - 2) * spacing, y * spacing, (z - 1) * spacing)
				tile.name = "Tile_%d" % count
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
