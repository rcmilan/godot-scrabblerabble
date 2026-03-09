class_name InteractionState
extends RefCounted

## Immutable value object representing the full interaction state.
## Composes SelectionState and DragSnapshot.

var _selection: SelectionState
var _drag: DragSnapshot


func _init(
	selection: SelectionState,
	drag: DragSnapshot,
) -> void:
	_selection = selection
	_drag = drag


static func initial() -> InteractionState:
	return InteractionState.new(SelectionState.empty(), DragSnapshot.inactive())


func get_selection() -> SelectionState: return _selection
func get_drag() -> DragSnapshot: return _drag


func with_selection(new_selection: SelectionState) -> InteractionState:
	return InteractionState.new(new_selection, _drag)


func with_drag(new_drag: DragSnapshot) -> InteractionState:
	return InteractionState.new(_selection, new_drag)
