extends Node
class_name GameplayController

## GameplayController: Manages all tile-based gameplay interaction.
## Handles tile selection, drag/drop, placement, discard, and play actions.
## Can be enabled/disabled based on game state (e.g., disabled during menus).

# =============================================================================
# SIGNALS
# =============================================================================

signal tile_placement_completed(tile: Tile, cell: BoardCell)
signal tile_returned_to_hand(tile: Tile)
signal play_completed(tiles: Array[Tile], words: Array)

# =============================================================================
# STATE
# =============================================================================

enum InteractionMode {
	IDLE,           # No tile selected, waiting for input
	TILE_SELECTED,  # Tile selected from hand, waiting for placement
	DRAGGING        # Tile being dragged
}

var interaction_mode: InteractionMode = InteractionMode.IDLE
var selected_tile: Tile = null
var _last_placement_success: bool = false
var _is_active: bool = false

# =============================================================================
# DEPENDENCIES (injected via setup)
# =============================================================================

var board: Board = null
var hand: Hand = null
var discard_pile: Control = null
var discard_dialog: CanvasLayer = null
var main_hud: CanvasLayer = null

var _word_validator: WordValidator = null


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_word_validator = WordValidator.new()


## Returns the word validator instance for external scoring.
func get_word_validator() -> WordValidator:
	return _word_validator


func _unhandled_input(event: InputEvent) -> void:
	if not _is_active:
		return

	if event.is_action_pressed("toggle_multi_select"):
		SelectionManager.toggle_mode()

	if event.is_action_pressed("discard_tiles"):
		_request_discard()


## Sets up the controller with required scene references.
func setup(p_board: Board, p_hand: Hand, p_discard_pile: Control, p_discard_dialog: CanvasLayer, p_hud: CanvasLayer) -> void:
	board = p_board
	hand = p_hand
	discard_pile = p_discard_pile
	discard_dialog = p_discard_dialog
	main_hud = p_hud


## Activates the controller and connects all signals.
func activate() -> void:
	if _is_active:
		return
	_is_active = true
	_connect_signals()
	print("[GameplayController] Activated")


## Deactivates the controller and disconnects all signals.
func deactivate() -> void:
	if not _is_active:
		return
	_is_active = false
	_disconnect_signals()
	SelectionManager.deselect_all()
	print("[GameplayController] Deactivated")


func _connect_signals() -> void:
	# Board signals
	if board:
		board.cell_clicked.connect(_on_cell_clicked)
		board.cell_hovered.connect(_on_cell_hovered)
		board.cell_unhovered.connect(_on_cell_unhovered)

	# Discard signals
	if discard_pile:
		discard_pile.tiles_dropped.connect(_on_discard_pile_tiles_dropped)
		discard_pile.discard_clicked.connect(_on_discard_pile_clicked)
		discard_pile.peek_requested.connect(_on_discard_pile_peek_requested)

	# HUD signals
	if main_hud:
		main_hud.play_requested.connect(_on_play_requested)

	# Drag signals
	DragManager.drag_release_requested.connect(_handle_drag_release)


func _disconnect_signals() -> void:
	# Board signals
	if board:
		if board.cell_clicked.is_connected(_on_cell_clicked):
			board.cell_clicked.disconnect(_on_cell_clicked)
		if board.cell_hovered.is_connected(_on_cell_hovered):
			board.cell_hovered.disconnect(_on_cell_hovered)
		if board.cell_unhovered.is_connected(_on_cell_unhovered):
			board.cell_unhovered.disconnect(_on_cell_unhovered)

	# Discard signals
	if discard_pile and discard_pile.tiles_dropped.is_connected(_on_discard_pile_tiles_dropped):
		discard_pile.tiles_dropped.disconnect(_on_discard_pile_tiles_dropped)
	if discard_pile and discard_pile.discard_clicked.is_connected(_on_discard_pile_clicked):
		discard_pile.discard_clicked.disconnect(_on_discard_pile_clicked)
	if discard_pile and discard_pile.peek_requested.is_connected(_on_discard_pile_peek_requested):
		discard_pile.peek_requested.disconnect(_on_discard_pile_peek_requested)

	# HUD signals
	if main_hud and main_hud.play_requested.is_connected(_on_play_requested):
		main_hud.play_requested.disconnect(_on_play_requested)

	# Drag signals
	if DragManager.drag_release_requested.is_connected(_handle_drag_release):
		DragManager.drag_release_requested.disconnect(_handle_drag_release)


