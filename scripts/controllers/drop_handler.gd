class_name DropHandler
extends RefCounted

## DropHandler: Handles drag-and-drop release validation and execution.
## Validates drop targets, handles invalid drops with animation,
## and executes valid drops by delegating to TilePlacementHandler.

# =============================================================================
# DEPENDENCIES (injected via setup)
# =============================================================================

var _placement: TilePlacementHandler = null
var hand: Hand = null

## Tracks whether the last drop was successful (read by coordinator).
var last_placement_success: bool = false


func setup(placement: TilePlacementHandler, p_hand: Hand) -> void:
	_placement = placement
	hand = p_hand


# =============================================================================
# DROP HANDLING
# =============================================================================

## Unified drop handler for single and multi-tile drops.
## Validates placement, handles cancellation with animation, or places tiles.
func handle_tile_drop(drop_cell: BoardCell, tiles: Array[Tile]) -> bool:
	if tiles.is_empty():
		last_placement_success = false
		return false

	# Determine if any tiles are from the board (vs hand)
	var has_board_tiles: bool = _any_tiles_on_board(tiles)

	# Get target cells for placement
	var target_cells: Array[BoardCell] = _get_target_cells_for_drop(drop_cell, tiles)

	# Check if placement is valid
	if target_cells.is_empty():
		_handle_invalid_drop(tiles, has_board_tiles, drop_cell)
		last_placement_success = false
		return false

	# Valid drop - restore tiles and place them
	_execute_valid_drop(tiles, target_cells)
	last_placement_success = true
	return true


# =============================================================================
# PRIVATE HELPERS
# =============================================================================

## Checks if any tiles in the array are currently on the board.
func _any_tiles_on_board(tiles: Array[Tile]) -> bool:
	for tile in tiles:
		if tile.location == Tile.TileLocation.ON_BOARD:
			return true
	return false


## Gets the target cells for a drop operation.
## Returns empty array if placement is invalid.
func _get_target_cells_for_drop(drop_cell: BoardCell, tiles: Array[Tile]) -> Array[BoardCell]:
	if drop_cell == null:
		return []

	if tiles.size() == 1:
		# Single tile - just check if the cell is free
		if drop_cell.is_occupied():
			return []
		return [drop_cell]

	# Multi-tile - get sequential cells centered on lead tile
	var lead_tile: Tile = DragManager.lead_tile
	var lead_index: int = tiles.find(lead_tile)
	if lead_index == -1:
		lead_index = 0

	return _placement.get_sequential_cells_centered(drop_cell, tiles.size(), lead_index)


## Handles an invalid drop by animating tiles back or restoring board tiles.
func _handle_invalid_drop(tiles: Array[Tile], has_board_tiles: bool, drop_cell: BoardCell) -> void:
	if drop_cell != null and drop_cell.is_occupied():
		print("[Gameplay] Cannot drop on occupied cell: %s" % drop_cell.name)
	elif drop_cell == null:
		print("[Gameplay] Cannot drop outside board")

	if has_board_tiles:
		# Board tiles - restore to original positions without animation
		DragManager.restore_tiles_to_parents()
		for tile in tiles:
			if tile.location == Tile.TileLocation.ON_BOARD:
				_placement.return_to_original_cell(tile)
	else:
		# Hand tiles - animate back with smooth transition
		_animate_tiles_back_to_hand(tiles)

	_placement.clear_all_cell_hovers()


## Animates tiles back to hand with proper selection handling.
func _animate_tiles_back_to_hand(tiles: Array[Tile]) -> void:
	# In single-select mode with one tile, deselect it
	if tiles.size() == 1 and not SelectionManager.is_multi_select_enabled():
		SelectionManager.deselect_tile(tiles[0])

	# Animate all tiles back to hand
	TileAnimator.animate_cancel_to_hand(tiles, hand)
	print("[Gameplay] Animating %d tile(s) back to hand" % tiles.size())


## Executes a valid drop by restoring and placing tiles.
func _execute_valid_drop(tiles: Array[Tile], target_cells: Array[BoardCell]) -> void:
	DragManager.restore_tiles_to_parents()

	for i in tiles.size():
		_placement.place_tile_on_cell_silent(tiles[i], target_cells[i])

	SelectionManager.deselect_all()
	print("[Gameplay] Placed %d tile(s) on board" % tiles.size())
