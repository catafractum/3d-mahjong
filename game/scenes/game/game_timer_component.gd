class_name GameTimerComponent
extends BaseComponent

signal timer_finished

var session: GameSession
var paused := true
var finished := false


func _ready() -> void:
	_initialize.call_deferred()


func _initialize() -> void:
	var session_component := CurrentGameSessionComponent.of_as(self)
	if session_component == null or session_component.session == null:
		return
	session = session_component.session
	paused = false


func _process(delta: float) -> void:
	if paused or finished or session == null or session.time_limit_seconds <= 0.0:
		return
	session.elapsed_seconds = minf(
		session.elapsed_seconds + delta,
		session.time_limit_seconds
	)
	if session.elapsed_seconds >= session.time_limit_seconds:
		finished = true
		paused = true
		timer_finished.emit()


func pause() -> void:
	paused = true


func resume() -> void:
	if not finished:
		paused = false


func reset() -> void:
	if session == null:
		return
	session.elapsed_seconds = 0.0
	finished = false
	paused = false


static func of_as(node: Node) -> GameTimerComponent:
	return BaseComponent.of(node, GameTimerComponent) as GameTimerComponent
