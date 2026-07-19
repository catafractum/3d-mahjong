class_name GameUIComponent
extends BaseComponent

@export var minutes_label: Label
@export var seconds_label: Label
@export var selected_tile: Control
@export var selected_tile_icon: TextureRect
@export var rotate_left_button: BaseButton
@export var rotate_right_button: BaseButton
@export var shuffle_button: BaseButton

var _session: GameSession
var _displayed_selected_tile: Node3D


func _ready() -> void:
	rotate_left_button.pressed.connect(_rotate_board.bind(false))
	rotate_right_button.pressed.connect(_rotate_board.bind(true))
	shuffle_button.pressed.connect(_shuffle_board)
	set_selected_tile_texture(null)
	_initialize.call_deferred()


func _initialize() -> void:
	var session_component := CurrentGameSessionComponent.of_as(self)
	if session_component != null:
		_session = session_component.session


func _process(_delta: float) -> void:
	if _session == null:
		return
	set_remaining_seconds(_session.get_remaining_seconds())
	_refresh_selected_tile()


func _rotate_board(right: bool) -> void:
	var rotation := BoardRotationComponent.of_as(self)
	if rotation != null:
		rotation.rotate(right)


func _shuffle_board() -> void:
	var interaction := BoardInteractionComponent.of_as(self)
	if interaction != null:
		interaction.shuffle()


func _refresh_selected_tile() -> void:
	var current := _session.selected_tile if is_instance_valid(_session.selected_tile) else null
	if current == _displayed_selected_tile:
		return
	_displayed_selected_tile = current
	var texture: Texture2D
	if current != null:
		var tile := MahjongTileComponent.of_as(current)
		if tile != null:
			texture = tile.get_icon_texture()
	set_selected_tile_texture(texture)


func set_remaining_seconds(value: float) -> void:
	var total_seconds := maxi(int(ceil(value)), 0)
	minutes_label.text = "%02d" % int(total_seconds / 60.0)
	seconds_label.text = "%02d" % (total_seconds % 60)


func set_selected_tile_texture(texture: Texture2D) -> void:
	selected_tile_icon.texture = texture
	selected_tile.visible = texture != null


static func of_as(node: Node) -> GameUIComponent:
	return BaseComponent.of(node, GameUIComponent) as GameUIComponent
