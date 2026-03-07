extends Node
class_name GameplayController

## GameplayController: Coordinator for tile-based gameplay interaction.
## Routes input events and signals to specialized handlers:
##   - TilePlacementHandler: tile placement/return, cell queries
##   - DropHandler: drag-and-drop validation and execution
##   - PlayHandler: play submission, scoring, auto-end-round
## Retains discard logic, interaction state, and signal management.

# =============================================================================
# SIGNALS
# =============================================================================

signal tile_placement_completed(tile: Tile, cell: BoardCell)
signal tile_returned_to_hand(tile: Tile)
signal play_completed(tiles: Array[Tile], words: Array)
signal pause_requested

# =============================================================================
# STATE
# =============================================================================

enum InteractionMode {
	IDLE,           # No tile selected, waiting for input
	TILE_SELECTED,  # Tile selected from hand, waiting for placement
	DRAGGING        # Tile being dragged
}

var _interaction_mode: InteractionMode = InteractionMode.IDLE
var _selected_tile: Tile = null
var _is_active: bool = false
var _cursor: FocusCursor = null

# =============================================================================
# DEPENDENCIES (injected via setup)
# =============================================================================

var board: Board = null
var hand: Hand = null
var discard_pile: Control = null
var discard_dialog: CanvasLayer = null
var main_hud: CanvasLayer = null
var _selection: SelectionManager = null

# =============================================================================
# LOCAL MANAGERS
# =============================================================================

var _drag_mgr: DragManager = null

# =============================================================================
# HANDLERS
# =============================================================================

var _placement: TilePlacementHandler = null
var _drop: DropHandler = null
var _play: PlayHandler = null

# =============================================================================
# SIGNAL CONNECTION TRACKING
# =============================================================================

var _tracker: SignalTracker = SignalTracker.new()

var _word_validator: WordValidator = null
var _play_state_manager: PlayStateManager = null
var _word_finder: WordFinder = null

## Cached validation results from the last real-time scan.
var _current_valid_words: Array = []
## Positions currently highlighted as part of valid words.
var _highlighted_positions: Array[Vector2i] = []


# =============================================================================
# LIFECYCLE
# =============================================================================

## Returns the word validator instance for external scoring.
func get_word_validator() -> WordValidator:
	return _play.get_word_validator()
func _ready() -> void:
	_word_validator = WordValidator.new()
	_word_validator.load_word_list("res://data/dictionaries/english_words.txt")

	_word_finder = WordFinder.new()
	_word_finder.set_validator(_word_validator)

	_play_state_manager = PlayStateManager.new()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_active:
		return

	if event.is_action_pressed(KeyAction.PAUSE_GAME):
		pause_requested.emit()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(KeyAction.TOGGLE_MULTI):
		_selection.toggle_mode()

	if event.is_action_pressed(KeyAction.DISCARD_TILES):
		_request_discard()

	if event.is_action_pressed(KeyAction.PLAY_HAND):
		_on_play_requested()
		get_viewport().set_input_as_handled()


## Sets up the controller with required scene references and creates handlers.
func setup(p_board: Board, p_hand: Hand, p_discard_pile: Control, p_discard_dialog: CanvasLayer, p_hud: CanvasLayer, p_selection: SelectionManager, p_cursor: FocusCursor = null) -> void:
	board = p_board
	hand = p_hand
	discard_pile = p_discard_pile
	discard_dialog = p_discard_dialog
	main_hud = p_hud
	_selection = p_selection
	_cursor = p_cursor

	# Create DragManager as local child
	_drag_mgr = DragManager.new()
	_drag_mgr.name = "DragManager"
	add_child(_drag_mgr)

	_placement = TilePlacementHandler.new()
	_placement.setup(board, hand, _selection)

	_drop = DropHandler.new()
	_drop.setup(_placement, hand, _selection, _drag_mgr)

	_play = PlayHandler.new()
	_play.setup(board, _selection)
	_play.play_completed.connect(_on_play_completed_internal)
	_play.play_completed.connect(func(tiles, words): play_completed.emit(tiles, words))
	_play.play_button_changed.connect(
		func(enabled, mode):
			main_hud.set_play_button_enabled(enabled)
			main_hud.set_play_button_mode(mode)
	)

	# Initialize grid cache to match board dimensions
	if board and _play_state_manager:
		_play_state_manager.initialize_grid(board.rows, board.columns)


