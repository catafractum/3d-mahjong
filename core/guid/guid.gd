extends Node

var _counter: int = 0


func generate_guid(prefix: String = "obj") -> String:
	_counter += 1
	var timestamp = Time.get_unix_time_from_system()
	var random_val = randi() % 1000
	return "%s_%x_$x_%d" % [prefix, int(timestamp), random_val, _counter]
