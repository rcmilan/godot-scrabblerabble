class_name TileHighlightState
extends RefCounted

## Value object that unifies cursor hover and selection highlight into one state.
## Determines visual priority: CURSOR > SELECTED > NONE.

enum HighlightType { NONE, SELECTED, CURSOR }

var _is_cursor_hovered: bool
var _is_selected: bool
var _selection_order: int  # -1 = not selected


func _init(is_cursor_hovered: bool, is_selected: bool, selection_order: int = -1) -> void:
	_is_cursor_hovered = is_cursor_hovered
	_is_selected = is_selected
	_selection_order = selection_order


static func none() -> TileHighlightState:
	return TileHighlightState.new(false, false, -1)


static func selected(order: int) -> TileHighlightState:
	return TileHighlightState.new(false, true, order)


static func cursor_hovered() -> TileHighlightState:
	return TileHighlightState.new(true, false, -1)


static func cursor_and_selected(order: int) -> TileHighlightState:
	return TileHighlightState.new(true, true, order)


func is_cursor_hovered() -> bool: return _is_cursor_hovered
func is_selected() -> bool: return _is_selected
func get_selection_order() -> int: return _selection_order


## Returns the highest priority highlight type for visual rendering.
func get_visual_priority() -> HighlightType:
	if _is_cursor_hovered:
		return HighlightType.CURSOR
	if _is_selected:
		return HighlightType.SELECTED
	return HighlightType.NONE
