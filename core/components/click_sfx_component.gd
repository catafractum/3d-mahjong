class_name ClickSFXComponent
extends BaseComponent

@export_file("*") var click_sfx_path: String

var _control: Control


func _ready() -> void:
	_initialize.call_deferred()


func _initialize() -> void:
	_control = _owner_node as Control
	if _control == null:
		push_error("ButtonHoverEffectComponent: Owner node must be a Control.")
		return
	_control.gui_input.connect(_on_gui_input)


func _exit_tree() -> void:
	_control.gui_input.disconnect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		SoundManager.play_sfx(click_sfx_path)
