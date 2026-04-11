class_name PlacementExecutor
extends RefCounted

## PlacementExecutor: Executes tile placement, swap, and return operations.
## Delegates cell validation queries to PlacementValidator.
## No validation logic — callers check PlacementValidator or DropResolver first.

# =============================================================================
# DEPENDENCIES (injected via setup)
# =============================================================================

var board: Board = null
var hand: Hand = null
var _selection: SelectionManager = null
var _validator: PlacementValidator = null


func setup(p_board: Board, p_hand: Hand, p_selection: SelectionManager) -> void:
	board = p_board
	hand = p_hand
	_selection = p_selection
	_validator = PlacementValidator.new(p_board)


func get_validator() -> PlacementValidator:
	return _validator


# =============================================================================
# TILE PLACEMENT
# =============================================================================

## Places a tile on a cell and updates selection/interaction state.
func place_tile_on_cell(tile: Tile, cell: BoardCell) -> void:
	if cell.is_occupied() or cell.is_unavailable():
		return

	place_tile_on_cell_silent(tile, cell)
	_selection.deselect_tile(tile)


## Places a tile on a cell and starts a glide animation from hand to board.
func place_tile_on_cell_animated(tile: Tile, cell: BoardCell) -> void:
	if cell.is_occupied() or cell.is_unavailable():
		return

	var start_global_pos: Vector2 = tile.global_position
	place_tile_on_cell(tile, cell)
	TileAnimator.animate_place_to_board(tile, start_global_pos)


## Places a batch of tiles on their cells with staggered glide animations.
func place_tiles_on_cells_animated(tiles: Array[Tile], cells: Array[BoardCell]) -> void:
	var start_positions: Dictionary = {}
	for tile in tiles:
		start_positions[tile] = tile.global_position

	for i in tiles.size():
		place_tile_on_cell_silent(tiles[i], cells[i])

	TileAnimator.animate_place_batch_to_board(tiles, start_positions)


## Places a tile on a cell without updating selection state.
func place_tile_on_cell_silent(tile: Tile, cell: BoardCell) -> void:
	if cell.is_occupied() or cell.is_unavailable():
		return

	var was_in_hand: bool = tile.location == Tile.TileLocation.IN_HAND

	if tile.get_parent():
		tile.get_parent().remove_child(tile)
	cell.tile_anchor.add_child(tile)
	tile.position = Vector2.ZERO

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
	if tile.current_cell == null and tile.location != Tile.TileLocation.IN_HAND:
		if tile.get_parent():
			tile.get_parent().remove_child(tile)
		hand.add_tile(tile)
		tile.move_to_hand()
		tile._update_visual()
		EventBus.hand_count_changed.emit(hand.get_tile_count())
		if not preserve_selection:
			_selection.deselect_tile(tile)
		return

	if tile.current_cell == null:
		return

	var cell: BoardCell = tile.current_cell
	TileAnimator.animate_return_to_hand(tile, hand, cell)

	if not preserve_selection:
		_selection.deselect_tile(tile)

	clear_all_cell_hovers()

	EventBus.tile_removed.emit(tile, cell)
	print("[Gameplay] Returned tile %s from cell %s to hand (animated)" % [tile.name, cell.name])


# =============================================================================
# CELL HELPERS (delegated to PlacementValidator)
# =============================================================================

func get_sequential_cells(start: BoardCell, count: int) -> Array[BoardCell]:
	return _validator.get_sequential_cells(start, count)


func get_sequential_cells_centered(drop_cell: BoardCell, count: int, lead_index: int) -> Array[BoardCell]:
	return _validator.get_sequential_cells_centered(drop_cell, count, lead_index)


