class_name TilePlacementHandler
extends RefCounted

## TilePlacementHandler: Manages tile placement and return operations.
## Handles placing tiles on board cells, returning them to hand,
## cell queries, and hover state management.

# =============================================================================
# DEPENDENCIES (injected via setup)
# =============================================================================

var board: Board = null
var hand: Hand = null
var _selection: SelectionManager = null


func setup(p_board: Board, p_hand: Hand, p_selection: SelectionManager) -> void:
	board = p_board
	hand = p_hand
	_selection = p_selection


# =============================================================================
# TILE PLACEMENT
# =============================================================================

## Places a tile on a cell and updates selection/interaction state.
func place_tile_on_cell(tile: Tile, cell: BoardCell) -> void:
	if cell.is_occupied():
		return

	place_tile_on_cell_silent(tile, cell)
	_selection.deselect_tile(tile)


## Places a tile on a cell and starts a glide animation from hand to board.
## Only for single-tile keyboard placements. Animation runs fire-and-forget.
func place_tile_on_cell_animated(tile: Tile, cell: BoardCell) -> void:
	if cell.is_occupied():
		return

	# Capture hand position BEFORE reparenting — used as animation start point.
	var start_global_pos: Vector2 = tile.global_position

	# Synchronous placement: reparents tile to cell anchor, sets position = Vector2.ZERO.
	place_tile_on_cell(tile, cell)

	# Fire-and-forget glide animation.
	TileAnimator.animate_place_to_board(tile, start_global_pos)


## Places a batch of tiles on their cells with staggered glide animations.
## Pre-condition: tiles and cells arrays have matching indices and same length.
func place_tiles_on_cells_animated(tiles: Array[Tile], cells: Array[BoardCell]) -> void:
	# Capture all hand positions BEFORE any reparenting.
	var start_positions: Dictionary = {}
	for tile in tiles:
		start_positions[tile] = tile.global_position

	# Synchronous placement of all tiles.
	for i in tiles.size():
		place_tile_on_cell_silent(tiles[i], cells[i])

	# Fire-and-forget staggered glide animation.
	TileAnimator.animate_place_batch_to_board(tiles, start_positions)


## Places a tile on a cell without updating selection state.
## Used for batch placement (multi-tile click/drop).
func place_tile_on_cell_silent(tile: Tile, cell: BoardCell) -> void:
	if cell.is_occupied():
		return

	var was_in_hand: bool = tile.location == Tile.TileLocation.IN_HAND

	# Reparent tile to cell's tile anchor
	if tile.get_parent():
		tile.get_parent().remove_child(tile)
	cell.tile_anchor.add_child(tile)
	tile.position = Vector2.ZERO
	tile.rotation = 0.0

	# Use atomic state management to ensure tile-cell binding consistency
	tile.attach_to_cell(cell)

	clear_all_cell_hovers()

	if was_in_hand:
		EventBus.hand_count_changed.emit(hand.get_tile_count())

	EventBus.tile_placed.emit(tile, cell)


# =============================================================================
# TILE RETURN TO HAND
# =============================================================================

## Returns a tile from the board to the hand (with animation).
func return_tile_to_hand(tile: Tile, preserve_selection: bool = false) -> void:
	# Handle tiles not on board (e.g., in drag container)
	if tile.current_cell == null and tile.location != Tile.TileLocation.IN_HAND:
		if tile.get_parent():
			tile.get_parent().remove_child(tile)
		hand.add_tile(tile)
		tile.move_to_hand()  # Atomic state update
		tile._update_visual()
		EventBus.hand_count_changed.emit(hand.get_tile_count())
		if not preserve_selection:
			_selection.deselect_tile(tile)
		return

	if tile.current_cell == null:
		return

	# Tile is on board - animate return
	var cell: BoardCell = tile.current_cell
	TileAnimator.animate_return_to_hand(tile, hand, cell)

	if not preserve_selection:
		_selection.deselect_tile(tile)

	clear_all_cell_hovers()

	EventBus.tile_removed.emit(tile, cell)
	print("[Gameplay] Returned tile %s from cell %s to hand (animated)" % [tile.name, cell.name])


# =============================================================================
# CELL HELPERS
# =============================================================================

## Gets sequential cells starting from a position, going right.
## Returns empty array if any cell is occupied or out of bounds.
func get_sequential_cells(start: BoardCell, count: int) -> Array[BoardCell]:
	var cells: Array[BoardCell] = []
	var pos: Vector2i = start.grid_position
	var direction: Vector2i = Vector2i.RIGHT

	for i in count:
		var cell: BoardCell = board.get_cell(pos.y, pos.x)
		if cell == null or cell.is_occupied():
			return []
		cells.append(cell)
		pos += direction
	return cells


## Gets sequential cells centered on a drop position based on lead tile index.
func get_sequential_cells_centered(drop_cell: BoardCell, count: int, lead_index: int) -> Array[BoardCell]:
	var cells: Array[BoardCell] = []
	var drop_pos: Vector2i = drop_cell.grid_position
	var direction: Vector2i = Vector2i.RIGHT
	var start_pos: Vector2i = drop_pos - (direction * lead_index)

	for i in count:
		var pos: Vector2i = start_pos + (direction * i)
		var cell: BoardCell = board.get_cell(pos.y, pos.x)
		if cell == null or cell.is_occupied():
			return []
		cells.append(cell)

	return cells


