extends Node3D

const SPARK_TEXTURE = preload("res://assets/images/spark.png")
const PARTICLE_COUNT := 36
const TILE_HALF_EDGE := 0.42
const TILE_EDGE := TILE_HALF_EDGE * 2.0
const SPARK_SIZE := Vector2(0.16, 0.2)
const MAX_SPARK_SCALE := 2.0
const START_ALPHA := 0.0
const PEAK_ALPHA := 1.0
const EXPAND_DURATION := 0.4
const FADE_OUT_DURATION := 0.2
const TOTAL_DURATION := EXPAND_DURATION + FADE_OUT_DURATION
const ALPHA_HALF_DURATION := TOTAL_DURATION * 0.5

func play_effect() -> void:
	for i in range(PARTICLE_COUNT):
		_spawn_spark()

	get_tree().create_timer(TOTAL_DURATION).timeout.connect(queue_free)

func _spawn_spark() -> void:
	var spark := MeshInstance3D.new()
	spark.mesh = _make_spark_mesh()
	spark.scale = Vector3.ONE * randf_range(1.0, MAX_SPARK_SCALE)
	spark.position = Vector3.ZERO
	spark.rotation_degrees.z = randf_range(0.0, 360.0)
	add_child(spark)

	var material := spark.mesh.material as StandardMaterial3D
	var direction := _random_direction()
	var end_position := direction * TILE_EDGE

	var movement_tween := create_tween()
	movement_tween.set_ease(Tween.EASE_OUT)
	movement_tween.set_trans(Tween.TRANS_CUBIC)
	movement_tween.tween_property(spark, "position", end_position, TOTAL_DURATION)

	var alpha_tween := create_tween()
	alpha_tween.set_ease(Tween.EASE_IN_OUT)
	alpha_tween.set_trans(Tween.TRANS_SINE)
	alpha_tween.tween_method(_set_material_alpha.bind(material), START_ALPHA, PEAK_ALPHA, ALPHA_HALF_DURATION)
	alpha_tween.tween_method(_set_material_alpha.bind(material), PEAK_ALPHA, START_ALPHA, ALPHA_HALF_DURATION)

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

func _make_spark_mesh() -> QuadMesh:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = Color(1, 1, 1, START_ALPHA)
	material.albedo_texture = SPARK_TEXTURE
	material.emission_enabled = true
	material.emission = Color.WHITE
	material.emission_texture = SPARK_TEXTURE
	material.emission_energy_multiplier = 1.8

	var mesh := QuadMesh.new()
	mesh.size = SPARK_SIZE
	mesh.material = material
	return mesh

func _set_material_alpha(alpha: float, material: StandardMaterial3D) -> void:
	var albedo := material.albedo_color
	albedo.a = alpha
	material.albedo_color = albedo
