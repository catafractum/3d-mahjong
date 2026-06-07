extends Node3D

const LEVEL_EDITOR_SCENE := "res://scenes/level_editor.tscn"
const DIFFICULTIES := ["easy", "medium", "hard"]

@export var level_id := 20

@onready var camera: Camera3D = $Camera3D
@onready var board_container: Node3D = $BoardContainer
@onready var board_manager: Node = $BoardManager
@onready var gui: Control = $GUI/Control

func _enter_tree() -> void:
	level_id = GameState.selected_level_id

func _ready() -> void:
	_build_editor_controls()
	board_container.tile_selected.connect(board_manager.on_tile_selected)
	board_container.board_ready.connect(board_manager.on_board_ready)
	board_container.layer_rotated.connect(func(axis, value, angle, visual_offset):
		board_manager.on_layer_rotated(axis, value, angle, board_container.spacing, visual_offset)
	)
	$GUI/Control/RightArrowBtn.pressed.connect(_on_rotate_right)
	$GUI/Control/LeftArrowBtn.pressed.connect(_on_rotate_left)
	$GUI/Control/ShuffleBtn.pressed.connect(_on_shuffle)
	gui.home_pressed.connect(_on_home)
	gui.reset_pressed.connect(_on_reset)
	gui.sfx_toggled.connect(_on_sfx_toggled)
	gui.soundtrack_toggled.connect(_on_soundtrack_toggled)

func _build_editor_controls() -> void:
	var editor_button := Button.new()
	editor_button.text = "Editor"
	editor_button.custom_minimum_size = Vector2(128, 56)
	editor_button.anchors_preset = Control.PRESET_TOP_LEFT
	editor_button.offset_left = 24.0
	editor_button.offset_top = 24.0
	editor_button.offset_right = 152.0
	editor_button.offset_bottom = 80.0
	editor_button.pressed.connect(_on_editor)
	gui.add_child(editor_button)

	var level_label := Label.new()
	level_label.text = _get_level_label()
	level_label.anchors_preset = Control.PRESET_TOP_LEFT
	level_label.offset_left = 168.0
	level_label.offset_top = 32.0
	level_label.offset_right = 440.0
	level_label.offset_bottom = 72.0
	gui.add_child(level_label)

func _get_level_label() -> String:
	var difficulty_index := clampi(int(level_id / 10), 0, DIFFICULTIES.size() - 1)
	var order := level_id % 10 + 1
	return "%02d  %s  id %d" % [order, DIFFICULTIES[difficulty_index], level_id]

func _on_rotate_right() -> void:
	board_container.rotate_board(true)

func _on_rotate_left() -> void:
	board_container.rotate_board(false)

func _on_shuffle() -> void:
	board_container.shuffle()

func _on_home() -> void:
	get_tree().change_scene_to_file("res://scenes/splash_scene.tscn")

func _on_editor() -> void:
	get_tree().change_scene_to_file(LEVEL_EDITOR_SCENE)

func _on_reset() -> void:
	get_tree().reload_current_scene()

func _on_sfx_toggled(is_on: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not is_on)

func _on_soundtrack_toggled(is_on: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not is_on)