# =============================================================================
# PUBLIC API - Called by Main or HandManager when tiles are created
# =============================================================================

## Connects tile signals to this controller. Call when a tile is created.
func register_tile(tile: Tile) -> void:
	if not tile.tile_selected.is_connected(_on_tile_selected):
		tile.tile_selected.connect(_on_tile_selected)
	if not tile.tile_right_clicked.is_connected(_on_tile_right_clicked):
		tile.tile_right_clicked.connect(_on_tile_right_clicked)
	if not tile.tile_drag_started.is_connected(_on_tile_drag_started):
		tile.tile_drag_started.connect(_on_tile_drag_started)
	if not tile.tile_drag_ended.is_connected(_on_tile_drag_ended):
		tile.tile_drag_ended.connect(_on_tile_drag_ended)


# =============================================================================
# TILE SELECTION HANDLERS
# =============================================================================

func _on_tile_selected(tile: Tile) -> void:
	if not _is_active:
		return

	print("[Gameplay] Tile selected: %s" % tile.name)

	# Clicking a board tile while we have selection
	if SelectionManager.has_selection() and tile.location == Tile.TileLocation.ON_BOARD:
		print("[Gameplay] Cannot stack tiles")
		return

	# Clicking a tile that's already on the board (info only)
	if not SelectionManager.has_selection() and tile.location == Tile.TileLocation.ON_BOARD:
		print("[Gameplay] Board tile at cell: %s" % tile.current_cell.name)
		return

	# Hand tile - use SelectionManager
	if tile.location == Tile.TileLocation.IN_HAND:
		SelectionManager.select_tile(tile)
		_update_interaction_state()


func _on_tile_right_clicked(tile: Tile) -> void:
	if not _is_active:
		return

	if SelectionManager.has_selection():
		print("[Gameplay] Cannot remove tile while selection active")
		return

	if tile.current_cell == null:
		print("[Gameplay] Tile is not on board")
		return

	if tile.is_locked:
		print("[Gameplay] Cannot return tile - tile is locked (already played)")
		TileAnimator.animate_shake(tile)
		return

	if hand.is_full():
		print("[Gameplay] Cannot return tile - hand is full")
		TileAnimator.animate_shake(tile)
		return

	_return_tile_to_hand(tile)


func _on_tile_drag_started(tile: Tile) -> void:
	if not _is_active:
		return

	# Safety check - tile should have prevented this, but double-check
	if not tile.can_interact():
		print("[Gameplay] Cannot drag non-interactable tile: %s" % tile.name)
		return

	var tiles_to_drag: Array[Tile] = SelectionManager.get_selected_tiles()

	# Filter out any locked/non-interactable tiles from multi-drag
	var valid_tiles: Array[Tile] = []
	for t in tiles_to_drag:
		if t.can_interact():
			valid_tiles.append(t)

	if tile not in valid_tiles:
		SelectionManager.deselect_all()
		SelectionManager.select_tile(tile)
		valid_tiles = [tile]

	# Set follower tiles (skip lead tile)
	for t in valid_tiles:
		if t != tile:
			if not t.set_as_drag_follower():
				# Tile refused to be a follower (locked), remove from drag
				valid_tiles.erase(t)

	if valid_tiles.is_empty():
		print("[Gameplay] No valid tiles to drag")
		return

	DragManager.start_drag(tile, valid_tiles)

	if valid_tiles.size() > 1:
		print("[Gameplay] Multi-drag started with %d tiles" % valid_tiles.size())