## Activates the controller and connects all signals.
func activate() -> void:
	if _is_active:
		return
	_is_active = true
	_connect_signals()
	_play.update_play_button_state()
	print("[GameplayController] Activated")


## Deactivates the controller and disconnects all signals.
func deactivate() -> void:
	if not _is_active:
		return
	_is_active = false
	_tracker.disconnect_all()
	_selection.deselect_all()
	print("[GameplayController] Deactivated")


# =============================================================================
# SIGNAL CONNECTION MANAGEMENT
# =============================================================================

func _connect_signals() -> void:
	if board:
		_tracker.track(board.cell_clicked, _on_cell_clicked)
		_tracker.track(board.cell_hovered, _on_cell_hovered)
		_tracker.track(board.cell_unhovered, _on_cell_unhovered)

	if discard_pile:
		_tracker.track(discard_pile.tiles_dropped, _on_discard_pile_tiles_dropped)
		_tracker.track(discard_pile.discard_clicked, _on_discard_pile_clicked)
		_tracker.track(discard_pile.peek_requested, _on_discard_pile_peek_requested)

	if main_hud:
		_tracker.track(main_hud.play_requested, _on_play_requested)

	_tracker.track(_drag_mgr.drag_release_requested, _handle_drag_release)
	_tracker.track(EventBus.hand_count_changed, _on_tile_supply_changed)
	_tracker.track(EventBus.bag_count_changed, _on_tile_supply_changed)

	if _cursor:
		_tracker.track(_cursor.cursor_confirmed, _on_cursor_confirmed)
		_tracker.track(_cursor.cursor_cancelled, _on_cursor_cancelled)
		_tracker.track(_cursor.cursor_moved,     _on_cursor_moved)
		_tracker.track(_cursor.letter_typed, _on_cursor_letter_typed)
		_tracker.track(_cursor.backspace_pressed, _on_cursor_backspace_pressed)


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


## Returns a board tile to hand, syncing all state. For use by debug commands.
func debug_return_tile_to_hand(tile: Tile) -> void:
	if tile == null or tile.current_cell == null:
		return

	var cell_pos: Vector2i = tile.current_cell.grid_position
	_play_state_manager.remove_tile_at(cell_pos)
	_placement.return_tile_to_hand(tile)
	_run_realtime_word_scan()
	_play.update_play_button_state()


# =============================================================================
# TILE SELECTION HANDLERS
# =============================================================================

func _on_tile_selected(tile: Tile) -> void:
	if not _is_active:
		return

	print("[Gameplay] Tile selected: %s" % tile.name)

	match tile.location:
		Tile.TileLocation.ON_BOARD:
			if _selection.has_selection():
				print("[Gameplay] Cannot stack tiles")
			else:
				print("[Gameplay] Board tile at cell: %s" % tile.current_cell.name)
		Tile.TileLocation.IN_HAND:
			_selection.select_tile(tile)
			if _cursor and _cursor.get_typing_session() != null:
				_cursor.set_typing_session(null)
			_update_interaction_state()


func _on_tile_right_clicked(tile: Tile) -> void:
	if not _is_active:
		return

	if _selection.has_selection():
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

	# PSM: remove tile from grid cache before returning to hand
	var cell_pos: Vector2i = tile.current_cell.grid_position
	_play_state_manager.remove_tile_at(cell_pos)

	_placement.return_tile_to_hand(tile)

	# Re-scan words after removal
	_run_realtime_word_scan()
	_update_interaction_state()
	tile_returned_to_hand.emit(tile)
	_play.update_play_button_state()


