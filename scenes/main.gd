extends Control
class_name Main

## Main game controller responsible for coordinating game components.
## Manages tile selection, placement, and overall game interaction flow.

# === Signals ===
signal tile_placement_completed(tile: Tile, cell: BoardCell)
signal tile_returned_to_hand(tile: Tile)

# === Interaction State Machine ===
enum InteractionMode {
	IDLE,           # No tile selected, waiting for input
	TILE_SELECTED,  # Tile selected from hand, waiting for placement
	DRAGGING        # Tile being dragged
}

# === State ===
var selected_tile: Tile = null
var interaction_mode: InteractionMode = InteractionMode.IDLE

# === Drag State ===
# DragManager handles multi-tile drag state
# Local tracking only for placement success
var _last_placement_success: bool = false

# === Services ===
var _word_validator: WordValidator = null

# === Node References ===
@onready var board: Board = $Board
@onready var hand: Hand = $Hand
@onready var discard_pile: Control = $DiscardPile
@onready var discard_dialog: CanvasLayer = $DiscardConfirmationDialog
@onready var main_hud: CanvasLayer = $MainHUD


func _ready() -> void:
	_word_validator = WordValidator.new()
	_connect_board_signals()
	_connect_discard_signals()
	_connect_hud_signals()
	_connect_drag_signals()
	_start_game()


func _connect_drag_signals() -> void:
	DragManager.drag_release_requested.connect(_handle_drag_release)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_multi_select"):
		SelectionManager.toggle_mode()

	if event.is_action_pressed("discard_tiles"):
		_request_discard_confirmation()


func _process(_delta: float) -> void:
	pass


# === Initialization ===

func _connect_board_signals() -> void:
	# Wait for board to initialize
	if not board.is_node_ready():
		await board.ready

	# Connect to board's forwarded signals
	board.cell_clicked.connect(_on_cell_clicked)
	board.cell_hovered.connect(_on_cell_hovered)
	board.cell_unhovered.connect(_on_cell_unhovered)


func _connect_discard_signals() -> void:
	discard_pile.tiles_dropped.connect(_on_discard_pile_tiles_dropped)
	discard_pile.peek_requested.connect(_on_discard_pile_peek_requested)
	discard_dialog.confirmed.connect(_on_discard_confirmed)
	discard_dialog.cancelled.connect(_on_discard_cancelled)


func _connect_hud_signals() -> void:
	main_hud.play_requested.connect(_on_play_requested)


func _start_game() -> void:
	var default_bag: BagDistribution = load("res://Data/BagDistribution/bag_default.tres")
	GameManager.start_game(default_bag, 0)


# === Tile Selection Handlers ===

func _on_tile_selected(tile: Tile) -> void:
	print("[Main] Tile selected: %s" % tile.name)

	# Clicking a board tile while we have selection
	if SelectionManager.has_selection() and tile.location == Tile.TileLocation.ON_BOARD:
		print("[Main] Cannot stack tiles")
		return

	# Clicking a tile that's already on the board (info only)
	if not SelectionManager.has_selection() and tile.location == Tile.TileLocation.ON_BOARD:
		print("[Main] Board tile at cell: %s" % tile.current_cell.name)
		return

	# Hand tile - use SelectionManager
	if tile.location == Tile.TileLocation.IN_HAND:
		SelectionManager.select_tile(tile)
		_update_interaction_state()


func _on_tile_right_clicked(tile: Tile) -> void:
	if SelectionManager.has_selection():
		print("[Main] Cannot remove tile while selection active")
		return

	if tile.current_cell == null:
		print("[Main] Tile is not on board")
		return

	# Check if tile is locked (already played)
	if tile.is_locked:
		print("[Main] Cannot return tile - tile is locked (already played)")
		TileAnimator.animate_shake(tile)
		return

	# Check if hand has space for the tile
	if hand.is_full():
		print("[Main] Cannot return tile - hand is full")
		TileAnimator.animate_shake(tile)
		return

	return_tile_to_hand(tile)


func _on_tile_drag_started(tile: Tile) -> void:
	# Prevent dragging locked tiles
	if tile.is_locked:
		print("[Main] Cannot drag locked tile: %s" % tile.name)
		return

	# Get all selected tiles for multi-drag
	var tiles_to_drag: Array[Tile] = SelectionManager.get_selected_tiles()

	# If dragged tile is not in selection, select only it
	if tile not in tiles_to_drag:
		SelectionManager.deselect_all()
		SelectionManager.select_tile(tile)
		tiles_to_drag = [tile]

	# Mark follower tiles for multi-drag visual
	for t in tiles_to_drag:
		if t != tile:
			t.set_as_drag_follower()

	# Start drag through DragManager
	DragManager.start_drag(tile, tiles_to_drag)

	if tiles_to_drag.size() > 1:
		print("[Main] Multi-drag started with %d tiles" % tiles_to_drag.size())


