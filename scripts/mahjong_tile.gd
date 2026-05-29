extends Node3D

@onready var face_front: MeshInstance3D = $FaceFront
@onready var face_back: MeshInstance3D = $FaceBack
@onready var face_left: MeshInstance3D = $FaceLeft
@onready var face_right: MeshInstance3D = $FaceRight

func counter_rotate_icons(delta_rad: float) -> void:
	for face in [face_front, face_back, face_left, face_right]:
		var face_normal: Vector3 = face.global_transform.basis.y.normalized()
		face.global_rotate(face_normal, delta_rad)

func set_icon(texture: Texture2D) -> void:
	for face in [face_front, face_back, face_left, face_right]:
		var mat: StandardMaterial3D = face.get_active_material(0).duplicate()
		mat.albedo_texture = texture
		face.set_surface_override_material(0, mat)
