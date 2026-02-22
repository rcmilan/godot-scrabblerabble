# scripts/input/cursor_state.gd
class_name CursorState
extends RefCounted

## Immutable-by-convention aggregate for FocusCursor state.
## Never mutate fields directly — use the with_* helpers to get a new instance.

var position: CursorPosition = null  ## Never null after construction.
var held_tile: Tile          = null  ## null when no tile is being placed.


## Factory: initial state — hand zone, index 0, no held tile.
static func at_hand(index: int) -> CursorState:
	var s := CursorState.new()
	s.position = CursorPosition.hand(index)
	return s


## Returns a new CursorState with hand_index changed; zone forced to HAND.
func with_hand_index(i: int) -> CursorState:
	var s := CursorState.new()
	s.position  = CursorPosition.hand(i)
	s.held_tile = held_tile
	return s


## Returns a new CursorState with board_coords changed; zone forced to BOARD.
func with_board_coords(c: Vector2i) -> CursorState:
	var s := CursorState.new()
	s.position  = CursorPosition.board(c)
	s.held_tile = held_tile
	return s


## Returns a new CursorState with held_tile set; position unchanged.
func with_held_tile(t: Tile) -> CursorState:
	var s := CursorState.new()
	s.position  = position
	s.held_tile = t
	return s


## Returns a new CursorState with held_tile cleared; position unchanged.
func cleared_tile() -> CursorState:
	var s := CursorState.new()
	s.position  = position
	s.held_tile = null
	return s
