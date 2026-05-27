extends Node3D

@export var tile_scene: PackedScene
var spacing := 1.08

@onready var camera: Camera3D = $Camera3D
@onready var tile_container: Node3D = $TileContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	create_cube_board()
	#pass # Replace with function body.
#
#
## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	tile_container.rotate_y(delta * 0.6)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			pick_tile(event.position)
			
func pick_tile(mouse_pos: Vector2):
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	var space_state = get_world_3d().direct_space_state
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space_state.intersect_ray(query)
	
	if result:
		print("Clicked", result.collider.name)
		
func create_cube_board() -> void:

	var count := 0
	
	for x in range(5):
		for y in range(6):
			for z in range(3):
				var tile = tile_scene.instantiate()
				tile_container.add_child(tile)
				
				tile.position = Vector3(
					(x - 2) * spacing,
					y * spacing,
					(z - 1) * spacing
				)
				
				tile.name = "Tile_%d" % count
				count += 1
	
	
	
