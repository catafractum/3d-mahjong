extends Node3D

const TileDataRes = preload("res://scripts/tile_data.gd")

@onready var face_front: MeshInstance3D = $FaceFront
@onready var face_back: MeshInstance3D = $FaceBack
@onready var face_left: MeshInstance3D = $FaceLeft
@onready var face_right: MeshInstance3D = $FaceRight
@onready var cube_root: Node3D = $cube

@export var tile_icons: Array[Texture2D]

var id: int = -1
var tile_data = null
var _body_meshes: Array[MeshInstance3D] = []
var _body_original_surface_materials: Dictionary = {}
var _editor_dim_original_surface_materials: Dictionary = {}
var _selection_light: OmniLight3D
var _is_removing: bool = false

func _icon_faces() -> Array[MeshInstance3D]:
	return [face_front, face_back, face_left, face_right]

func _ready() -> void:
	_body_meshes = _collect_body_meshes(cube_root)

func set_tile_data(data: Resource, icon_type: int) -> void:
	tile_data = data
	if tile_icons.is_empty():
		push_error("MahjongTile: tile_icons is empty — assign textures in the Inspector")
		return
	var texture: Texture2D = tile_icons[icon_type % tile_icons.size()]
	for face in _icon_faces():
		var mat: StandardMaterial3D = face.get_active_material(0).duplicate()
		mat.albedo_texture = texture
		face.set_surface_override_material(0, mat)

func select() -> void:
	for body_mesh in _body_meshes:
		if body_mesh.mesh == null:
			continue
		var surface_count := body_mesh.mesh.get_surface_count()
		if not _body_original_surface_materials.has(body_mesh):
			var original_materials: Array[Material] = []
			for surface_index in range(surface_count):
				original_materials.append(body_mesh.get_surface_override_material(surface_index))
			_body_original_surface_materials[body_mesh] = original_materials
		for surface_index in range(surface_count):
			body_mesh.set_surface_override_material(surface_index, _make_selected_body_material(body_mesh, surface_index))
	_ensure_selection_light()
	_selection_light.visible = true

func deselect() -> void:
	for body_mesh in _body_meshes:
		if not _body_original_surface_materials.has(body_mesh):
			continue
		var original_materials: Array = _body_original_surface_materials[body_mesh]
		for surface_index in range(original_materials.size()):
			body_mesh.set_surface_override_material(surface_index, original_materials[surface_index])
	_body_original_surface_materials.clear()
	if _selection_light != null:
		_selection_light.visible = false

func remove_tile() -> void:
	if _is_removing:
		return
	_is_removing = true
	deselect()

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", Vector3.ONE * 1.1, 0.25)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.4)
	tween.tween_callback(queue_free)

func counter_rotate_icons(delta_rad: float) -> void:
	for face in _icon_faces():
		var face_normal: Vector3 = face.global_transform.basis.y.normalized()
		face.global_rotate(face_normal, delta_rad)

func set_editor_dimmed(is_dimmed: bool) -> void:
	var meshes := _collect_body_meshes(self)

	if is_dimmed:
		if not _editor_dim_original_surface_materials.is_empty():
			return
		for mesh_instance in meshes:
			if mesh_instance.mesh == null:
				continue
			var surface_count := mesh_instance.mesh.get_surface_count()
			if not _editor_dim_original_surface_materials.has(mesh_instance):
				var original_materials: Array[Material] = []
				for surface_index in range(surface_count):
					original_materials.append(mesh_instance.get_surface_override_material(surface_index))
				_editor_dim_original_surface_materials[mesh_instance] = original_materials
			for surface_index in range(surface_count):
				mesh_instance.set_surface_override_material(surface_index, _make_editor_dimmed_material(mesh_instance, surface_index))
		return

	for mesh_instance in _editor_dim_original_surface_materials.keys():
		if not is_instance_valid(mesh_instance):
			continue
		var original_materials: Array = _editor_dim_original_surface_materials[mesh_instance]
		for surface_index in range(original_materials.size()):
			mesh_instance.set_surface_override_material(surface_index, original_materials[surface_index])
	_editor_dim_original_surface_materials.clear()

func _collect_body_meshes(root: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		meshes.append(root)
	for child in root.get_children():
		meshes.append_array(_collect_body_meshes(child))
	return meshes

func _make_selected_body_material(body_mesh: MeshInstance3D, surface_index: int) -> StandardMaterial3D:
	var base_mat := body_mesh.get_active_material(surface_index) as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	if base_mat != null:
		mat = base_mat.duplicate()
	mat.albedo_color = Color.WHITE
	mat.emission_enabled = true
	mat.emission = Color.WHITE
	mat.emission_energy_multiplier = 0.75
	return mat

func _make_editor_dimmed_material(mesh_instance: MeshInstance3D, surface_index: int) -> StandardMaterial3D:
	var base_mat := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	if base_mat != null:
		mat = base_mat.duplicate()
	mat.albedo_color = mat.albedo_color * Color(0.24, 0.24, 0.24, 1.0)
	mat.emission_enabled = false
	return mat

func _ensure_selection_light() -> void:
	if _selection_light != null:
		return
	_selection_light = OmniLight3D.new()
	_selection_light.name = "SelectionLight"
	_selection_light.light_color = Color.WHITE
	_selection_light.light_energy = 0.45
	_selection_light.omni_range = 1.35
	_selection_light.position = Vector3.ZERO
	add_child(_selection_light)
