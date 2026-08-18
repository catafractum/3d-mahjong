extends Node

signal saved
signal loaded
signal cleared

var storage_provider: StorageProvider

var data: SavedataDTO:
	get:
		return _data

var _data: SavedataDTO = SavedataDTO.new()
var _save_components: Array[BaseSaveComponent] = []


func _ready() -> void:
	storage_provider = LocalStorageProvider.new()


func save_game() -> void:
	for save_component in _save_components:
		save_component.update_save_data_before_save()
	var json_string = JSON.stringify(_data.to_dict())
	storage_provider.on_saved.connect(_on_saved)
	storage_provider.save_as_string(json_string)


func _on_saved():
	storage_provider.on_saved.disconnect(_on_saved)
	saved.emit()


func load_game() -> void:
	await get_tree().process_frame
	storage_provider.on_loaded.connect(_set_from_loaded_string)
	storage_provider.load_as_string()


func clear_save_data() -> void:
	storage_provider.on_cleared.connect(_on_cleared)
	storage_provider.clear_data()


func _on_cleared():
	storage_provider.on_cleared.disconnect(_on_cleared)
	cleared.emit()


func _set_from_loaded_string(json_string: String) -> void:
	storage_provider.on_loaded.disconnect(_set_from_loaded_string)
	if json_string == "":
		_data = SavedataDTO.new()
	else:
		_data.set_from_json(json_string)

	loaded.emit()


func register(component: BaseSaveComponent) -> void:
	if not _save_components.has(component):
		_save_components.append(component)


func unregister(component: BaseSaveComponent) -> void:
	if _save_components.has(component):
		_save_components.erase(component)
