class_name GameSoundComponent
extends BaseComponent

@export var game_ui: GameUIComponent
@export var settings_menu: GameSettingsMenuComponent
@export var next_level_menu: NextLevelMenuComponent
@export var game_over_menu: GameOverMenuComponent
@export var challenge_complete_menu: ChallengeCompleteMenuComponent


func _ready() -> void:
	var matching := TileMatchingComponent.of_as(self)
	if matching != null:
		matching.selection_changed.connect(_on_selection_changed)
		matching.blocked_tile_pressed.connect(func(_tile, _normal): Soundmanager.play_move_wrong_sfx())
		matching.match_succeeded.connect(func(_first, _second): Soundmanager.play_move_correct_sfx())

	game_ui.rotate_requested.connect(func(_right): Soundmanager.play_click_sfx())
	game_ui.shuffle_requested.connect(Soundmanager.play_click_sfx)
	settings_menu.reset_requested.connect(Soundmanager.play_click_sfx)
	settings_menu.home_requested.connect(Soundmanager.play_click_sfx)
	settings_menu.settings_pressed.connect(Soundmanager.play_click_sfx)
	settings_menu.sfx_toggled.connect(func(_enabled): Soundmanager.play_click_sfx())
	settings_menu.music_toggled.connect(func(_enabled): Soundmanager.play_click_sfx())
	next_level_menu.play_requested.connect(Soundmanager.play_click_sfx)
	game_over_menu.home_requested.connect(Soundmanager.play_click_sfx)
	game_over_menu.replay_requested.connect(Soundmanager.play_click_sfx)
	challenge_complete_menu.home_requested.connect(Soundmanager.play_click_sfx)
	challenge_complete_menu.replay_requested.connect(Soundmanager.play_click_sfx)


func _on_selection_changed(previous: Node3D, selected: Node3D) -> void:
	if selected != null and selected != previous:
		Soundmanager.play_tile_click_sfx()


func play_popup() -> void:
	Soundmanager.play_popup_sfx()


static func of_as(node: Node) -> GameSoundComponent:
	return BaseComponent.of(node, GameSoundComponent) as GameSoundComponent