func _on_cursor_confirmed(pos: CursorPosition) -> void:
	if not _is_active:
		return

	if pos.is_hand():
		var tile: Tile = hand.get_tile_at(pos.hand_index)
		if tile == null:
			return
		_on_tile_selected(tile)
		if _selection.has_selection() and _cursor:
			_cursor.set_held_tile(tile)

	elif pos.is_board():
		var cell: BoardCell = board.get_cell(pos.board_coords.y, pos.board_coords.x)
		if cell == null:
			return
		if _selection.has_selection():
			var movable: Array[Tile] = _selection.get_selected_tiles().filter(
				func(t: Tile) -> bool: return not t.is_locked
			)
			if not movable.is_empty() and not cell.is_occupied():
				_place_tiles_on_cell(movable, cell, true)
				if _cursor:
					_cursor.clear_held_tile()
			elif cell.is_occupied():
				TileAnimator.animate_shake(movable[0])
		elif cell.is_occupied():
			var board_tile: Tile = cell.tile
			if not board_tile.is_locked:
				_placement.return_tile_to_hand(board_tile)
				_selection.select_tile(board_tile)
				if _cursor:
					_cursor.set_held_tile(board_tile)
				_update_interaction_state()
				tile_returned_to_hand.emit(board_tile)
			else:
				TileAnimator.animate_shake(board_tile)
		else:
			_on_play_requested()


func _on_cursor_cancelled(_pos: CursorPosition) -> void:
	if not _is_active:
		return
	_selection.deselect_all()
	if _cursor:
		_cursor.clear_held_tile()
	_update_interaction_state()
	_play.update_play_button_state()


func _on_cursor_moved(pos: CursorPosition) -> void:
	if not _is_active:
		return
	_placement.clear_all_cell_hovers()
	if pos.is_board():
		var cell: BoardCell = board.get_cell(pos.board_coords.y, pos.board_coords.x)
		if cell:
			_on_cell_hovered(cell)


# =============================================================================
# CURSOR TYPING HANDLERS
# =============================================================================

func _on_cursor_letter_typed(letter: String) -> void:
	if not _is_active or _cursor == null:
		return
	var session := _cursor.get_typing_session()
	if session == null:
		return

	var tile := hand.find_tile_by_letter(letter)
	if tile == null:
		return

	var cell := session.get_cursor_cell()
	if cell == null:
		return

	var swapped: Tile = null
	if cell.is_occupied() and not cell.tile.is_locked:
		swapped = cell.tile
		_play_state_manager.remove_tile_at(cell.grid_position)
		_placement.return_tile_to_hand(swapped, true)

	_placement.place_tile_on_cell_animated(tile, cell)
	_play_state_manager.place_temporary_tile(tile, cell.grid_position)

	var new_session := session.with_placement(tile, swapped).advance()
	_cursor.set_typing_session(new_session)

	_run_realtime_word_scan()
	_play.update_play_button_state()


func _on_cursor_backspace_pressed() -> void:
	if not _is_active or _cursor == null:
		return
	var session := _cursor.get_typing_session()
	if session == null:
		return

	var entry := session.last_placement()
	if entry.is_empty():
		return

	var tile_placed: Tile = entry.tile_placed
	var tile_swapped: Tile = entry.tile_swapped
	var pos: Vector2i = entry.pos

	_play_state_manager.remove_tile_at(pos)
	_placement.return_tile_to_hand(tile_placed)

	if tile_swapped and tile_swapped.location == Tile.TileLocation.IN_HAND:
		var cell := board.get_cell(pos.y, pos.x)
		if cell and not cell.is_occupied():
			hand.remove_tile(tile_swapped)
			cell.tile_anchor.add_child(tile_swapped)
			tile_swapped.position = Vector2.ZERO
			tile_swapped.attach_to_cell(cell)
			_play_state_manager.place_temporary_tile(tile_swapped, pos)

	_cursor.set_typing_session(session.retreat())

	_run_realtime_word_scan()
	_play.update_play_button_state()


## Builds the list of tiles to drag. Ensures lead tile is always included.
## Removes followers that refuse drag. Resets selection if lead was not selected.
func _collect_drag_candidates(tile: Tile) -> Array[Tile]:
	var candidates: Array[Tile] = []
	for t in _selection.get_selected_tiles():
		if t.can_interact():
			candidates.append(t)

	if tile not in candidates:
		_selection.deselect_all()
		_selection.select_tile(tile)
		return [tile]

	for t in candidates.duplicate():
		if t != tile and not t.set_as_drag_follower():
			candidates.erase(t)

	return candidates


