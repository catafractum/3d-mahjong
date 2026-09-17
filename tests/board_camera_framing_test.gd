extends Node

var failures := 0

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(900, 600)
	add_child(viewport)
	var board := Node3D.new()
	viewport.add_child(board)
	board.position = Vector3(1.2, -0.25, -0.7)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(7, 3.8, 7)
	camera.look_at(Vector3.ZERO)
	var framing := BoardCameraFramingComponent.new()
	framing.camera = camera
	framing.board = board
	viewport.add_child(framing)
	var tiles: Array[Node3D] = []
	for point in [Vector3(-3, 0, 1), Vector3(1, 4, -2), Vector3(2, 1, 3)]:
		var tile := Node3D.new()
		board.add_child(tile)
		tile.position = point
		var mesh := MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		tile.add_child(mesh)
		mesh.rotation_degrees = Vector3(0, 25, 0)
		tiles.append(tile)
	for dimensions in [Vector2i(900, 600), Vector2i(400, 900)]:
		viewport.size = dimensions
		for scale_value in [1.0, 0.775]:
			board.scale = Vector3.ONE * scale_value
			for aspect_mode in [Camera3D.KEEP_HEIGHT, Camera3D.KEEP_WIDTH]:
				camera.keep_aspect = aspect_mode
				board.rotation_degrees.y = -10
				var target := framing._calculate_target(tiles)
				camera.global_position = target.position
				camera.size = target.size
				var aspect: float = float(dimensions.x) / dimensions.y
				var half_span := Vector2(camera.size * aspect, camera.size) * 0.5
				if aspect_mode == Camera3D.KEEP_WIDTH:
					half_span = Vector2(camera.size, camera.size / aspect) * 0.5
				for angle in range(360):
					board.rotation_degrees.y = angle
					for tile in tiles:
						var mesh := tile.get_child(0) as MeshInstance3D
						for index in 8:
							var view_point := camera.global_transform.affine_inverse() * (mesh.global_transform * mesh.get_aabb().get_endpoint(index))
							_check(absf(view_point.x) <= half_span.x - framing.frame_padding + 0.001 and absf(view_point.y) <= half_span.y - framing.frame_padding + 0.001, "Tile corner escaped rotation framing")
					if angle % 45 == 0:
						var rotated_target := framing._calculate_target(tiles)
						_check(absf(rotated_target.size - camera.size) < 0.001, "Framing size depends on rotation")
						_check(camera.global_position.distance_to(rotated_target.position) < 0.001, "Framing position depends on rotation")
				_check(framing._calculate_target(tiles, camera.size + 2.0).size >= camera.size + 2.0, "Minimum camera size was lost")
	print("Full-rotation camera framing: ", "PASS" if failures == 0 else "FAIL")
	get_tree().quit(0 if failures == 0 else 1)
