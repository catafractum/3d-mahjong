class_name SceneSwitcherComponent
extends BaseComponent

@export var scene_parent_path: NodePath

var _scene_parent: Node
var _current_scene: Node


func _ready() -> void:
	_scene_parent = get_node(scene_parent_path)


func switch_scene(path: String) -> void:
	_remove_current_scene()
	var new_scene = load(path).instantiate()
	_scene_parent.add_child.call_deferred(new_scene)
	_current_scene = new_scene


func switch_scene_async(path: String) -> bool:
	var packed_scene := load(path) as PackedScene
	if packed_scene == null:
		push_error("SceneSwitcherComponent: Loaded resource is not a PackedScene: ", path)
		return false

	_remove_current_scene()
	var new_scene := packed_scene.instantiate()
	_scene_parent.add_child.call_deferred(new_scene)
	_current_scene = new_scene
	return true


func _remove_current_scene() -> void:
	if _current_scene and _current_scene.is_inside_tree():
		_current_scene.queue_free()
	_current_scene = null


static func of_as(node: Node) -> SceneSwitcherComponent:
	return BaseComponent.of(node, SceneSwitcherComponent) as SceneSwitcherComponent