func _on_tile_drag_ended(tile: Tile) -> void:
	# Only process if this is the lead tile of the current drag
	if not DragManager.is_dragging:
		return
	if tile != DragManager.lead_tile:
		return
	_handle_drag_release(tile)


## Handles the end of a drag operation (called from tile signal or unhandled input).
func _handle_drag_release(tile: Tile) -> void:
	if not DragManager.is_dragging:
		return

	var dragged_tiles: Array[Tile] = DragManager.get_dragged_tiles()
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()

	# Check if dropped on discard pile first
	if discard_pile.is_drop_target(mouse_pos):
		_handle_drop_on_discard_pile(dragged_tiles)
		DragManager.end_drag(false)
		return

	var cell: BoardCell = _get_cell_under_mouse()

	var cell_name: String = String(cell.name) if cell else "none"
	print("[Main] Drag ended - Tile: %s | Location: %s | Cell: %s | Multi: %d" % [
		tile.name,
		Tile.TileLocation.keys()[tile.location],
		cell_name,
		dragged_tiles.size()
	])

	# Handle multi-tile or single-tile drop
	if dragged_tiles.size() > 1:
		_handle_multi_tile_drop(cell, dragged_tiles)
	else:
		_handle_single_tile_drop(tile, cell)

	# End drag operation
	DragManager.end_drag(_last_placement_success)


# === Cell Handlers ===

func _on_cell_clicked(cell: BoardCell) -> void:
	var selected_tiles: Array[Tile] = SelectionManager.get_selected_tiles()

	if selected_tiles.is_empty():
		print("[Main] No tile selected")
		return

	if cell.is_occupied():
		print("[Main] Cell occupied: %s" % cell.name)
		return

	# Multi-tile click placement
	if selected_tiles.size() > 1:
		var cells: Array[BoardCell] = _get_sequential_cells(cell, selected_tiles.size())
		if cells.is_empty():
			print("[Main] Cannot place %d tiles starting at %s" % [selected_tiles.size(), cell.name])
			return

		# Place all tiles
		for i in selected_tiles.size():
			_place_tile_on_cell_silent(selected_tiles[i], cells[i])

		SelectionManager.deselect_all()
		_update_interaction_state()
		print("[Main] Placed %d tiles starting at %s" % [selected_tiles.size(), cell.name])
	else:
		# Single tile placement
		place_tile_on_cell(selected_tiles[0], cell)


func _on_cell_hovered(cell: BoardCell) -> void:
	if not SelectionManager.has_selection():
		return

	var selected_count: int = SelectionManager.get_selection_count()

	if selected_count > 1:
		# Multi-tile hover - check if all sequential cells are valid
		var cells: Array[BoardCell] = _get_sequential_cells(cell, selected_count)
		if cells.is_empty():
			cell.show_invalid_hover()
		else:
			# Show valid hover on all cells that would be used
			for c in cells:
				c.show_valid_hover()
	else:
		# Single tile hover
		if cell.is_occupied():
			cell.show_invalid_hover()
		else:
			cell.show_valid_hover()


func _on_cell_unhovered(cell: BoardCell) -> void:
	cell.clear_hover()


# === Tile Placement ===

func place_tile_on_cell(tile: Tile, cell: BoardCell) -> void:
	if cell.is_occupied():
		return

	_place_tile_on_cell_silent(tile, cell)

	# Deselect and reset interaction
	SelectionManager.deselect_tile(tile)
	_update_interaction_state()


## Places a tile on a cell without deselecting or updating interaction state.
## Used for multi-tile placement where we batch the state updates.
func _place_tile_on_cell_silent(tile: Tile, cell: BoardCell) -> void:
	if cell.is_occupied():
		return

	# Clear old cell if tile was on board
	if tile.location == Tile.TileLocation.ON_BOARD and tile.current_cell != null:
		var old_cell: BoardCell = tile.current_cell
		old_cell.tile = null
		print("[Main] Cleared old cell: %s" % old_cell.name)

	# Reparent tile to cell
	tile.get_parent().remove_child(tile)
	cell.tile_anchor.add_child(tile)
	tile.position = Vector2.ZERO

	# Update tile state
	tile.current_cell = cell
	tile.location = Tile.TileLocation.ON_BOARD

	# Update cell state
	cell.tile = tile

	_clear_all_cell_hovers()

	EventBus.tile_placed.emit(tile, cell)
	tile_placement_completed.emit(tile, cell)
	_update_play_button_state()
	print("[Main] Placed tile %s on cell %s" % [tile.name, cell.name])


