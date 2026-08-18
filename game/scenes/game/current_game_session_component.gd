class_name CurrentGameSessionComponent
extends BaseComponent

signal session_available(session: GameSession)
signal session_missing

var session: GameSession


func _ready() -> void:
	session = GameDB.current_session
	if session == null:
		push_error("CurrentGameSessionComponent: GameDB.current_session is not set.")
		session_missing.emit()
		return

	session.status = GameSession.Status.PLAYING
	session_available.emit(session)


static func of_as(node: Node) -> CurrentGameSessionComponent:
	return BaseComponent.of(node, CurrentGameSessionComponent) as CurrentGameSessionComponent
