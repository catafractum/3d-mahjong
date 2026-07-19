class_name GameUIBindingComponent
extends BaseComponent

@export var game_ui: GameUIComponent


func _ready() -> void:
	var interaction := BoardInteractionComponent.of_as(self)
	if interaction == null:
		return
	interaction.selection_changed.connect(_on_selection_changed)


func _on_selection_changed(_previous: Node3D, selected: Node3D) -> void:
	var texture: Texture2D = null
	if is_instance_valid(selected):
		var tile := MahjongTileComponent.of_as(selected)
		if tile != null:
			texture = tile.get_icon_texture()
	game_ui.set_selected_tile_texture(texture)