func return_tile_to_hand(tile: Tile) -> void:
	_return_tile_to_hand_internal(tile, false)


func _return_tile_to_hand_internal(tile: Tile, preserve_selection: bool) -> void:
	if tile.current_cell == null and tile.location != Tile.TileLocation.IN_HAND:
		# Tile being returned from drag, not from board
		if tile.get_parent():
			tile.get_parent().remove_child(tile)
		hand.add_tile(tile)
		tile.location = Tile.TileLocation.IN_HAND
		tile.modulate = Color.WHITE
		if not preserve_selection:
			SelectionManager.deselect_tile(tile)
		return

	if tile.current_cell == null:
		return

	var cell: BoardCell = tile.current_cell

	# Use animated return - TileAnimator handles the tile movement
	TileAnimator.animate_return_to_hand(tile, hand, cell)

	if not preserve_selection:
		SelectionManager.deselect_tile(tile)

	_update_interaction_state()
	_clear_all_cell_hovers()

	EventBus.tile_removed.emit(tile, cell)
	tile_returned_to_hand.emit(tile)
	_update_play_button_state()
	print("[Main] Returned tile %s from cell %s to hand (animated)" % [tile.name, cell.name])


# === Private Helpers ===

func _update_interaction_state() -> void:
	var has_selection: bool = SelectionManager.has_selection()

	if has_selection:
		interaction_mode = InteractionMode.TILE_SELECTED
		selected_tile = SelectionManager.get_selected_tiles()[0] if SelectionManager.get_selection_count() == 1 else null
		_set_hand_tiles_hover_enabled(false)
	else:
		interaction_mode = InteractionMode.IDLE
		selected_tile = null
		_set_hand_tiles_hover_enabled(true)
		_clear_all_cell_hovers()


func _deselect_tile() -> void:
	SelectionManager.deselect_all()
	_update_interaction_state()


func _set_hand_tiles_hover_enabled(enabled: bool) -> void:
	for tile in hand.get_tiles():
		tile.allow_hover_feedback = enabled


func _get_cell_under_mouse() -> BoardCell:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	return board.get_cell_at_position(mouse_pos)


func _clear_all_cell_hovers() -> void:
	for cell in board.get_all_cells():
		cell.clear_hover()


# Original position tracking is now handled by DragManager


func _handle_single_tile_drop(tile: Tile, cell: BoardCell) -> void:
	# Restore tile to original parent first
	DragManager.restore_tiles_to_parents()

	# Dropped outside board
	if cell == null:
		if tile.location == Tile.TileLocation.ON_BOARD:
			_return_to_original_cell(tile)
		else:
			_cancel_drag_to_hand(tile)
		_last_placement_success = false
		return

	# Dropped on occupied cell
	if cell.is_occupied():
		print("[Main] Cannot drop on occupied cell: %s" % cell.name)
		if tile.location == Tile.TileLocation.ON_BOARD:
			_return_to_original_cell(tile)
		else:
			_cancel_drag_to_hand(tile)
		_last_placement_success = false
		return

	# Valid placement
	print("[Main] Valid drop on cell: %s" % cell.name)
	place_tile_on_cell(tile, cell)
	_last_placement_success = true


func _handle_multi_tile_drop(drop_cell: BoardCell, tiles: Array[Tile]) -> void:
	if drop_cell == null:
		_cancel_multi_drag_preserve_selection(tiles)
		_last_placement_success = false
		return

	# Find which tile in the selection is the lead (the one being dragged)
	var lead_tile: Tile = DragManager.lead_tile
	var lead_index: int = tiles.find(lead_tile)
	if lead_index == -1:
		lead_index = 0  # Fallback to first tile

	# Calculate the actual starting position based on lead tile's position in selection
	# If lead is at index 2 and we drop on cell (3,4), first tile goes at (1,4)
	var cells: Array[BoardCell] = _get_sequential_cells_centered(drop_cell, tiles.size(), lead_index)
	if cells.is_empty():
		print("[Main] Cannot place %d tiles centered at %s (lead index: %d)" % [tiles.size(), drop_cell.name, lead_index])
		_cancel_multi_drag_preserve_selection(tiles)
		_last_placement_success = false
		return

	# Restore tiles to original parents before placing
	DragManager.restore_tiles_to_parents()

	# Place all tiles
	for i in tiles.size():
		_place_tile_on_cell_silent(tiles[i], cells[i])

	# Deselect all after successful placement
	SelectionManager.deselect_all()
	_update_interaction_state()
	_last_placement_success = true
	print("[Main] Multi-drop: placed %d tiles centered at %s" % [tiles.size(), drop_cell.name])


