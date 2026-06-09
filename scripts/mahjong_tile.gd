extends Node3D

const TileDataRes = preload("res://scripts/tile_data.gd")
const DISAPPEAR_PARTICLES = preload("res://scenes/TileDisappearParticles.tscn")
const TILE_OUTLINE_SHADER = preload("res://shaders/tile_outline.gdshader")
const CUBE_ALBEDO := Color("#F3E8D2")
const ICON_FACE_BASE_SCALE := 0.36
const SHAKE_DELTA := 0.048
const SHAKE_STEP_DURATION := 0.03375

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
var _shake_tween: Tween
var _select_tween: Tween
var _is_removing: bool = false
var _current_icon_type: int = -1
var _normal_icon_texture: Texture2D
var _selected_icon_texture: Texture2D

func _icon_faces() -> Array[MeshInstance3D]:
	return [face_front, face_back, face_left, face_right]

func _ready() -> void:
	_body_meshes = _collect_body_meshes(cube_root)
	_apply_cube_albedo()
	_add_shader_outline()

func set_tile_data(data: Resource, icon_type: int) -> void:
	tile_data = data
	if tile_icons.is_empty():
		push_error("MahjongTile: tile_icons is empty — assign textures in the Inspector")
		return
	_current_icon_type = icon_type
	_normal_icon_texture = tile_icons[icon_type % tile_icons.size()]
	_selected_icon_texture = _load_selected_icon_texture(icon_type)
	_apply_icon_texture(_normal_icon_texture)

func select() -> void:
	if _select_tween != null:
		_select_tween.kill()

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
			var mat := _make_selected_body_material(body_mesh, surface_index)
			mat.emission_energy_multiplier = 0.0
			body_mesh.set_surface_override_material(surface_index, mat)

	_apply_icon_texture(_selected_icon_texture)
	for face in _icon_faces():
		var mat := face.get_surface_override_material(0) as StandardMaterial3D
		if mat != null:
			mat.albedo_color = Color(0.5, 0.5, 0.5)

	_ensure_selection_light()
	_selection_light.visible = true

	_select_tween = create_tween()
	_select_tween.set_parallel(true)
	_select_tween.set_ease(Tween.EASE_OUT)
	_select_tween.set_trans(Tween.TRANS_CUBIC)
	for body_mesh in _body_meshes:
		if body_mesh.mesh == null:
			continue
		for i in range(body_mesh.mesh.get_surface_count()):
			var mat := body_mesh.get_surface_override_material(i) as StandardMaterial3D
			if mat != null:
				_select_tween.tween_property(mat, "emission_energy_multiplier", 0.75, 0.3)
	for face in _icon_faces():
		var mat := face.get_surface_override_material(0) as StandardMaterial3D
		if mat != null:
			_select_tween.tween_property(mat, "albedo_color", Color(1.0, 1.0, 1.0, 0.9), 0.3)

func deselect() -> void:
	if _select_tween != null:
		_select_tween.kill()
		_select_tween = null

	_apply_icon_texture(_normal_icon_texture)
	for face in _icon_faces():
		var mat := face.get_surface_override_material(0) as StandardMaterial3D
		if mat != null:
			mat.albedo_color = Color(0.5, 0.5, 0.5)

	if _selection_light != null:
		_selection_light.visible = false

	_select_tween = create_tween()
	_select_tween.set_parallel(true)
	_select_tween.set_ease(Tween.EASE_IN)
	_select_tween.set_trans(Tween.TRANS_CUBIC)
	for body_mesh in _body_meshes:
		if body_mesh.mesh == null:
			continue
		for i in range(body_mesh.mesh.get_surface_count()):
			var mat := body_mesh.get_surface_override_material(i) as StandardMaterial3D
			if mat != null:
				_select_tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.15)
	for face in _icon_faces():
		var mat := face.get_surface_override_material(0) as StandardMaterial3D
		if mat != null:
			_select_tween.tween_property(mat, "albedo_color", Color.WHITE, 0.15)
	_select_tween.finished.connect(_finish_deselect, CONNECT_ONE_SHOT)

