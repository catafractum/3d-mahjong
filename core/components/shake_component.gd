class_name ShakeComponent
extends BaseComponent


func shake(magnitude = 10.0, duration = 0.2) -> void:
	var original_offset: Vector2 = _owner_node.offset
	var elapsed_time: float = 0.0
	while elapsed_time < duration:
		var random_offset: Vector2 = Vector2(
			randf_range(-magnitude, magnitude), randf_range(-magnitude, magnitude)
		)
		_owner_node.offset = original_offset + random_offset
		await get_tree().create_timer(0.01).timeout
		elapsed_time += 0.01
	_owner_node.offset = original_offset


static func of_as(node: Node) -> ShakeComponent:
	return BaseComponent.of(node, ShakeComponent) as ShakeComponent
