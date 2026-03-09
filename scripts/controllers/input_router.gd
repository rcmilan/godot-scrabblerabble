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
			print("[InputRouter] Routed: %s (event: %s)" % [action, event.as_text()])
			_action_map[action].call()
			return true
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var checks := []
		for action in _action_map:
			checks.append("%s=%s" % [action, event.is_action(action)])
		print("[InputRouter] No match for key=%s (keycode=%d, phys=%d) checks: %s" % [
			event.as_text(), event.keycode, event.physical_keycode, ", ".join(checks)])
	return false
