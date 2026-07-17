@abstract class_name StorageProvider
extends RefCounted


@warning_ignore_start("unused_signal")
signal on_saved
signal on_loaded(data:String)
signal on_cleared

@abstract func save_as_string(data:String) -> void
@abstract func load_as_string() -> void
@abstract func clear_data() -> void