func _on_tile_drag_started(tile: Tile) -> void:
	if not _is_active or not tile.can_interact():
		return

	var valid_tiles := _collect_drag_candidates(tile)
	if valid_tiles.is_empty():
		print("[Gameplay] No valid tiles to drag")
		return

	_drag_mgr.start_drag(tile, valid_tiles)
	
	# Remove board tiles from PSM grid temporarily during drag
	for t in valid_tiles:
		if t.location == Tile.TileLocation.ON_BOARD and t.current_cell:
			_play_state_manager.remove_temporary_tile(t.current_cell.grid_position)

	# Re-scan words - automatically updates highlights for affected rows/columns only
	# Unaffected words in other rows/columns keep their highlights
	if _any_tiles_on_board(valid_tiles):
		_run_realtime_word_scan()
		_play.update_play_button_state()

	if valid_tiles.size() > 1:
		print("[Gameplay] Multi-drag started with %d tiles" % valid_tiles.size())


func _on_tile_drag_ended(tile: Tile) -> void:
	if not _is_active:
		return
	if not _drag_mgr.is_dragging:
		return
	if tile != _drag_mgr.lead_tile:
		return
	_handle_drag_release(tile)


func _handle_drag_release(tile: Tile) -> void:
	if not _is_active:
		return
	if not _drag_mgr.is_dragging:
		return

	var dragged_tiles: Array[Tile] = _drag_mgr.get_dragged_tiles()
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()

	if discard_pile and discard_pile.is_drop_target(mouse_pos):
		_handle_drop_on_discard_pile(dragged_tiles)
		_drag_mgr.end_drag(false)
		return

	var cell: BoardCell = _placement.get_cell_under_mouse(get_viewport())

	var cell_name: String = String(cell.name) if cell else "none"
	print("[Gameplay] Drag ended - Tile: %s | Location: %s | Cell: %s | Multi: %d" % [
		tile.name,
		Tile.TileLocation.keys()[tile.location],
		cell_name,
		dragged_tiles.size()
	])

	# Fast path: Check if tiles are being dropped back on their original cells (no-op)
	if _is_dropping_on_same_cells(dragged_tiles, cell):
		_handle_same_cell_drop(dragged_tiles)
		_drag_mgr.end_drag(true)
		return

	# Handle single-tile swap (drop on occupied cell)
	if dragged_tiles.size() == 1 and cell != null and cell.is_occupied():
		var tile_to_place: Tile = dragged_tiles[0]
		var tile_on_cell: Tile = cell.tile
		
		if not tile_on_cell.is_locked:
			_drag_mgr.restore_tiles_to_parents()
			
			# PSM: remove both tiles before swap
			if tile_to_place.current_cell:
				_play_state_manager.remove_tile_at(tile_to_place.current_cell.grid_position)
			if tile_on_cell.current_cell:
				_play_state_manager.remove_tile_at(tile_on_cell.current_cell.grid_position)
			
			_placement.swap_tiles(tile_to_place, tile_on_cell, cell)
			_selection.deselect_all()
			
			# PSM: add swapped tiles back to grid
			if tile_to_place.current_cell:
				_play_state_manager.place_temporary_tile(tile_to_place, tile_to_place.current_cell.grid_position)
			if tile_on_cell.current_cell:
				_play_state_manager.place_temporary_tile(tile_on_cell, tile_on_cell.current_cell.grid_position)
			
			_run_realtime_word_scan()
			_update_interaction_state()
			_play.update_play_button_state()
			_drag_mgr.end_drag(true)
			return
		else:
			print("[Gameplay] Cannot swap with locked tile: %s" % tile_on_cell.name)
			# Fall through to invalid drop handling

	# Unified drop handling for single and multi-tile
	var success := _drop.handle_tile_drop(cell, dragged_tiles)

	if success:
		# PSM: sync newly placed tiles into grid cache
		for t in dragged_tiles:
			if t.current_cell:
				_play_state_manager.place_temporary_tile(t, t.current_cell.grid_position)
	else:
		# PSM: restore board tiles that were removed at drag start
		for t in dragged_tiles:
			if t.location == Tile.TileLocation.ON_BOARD and t.current_cell:
				_play_state_manager.place_temporary_tile(t, t.current_cell.grid_position)

	# Re-scan words after any drop outcome
	_run_realtime_word_scan()
	_update_interaction_state()
	_play.update_play_button_state()
	_drag_mgr.end_drag(success)


