class_name BoardState
extends RefCounted

## Immutable value object representing the board's tile layout.
## All mutations return new instances.

var _grid: Dictionary = {}  # Vector2i → TileState

static var _empty: BoardState = null


static func empty() -> BoardState:
	if _empty == null:
		_empty = BoardState.new({})
	return _empty


func _init(grid: Dictionary = {}) -> void:
	_grid = grid.duplicate()


## Creates a BoardState from the current Board node.
static func from_board(board: Board) -> BoardState:
	var grid: Dictionary = {}
	for cell in board.get_all_cells():
		if cell.is_occupied():
			grid[cell.grid_position] = cell.tile.get_state()
	return BoardState.new(grid)


func with_tile_at(pos: Vector2i, state: TileState) -> BoardState:
	var new_grid: Dictionary = _grid.duplicate()
	new_grid[pos] = state
	return BoardState.new(new_grid)


func without_tile_at(pos: Vector2i) -> BoardState:
	if not _grid.has(pos):
		return self
	var new_grid: Dictionary = _grid.duplicate()
	new_grid.erase(pos)
	return BoardState.new(new_grid)


func with_swapped(pos_a: Vector2i, pos_b: Vector2i) -> BoardState:
	var new_grid: Dictionary = _grid.duplicate()
	var state_a = new_grid.get(pos_a)
	var state_b = new_grid.get(pos_b)
	if state_a:
		new_grid[pos_b] = state_a
	else:
		new_grid.erase(pos_b)
	if state_b:
		new_grid[pos_a] = state_b
	else:
		new_grid.erase(pos_a)
	return BoardState.new(new_grid)


func get_tile_at(pos: Vector2i) -> TileState:
	return _grid.get(pos)


func is_occupied(pos: Vector2i) -> bool:
	return _grid.has(pos)


func is_locked_at(pos: Vector2i) -> bool:
	var state: TileState = _grid.get(pos)
	return state != null and state.is_locked()


func get_occupied_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for pos in _grid:
		positions.append(pos)
	return positions


func size() -> int:
	return _grid.size()
