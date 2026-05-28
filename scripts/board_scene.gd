extends Node3D

@onready var camera: Camera3D = $Camera3D
@onready var board_container: Node3D = $BoardContainer

func _ready() -> void:
	$BoardContainer.tile_selected.connect(_on_tile_selected)

func _on_tile_selected(tile: Node3D) -> void:
	print("Clicked ", tile.name)
