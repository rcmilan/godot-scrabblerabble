class_name PlacementValidator
extends RefCounted

## Pure domain service for validating tile placement on the board.

var _board: Board


func _init(board: Board) -> void:
	_board = board


## Can a tile be placed on this cell?
func can_place(cell: BoardCell) -> bool:
	return cell != null and not cell.is_occupied()


## Can a tile swap with the tile on this cell?
func can_swap(cell: BoardCell) -> bool:
	return cell != null and cell.is_occupied() and not cell.tile.is_locked


## Can a sequence of tiles be placed starting from start_pos going right?
func can_place_sequence(start_pos: Vector2i, count: int) -> bool:
	for i in count:
		var pos: Vector2i = start_pos + Vector2i(i, 0)
		var cell: BoardCell = _board.get_cell(pos.y, pos.x)
		if cell == null or cell.is_occupied():
			return false
	return true


## Gets sequential empty cells starting from a position going right.
## Returns empty array if any cell is occupied or out of bounds.
func get_sequential_cells(start: BoardCell, count: int) -> Array[BoardCell]:
	var cells: Array[BoardCell] = []
	var pos: Vector2i = start.grid_position

	for i in count:
		var cell: BoardCell = _board.get_cell(pos.y, pos.x)
		if cell == null or cell.is_occupied():
			return []
		cells.append(cell)
		pos += Vector2i.RIGHT
	return cells


## Gets sequential empty cells centered on a drop position based on lead tile index.
func get_sequential_cells_centered(drop_cell: BoardCell, count: int, lead_index: int) -> Array[BoardCell]:
	var cells: Array[BoardCell] = []
	var start_pos: Vector2i = drop_cell.grid_position - (Vector2i.RIGHT * lead_index)

	for i in count:
		var pos: Vector2i = start_pos + (Vector2i.RIGHT * i)
		var cell: BoardCell = _board.get_cell(pos.y, pos.x)
		if cell == null or cell.is_occupied():
			return []
		cells.append(cell)

	return cells
