class_name InteractionState
extends RefCounted

## Immutable value object representing the full interaction state.
## Composes SelectionState, DragSnapshot, and cursor-held tile.

var _selection: SelectionState
var _drag: DragSnapshot
var _cursor_held_tile_id: int  # -1 = none


func _init(
	selection: SelectionState,
	drag: DragSnapshot,
	cursor_held_tile_id: int = -1
) -> void:
	_selection = selection
	_drag = drag
	_cursor_held_tile_id = cursor_held_tile_id


static func initial() -> InteractionState:
	return InteractionState.new(SelectionState.empty(), DragSnapshot.inactive(), -1)


func get_selection() -> SelectionState: return _selection
func get_drag() -> DragSnapshot: return _drag
func get_cursor_held_tile_id() -> int: return _cursor_held_tile_id
func has_cursor_held_tile() -> bool: return _cursor_held_tile_id != -1


func with_selection(new_selection: SelectionState) -> InteractionState:
	return InteractionState.new(new_selection, _drag, _cursor_held_tile_id)


func with_drag(new_drag: DragSnapshot) -> InteractionState:
	return InteractionState.new(_selection, new_drag, _cursor_held_tile_id)


func with_cursor_held(tile_id: int) -> InteractionState:
	return InteractionState.new(_selection, _drag, tile_id)


func with_cursor_cleared() -> InteractionState:
	return InteractionState.new(_selection, _drag, -1)
