class_name MahjongTileComponent
extends BaseComponent

signal configured

const ICON_FACE_BASE_SCALE := 0.36

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
		_apply_icon_aspect_ratio(face, texture)


func _apply_icon_aspect_ratio(face: MeshInstance3D, texture: Texture2D) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var current_scale := face.scale
	var aspect := texture_size.y / texture_size.x
	var width_scale := ICON_FACE_BASE_SCALE
	var height_scale := ICON_FACE_BASE_SCALE
	if aspect > 1.0:
		width_scale = ICON_FACE_BASE_SCALE / aspect
	else:
		height_scale = ICON_FACE_BASE_SCALE * aspect
	face.scale = Vector3(width_scale, current_scale.y, height_scale)


static func of_as(node: Node) -> MahjongTileComponent:
	return BaseComponent.of(node, MahjongTileComponent) as MahjongTileComponent
