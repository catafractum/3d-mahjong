extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var board_container: Node3D = $BoardContainer

func _ready() -> void:
	$BoardContainer.tile_selected.connect(_on_tile_selected)
	$GUI/Control/RightArrowBtn.pressed.connect(_on_rotate_right)
	$GUI/Control/LeftArrowBtn.pressed.connect(_on_rotate_left)
	$GUI/Control/ShuffleBtn.pressed.connect(_on_shuffle)

func _on_tile_selected(tile: Node3D) -> void:
	print("Clicked ", tile.name)
	
func _on_rotate_right() -> void:
	$BoardContainer.rotate_board(true)

func _on_rotate_left() -> void:
	$BoardContainer.rotate_board(false)

func _on_shuffle() -> void:
	$BoardContainer.shuffle()