func _get_sequential_cells(start: BoardCell, count: int) -> Array[BoardCell]:
	var cells: Array[BoardCell] = []
	var pos: Vector2i = start.grid_position
	var direction: Vector2i = Vector2i.RIGHT  # Future: configurable direction

	for i in count:
		var cell: BoardCell = board.get_cell(pos.y, pos.x)
		if cell == null or cell.is_occupied():
			return []  # Invalid - return empty
		cells.append(cell)
		pos += direction
	return cells


## Gets sequential cells centered around a drop position based on lead tile index.
## Example: If dropping 3 tiles [A,B,C] by dragging B (index 1) onto cell (3,4):
##   - A goes at (2,4) - one cell LEFT of drop
##   - B goes at (3,4) - the drop cell
##   - C goes at (4,4) - one cell RIGHT of drop
func _get_sequential_cells_centered(drop_cell: BoardCell, count: int, lead_index: int) -> Array[BoardCell]:
	var cells: Array[BoardCell] = []
	var drop_pos: Vector2i = drop_cell.grid_position
	var direction: Vector2i = Vector2i.RIGHT

	# Calculate starting position: move LEFT by lead_index cells
	var start_pos: Vector2i = drop_pos - (direction * lead_index)

	for i in count:
		var pos: Vector2i = start_pos + (direction * i)
		var cell: BoardCell = board.get_cell(pos.y, pos.x)
		if cell == null or cell.is_occupied():
			return []  # Invalid - return empty
		cells.append(cell)

	return cells


func _cancel_multi_drag_preserve_selection(tiles: Array[Tile]) -> void:
	# Restore tiles to their original parents via DragManager
	DragManager.restore_tiles_to_parents()

	# Selection is preserved - tiles remain selected
	_update_interaction_state()
	print("[Main] Multi-drag cancelled, selection preserved")


func _handle_drop_on_discard_pile(tiles: Array[Tile]) -> void:
	# Filter to only hand tiles
	var hand_tiles: Array[Tile] = []
	for tile in tiles:
		if tile.location == Tile.TileLocation.IN_HAND:
			hand_tiles.append(tile)

	if hand_tiles.is_empty():
		# Return board tiles to their cells via DragManager
		DragManager.restore_tiles_to_parents()
		print("[Main] Cannot discard board tiles")
		return

	# Return tiles to their original parents via DragManager
	DragManager.restore_tiles_to_parents()

	# Show confirmation dialog
	discard_dialog.show_confirmation(hand_tiles.size())
	print("[Main] Dropped %d tiles on discard pile, awaiting confirmation" % hand_tiles.size())


func _cancel_drag_to_hand(tile: Tile) -> void:
	# Tile was already restored to parent by DragManager.restore_tiles_to_parents()
	# Just update its state
	tile.location = Tile.TileLocation.IN_HAND
	tile.current_cell = null
	tile.modulate = Color.WHITE

	# Deselect only in single mode
	if not SelectionManager.is_multi_select_enabled():
		SelectionManager.deselect_tile(tile)

	_update_interaction_state()
	_clear_all_cell_hovers()

	print("[Main] Cancelled drag for tile: %s" % tile.name)


func _return_to_original_cell(tile: Tile) -> void:
	if tile.current_cell == null:
		push_error("[Main] Board tile has no current_cell reference!")
		return

	tile.position = Vector2.ZERO
	tile.modulate = Color.WHITE

	print("[Main] Tile %s returned to cell: %s" % [tile.name, tile.current_cell.name])


# === Discard Handlers ===

