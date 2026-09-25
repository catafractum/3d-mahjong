class_name PreviousDaysPopupComponent
extends BaseComponent

@export var popup: Control
@export var panel: Control
@export var shadow: Control
@export var rows_container: VBoxContainer
@export var day_row_scene: PackedScene
@export var close_button: BaseButton

var _rows: Array[DayRowComponent] = []
var _today_key := ""


func _ready() -> void:
	close_button.pressed.connect(hide_menu)
	DailyChallengeService.completion_changed.connect(_on_completion_changed)
	get_viewport().size_changed.connect(_fit_popup)
	for index in 6:
		var row := day_row_scene.instantiate()
		rows_container.add_child(row)
		var component := DayRowComponent.of_as(row)
		component.play_requested.connect(_play_day)
		_rows.append(component)
	# Keep keyboard navigation within the modal.
	var buttons: Array[BaseButton] = []
	for row in _rows:
		buttons.append(row.play_button)
	buttons.append(close_button)
	for index in buttons.size():
		var button := buttons[index]
		button.focus_next = button.get_path_to(buttons[(index + 1) % buttons.size()])
		button.focus_previous = button.get_path_to(buttons[posmod(index - 1, buttons.size())])
		button.focus_neighbor_bottom = button.focus_next
		button.focus_neighbor_top = button.focus_previous
		button.focus_neighbor_left = NodePath(".")
		button.focus_neighbor_right = NodePath(".")
	refresh()
	_fit_popup.call_deferred()
	popup.hide()


func _process(_delta: float) -> void:
	if popup.visible and _today_key != DailyChallengeService.get_today_key():
		refresh()


func _unhandled_input(event: InputEvent) -> void:
	if popup.visible and event.is_action_pressed("ui_cancel"):
		hide_menu()
		get_viewport().set_input_as_handled()


func show_menu() -> void:
	refresh()
	popup.show()
	# GUI input order follows sibling order, independently of z_index.
	popup.move_to_front()
	_fit_popup()
	close_button.grab_focus()


func hide_menu() -> void:
	popup.hide()


func refresh() -> void:
	_today_key = DailyChallengeService.get_today_key()
	var dates := DailyChallengeService.get_previous_date_keys()
	for index in _rows.size():
		_rows[index].configure(dates[index])


func _play_day(date_key: String) -> void:
	if date_key not in DailyChallengeService.get_previous_date_keys():
		refresh()
		return
	var launcher := SplashChallengeLauncherComponent.of_as(self)
	if launcher != null:
		launcher.start_challenge(date_key)


func _on_completion_changed(_date_key: String) -> void:
	refresh()


func _fit_popup() -> void:
	var available := get_viewport().get_visible_rect().size - Vector2(48, 48)
	var factor := minf(1.5, minf(available.x / 836.0, available.y / 1120.0))
	panel.scale = Vector2.ONE * maxf(factor, 0.1)
	shadow.scale = panel.scale


static func of_as(node: Node) -> PreviousDaysPopupComponent:
	return BaseComponent.of(node, PreviousDaysPopupComponent) as PreviousDaysPopupComponent
