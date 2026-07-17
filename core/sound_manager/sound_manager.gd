extends Node

# Tracks metadata for SFX (pitch/debounce)
var _sound_data: Dictionary = {}

# Tracks when an SFX path/group can be played again.
var _sfx_debounce_until: Dictionary = {}

# Tracks active music players: { "res://path.mp3": AudioStreamPlayer }
var _active_music_players: Dictionary = {}


func _ready() -> void:
	set_process_mode(Node.PROCESS_MODE_ALWAYS)


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
		var now: int = Time.get_ticks_msec()
		var next_play_time: int = _sfx_debounce_until.get(path, 0)
		if now < next_play_time:
			return null
		_sfx_debounce_until[path] = now + int(debounce * 1000.0)

	var current_pitch = 1.0
	if _sound_data.has(path):
		var data = _sound_data[path]
		if data.timer and data.timer.time_left > 0:
			current_pitch = min(data.pitch + pitch_step, max_pitch)

	_sound_data[path] = {"pitch": current_pitch, "timer": get_tree().create_timer(pitch_reset)}

	var player = AudioStreamPlayer.new()
	add_child(player)
	player.stream = load(path)
	player.volume_db = linear_to_db(volume)
	player.pitch_scale = current_pitch
	player.bus = "SFX"
	player.finished.connect(player.queue_free)
	player.play()

	return player