## Restores a tile to its original cell after a cancelled drag.
func return_to_original_cell(tile: Tile) -> void:
	if tile.current_cell == null:
		push_error("[Gameplay] Board tile has no current_cell reference!")
		return

	if not tile.has_active_cell_binding():
		push_warning("[Gameplay] Cell binding not active, restoring...")
		tile.restore_cell_binding()

	tile.position = Vector2.ZERO
	tile._update_visual()
	print("[Gameplay] Tile %s returned to cell: %s" % [tile.name, tile.current_cell.name])


## Gets the board cell under the current mouse position.
func get_cell_under_mouse(viewport: Viewport) -> BoardCell:
	var mouse_pos: Vector2 = viewport.get_mouse_position()
	return board.get_cell_at_position(mouse_pos)


## Clears hover state on all board cells.
func clear_all_cell_hovers() -> void:
	board.clear_all_cell_hovers()


# =============================================================================
# TILE SWAP
# =============================================================================

## Swaps two tiles between their locations (hand/board).
func swap_tiles(tile_a: Tile, tile_b: Tile, target_cell: BoardCell) -> void:
	var loc_a: Tile.TileLocation = tile_a.location
	var loc_b: Tile.TileLocation = tile_b.location
	var cell_a: BoardCell = tile_a.current_cell
	var cell_b: BoardCell = tile_b.current_cell

	print("[Gameplay] Swapping %s (%s) with %s (%s)" % [
		tile_a.name,
		"board" if loc_a == Tile.TileLocation.ON_BOARD else "hand",
		tile_b.name,
		"board" if loc_b == Tile.TileLocation.ON_BOARD else "hand"
	])

	if loc_a == Tile.TileLocation.ON_BOARD and loc_b == Tile.TileLocation.ON_BOARD:
		_swap_board_tiles(tile_a, tile_b, cell_a, cell_b)
	elif loc_a == Tile.TileLocation.IN_HAND and loc_b == Tile.TileLocation.ON_BOARD:
		_swap_hand_and_board_tiles(tile_a, tile_b, cell_b)
	else:
		push_error("[Gameplay] Invalid swap configuration: %s ↔ %s" % [loc_a, loc_b])
		return

	clear_all_cell_hovers()


func _swap_board_tiles(tile_a: Tile, tile_b: Tile, cell_a: BoardCell, cell_b: BoardCell) -> void:
	tile_a.detach_from_cell()
	tile_b.detach_from_cell()

	tile_a.get_parent().remove_child(tile_a)
	cell_b.tile_anchor.add_child(tile_a)
	tile_a.position = Vector2.ZERO
	tile_a.attach_to_cell(cell_b)

	tile_b.get_parent().remove_child(tile_b)
	cell_a.tile_anchor.add_child(tile_b)
	tile_b.position = Vector2.ZERO
	tile_b.attach_to_cell(cell_a)

	EventBus.tile_placed.emit(tile_a, cell_b)
	EventBus.tile_placed.emit(tile_b, cell_a)

	print("[Gameplay] Board ↔ Board swap complete: %s @ %s ↔ %s @ %s" % [
		tile_a.name, cell_b.name, tile_b.name, cell_a.name
	])


func _swap_hand_and_board_tiles(hand_tile: Tile, board_tile: Tile, board_cell: BoardCell) -> void:
	board_tile.detach_from_cell()

	board_tile.get_parent().remove_child(board_tile)
	hand.add_tile(board_tile)
	board_tile.position = Vector2.ZERO

	hand.remove_tile(hand_tile)
	board_cell.tile_anchor.add_child(hand_tile)
	hand_tile.position = Vector2.ZERO
	hand_tile.attach_to_cell(board_cell)
	hand_tile.location = Tile.TileLocation.ON_BOARD

	EventBus.tile_placed.emit(hand_tile, board_cell)
	EventBus.tile_removed.emit(board_tile, board_cell)
	EventBus.hand_count_changed.emit(hand.get_tile_count())

	print("[Gameplay] Hand ↔ Board swap complete: %s → %s, %s → hand" % [
		hand_tile.name, board_cell.name, board_tile.name
	])
