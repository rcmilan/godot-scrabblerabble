class_name BoardStateCoordinator
extends RefCounted

## BoardStateCoordinator: Atomic facade over PlacementExecutor + PlayStateManager.
## Callers never touch PSM directly; all visual and logical updates happen here atomically.
## Eliminates the dual-update anti-pattern (remove PSM entry before, add after placement).

var _placement: PlacementExecutor = null
var _psm: PlayStateManager = null


func setup(placement: PlacementExecutor, psm: PlayStateManager) -> void:
	_placement = placement
	_psm = psm


# =============================================================================
# ATOMIC PLACEMENT + PSM OPERATIONS
# =============================================================================

## Places a single tile on a cell. Clears its old PSM entry if it was on the board.
func place_tile(tile: Tile, cell: BoardCell, animated: bool = true) -> void:
	_remove_if_on_board(tile)
	if animated:
		_placement.place_tile_on_cell_animated(tile, cell)
	else:
		_placement.place_tile_on_cell(tile, cell)
	_psm.place_temporary_tile(tile, cell.grid_position)


## Places multiple tiles starting at start_cell. Returns the cells used, or [] on failure.
func place_tiles(tiles: Array[Tile], start_cell: BoardCell, animated: bool = true) -> Array[BoardCell]:
	var cells: Array[BoardCell] = _placement.get_sequential_cells(start_cell, tiles.size())
	if cells.is_empty():
		return []
	for t in tiles:
		_remove_if_on_board(t)
	if animated:
		_placement.place_tiles_on_cells_animated(tiles, cells)
	else:
		for i in tiles.size():
			_placement.place_tile_on_cell_silent(tiles[i], cells[i])
	for i in tiles.size():
		_psm.place_temporary_tile(tiles[i], cells[i].grid_position)
	return cells


## Returns a tile to hand, removing it from PSM.
func return_tile(tile: Tile, preserve_selection: bool = false) -> void:
	if tile.current_cell:
		_psm.remove_tile_at(tile.current_cell.grid_position)
	_placement.return_tile_to_hand(tile, preserve_selection)


## Swaps two tiles, updating PSM for both positions atomically.
func swap_tiles(tile_a: Tile, tile_b: Tile, cell: BoardCell) -> void:
	_psm_clear_two(tile_a, tile_b)
	_placement.swap_tiles(tile_a, tile_b, cell)
	_psm_restore_two(tile_a, tile_b)


## Removes tile from PSM only (used when lifting a tile off the board during drag-start).
func unregister_tile(pos: Vector2i) -> void:
	_psm.remove_tile_at(pos)


## Registers a dropped tile in PSM using its current cell (called after DropExecutor places it).
func register_dropped_tile(tile: Tile) -> void:
	if tile.current_cell:
		_psm.place_temporary_tile(tile, tile.current_cell.grid_position)


## Re-registers a tile in PSM at its current cell without moving it (same-cell drop restore).
func restore_psm_for_tile(tile: Tile) -> void:
	if tile.current_cell:
		_psm.place_temporary_tile(tile, tile.current_cell.grid_position)


## Registers a tile in PSM at an explicit position (used for raw reparenting paths).
func register_tile_at(tile: Tile, pos: Vector2i) -> void:
	_psm.place_temporary_tile(tile, pos)


## Commits all temporary tiles to permanent (called on play completed).
func commit() -> void:
	_psm.commit_temporary_tiles()


## Resets the grid cache for a new board size (called on round transition).
func reset_grid(rows: int, cols: int) -> void:
	_psm.initialize_grid(rows, cols)


# =============================================================================
# PASS-THROUGHS TO PLACEMENT EXECUTOR
# =============================================================================

func get_sequential_cells(start: BoardCell, count: int) -> Array[BoardCell]:
	return _placement.get_sequential_cells(start, count)


func get_cell_under_mouse(viewport: Viewport) -> BoardCell:
	return _placement.get_cell_under_mouse(viewport)


func clear_all_cell_hovers() -> void:
	_placement.clear_all_cell_hovers()


func get_validator() -> PlacementValidator:
	return _placement.get_validator()


func return_to_original_cell(tile: Tile) -> void:
	_placement.return_to_original_cell(tile)


# =============================================================================
# PRIVATE HELPERS
# =============================================================================

func _remove_if_on_board(tile: Tile) -> void:
	if tile.current_cell:
		_psm.remove_tile_at(tile.current_cell.grid_position)


func _psm_clear_two(tile_a: Tile, tile_b: Tile) -> void:
	if tile_a.current_cell:
		_psm.remove_tile_at(tile_a.current_cell.grid_position)
	if tile_b.current_cell:
		_psm.remove_tile_at(tile_b.current_cell.grid_position)


func _psm_restore_two(tile_a: Tile, tile_b: Tile) -> void:
	if tile_a.current_cell:
		_psm.place_temporary_tile(tile_a, tile_a.current_cell.grid_position)
	if tile_b.current_cell:
		_psm.place_temporary_tile(tile_b, tile_b.current_cell.grid_position)
