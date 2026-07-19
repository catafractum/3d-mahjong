class_name TileVisualFeedbackComponent
extends BaseComponent


func _ready() -> void:
	var matching := TileMatchingComponent.of_as(self)
	if matching == null:
		push_error("TileVisualFeedbackComponent: TileMatchingComponent was not found.")
		return
	matching.selection_changed.connect(_on_selection_changed)
	matching.blocked_tile_pressed.connect(_on_blocked_tile_pressed)
	matching.match_succeeded.connect(_on_match_succeeded)


func _on_selection_changed(previous_tile: Node3D, selected_tile: Node3D) -> void:
	if is_instance_valid(previous_tile):
		MahjongTileVisualComponent.of_as(previous_tile).deselect()
	if is_instance_valid(selected_tile):
		MahjongTileVisualComponent.of_as(selected_tile).select()


func _on_blocked_tile_pressed(tile: Node3D, hit_normal: Vector3) -> void:
	if is_instance_valid(tile):
		MahjongTileVisualComponent.of_as(tile).shake(hit_normal)


func _on_match_succeeded(first_tile: Node3D, second_tile: Node3D) -> void:
	if is_instance_valid(first_tile):
		MahjongTileVisualComponent.of_as(first_tile).remove()
	if is_instance_valid(second_tile):
		MahjongTileVisualComponent.of_as(second_tile).remove()
