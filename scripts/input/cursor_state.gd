# scripts/input/cursor_state.gd
class_name CursorState
extends RefCounted

## Immutable-by-convention aggregate for FocusCursor state.
## Never mutate fields directly — use the with_* helpers to get a new instance.

var position: CursorPosition = null  ## Never null after construction.


## Factory: initial state — hand zone, index 0.
static func at_hand(index: int) -> CursorState:
	var s := CursorState.new()
	s.position = CursorPosition.hand(index)
	return s


## Returns a new CursorState with hand_index changed; zone forced to HAND.
func with_hand_index(i: int) -> CursorState:
	var s := CursorState.new()
	s.position = CursorPosition.hand(i)
	return s


## Returns a new CursorState with board_coords changed; zone forced to BOARD.
func with_board_coords(c: Vector2i) -> CursorState:
	var s := CursorState.new()
	s.position = CursorPosition.board(c)
	return s
