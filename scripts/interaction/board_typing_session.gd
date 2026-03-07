class_name BoardTypingSession
extends RefCounted

## Immutable typing session. Methods return new instances.
## Tracks cursor position, orientation, and placement history for undo.

const _HORIZONTAL := Vector2i(1, 0)

var board: Board
var cursor_pos: Vector2i
var orientation: Vector2i
var history: Array[Dictionary]  # [{pos, tile_placed, tile_swapped}]


static func create(p_board: Board, start_pos: Vector2i) -> BoardTypingSession:
	var s := BoardTypingSession.new()
	s.board = p_board
	s.cursor_pos = start_pos
	s.orientation = _HORIZONTAL
	s.history = []
	return s


func get_cursor_cell() -> BoardCell:
	return board.get_cell(cursor_pos.y, cursor_pos.x)


func is_exhausted() -> bool:
	return get_cursor_cell() == null


func last_placement() -> Dictionary:
	return history.back() if not history.is_empty() else {}


func with_placement(tile_placed: Tile, tile_swapped: Tile) -> BoardTypingSession:
	var s := _clone()
	s.history.append({pos = cursor_pos, tile_placed = tile_placed, tile_swapped = tile_swapped})
	return s


func advance() -> BoardTypingSession:
	var s := _clone()
	s.cursor_pos = _next_valid_pos(cursor_pos + orientation)
	return s


func retreat() -> BoardTypingSession:
	if history.is_empty():
		return self
	var s := _clone()
	var entry: Dictionary = s.history.pop_back()
	s.cursor_pos = entry.pos
	return s


func move(direction: Vector2i) -> BoardTypingSession:
	var resolved := _skip_locked(cursor_pos + direction, direction)
	if resolved == Vector2i(-1, -1):
		return self
	var s := _clone()
	s.cursor_pos = resolved
	return s


# =============================================================================
# PRIVATE
# =============================================================================

func _clone() -> BoardTypingSession:
	var s := BoardTypingSession.new()
	s.board = board
	s.cursor_pos = cursor_pos
	s.orientation = orientation
	s.history = history.duplicate()
	return s


func _next_valid_pos(from: Vector2i) -> Vector2i:
	var pos := _wrap_pos(from)
	if pos.y >= board.rows:
		return pos
	return _skip_locked(pos, orientation)


func _wrap_pos(pos: Vector2i) -> Vector2i:
	if orientation == _HORIZONTAL and pos.x >= board.columns:
		return Vector2i(0, pos.y + 1)
	return pos


func _skip_locked(pos: Vector2i, direction: Vector2i) -> Vector2i:
	var limit: int = board.rows * board.columns
	var current := pos
	for i in limit:
		var cell := board.get_cell(current.y, current.x)
		if cell == null:
			return Vector2i(-1, -1)
		if not cell.is_occupied() or not cell.tile.is_locked:
			return current
		current = _wrap_pos(current + direction)
		if current.y >= board.rows or current.x < 0 or current.y < 0:
			return Vector2i(-1, -1)
	return Vector2i(-1, -1)
