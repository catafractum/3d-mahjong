class_name PortalStorageProvider
extends StorageProvider


func save_as_string(data: String) -> void:
	# PortalSDK.shared().data_set_item("save_data", data)
	on_saved.emit.call_deferred()


func load_as_string() -> void:
	# PortalSDK.shared().data_get_item(
	# "save_data", func(result: String): on_loaded.emit.call_deferred(result)
	# )
	on_loaded.emit.call_deferred("")


func clear_data() -> void:
	# PortalSDK.shared().data_remove_item("save_data")
	on_cleared.emit.call_deferred()
