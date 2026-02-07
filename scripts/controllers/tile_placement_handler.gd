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


func setup(p_board: Board, p_hand: Hand) -> void:
	board = p_board
	hand = p_hand


# =============================================================================
# TILE PLACEMENT
# =============================================================================

## Places a tile on a cell and updates selection/interaction state.
func place_tile_on_cell(tile: Tile, cell: BoardCell) -> void:
	if cell.is_occupied():
		return

	place_tile_on_cell_silent(tile, cell)
	SelectionManager.deselect_tile(tile)


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
		tile.modulate = Color.WHITE
		EventBus.hand_count_changed.emit(hand.get_tile_count())
		if not preserve_selection:
			SelectionManager.deselect_tile(tile)
		return

	if tile.current_cell == null:
		return

	# Tile is on board - animate return
	var cell: BoardCell = tile.current_cell
	TileAnimator.animate_return_to_hand(tile, hand, cell)

	if not preserve_selection:
		SelectionManager.deselect_tile(tile)

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
	tile.modulate = Color.WHITE
	print("[Gameplay] Tile %s returned to cell: %s" % [tile.name, tile.current_cell.name])


## Gets the board cell under the current mouse position.
func get_cell_under_mouse(viewport: Viewport) -> BoardCell:
	var mouse_pos: Vector2 = viewport.get_mouse_position()
	return board.get_cell_at_position(mouse_pos)


## Clears hover state on all board cells.
func clear_all_cell_hovers() -> void:
	for cell in board.get_all_cells():
		cell.clear_hover()
