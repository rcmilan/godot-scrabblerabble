# scripts/input/modal_input_guard.gd
class_name ModalInputGuard
extends RefCounted

## Shared input guard for modal popups (CanvasLayer or Control-based).
## Owner must be a Node with .visible and .get_viewport() — both CanvasLayer
## and Control satisfy this. Compose via ModalInputGuard.new().setup(self).

signal close_requested

var _owner: Node = null
var _close_actions:   Array[StringName] = []
var _blocked_actions: Array[StringName] = [
	KeyAction.NAVIGATE_LEFT,
	KeyAction.NAVIGATE_RIGHT,
	KeyAction.NAVIGATE_UP,
	KeyAction.NAVIGATE_DOWN,
	KeyAction.CONFIRM,
	&"ui_up", &"ui_down", &"ui_left", &"ui_right",
]


## Fluent — call .setup(self) first, then chain .add_close_action() as needed.
func setup(owner: Node) -> ModalInputGuard:
	_owner = owner
	return self


func add_close_action(action: StringName) -> ModalInputGuard:
	_close_actions.append(action)
	return self


func add_blocked_action(action: StringName) -> ModalInputGuard:
	_blocked_actions.append(action)
	return self


## Call from _input(event). Returns true if the event was consumed.
func handle(event: InputEvent) -> bool:
	if not _owner.visible:
		return false
	for action: StringName in _close_actions:
		if event.is_action_pressed(action):
			close_requested.emit()
			_owner.get_viewport().set_input_as_handled()
			return true
	for action: StringName in _blocked_actions:
		if event.is_action_pressed(action):
			_owner.get_viewport().set_input_as_handled()
			return true
	return false
