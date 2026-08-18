class_name TileDisappearParticlesComponent
extends BaseComponent

const MOVEMENT_TRANSITIONS := [
	Tween.TRANS_CUBIC,
	Tween.TRANS_QUAD,
	Tween.TRANS_QUART,
	Tween.TRANS_SINE,
	Tween.TRANS_BACK,
]
const ALPHA_TRANSITIONS := [Tween.TRANS_SINE, Tween.TRANS_QUAD, Tween.TRANS_CUBIC]

@export var effect_root: Node3D
@export var spark_textures: Array[Texture2D]
@export var spark_weights: Array[int] = [4, 4, 4, 1]
@export var distance_multipliers: Array[float] = [1.0, 1.0, 1.0, 1.35]
@export var duration_multipliers: Array[float] = [1.0, 1.0, 1.0, 0.55]
@export var particle_count := 36
@export var tile_edge := 0.84
@export var spark_size := Vector2(0.33, 0.41)
@export var expand_duration := 0.4
@export var fade_duration := 0.2
@export var auto_play := true

var _has_played := false


func _ready() -> void:
	if auto_play:
		play_effect.call_deferred()


func play_effect() -> void:
	if _has_played:
		return
	_has_played = true
	for _index in particle_count:
		_spawn_spark()
	get_tree().create_timer((expand_duration + fade_duration) * 1.45).timeout.connect(
		effect_root.queue_free
	)


func _spawn_spark() -> void:
	if spark_textures.is_empty():
		return
	var spark_type := _random_spark_type()
	var spark := MeshInstance3D.new()
	var material := _make_material(spark_textures[spark_type])
	var mesh := QuadMesh.new()
	mesh.size = spark_size
	mesh.material = material
	mesh.orientation = PlaneMesh.FACE_Z
	spark.mesh = mesh
	spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spark.scale = Vector3.ONE * randf_range(1.0, 3.0)
	spark.rotation_degrees.z = randf_range(0.0, 360.0)
	effect_root.add_child(spark)

	var duration := (
		(expand_duration + fade_duration)
		* randf_range(0.55, 1.45)
		* duration_multipliers[spark_type]
	)
	var direction := _random_direction()
	var movement := create_tween()
	movement.set_ease(Tween.EASE_OUT)
	movement.set_trans(MOVEMENT_TRANSITIONS.pick_random())
	movement.tween_property(
		spark,
		"position",
		direction * tile_edge * distance_multipliers[spark_type],
		duration
	)

	var alpha := create_tween()
	alpha.set_ease(Tween.EASE_IN_OUT)
	alpha.set_trans(ALPHA_TRANSITIONS.pick_random())
	alpha.tween_method(_set_alpha.bind(material), 0.0, 1.0, duration * 0.5)
	alpha.tween_method(_set_alpha.bind(material), 1.0, 0.0, duration * 0.5)


func _make_material(texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = Color(1, 1, 1, 0)
	material.albedo_texture = texture
	material.emission_enabled = true
	material.emission = Color.WHITE
	material.emission_texture = texture
	material.emission_energy_multiplier = 1.8
	return material


func _random_direction() -> Vector3:
	var result := Vector3.ZERO
	while result.is_zero_approx():
		result = Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		)
	return result.normalized()


func _random_spark_type() -> int:
	var available_count := mini(
		spark_textures.size(),
		mini(spark_weights.size(), mini(distance_multipliers.size(), duration_multipliers.size()))
	)
	if available_count <= 0:
		return 0
	var total_weight := 0
	for index in available_count:
		total_weight += spark_weights[index]
	var roll := randi() % maxi(total_weight, 1)
	for index in available_count:
		roll -= spark_weights[index]
		if roll < 0:
			return index
	return available_count - 1


func _set_alpha(value: float, material: StandardMaterial3D) -> void:
	var color := material.albedo_color
	color.a = value
	material.albedo_color = color


static func of_as(node: Node) -> TileDisappearParticlesComponent:
	return BaseComponent.of(node, TileDisappearParticlesComponent) as TileDisappearParticlesComponent
