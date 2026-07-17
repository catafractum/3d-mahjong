@abstract class_name BaseSaveComponent
extends BaseComponent

signal initialized

var _id: String


func initialize(id: String) -> void:
	_id = id
	initialized.emit()


func _ready() -> void:
	SaveLoadManager.register(self)

func _exit_tree() -> void:
	SaveLoadManager.unregister(self)

static func of_as(node:Node)->BaseSaveComponent:
	return BaseComponent.of(node, BaseSaveComponent) as BaseSaveComponent

@abstract func update_save_data_before_save() -> void
@abstract func delete_from_save_data() -> void