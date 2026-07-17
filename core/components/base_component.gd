@abstract class_name BaseComponent
extends Node

@export var owner_node_path: NodePath

@export var enabled: bool = true:
	set(value):
		enabled = value
		_apply_enabled_state(enabled)
	get:
		return enabled

var _owner_node: Node = null


func get_owner_node() -> Node:
	return _owner_node


func _on_enable() -> void:
	pass


func _on_disable() -> void:
	pass


func _apply_enabled_state(is_enabled: bool) -> void:
	if not is_inside_tree() or Engine.is_editor_hint():
		return

	process_mode = Node.PROCESS_MODE_INHERIT if is_enabled else Node.PROCESS_MODE_DISABLED


func _register() -> void:
	if not owner_node_path.is_empty():
		_owner_node = get_node_or_null(owner_node_path)

	if _owner_node == null:
		_owner_node = owner

	if _owner_node == null:
		_owner_node = get_parent()

	if _owner_node == null:
		push_error("BaseComponent: Could not find owner node for component: ", self)
		return

	var current_script: Script = get_script()
	while current_script and current_script.get_global_name() != "BaseComponent":
		var type_name = current_script.get_global_name()
		if type_name != "":
			if not _owner_node.has_meta(type_name):
				_owner_node.set_meta(type_name, [self])
			elif self not in _owner_node.get_meta(type_name):
				_owner_node.get_meta(type_name).append(self)
			# prints("Registered component of type ", type_name, " to node ", _owner_node.name)
		current_script = current_script.get_base_script()


func _unregister() -> void:
	if _owner_node == null:
		return

	var current_script: Script = get_script()
	while current_script and current_script.get_global_name() != "BaseComponent":
		var type_name = current_script.get_global_name()
		if type_name != "" and _owner_node.has_meta(type_name):
			var components: Array = _owner_node.get_meta(type_name)
			components.erase(self)
			if components.is_empty():
				_owner_node.remove_meta(type_name)
			# prints("Unregistered component of type ", type_name, " from node ", _owner_node.name)
		current_script = current_script.get_base_script()


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		_register()
		_apply_enabled_state(enabled)
	elif what == NOTIFICATION_PREDELETE:
		_unregister()


static func of(node: Node, component_type: Script) -> BaseComponent:
	if node == null or component_type == null:
		return null

	var type_name = component_type.get_global_name()
	var current_search_target = node

	while current_search_target != null:
		if current_search_target.has_meta(type_name):
			var components: Array = current_search_target.get_meta(type_name)
			if not components.is_empty():
				return components[0]

		current_search_target = current_search_target.get_parent()

	return null
