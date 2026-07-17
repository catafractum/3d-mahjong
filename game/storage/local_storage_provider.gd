class_name LocalStorageProvider
extends StorageProvider

var _save_path: String = "user://save_data.json"


func save_as_string(data: String) -> void:
	var f = FileAccess.open(_save_path, FileAccess.WRITE)
	f.store_string(data)
	f.close()
	on_saved.emit.call_deferred()
	# prints("Game saved to local storage.", data)


func load_as_string() -> void:
	if FileAccess.file_exists(_save_path):
		var data = FileAccess.get_file_as_string(_save_path)
		# prints("Game loaded from local storage.", data)
		on_loaded.emit.call_deferred(data)
	else:
		# prints("No save data found in local storage.")
		on_loaded.emit.call_deferred("")


func clear_data() -> void:
	if FileAccess.file_exists(_save_path):
		var f = FileAccess.open(_save_path, FileAccess.WRITE)
		f.store_string("")
		f.close()
		# prints("Local save data cleared.")
	else:
		prints("No local save data to clear.")
	on_cleared.emit.call_deferred()