func _finish_deselect() -> void:
	for body_mesh in _body_meshes:
		if not _body_original_surface_materials.has(body_mesh):
			continue
		var original_materials: Array = _body_original_surface_materials[body_mesh]
		for surface_index in range(original_materials.size()):
			body_mesh.set_surface_override_material(surface_index, original_materials[surface_index])
	_body_original_surface_materials.clear()
	_select_tween = null

func remove_tile() -> void:
	if _is_removing:
		return
	_is_removing = true
	deselect()

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", Vector3.ONE * 1.1, 0.25)
	tween.tween_callback(_spawn_disappear_particles)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.4)
	tween.tween_callback(queue_free)

func counter_rotate_icons(delta_rad: float) -> void:
	for face in _icon_faces():
		var face_normal: Vector3 = face.global_transform.basis.y.normalized()
		face.global_rotate(face_normal, delta_rad)

func shake(hit_normal: Vector3) -> void:
	if _shake_tween != null:
		_shake_tween.kill()

	var local_normal := global_transform.basis.inverse() * hit_normal.normalized()
	var shake_axis := Vector3.ZERO
	if absf(local_normal.z) >= absf(local_normal.x):
		shake_axis = _local_axis_to_parent_offset(Vector3.RIGHT)
	else:
		shake_axis = _local_axis_to_parent_offset(Vector3.FORWARD)

	var base_position := position
	_shake_tween = create_tween()
	_shake_tween.set_ease(Tween.EASE_IN_OUT)
	_shake_tween.set_trans(Tween.TRANS_SINE)
	_shake_tween.tween_property(self, "position", base_position + shake_axis * SHAKE_DELTA, SHAKE_STEP_DURATION)
	_shake_tween.tween_property(self, "position", base_position - shake_axis * SHAKE_DELTA, SHAKE_STEP_DURATION)
	_shake_tween.tween_property(self, "position", base_position + shake_axis * (SHAKE_DELTA * 0.5), SHAKE_STEP_DURATION)
	_shake_tween.tween_property(self, "position", base_position, SHAKE_STEP_DURATION)

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

func _apply_cube_albedo() -> void:
	for body_mesh in _body_meshes:
		if body_mesh.mesh == null:
			continue
		for surface_index in range(body_mesh.mesh.get_surface_count()):
			var base_mat := body_mesh.get_active_material(surface_index) as StandardMaterial3D
			var mat := StandardMaterial3D.new()
			if base_mat != null:
				mat = base_mat.duplicate()
			mat.albedo_color = CUBE_ALBEDO
			body_mesh.set_surface_override_material(surface_index, mat)

func _spawn_disappear_particles() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var particles := DISAPPEAR_PARTICLES.instantiate() as Node3D
	parent.add_child(particles)
	particles.global_position = global_position
	particles.call("play_effect")

func _local_axis_to_parent_offset(local_axis: Vector3) -> Vector3:
	var global_axis := global_transform.basis * local_axis
	if get_parent() is Node3D:
		return (get_parent() as Node3D).global_transform.basis.inverse() * global_axis.normalized()
	return global_axis.normalized()

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

func _apply_icon_texture(texture: Texture2D) -> void:
	if texture == null:
		return
	for face in _icon_faces():
		var mat := StandardMaterial3D.new()
		var base_mat := face.get_active_material(0) as StandardMaterial3D
		if base_mat != null:
			mat = base_mat.duplicate()
		mat.albedo_texture = texture
		mat.albedo_color = Color.WHITE
		face.set_surface_override_material(0, mat)
		_apply_icon_aspect_ratio(face, texture)

func _load_selected_icon_texture(icon_type: int) -> Texture2D:
	var icon_number := (icon_type % tile_icons.size()) + 1
	var path := "res://assets/images/icons_tiles/icon_%d_on.png" % icon_number
	if not ResourceLoader.exists(path):
		push_warning("MahjongTile: selected icon texture not found: %s" % path)
		return _normal_icon_texture
	return load(path) as Texture2D

func _add_shader_outline() -> void:
	for body_mesh in _body_meshes:
		if body_mesh.mesh == null:
			continue
		var outline := MeshInstance3D.new()
		outline.name = "ShaderOutline"
		outline.mesh = body_mesh.mesh
		outline.material_override = _make_shader_outline_material()
		outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body_mesh.add_child(outline)

func _make_shader_outline_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = TILE_OUTLINE_SHADER
	return material

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
