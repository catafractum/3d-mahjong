class_name AudioSettingsComponent
extends BaseComponent

@export var settings_menu: GameSettingsMenuComponent


func _ready() -> void:
	settings_menu.sfx_toggled.connect(_set_sfx_enabled)
	settings_menu.music_toggled.connect(_set_music_enabled)
	_sync_menu.call_deferred()


func _sync_menu() -> void:
	settings_menu.set_toggle_states(
		_is_bus_enabled("SFX"),
		_is_bus_enabled("Music")
	)


func _set_sfx_enabled(enabled: bool) -> void:
	var bus := AudioServer.get_bus_index("SFX")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, not enabled)


func _set_music_enabled(enabled: bool) -> void:
	var bus := AudioServer.get_bus_index("Music")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, not enabled)


func _is_bus_enabled(bus_name: StringName) -> bool:
	var bus := AudioServer.get_bus_index(bus_name)
	return bus < 0 or not AudioServer.is_bus_mute(bus)
