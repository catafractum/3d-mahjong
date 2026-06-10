extends Control

signal play_pressed

@onready var play_button: TextureButton = %PlayButton

func _ready() -> void:
	play_button.pressed.connect(_on_play_button_pressed)
	play_button.mouse_entered.connect(_on_play_button_mouse_entered)
	play_button.mouse_exited.connect(_on_play_button_mouse_exited)

func _on_play_button_pressed() -> void:
	play_pressed.emit()

func _on_play_button_mouse_entered() -> void:
	play_button.scale = Vector2.ONE * 1.025

func _on_play_button_mouse_exited() -> void:
	play_button.scale = Vector2.ONE
