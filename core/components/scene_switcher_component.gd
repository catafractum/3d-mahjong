class_name SceneSwitcherComponent
extends BaseComponent

@export var scene_parent_path: NodePath
@export var transition_animation_player_path: NodePath

var _scene_parent: Node
var _current_scene: Node
var _transition_animation_player: AnimationPlayer


func _ready() -> void:
	_scene_parent = get_node(scene_parent_path)
	_transition_animation_player = get_node(transition_animation_player_path)


func switch_scene(path: String) -> void:
	_remove_current_scene()
	_transition_animation_player.play("cover")
	await _transition_animation_player.animation_finished
	var new_scene = load(path).instantiate()
	_scene_parent.add_child.call_deferred(new_scene)
	_current_scene = new_scene
	_transition_animation_player.play("reveal")
	await _transition_animation_player.animation_finished
	_transition_animation_player.play("RESET")


func _remove_current_scene() -> void:
	if _current_scene and _current_scene.is_inside_tree():
		_current_scene.queue_free()
	_current_scene = null


static func of_as(node: Node) -> SceneSwitcherComponent:
	return BaseComponent.of(node, SceneSwitcherComponent) as SceneSwitcherComponent