## Restores a tile to its original cell after a cancelled drag.
func return_to_original_cell(tile: Tile) -> void:
	if tile.current_cell == null:
		push_error("[Gameplay] Board tile has no current_cell reference!")
		return

	# Verify cell binding is restored (should have been done by restore_tiles_to_parents)
	if not tile.has_active_cell_binding():
		push_warning("[Gameplay] Cell binding not active, restoring...")
		tile.restore_cell_binding()

	tile.position = Vector2.ZERO
	tile.rotation = 0.0
	tile._update_visual()
	print("[Gameplay] Tile %s returned to cell: %s" % [tile.name, tile.current_cell.name])


## Gets the board cell under the current mouse position.
func get_cell_under_mouse(viewport: Viewport) -> BoardCell:
	var mouse_pos: Vector2 = viewport.get_mouse_position()
	return board.get_cell_at_position(mouse_pos)


## Clears hover state on all board cells.
func clear_all_cell_hovers() -> void:
	for cell in board.get_all_cells():
		cell.clear_hover()


# =============================================================================
# TILE SWAP
# =============================================================================

## Swaps two tiles between their locations (hand/board).
## Handles: Board ↔ Board, Board ↔ Hand.
func swap_tiles(tile_a: Tile, tile_b: Tile, target_cell: BoardCell) -> void:
	var loc_a: Tile.TileLocation = tile_a.location
	var loc_b: Tile.TileLocation = tile_b.location
	var cell_a: BoardCell = tile_a.current_cell
	var cell_b: BoardCell = tile_b.current_cell  # Should be same as target_cell
	
	print("[Gameplay] Swapping %s (%s) with %s (%s)" % [
		tile_a.name, 
		"board" if loc_a == Tile.TileLocation.ON_BOARD else "hand",
		tile_b.name,
		"board" if loc_b == Tile.TileLocation.ON_BOARD else "hand"
	])
	
	# Case 1: Board ↔ Board swap
	if loc_a == Tile.TileLocation.ON_BOARD and loc_b == Tile.TileLocation.ON_BOARD:
		_swap_board_tiles(tile_a, tile_b, cell_a, cell_b)
	
	# Case 2: Hand → Board, Board → Hand
	elif loc_a == Tile.TileLocation.IN_HAND and loc_b == Tile.TileLocation.ON_BOARD:
		_swap_hand_and_board_tiles(tile_a, tile_b, cell_b)
	
	# Case 3: Invalid swap configuration
	else:
		push_error("[Gameplay] Invalid swap configuration: %s ↔ %s" % [loc_a, loc_b])
		return
	
	clear_all_cell_hovers()


## Swaps two tiles that are both on the board.
func _swap_board_tiles(tile_a: Tile, tile_b: Tile, cell_a: BoardCell, cell_b: BoardCell) -> void:
	# Detach both tiles from their cells
	tile_a.detach_from_cell()
	tile_b.detach_from_cell()
	
	# Reparent tile_a to cell_b
	tile_a.get_parent().remove_child(tile_a)
	cell_b.tile_anchor.add_child(tile_a)
	tile_a.position = Vector2.ZERO
	tile_a.attach_to_cell(cell_b)
	
	# Reparent tile_b to cell_a
	tile_b.get_parent().remove_child(tile_b)
	cell_a.tile_anchor.add_child(tile_b)
	tile_b.position = Vector2.ZERO
	tile_b.attach_to_cell(cell_a)
	
	EventBus.tile_placed.emit(tile_a, cell_b)
	EventBus.tile_placed.emit(tile_b, cell_a)
	
	print("[Gameplay] Board ↔ Board swap complete: %s @ %s ↔ %s @ %s" % [
		tile_a.name, cell_b.name, tile_b.name, cell_a.name
	])


## Swaps a hand tile with a board tile.
func _swap_hand_and_board_tiles(hand_tile: Tile, board_tile: Tile, board_cell: BoardCell) -> void:
	# Detach board tile from cell
	board_tile.detach_from_cell()
	
	# Move board tile to hand
	board_tile.get_parent().remove_child(board_tile)
	hand.add_tile(board_tile)
	board_tile.position = Vector2.ZERO
	board_tile.rotation = 0.0

	# Move hand tile to board
	hand.remove_tile(hand_tile)
	board_cell.tile_anchor.add_child(hand_tile)
	hand_tile.position = Vector2.ZERO
	hand_tile.rotation = 0.0
	hand_tile.attach_to_cell(board_cell)
	hand_tile.location = Tile.TileLocation.ON_BOARD
	
	EventBus.tile_placed.emit(hand_tile, board_cell)
	EventBus.tile_removed.emit(board_tile, board_cell)
	EventBus.hand_count_changed.emit(hand.get_tile_count())
	
	print("[Gameplay] Hand ↔ Board swap complete: %s → %s, %s → hand" % [
		hand_tile.name, board_cell.name, board_tile.name
	])
