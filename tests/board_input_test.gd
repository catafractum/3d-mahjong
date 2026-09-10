extends Node

class InputProbe extends BoardInteractionComponent:
	var target: Node3D
	var presses: Array[Node3D] = []
	var rotations: Array[bool] = []

	func _ready() -> void:
		pass

	func _process(_delta: float) -> void:
		pass

	func _raycast_tile(_position: Vector2) -> Dictionary:
		return {"collider": target} if target != null else {}

	func _find_tile(node: Node) -> Node3D:
		return node as Node3D

	func _on_tile_pressed(tile: Node3D, _normal: Vector3) -> void:
		presses.append(tile)

	func _rotate_board(right: bool) -> void:
		rotations.append(right)

var failures := 0

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var probe := InputProbe.new()
	add_child(probe)
	var tile := Node3D.new()
	add_child(tile)
	probe.target = tile
	# Fast clicks with ordinary hand drift must retain the down target.
	for index in 100:
		probe._begin_pointer(Vector2.ZERO)
		probe.target = null
		probe._end_pointer(Vector2(30, 5))
		probe.target = tile
	_check(probe.presses.size() == 100, "Rapid drifting clicks were dropped")
	probe._begin_pointer(Vector2.ZERO)
	probe._end_pointer(Vector2(80, 0))
	probe._begin_pointer(Vector2.ZERO)
	probe._end_pointer(Vector2(-100, 10))
	_check(probe.rotations == [true, false], "Swipes did not rotate correctly")
	_check(probe.presses.size() == 100, "Swipe selected a tile")
	probe._begin_pointer(Vector2.ZERO)
	probe._end_pointer(Vector2(0, 100))
	_check(probe.presses.size() == 100, "Long vertical drag selected a tile")
	probe._begin_pointer(Vector2.ZERO, 0)
	probe._begin_pointer(Vector2(200, 0), 1)
	probe._end_pointer(Vector2(200, 0), 1)
	_check(probe._tracking_pointer, "Second finger ended the first gesture")
	probe._end_pointer(Vector2(20, 0), 0)
	_check(probe.presses.size() == 101, "First finger tap was lost")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	probe._unhandled_input(touch)
	var mouse := InputEventMouseButton.new()
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	probe._unhandled_input(mouse)
	mouse.pressed = false
	probe._unhandled_input(mouse)
	touch.pressed = false
	probe._unhandled_input(touch)
	_check(probe.presses.size() == 102, "Emulated mouse duplicated or canceled touch")
	touch.pressed = true
	probe._unhandled_input(touch)
	touch.pressed = false
	touch.canceled = true
	probe._unhandled_input(touch)
	_check(probe.presses.size() == 102 and not probe._tracking_pointer, "Canceled touch selected a tile")
	probe._begin_pointer(Vector2.ZERO)
	probe._clear_state()
	probe._end_pointer(Vector2.ZERO)
	_check(probe.presses.size() == 102, "Board reset retained a pending tap")
	probe._begin_pointer(Vector2.ZERO)
	probe.begin_shuffle()
	probe._end_pointer(Vector2.ZERO)
	_check(probe.presses.size() == 102, "Shuffle retained a pending tap")
	probe._input_locked = false
	probe.target = Node3D.new()
	probe._begin_pointer(Vector2.ZERO)
	probe.target.free()
	probe.target = null
	probe._end_pointer(Vector2.ZERO)
	_check(probe.presses.size() == 102, "Freed tile was selected")
	print("Board input regression checks: ", "PASS" if failures == 0 else "FAIL")
	get_tree().quit(0 if failures == 0 else 1)