func _on_tile_drag_ended(tile: Tile) -> void:
	if not _is_active:
		return
	if not DragManager.is_dragging:
		return
	if tile != DragManager.lead_tile:
		return
	_handle_drag_release(tile)


func _handle_drag_release(tile: Tile) -> void:
	if not _is_active:
		return
	if not DragManager.is_dragging:
		return

	var dragged_tiles: Array[Tile] = DragManager.get_dragged_tiles()
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()

	if discard_pile and discard_pile.is_drop_target(mouse_pos):
		_handle_drop_on_discard_pile(dragged_tiles)
		DragManager.end_drag(false)
		return

	var cell: BoardCell = _get_cell_under_mouse()

	var cell_name: String = String(cell.name) if cell else "none"
	print("[Gameplay] Drag ended - Tile: %s | Location: %s | Cell: %s | Multi: %d" % [
		tile.name,
		Tile.TileLocation.keys()[tile.location],
		cell_name,
		dragged_tiles.size()
	])

	# Unified drop handling for single and multi-tile
	_handle_tile_drop(cell, dragged_tiles)
	DragManager.end_drag(_last_placement_success)


# =============================================================================
# CELL HANDLERS
# =============================================================================

func _on_cell_clicked(cell: BoardCell) -> void:
	if not _is_active:
		return

	var selected_tiles: Array[Tile] = SelectionManager.get_selected_tiles()

	if selected_tiles.is_empty():
		print("[Gameplay] No tile selected")
		return

	# Filter out locked tiles - they cannot be moved
	var movable_tiles: Array[Tile] = []
	for tile in selected_tiles:
		if not tile.is_locked:
			movable_tiles.append(tile)

	if movable_tiles.is_empty():
		print("[Gameplay] All selected tiles are locked")
		SelectionManager.deselect_all()
		_update_interaction_state()
		return

	selected_tiles = movable_tiles

	if cell.is_occupied():
		print("[Gameplay] Cell occupied: %s" % cell.name)
		return

	if selected_tiles.size() > 1:
		var cells: Array[BoardCell] = _get_sequential_cells(cell, selected_tiles.size())
		if cells.is_empty():
			print("[Gameplay] Cannot place %d tiles starting at %s" % [selected_tiles.size(), cell.name])
			return

		for i in selected_tiles.size():
			_place_tile_on_cell_silent(selected_tiles[i], cells[i])

		SelectionManager.deselect_all()
		_update_interaction_state()
		print("[Gameplay] Placed %d tiles starting at %s" % [selected_tiles.size(), cell.name])
	else:
		_place_tile_on_cell(selected_tiles[0], cell)


func _on_cell_hovered(cell: BoardCell) -> void:
	if not _is_active:
		return
	if not SelectionManager.has_selection():
		return

	var selected_count: int = SelectionManager.get_selection_count()

	if selected_count > 1:
		var cells: Array[BoardCell] = _get_sequential_cells(cell, selected_count)
		if cells.is_empty():
			cell.show_invalid_hover()
		else:
			for c in cells:
				c.show_valid_hover()
	else:
		if cell.is_occupied():
			cell.show_invalid_hover()
		else:
			cell.show_valid_hover()


func _on_cell_unhovered(cell: BoardCell) -> void:
	if not _is_active:
		return
	cell.clear_hover()


# =============================================================================
# TILE PLACEMENT
# =============================================================================

func _place_tile_on_cell(tile: Tile, cell: BoardCell) -> void:
	if cell.is_occupied():
		return

	_place_tile_on_cell_silent(tile, cell)
	SelectionManager.deselect_tile(tile)
	_update_interaction_state()


func _place_tile_on_cell_silent(tile: Tile, cell: BoardCell) -> void:
	if cell.is_occupied():
		return

	# Reparent tile to cell's tile anchor
	if tile.get_parent():
		tile.get_parent().remove_child(tile)
	cell.tile_anchor.add_child(tile)
	tile.position = Vector2.ZERO

	# Use atomic state management to ensure tile-cell binding consistency
	tile.attach_to_cell(cell)

	_clear_all_cell_hovers()

	EventBus.tile_placed.emit(tile, cell)
	tile_placement_completed.emit(tile, cell)
	_update_play_button_state()


