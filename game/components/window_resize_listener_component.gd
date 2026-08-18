class_name WindowResizeListenerComponent
extends BaseComponent

signal on_size_changed(is_portrait: bool)

@export var landscape: Control
@export var portrait: Control


func _ready() -> void:
	_add_resize_listener.call_deferred()
	_resized.call_deferred()


func _exit_tree() -> void:
	if get_viewport().size_changed.is_connected(_resized):
		get_viewport().size_changed.disconnect(_resized)


func _add_resize_listener() -> void:
	if not get_viewport().size_changed.is_connected(_resized):
		get_viewport().size_changed.connect(_resized)


func _resized() -> void:
	var screen_size := DisplayServer.window_get_size()
	if screen_size.x > screen_size.y:
		_set_landscape()
	else:
		_set_portrait()


func _set_portrait() -> void:
	if portrait:
		portrait.show()
	if landscape:
		landscape.hide()
	on_size_changed.emit(true)


func _set_landscape() -> void:
	if portrait:
		portrait.hide()
	if landscape:
		landscape.show()
	on_size_changed.emit(false)


static func of_as(node: Node) -> WindowResizeListenerComponent:
	return BaseComponent.of(node, WindowResizeListenerComponent) as WindowResizeListenerComponent
