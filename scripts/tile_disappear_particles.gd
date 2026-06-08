extends Node3D

const SPARK_TEXTURE = preload("res://assets/images/spark.png")
const PARTICLE_COUNT := 36
const TILE_EXTENTS := Vector3(0.42, 0.42, 0.42)
const SPARK_SIZE := Vector2(0.16, 0.2)
const START_ALPHA := 0.0
const PEAK_ALPHA := 1.0
const FADE_IN_DURATION := 0.16
const FADE_OUT_DURATION := 0.24

func play_effect() -> void:
	for i in range(PARTICLE_COUNT):
		_spawn_spark()

	var lifetime := FADE_IN_DURATION + FADE_OUT_DURATION
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _spawn_spark() -> void:
	var spark := MeshInstance3D.new()
	spark.mesh = _make_spark_mesh()
	spark.position = Vector3.ZERO
	spark.rotation_degrees.z = randf_range(0.0, 360.0)
	add_child(spark)

	var material := spark.mesh.material as StandardMaterial3D
	var target_position := Vector3(
		randf_range(-TILE_EXTENTS.x, TILE_EXTENTS.x),
		randf_range(-TILE_EXTENTS.y, TILE_EXTENTS.y),
		randf_range(-TILE_EXTENTS.z, TILE_EXTENTS.z)
	)

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(spark, "position", target_position, FADE_IN_DURATION)
	tween.parallel().tween_method(_set_material_alpha.bind(material), START_ALPHA, PEAK_ALPHA, FADE_IN_DURATION)
	tween.tween_property(spark, "position", Vector3.ZERO, FADE_OUT_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_method(_set_material_alpha.bind(material), PEAK_ALPHA, START_ALPHA, FADE_OUT_DURATION)

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
