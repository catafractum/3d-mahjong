extends Node3D

const SPARK_TEXTURES := [
	preload("res://assets/images/spark_01.png"),
	preload("res://assets/images/spark_02.png"),
	preload("res://assets/images/spark_03.png"),
	preload("res://assets/images/spark_04.png")
]
const SPARK_WEIGHTS := [4, 4, 4, 1]
const SPARK_DISTANCE_MULTIPLIERS := [1.0, 1.0, 1.0, 1.35]
const SPARK_DURATION_MULTIPLIERS := [1.0, 1.0, 1.0, 0.55]
const PARTICLE_COUNT := 36
const TILE_HALF_EDGE := 0.42
const TILE_EDGE := TILE_HALF_EDGE * 2.0
const SPARK_SIZE := Vector2(0.16, 0.2) * 2.0625
const MAX_SPARK_SCALE := 3.0
const START_ALPHA := 0.0
const PEAK_ALPHA := 1.0
const EXPAND_DURATION := 0.4
const FADE_OUT_DURATION := 0.2
const TOTAL_DURATION := EXPAND_DURATION + FADE_OUT_DURATION
const MIN_DURATION_MULTIPLIER := 0.55
const MAX_DURATION_MULTIPLIER := 1.45
const MOVEMENT_TRANSITIONS := [Tween.TRANS_CUBIC, Tween.TRANS_QUAD, Tween.TRANS_QUART, Tween.TRANS_SINE, Tween.TRANS_BACK]
const ALPHA_TRANSITIONS := [Tween.TRANS_SINE, Tween.TRANS_QUAD, Tween.TRANS_CUBIC]

func play_effect() -> void:
	for i in range(PARTICLE_COUNT):
		_spawn_spark()

	get_tree().create_timer(TOTAL_DURATION * MAX_DURATION_MULTIPLIER).timeout.connect(queue_free)

func _spawn_spark() -> void:
	var spark_type := _random_spark_type()
	var spark := MeshInstance3D.new()
	spark.mesh = _make_spark_mesh(SPARK_TEXTURES[spark_type])
	spark.scale = Vector3.ONE * randf_range(1.0, MAX_SPARK_SCALE)
	spark.position = Vector3.ZERO
	spark.rotation_degrees.z = randf_range(0.0, 360.0)
	add_child(spark)

	var material := spark.mesh.material as StandardMaterial3D
	var direction := _random_direction()
	var end_position := direction * TILE_EDGE * float(SPARK_DISTANCE_MULTIPLIERS[spark_type])
	var duration := TOTAL_DURATION \
		* randf_range(MIN_DURATION_MULTIPLIER, MAX_DURATION_MULTIPLIER) \
		* float(SPARK_DURATION_MULTIPLIERS[spark_type])
	var alpha_half_duration := duration * 0.5

	var movement_tween := create_tween()
	movement_tween.set_ease(Tween.EASE_OUT)
	movement_tween.set_trans(MOVEMENT_TRANSITIONS[randi() % MOVEMENT_TRANSITIONS.size()])
	movement_tween.tween_property(spark, "position", end_position, duration)

	var alpha_tween := create_tween()
	alpha_tween.set_ease(Tween.EASE_IN_OUT)
	alpha_tween.set_trans(ALPHA_TRANSITIONS[randi() % ALPHA_TRANSITIONS.size()])
	alpha_tween.tween_method(_set_material_alpha.bind(material), START_ALPHA, PEAK_ALPHA, alpha_half_duration)
	alpha_tween.tween_method(_set_material_alpha.bind(material), PEAK_ALPHA, START_ALPHA, alpha_half_duration)

func _random_direction() -> Vector3:
	var direction := Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	)
	while direction.length_squared() == 0.0:
		direction = Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		)
	return direction.normalized()

func _make_spark_mesh(texture: Texture2D) -> QuadMesh:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = Color(1, 1, 1, START_ALPHA)
	material.albedo_texture = texture
	material.emission_enabled = true
	material.emission = Color.WHITE
	material.emission_texture = texture
	material.emission_energy_multiplier = 1.8

	var mesh := QuadMesh.new()
	mesh.size = SPARK_SIZE
	mesh.material = material
	return mesh

func _random_spark_type() -> int:
	var total_weight := 0
	for weight in SPARK_WEIGHTS:
		total_weight += int(weight)

	var roll := randi() % total_weight
	for i in range(SPARK_WEIGHTS.size()):
		roll -= int(SPARK_WEIGHTS[i])
		if roll < 0:
			return i

	return SPARK_WEIGHTS.size() - 1

func _set_material_alpha(alpha: float, material: StandardMaterial3D) -> void:
	var albedo := material.albedo_color
	albedo.a = alpha
	material.albedo_color = albedo