# =============================================================================
# CELL HANDLERS
# =============================================================================

## Places one or more movable tiles starting at the target cell.
func _place_tiles_on_cell(movable: Array[Tile], cell: BoardCell, animated: bool = true) -> void:
	if movable.size() > 1:
		var cells: Array[BoardCell] = _placement.get_sequential_cells(cell, movable.size())
		if cells.is_empty():
			print("[Gameplay] Cannot place %d tiles starting at %s" % [movable.size(), cell.name])
			return
		# PSM: remove from old positions if tiles are moving between board cells
		for i in movable.size():
			if movable[i].current_cell:
				_play_state_manager.remove_tile_at(movable[i].current_cell.grid_position)
		if animated:
			_placement.place_tiles_on_cells_animated(movable, cells)
		else:
			for i in movable.size():
				_placement.place_tile_on_cell_silent(movable[i], cells[i])
		# PSM: add new placements
		for i in movable.size():
			_play_state_manager.place_temporary_tile(movable[i], cells[i].grid_position)
		print("[Gameplay] Placed %d tiles starting at %s" % [movable.size(), cell.name])
	else:
		# PSM: remove from old position if tile is moving between board cells
		if movable[0].current_cell:
			_play_state_manager.remove_tile_at(movable[0].current_cell.grid_position)
		if animated:
			_placement.place_tile_on_cell_animated(movable[0], cell)
		else:
			_placement.place_tile_on_cell(movable[0], cell)
		_play_state_manager.place_temporary_tile(movable[0], cell.grid_position)
	_selection.deselect_all()
	_run_realtime_word_scan()
	_update_interaction_state()
	_play.update_play_button_state()
	tile_placement_completed.emit(movable[0], cell)


func _on_cell_clicked(cell: BoardCell) -> void:
	if not _is_active:
		return

	# Move cursor to cell on empty cell click when no hand selection active
	if not cell.is_occupied() and not _selection.has_selection():
		if _cursor:
			_cursor.move_to_board_cell(cell.grid_position)
		return

	var selected: Array[Tile] = _selection.get_selected_tiles()
	if selected.is_empty():
		return

	var movable: Array[Tile] = selected.filter(func(t): return not t.is_locked)
	if movable.is_empty():
		print("[Gameplay] All selected tiles are locked")
		_selection.deselect_all()
		_update_interaction_state()
		return

	# Handle tile swap for single-tile selection
	if movable.size() == 1 and cell.is_occupied():
		var tile_to_place: Tile = movable[0]
		var tile_on_cell: Tile = cell.tile
		
		if tile_on_cell.is_locked:
			print("[Gameplay] Cannot swap with locked tile: %s" % tile_on_cell.name)
			return
		
		# PSM: remove both tiles before swap
		if tile_to_place.current_cell:
			_play_state_manager.remove_tile_at(tile_to_place.current_cell.grid_position)
		if tile_on_cell.current_cell:
			_play_state_manager.remove_tile_at(tile_on_cell.current_cell.grid_position)
		
		_placement.swap_tiles(tile_to_place, tile_on_cell, cell)
		_selection.deselect_all()
		
		# PSM: add swapped tiles back to grid
		if tile_to_place.current_cell:
			_play_state_manager.place_temporary_tile(tile_to_place, tile_to_place.current_cell.grid_position)
		if tile_on_cell.current_cell:
			_play_state_manager.place_temporary_tile(tile_on_cell, tile_on_cell.current_cell.grid_position)
		
		_run_realtime_word_scan()
		_update_interaction_state()
		_play.update_play_button_state()
		return

	# Multi-tile placement requires unoccupied cells
	if movable.size() > 1 and cell.is_occupied():
		print("[Gameplay] Cell occupied: %s" % cell.name)
		return

	_place_tiles_on_cell(movable, cell)


