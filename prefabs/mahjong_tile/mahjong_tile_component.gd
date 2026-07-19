class_name MahjongTileComponent
extends BaseComponent

signal configured

@export var icon_faces: Array[MeshInstance3D]
@export var icon_textures: Array[Texture2D]

var tile_id := -1
var grid_position := Vector3i.ZERO
var icon_type := 0


func configure(id: int, position: Vector3i, symbol: int) -> void:
	tile_id = id
	grid_position = position
	icon_type = symbol
	_apply_icon_texture(get_icon_texture())
	configured.emit()


func get_icon_texture() -> Texture2D:
	if icon_textures.is_empty():
		return null
	return icon_textures[posmod(icon_type, icon_textures.size())]


func set_icon_type(value: int) -> void:
	icon_type = value
	_apply_icon_texture(get_icon_texture())


func _apply_icon_texture(texture: Texture2D) -> void:
	if texture == null:
		return
	for face in icon_faces:
		var material := StandardMaterial3D.new()
		var existing := face.get_active_material(0) as StandardMaterial3D
		if existing != null:
			material = existing.duplicate()
		material.albedo_texture = texture
		material.albedo_color = Color.WHITE
		face.set_surface_override_material(0, material)


static func of_as(node: Node) -> MahjongTileComponent:
	return BaseComponent.of(node, MahjongTileComponent) as MahjongTileComponent