func _return_tile_to_hand(tile: Tile) -> void:
	_return_tile_to_hand_internal(tile, false)


func _return_tile_to_hand_internal(tile: Tile, preserve_selection: bool) -> void:
	# Handle tiles not on board (e.g., in drag container)
	if tile.current_cell == null and tile.location != Tile.TileLocation.IN_HAND:
		if tile.get_parent():
			tile.get_parent().remove_child(tile)
		hand.add_tile(tile)
		tile.move_to_hand()  # Atomic state update
		tile.modulate = Color.WHITE
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

	_update_interaction_state()
	_clear_all_cell_hovers()

	EventBus.tile_removed.emit(tile, cell)
	tile_returned_to_hand.emit(tile)
	_update_play_button_state()
	print("[Gameplay] Returned tile %s from cell %s to hand (animated)" % [tile.name, cell.name])


# =============================================================================
# DROP HANDLERS
# =============================================================================

## Unified drop handler for single and multi-tile drops.
## Validates placement, handles cancellation with animation, or places tiles.
func _handle_tile_drop(drop_cell: BoardCell, tiles: Array[Tile]) -> void:
	if tiles.is_empty():
		_last_placement_success = false
		return

	# Determine if any tiles are from the board (vs hand)
	var has_board_tiles: bool = _any_tiles_on_board(tiles)

	# Get target cells for placement
	var target_cells: Array[BoardCell] = _get_target_cells_for_drop(drop_cell, tiles)

	# Check if placement is valid
	if target_cells.is_empty():
		_handle_invalid_drop(tiles, has_board_tiles, drop_cell)
		_last_placement_success = false
		return

	# Valid drop - restore tiles and place them
	_execute_valid_drop(tiles, target_cells)
	_last_placement_success = true


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

	return _get_sequential_cells_centered(drop_cell, tiles.size(), lead_index)


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
				_return_to_original_cell(tile)
	else:
		# Hand tiles - animate back with smooth transition
		_animate_tiles_back_to_hand(tiles)

	_update_interaction_state()
	_clear_all_cell_hovers()


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
		_place_tile_on_cell_silent(tiles[i], target_cells[i])

	SelectionManager.deselect_all()
	_update_interaction_state()
	print("[Gameplay] Placed %d tile(s) on board" % tiles.size())


func _handle_drop_on_discard_pile(tiles: Array[Tile]) -> void:
	var hand_tiles: Array[Tile] = []
	for tile in tiles:
		if tile.location == Tile.TileLocation.IN_HAND:
			hand_tiles.append(tile)

	if hand_tiles.is_empty():
		DragManager.restore_tiles_to_parents()
		print("[Gameplay] Cannot discard board tiles")
		return

	DragManager.restore_tiles_to_parents()
	_discard_tiles_animated(hand_tiles)


# =============================================================================
# CELL HELPERS
# =============================================================================

func _get_sequential_cells(start: BoardCell, count: int) -> Array[BoardCell]:
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


func _get_sequential_cells_centered(drop_cell: BoardCell, count: int, lead_index: int) -> Array[BoardCell]:
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


func _return_to_original_cell(tile: Tile) -> void:
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


func _get_cell_under_mouse() -> BoardCell:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	return board.get_cell_at_position(mouse_pos)


func _clear_all_cell_hovers() -> void:
	for cell in board.get_all_cells():
		cell.clear_hover()


# =============================================================================
# DISCARD HANDLERS
# =============================================================================

## Discards selected hand tiles directly (no confirmation).
func _request_discard() -> void:
	var selected_tiles: Array[Tile] = SelectionManager.get_selected_tiles()

	var hand_tiles: Array[Tile] = []
	for tile in selected_tiles:
		if tile.location == Tile.TileLocation.IN_HAND:
			hand_tiles.append(tile)

	if hand_tiles.is_empty():
		print("[Gameplay] No hand tiles selected to discard")
		return

	_discard_tiles_animated(hand_tiles)


