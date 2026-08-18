class_name MusicPlayerComponent
extends BaseComponent

@export_file("*") var music_path: String
@export var fade_in_time: float = 3.0
@export var fade_out_time: float = 3.0
@export var stop_this_on_exit: bool = true
@export_file("*") var stop_other_musics: Array[String] = []


func _ready() -> void:
	for path in stop_other_musics:
		SoundManager.stop_music(path, fade_out_time)
	SoundManager.play_music(music_path, 1, fade_in_time)


func _exit_tree() -> void:
	if stop_this_on_exit:
		SoundManager.stop_music(music_path, fade_out_time)
