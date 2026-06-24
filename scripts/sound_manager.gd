extends Node

@export_file("*") var music: String
@export_file("*") var click_sfx: String
@export_file("*") var move_correct_sfx: String
@export_file("*") var move_wrong_sfx: String
@export_file("*") var tile_click: String
@export_file("*") var popup: String

# Tracks metadata for SFX (pitch/debounce)
var _sound_data: Dictionary = {}

# Tracks active music players: { "res://path.mp3": AudioStreamPlayer }
var _active_music_players: Dictionary = {}

# --- MUSIC LOGIC ---


func play_music(path: String, volume: float = 1, fade_in: float = 1.0) -> AudioStreamPlayer:
	# If this specific track is already playing, just return it (prevents double-play)
	if _active_music_players.has(path):
		return _active_music_players[path]

	var stream = load(path)
	var new_player = AudioStreamPlayer.new()
	add_child(new_player)

	_active_music_players[path] = new_player

	new_player.stream = stream
	new_player.bus = "Music"
	new_player.volume_db = -80.0
	new_player.play()

	var tween = create_tween()
	tween.tween_property(new_player, "volume_db", linear_to_db(volume), fade_in)

	return new_player


## Stop a specific music track by its resource path
func stop_music(path: String, fade_out: float = 1.0):
	if _active_music_players.has(path):
		var player = _active_music_players[path]
		_active_music_players.erase(path)  # Remove from tracking immediately

		var tween = create_tween()
		tween.tween_property(player, "volume_db", -80.0, fade_out)
		tween.tween_callback(player.queue_free)


## Fades out and kills every music track currently tracked
func stop_all_music(fade_out: float = 1.0):
	for path in _active_music_players.keys():
		stop_music(path, fade_out)


# --- SFX LOGIC ---


func play_sfx(
	path: String,
	volume: float = 1,
	debounce: float = 0.0,
	pitch_step: float = 0.0,
	pitch_reset: float = 1.0,
	max_pitch: float = 2.0
) -> AudioStreamPlayer:
	if debounce > 0:
		if _sound_data.has(path) and _sound_data[path].get("debounce_active", false):
			return null

	var current_pitch = 1.0
	if _sound_data.has(path):
		var data = _sound_data[path]
		if data.timer and data.timer.time_left > 0:
			current_pitch = min(data.pitch + pitch_step, max_pitch)

	_sound_data[path] = {
		"pitch": current_pitch,
		"timer": get_tree().create_timer(pitch_reset),
		"debounce_active": true if debounce > 0 else false
	}

	if debounce > 0:
		get_tree().create_timer(debounce).timeout.connect(_disable_debounce.bind(path))

	var player = AudioStreamPlayer.new()
	add_child(player)
	player.stream = load(path)
	player.volume_db = linear_to_db(volume)
	player.pitch_scale = current_pitch
	player.bus = "SFX"
	player.finished.connect(player.queue_free)
	player.play()

	return player


func _disable_debounce(path: String):
	if _sound_data.has(path):
		_sound_data[path]["debounce_active"] = false


# --- HELPERS ---


func play_main_music() -> void:
	play_music(music)


func play_click_sfx() -> void:
	play_sfx(click_sfx)


func play_move_correct_sfx() -> void:
	play_sfx(move_correct_sfx)


func play_move_wrong_sfx() -> void:
	play_sfx(move_wrong_sfx)


func play_tile_click_sfx() -> void:
	play_sfx(tile_click)


func play_popup_sfx() -> void:
	play_sfx(popup)
