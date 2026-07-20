class_name MahjongTileVisualComponent
extends BaseComponent

@export var tile: Node3D
@export var body_root: Node3D
@export var icon_faces: Array[MeshInstance3D]
@export var disappear_particles_scene: PackedScene
@export var shake_distance := 0.048
@export var removal_grow_duration := 0.225
@export var removal_shrink_duration := 0.36
@export var removal_finish_delay := 0.2

var _base_position := Vector3.ZERO
var _tween: Tween
var _body_meshes: Array[MeshInstance3D] = []
var _editor_dimmed := false


func _ready() -> void:
	_base_position = tile.position
	_body_meshes = _collect_meshes(body_root)
	_prepare_body_materials()


func select() -> void:
	_set_icon_color(Color(1.0, 0.85, 0.45))
	_set_body_selected(true)


func deselect() -> void:
	_set_icon_color(Color(0.28, 0.28, 0.28) if _editor_dimmed else Color.WHITE)
	_set_body_selected(false)


func set_editor_dimmed(is_dimmed: bool) -> void:
	_editor_dimmed = is_dimmed
	var color := Color(0.28, 0.28, 0.28) if is_dimmed else Color.WHITE
	_set_icon_color(color)
	for mesh in _body_meshes:
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_surface_override_material(surface) as StandardMaterial3D
			if material != null:
				material.albedo_color = Color("49443c") if is_dimmed else Color("f3e8d2")


func remove() -> void:
	_kill_tween()
	_disable_collisions(tile)
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	var base_scale := tile.scale
	_tween.tween_property(tile, "scale", base_scale * 1.1, removal_grow_duration)
	_tween.tween_callback(_spawn_disappear_particles)
	_tween.tween_property(tile, "scale", Vector3.ZERO, removal_shrink_duration)
	_tween.tween_interval(removal_finish_delay)
	_tween.tween_callback(tile.queue_free)


func shake(_hit_normal: Vector3) -> void:
	_kill_tween()
	_base_position = tile.position
	_tween = create_tween()
	_tween.tween_property(tile, "position:x", _base_position.x + shake_distance, 0.04)
	_tween.tween_property(tile, "position:x", _base_position.x - shake_distance, 0.04)
	_tween.tween_property(tile, "position:x", _base_position.x, 0.04)


func _set_icon_color(color: Color) -> void:
	for face in icon_faces:
		var material := face.get_surface_override_material(0) as StandardMaterial3D
		if material != null:
			material.albedo_color = color


func _prepare_body_materials() -> void:
	for mesh in _body_meshes:
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var material := StandardMaterial3D.new()
			var existing := mesh.get_active_material(surface) as StandardMaterial3D
			if existing != null:
				material = existing.duplicate()
			material.albedo_color = Color("f3e8d2")
			material.emission_enabled = true
			material.emission = Color.WHITE
			material.emission_energy_multiplier = 0.0
			mesh.set_surface_override_material(surface, material)


func _set_body_selected(is_selected: bool) -> void:
	for mesh in _body_meshes:
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_surface_override_material(surface) as StandardMaterial3D
			if material != null:
				material.emission_energy_multiplier = 0.65 if is_selected else 0.0


func _collect_meshes(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		result.append(root)
	for child in root.get_children():
		result.append_array(_collect_meshes(child))
	return result


func _disable_collisions(root: Node) -> void:
	if root is CollisionObject3D:
		root.set_deferred("collision_layer", 0)
		root.set_deferred("collision_mask", 0)
	for child in root.get_children():
		_disable_collisions(child)


func _spawn_disappear_particles() -> void:
	if disappear_particles_scene == null or tile.get_parent() == null:
		return
	var particles := disappear_particles_scene.instantiate() as Node3D
	tile.get_parent().add_child(particles)
	particles.global_position = tile.global_position


func _kill_tween() -> void:
	if _tween != null:
		_tween.kill()


static func of_as(node: Node) -> MahjongTileVisualComponent:
	return BaseComponent.of(node, MahjongTileVisualComponent) as MahjongTileVisualComponent
