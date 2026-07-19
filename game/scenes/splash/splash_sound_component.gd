class_name SplashSoundComponent
extends BaseComponent

@export_file("*.mp3", "*.wav", "*.ogg") var music_path: String


func _ready() -> void:
	SoundManager.play_music(music_path)
