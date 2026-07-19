class_name GameUIComponent
extends BaseComponent

signal rotate_requested(right: bool)
signal shuffle_requested

@export var minutes_label: Label
@export var seconds_label: Label
@export var selected_tile: Control
@export var selected_tile_icon: TextureRect
@export var rotate_left_button: BaseButton
@export var rotate_right_button: BaseButton
@export var shuffle_button: BaseButton


func _ready() -> void:
	rotate_left_button.pressed.connect(rotate_requested.emit.bind(false))
	rotate_right_button.pressed.connect(rotate_requested.emit.bind(true))
	shuffle_button.pressed.connect(shuffle_requested.emit)

	set_selected_tile_texture(null)


func set_remaining_seconds(value: float) -> void:
	var total_seconds := maxi(int(ceil(value)), 0)
	minutes_label.text = "%02d" % int(total_seconds / 60.0)
	seconds_label.text = "%02d" % (total_seconds % 60)


func set_selected_tile_texture(texture: Texture2D) -> void:
	selected_tile_icon.texture = texture
	selected_tile.visible = texture != null


static func of_as(node: Node) -> GameUIComponent:
	return BaseComponent.of(node, GameUIComponent) as GameUIComponent