func _on_discard_pile_clicked() -> void:
	_request_discard()


func _on_discard_pile_tiles_dropped(tiles: Array) -> void:
	var hand_tiles: Array[Tile] = []
	for tile in tiles:
		if tile is Tile and tile.location == Tile.TileLocation.IN_HAND:
			hand_tiles.append(tile)

	if hand_tiles.is_empty():
		return

	_discard_tiles_animated(hand_tiles)


func _on_discard_pile_peek_requested() -> void:
	var pile: Array[Tile] = HandManager.get_discard_pile()
	print("[Gameplay] Peek requested - Discard pile has %d tiles" % pile.size())


## Animates tiles to discard pile, then discards them.
func _discard_tiles_animated(tiles: Array[Tile]) -> void:
	if tiles.is_empty():
		return

	SelectionManager.deselect_all()

	# Get discard pile center position for animation target
	var target_pos: Vector2 = _get_discard_pile_center()

	# Animate tiles to discard pile, then actually discard
	TileAnimator.animate_discard_batch(tiles, target_pos, func():
		_complete_discard(tiles)
	)

	print("[Gameplay] Animating %d tiles to discard pile" % tiles.size())


## Completes the discard after animation finishes.
func _complete_discard(tiles: Array[Tile]) -> void:
	for tile in tiles:
		# Reset visual state before discarding
		tile.scale = Vector2.ONE
		tile.modulate = Color.WHITE
		HandManager.discard_tile(tile)

	var refilled: int = HandManager.refill_hand()
	print("[Gameplay] Discarded %d tiles, refilled %d" % [tiles.size(), refilled])

	_update_interaction_state()


## Gets the center position of the discard pile for animation targeting.
func _get_discard_pile_center() -> Vector2:
	if discard_pile:
		return discard_pile.global_position + (discard_pile.size / 2.0)
	return Vector2.ZERO


# =============================================================================
# PLAY HANDLERS
# =============================================================================

func _on_play_requested() -> void:
	if not _is_active:
		return

	print("[Gameplay] Play requested")

	var unplayed_tiles: Array[Tile] = _get_unplayed_board_tiles()

	if unplayed_tiles.is_empty():
		print("[Gameplay] No tiles to play")
		return

	var positions: Array[Vector2i] = []
	for tile in unplayed_tiles:
		if tile.current_cell:
			positions.append(tile.current_cell.grid_position)

	var words: Array = _word_validator.find_formed_words(board, positions)

	print("[Gameplay] Found %d words from %d tiles" % [words.size(), unplayed_tiles.size()])
	for word_info in words:
		print("[Gameplay] Word: '%s' (%s)" % [word_info.word, word_info.direction])

	for tile in unplayed_tiles:
		tile.set_locked(true)  # Use setter to update visuals

	# Clear any selection - locked tiles cannot remain selected
	SelectionManager.deselect_all()
	_update_interaction_state()

	TileAnimator.animate_stomp_batch(unplayed_tiles)

	EventBus.tiles_played.emit(unplayed_tiles, words)
	play_completed.emit(unplayed_tiles, words)

	_update_play_button_state()
	print("[Gameplay] Played %d tiles, formed %d words" % [unplayed_tiles.size(), words.size()])


func _get_unplayed_board_tiles() -> Array[Tile]:
	var tiles: Array[Tile] = []
	for cell in board.get_all_cells():
		if cell.is_occupied() and not cell.tile.is_locked:
			tiles.append(cell.tile)
	return tiles


func _update_play_button_state() -> void:
	if main_hud:
		var has_unplayed_tiles: bool = not _get_unplayed_board_tiles().is_empty()
		main_hud.set_play_button_enabled(has_unplayed_tiles)


# =============================================================================
# STATE MANAGEMENT
# =============================================================================

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


func _set_hand_tiles_hover_enabled(enabled: bool) -> void:
	if hand:
		for tile in hand.get_tiles():
			tile.allow_hover_feedback = enabled