func _on_cell_hovered(cell: BoardCell) -> void:
	if not _is_active:
		return
	if not _selection.has_selection():
		return

	var selected_count: int = _selection.get_selection_count()

	if selected_count > 1:
		var cells: Array[BoardCell] = _placement.get_sequential_cells(cell, selected_count)
		if cells.is_empty():
			cell.show_invalid_hover()
		else:
			for c in cells:
				c.show_valid_hover()
	else:
		# Single-tile: Show valid for empty cells or swappable tiles
		if cell.is_occupied():
			if cell.tile.is_locked:
				cell.show_invalid_hover()  # Cannot swap with locked tile
			else:
				cell.show_valid_hover()     # Can swap with unlocked tile
		else:
			cell.show_valid_hover()         # Can place on empty cell


func _on_cell_unhovered(cell: BoardCell) -> void:
	if not _is_active:
		return
	cell.clear_hover()
	cell.clear_hover()

## Checks if any tiles in the array are currently on the board.
func _any_tiles_on_board(tiles: Array[Tile]) -> bool:
	for tile in tiles:
		if tile.location == Tile.TileLocation.ON_BOARD:
			return true
	return false



# =============================================================================
# CELL HELPERS
# =============================================================================

func _return_to_original_cell(tile: Tile) -> void:
	if tile.current_cell == null:
		push_error("[Gameplay] Board tile has no current_cell reference!")
		return

	# Verify cell binding is restored (should have been done by restore_tiles_to_parents)
	if not tile.has_active_cell_binding():
		push_warning("[Gameplay] Cell binding not active, restoring...")
		tile.restore_cell_binding()

	# Restore tile to PSM grid at original position
	_play_state_manager.place_temporary_tile(tile, tile.current_cell.grid_position)

	tile.position = Vector2.ZERO
	tile.modulate = Color.WHITE
	print("[Gameplay] Tile %s returned to cell: %s" % [tile.name, tile.current_cell.name])


## Checks if tiles are being dropped back on their original cells (no-op drag).
func _is_dropping_on_same_cells(tiles: Array[Tile], drop_cell: BoardCell) -> bool:
	if drop_cell == null:
		return false
	
	# Check if all tiles are board tiles being dropped on their original cells
	for i in tiles.size():
		var tile: Tile = tiles[i]
		
		# Must be a board tile
		if tile.location != Tile.TileLocation.ON_BOARD:
			return false
		
		# Must have original cell reference
		if tile.current_cell == null:
			return false
		
		# Calculate expected cell for this tile in the drop sequence
		var expected_cell: BoardCell
		if tiles.size() == 1:
			expected_cell = drop_cell
		else:
			# Multi-tile: calculate offset from drop_cell
			var lead_tile: Tile = _drag_mgr.lead_tile
			var lead_index: int = tiles.find(lead_tile)
			if lead_index == -1:
				lead_index = 0
			var offset: int = i - lead_index
			var target_pos: Vector2i = drop_cell.grid_position + Vector2i(offset, 0)
			expected_cell = board.get_cell_at_grid_position(target_pos.x, target_pos.y)
			
			if expected_cell == null:
				return false
		
		# Check if tile is being dropped on its original cell
		if tile.current_cell != expected_cell:
			return false
	
	return true


## Handles same-cell drop by restoring PSM state and rescanning highlights.
func _handle_same_cell_drop(tiles: Array[Tile]) -> void:
	print("[Gameplay] Same-cell drop detected - restoring state for %d tile(s)" % tiles.size())
	
	# Restore tiles to parents (they're already in the right place visually)
	_drag_mgr.restore_tiles_to_parents()
	
	# Restore PSM state for all tiles
	for tile in tiles:
		if tile.location == Tile.TileLocation.ON_BOARD and tile.current_cell:
			_return_to_original_cell(tile)
	
	# Re-scan to restore word highlights
	_run_realtime_word_scan()
	_play.update_play_button_state()
	
	_update_interaction_state()
	_clear_all_cell_hovers()


func _clear_all_cell_hovers() -> void:
	for cell in board.get_all_cells():
		cell.clear_hover()


# =============================================================================
# DISCARD HANDLERS
# =============================================================================

## Discards selected hand tiles directly (no confirmation).
func _request_discard() -> void:
	var _selected_tiles: Array[Tile] = _selection.get_selected_tiles()

	var hand_tiles: Array[Tile] = []
	for tile in _selected_tiles:
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