func _request_discard_confirmation() -> void:
	var selected_tiles: Array[Tile] = SelectionManager.get_selected_tiles()

	# Filter to only hand tiles
	var hand_tiles: Array[Tile] = []
	for tile in selected_tiles:
		if tile.location == Tile.TileLocation.IN_HAND:
			hand_tiles.append(tile)

	if hand_tiles.is_empty():
		print("[Main] No hand tiles selected to discard")
		return

	discard_dialog.show_confirmation(hand_tiles.size())
	EventBus.discard_confirmation_requested.emit(hand_tiles.size())


func _on_discard_confirmed() -> void:
	var selected_tiles: Array[Tile] = SelectionManager.get_selected_tiles()

	# Filter to only hand tiles
	var hand_tiles: Array[Tile] = []
	for tile in selected_tiles:
		if tile.location == Tile.TileLocation.IN_HAND:
			hand_tiles.append(tile)

	if hand_tiles.is_empty():
		return

	# Discard all selected hand tiles
	_discard_tiles(hand_tiles)

	EventBus.discard_confirmed.emit()
	print("[Main] Discard confirmed: %d tiles" % hand_tiles.size())


func _on_discard_cancelled() -> void:
	# Selection is preserved when user cancels
	EventBus.discard_cancelled.emit()
	print("[Main] Discard cancelled, selection preserved")


func _on_discard_pile_tiles_dropped(tiles: Array) -> void:
	# Filter to only hand tiles
	var hand_tiles: Array[Tile] = []
	for tile in tiles:
		if tile is Tile and tile.location == Tile.TileLocation.IN_HAND:
			hand_tiles.append(tile)

	if hand_tiles.is_empty():
		return

	# Show confirmation before discarding
	discard_dialog.show_confirmation(hand_tiles.size())


func _on_discard_pile_peek_requested() -> void:
	# Future feature: show discard pile contents
	var pile: Array[Tile] = HandManager.get_discard_pile()
	print("[Main] Peek requested - Discard pile has %d tiles" % pile.size())
	# TODO: Show discard pile viewer UI


func _discard_tiles(tiles: Array[Tile]) -> void:
	# Deselect all tiles first
	SelectionManager.deselect_all()

	# Discard each tile through HandManager
	for tile in tiles:
		HandManager.discard_tile(tile)

	# Refill hand from tile bag
	var refilled: int = HandManager.refill_hand()
	print("[Main] Discarded %d tiles, refilled %d" % [tiles.size(), refilled])

	_update_interaction_state()


# =============================================================================
# PLAY HANDLERS
# =============================================================================

func _on_play_requested() -> void:
	print("[Main] Play requested")

	# Get unplayed tiles on the board
	var unplayed_tiles: Array[Tile] = _get_unplayed_board_tiles()

	if unplayed_tiles.is_empty():
		print("[Main] No tiles to play")
		return

	# Get positions of unplayed tiles
	var positions: Array[Vector2i] = []
	for tile in unplayed_tiles:
		if tile.current_cell:
			positions.append(tile.current_cell.grid_position)

	# Find all words formed by the placement
	var words: Array = _word_validator.find_formed_words(board, positions)

	print("[Main] Found %d words from %d tiles" % [words.size(), unplayed_tiles.size()])
	for word_info in words:
		print("[Main] Word: '%s' (%s)" % [word_info.word, word_info.direction])

	# Lock all placed tiles (make them permanent)
	for tile in unplayed_tiles:
		tile.is_locked = true
		print("[Main] Locked tile: %s" % tile.name)

	# Play stomp animation
	TileAnimator.animate_stomp_batch(unplayed_tiles)

	# Emit event
	EventBus.tiles_played.emit(unplayed_tiles, words)

	# Update play button state
	_update_play_button_state()

	# For now, just log - score calculation will be added later
	print("[Main] Played %d tiles, formed %d words" % [unplayed_tiles.size(), words.size()])


## Returns all tiles on the board that haven't been played yet (not locked).
func _get_unplayed_board_tiles() -> Array[Tile]:
	var tiles: Array[Tile] = []
	for cell in board.get_all_cells():
		if cell.is_occupied() and not cell.tile.is_locked:
			tiles.append(cell.tile)
	return tiles


## Returns all tiles currently placed on the board.
func _get_all_board_tiles() -> Array[Tile]:
	var tiles: Array[Tile] = []
	for cell in board.get_all_cells():
		if cell.is_occupied():
			tiles.append(cell.tile)
	return tiles


## Updates the play button enabled state based on whether there are unplayed tiles.
func _update_play_button_state() -> void:
	var has_unplayed_tiles: bool = not _get_unplayed_board_tiles().is_empty()
	main_hud.set_play_button_enabled(has_unplayed_tiles)
