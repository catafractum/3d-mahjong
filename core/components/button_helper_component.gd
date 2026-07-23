class_name ButtonHelperComponent
extends BaseComponent

@export_file("*.mp3", "*.wav", "*.ogg") var click_sfx_path: String
@export var hover_scale_multiplier := 1.025

var _button: BaseButton
var _original_scale := Vector2.ONE


func _ready() -> void:
	_initialize.call_deferred()


func _initialize() -> void:
	_button = get_owner_node() as BaseButton
	if _button == null:
		push_error("ButtonHelperComponent: Owner node must be a BaseButton.")
		return
	_original_scale = _button.scale
	_button.mouse_entered.connect(_on_mouse_entered)
	_button.mouse_exited.connect(_on_mouse_exited)
	_button.button_down.connect(_on_pressed)


func _exit_tree() -> void:
	if not is_instance_valid(_button):
		return
	if _button.mouse_entered.is_connected(_on_mouse_entered):
		_button.mouse_entered.disconnect(_on_mouse_entered)
	if _button.mouse_exited.is_connected(_on_mouse_exited):
		_button.mouse_exited.disconnect(_on_mouse_exited)
	if _button.button_down.is_connected(_on_pressed):
		_button.button_down.disconnect(_on_pressed)


func _on_mouse_entered() -> void:
	_button.scale = _original_scale * hover_scale_multiplier


func _on_mouse_exited() -> void:
	_button.scale = _original_scale


func _on_pressed() -> void:
	if not click_sfx_path.is_empty():
		SoundManager.play_sfx(click_sfx_path)


func set_base_scale(value: Vector2) -> void:
	_original_scale = value
	if is_instance_valid(_button):
		_button.scale = _original_scale * hover_scale_multiplier if _button.is_hovered() else _original_scale


static func of_as(node: Node) -> ButtonHelperComponent:
	return BaseComponent.of(node, ButtonHelperComponent) as ButtonHelperComponent