func _handle_drop_on_discard_pile(tiles: Array[Tile]) -> void:
	var hand_tiles: Array[Tile] = []
	for tile in tiles:
		if tile.location == Tile.TileLocation.IN_HAND:
			hand_tiles.append(tile)

	if hand_tiles.is_empty():
		_drag_mgr.restore_tiles_to_parents()
		print("[Gameplay] Cannot discard board tiles")
		return

	_drag_mgr.restore_tiles_to_parents()
	_discard_tiles_animated(hand_tiles)


## Animates tiles to discard pile, then discards them.
func _discard_tiles_animated(tiles: Array[Tile]) -> void:
	if tiles.is_empty():
		return

	_selection.deselect_all()

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
		tile.modulate = Color.WHITE  # Reset for discard (tile leaves play)
		HandManager.discard_tile(tile)

	var refilled: int = HandManager.refill_hand()
	print("[Gameplay] Discarded %d tiles, refilled %d" % [tiles.size(), refilled])

	_update_interaction_state()
	_play.update_play_button_state()


## Gets the center position of the discard pile for animation targeting.
func _get_discard_pile_center() -> Vector2:
	if discard_pile:
		return discard_pile.global_position + (discard_pile.size / 2.0)
	return Vector2.ZERO


func _on_tile_supply_changed(_count: int) -> void:
	_play.update_play_button_state()


# =============================================================================
# PLAY HANDLER DELEGATION
# =============================================================================

func _on_play_requested() -> void:
	if not _is_active:
		return

	_play.on_play_requested()


## Called when PlayHandler completes a play. Syncs PSM and clears highlights.
func _on_play_completed_internal(tiles: Array[Tile], _words: Array) -> void:
	# Commit temporary → permanent in grid cache
	_play_state_manager.commit_temporary_tiles()

	# Clear word highlights (locked tiles don't re-highlight)
	_clear_word_highlights()
	_current_valid_words.clear()

	print("[Gameplay] PSM committed %d tiles, highlights cleared" % tiles.size())


# =============================================================================
# REAL-TIME WORD SCANNING
# =============================================================================

## Runs word finder on the current board state and updates cell highlights.
## Called after every tile placement or removal.
func _run_realtime_word_scan() -> void:
	# Clear previous highlights
	_clear_word_highlights()

	if not _play_state_manager.has_temporary_tiles():
		_current_valid_words.clear()
		return

	# Run word finder on the combined grid (temp + permanent)
	var grid: Array[Array] = _play_state_manager.get_grid()
	_current_valid_words = _word_finder.find_valid_words(grid)

	# Highlight cells that are part of valid words
	var valid_positions: Array[Vector2i] = _word_finder.get_valid_word_positions(_current_valid_words)
	_apply_word_highlights(valid_positions)

	if _current_valid_words.size() > 0:
		for fw in _current_valid_words:
			print("[Gameplay] Word found: '%s' (%s)" % [fw.word, fw.direction])


## Applies green highlight to cells at the given positions.
func _apply_word_highlights(positions: Array[Vector2i]) -> void:
	_highlighted_positions = positions
	for pos in positions:
		var cell: BoardCell = board.get_cell(pos.y, pos.x)
		if cell:
			cell.show_word_highlight()


## Clears all word highlights from the board.
func _clear_word_highlights() -> void:
	for pos in _highlighted_positions:
		var cell: BoardCell = board.get_cell(pos.y, pos.x)
		if cell:
			cell.clear_word_highlight()
	_highlighted_positions.clear()


# =============================================================================
# STATE MANAGEMENT
# =============================================================================

func _update_interaction_state() -> void:
	var has_selection: bool = _selection.has_selection()

	if has_selection:
		_interaction_mode = InteractionMode.TILE_SELECTED
		_selected_tile = _selection.get_selected_tiles()[0] if _selection.get_selection_count() == 1 else null
		_set_hand_tiles_hover_enabled(false)
	else:
		_interaction_mode = InteractionMode.IDLE
		_selected_tile = null
		_set_hand_tiles_hover_enabled(true)
		_placement.clear_all_cell_hovers()


func _set_hand_tiles_hover_enabled(enabled: bool) -> void:
	if hand:
		for tile in hand.get_tiles():
			tile.allow_hover_feedback = enabled
