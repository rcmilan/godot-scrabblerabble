class_name InputRouter
extends RefCounted

## Routes input actions to handler callables via dictionary lookup (CC 1).

var _action_map: Dictionary = {}


func register(action: StringName, handler: Callable) -> void:
	_action_map[action] = handler


## Routes an input event. Returns true if handled.
func route(event: InputEvent) -> bool:
	for action in _action_map:
		if event.is_action_pressed(action):
			_action_map[action].call()
			return true
	return false
