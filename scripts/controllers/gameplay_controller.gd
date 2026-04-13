extends Node
class_name GameplayController

## GameplayController: Thin orchestrator for tile-based gameplay interaction.
## Routes input events and signals to specialized handlers:
##   - PlacementExecutor: tile placement/return, cell queries
##   - DropExecutor: drag-and-drop resolution and execution
##   - PlayExecutor: play submission, scoring, auto-end-round
##   - CellHoverHandler: hover preview for placement validation
##   - WordHighlightHandler: real-time word scanning and highlighting
##   - DiscardHandler: discard pile interactions
##   - InputRouter: keyboard action dispatch

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

enum InteractionMode { IDLE, TILE_SELECTED, DRAGGING }

var _interaction_mode: InteractionMode = InteractionMode.IDLE
var _selected_tile: Tile = null
var _is_active: bool = false
var _cursor: FocusCursor = null
var _orientation_state: RunOrientationState = null
var _orientation_button: OrientationIconButton = null

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

var _placement: PlacementExecutor = null
var _drop: DropExecutor = null
var _play: PlayExecutor = null
var _hover: CellHoverHandler = null
var _word_highlight: WordHighlightHandler = null
var _discard: DiscardHandler = null
var _input_router: InputRouter = null

# =============================================================================
# SIGNAL CONNECTION TRACKING
# =============================================================================

var _tracker: SignalTracker = SignalTracker.new()
var _word_validator: WordValidator = null
var _play_state_manager: PlayStateManager = null
var _word_finder: WordFinder = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func get_word_validator() -> WordValidator:
	return _play.get_word_validator()


func _ready() -> void:
	_word_validator = WordValidator.new()
	_word_validator.load_word_list("res://data/dictionaries/english_words.txt")

	_word_finder = WordFinder.new()
	_word_finder.set_validator(_word_validator)

	_play_state_manager = PlayStateManager.new()


## Game actions run at _input priority — focused UI controls can consume
## key events during GUI processing before _unhandled_input sees them.
func _input(event: InputEvent) -> void:
	if not _is_active:
		if event is InputEventKey and event.is_pressed() and not event.is_echo():
			print("[Gameplay] _input SKIPPED (inactive), key=%s" % event.as_text())
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		print("[Gameplay] _input received key=%s, handled=%s" % [event.as_text(), get_viewport().is_input_handled()])
	if event.is_action_pressed(KeyAction.PLAY_HAND):
		print("[Gameplay] Play requested (Enter)")
		_on_play_requested()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(KeyAction.PAUSE_GAME):
		print("[Gameplay] Pause requested (Esc)")
		pause_requested.emit()
		get_viewport().set_input_as_handled()
		return
	# Letter-based game actions (Q, Z) — only route when NOT in a typing session,
	# otherwise the letter should be consumed by FocusCursor as a typed tile.
	# Also block routing during play sequence.
	if _play.is_sequence_active():
		print("[Gameplay] Skipped routing (sequence active), key=%s" % event.as_text())
		return
	var has_typing := _cursor != null and _cursor.get_typing_session() != null
	if not has_typing:
		if _input_router.route(event):
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.is_pressed():
		print("[Gameplay] Skipped routing (typing session active), key=%s" % event.as_text())


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

	# Core handlers
	_placement = PlacementExecutor.new()
	_placement.setup(board, hand, _selection)

	_drop = DropExecutor.new()
	_drop.setup(_placement, hand, _selection, _drag_mgr)

	_play = PlayExecutor.new()
	_play.setup(board, _selection)
	_play.set_hud(main_hud)
	_play.play_completed.connect(_on_play_completed_internal)
	_play.play_completed.connect(func(tiles, words): play_completed.emit(tiles, words))
	_play.play_button_changed.connect(
		func(enabled, mode):
			main_hud.set_play_button_enabled(enabled)
			main_hud.set_play_button_mode(mode)
	)

	# Extracted handlers
	_hover = CellHoverHandler.new()
	_hover.setup(_selection, _placement)

	_word_highlight = WordHighlightHandler.new()
	_word_highlight.setup(board, _word_finder, _play_state_manager)

	_discard = DiscardHandler.new()
	_discard.setup(_selection, _drag_mgr, discard_pile, hand, func():
		_update_interaction_state()
		_play.update_play_button_state()
	)

	# Input routing
	_input_router = InputRouter.new()
	_input_router.register(KeyAction.TOGGLE_MULTI, _selection.toggle_mode)
	_input_router.register(KeyAction.DISCARD_TILES, _discard.request_discard)

	# Debug: dump InputMap events for routed actions
	for action_name in [KeyAction.TOGGLE_MULTI, KeyAction.DISCARD_TILES]:
		var events := InputMap.action_get_events(action_name)
		var texts: Array[String] = []
		for ev in events:
			texts.append(ev.as_text())
		print("[Gameplay] InputMap '%s': %s" % [action_name, ", ".join(texts)])

	# Initialize grid cache
	if board and _play_state_manager:
		_play_state_manager.initialize_grid(board.rows, board.columns)

	# Initialize orientation
	_orientation_state = RunOrientationState.horizontal()
	if _cursor:
		_cursor.set_orientation_state(_orientation_state)
	_orientation_button = board.setup_orientation_button()
	if _orientation_button:
		_orientation_button.set_orientation_state(_orientation_state)
		_orientation_button.orientation_toggled.connect(_on_orientation_toggled)


## Resets the play state manager for a new board size.
## Call this after board.resize_board() on each round transition.
func reset_for_board(rows: int, cols: int) -> void:
	if _play_state_manager:
		_play_state_manager.initialize_grid(rows, cols)


func activate() -> void:
	if _is_active:
		return
	_is_active = true
	_connect_signals()
	_play.update_play_button_state()
	print("[GameplayController] Activated")


func deactivate() -> void:
	if not _is_active:
		return
	_is_active = false
	_tracker.disconnect_all()
	_selection.deselect_all()
	print("[GameplayController] Deactivated")


# =============================================================================
# SIGNAL CONNECTIONS
# =============================================================================

func _connect_signals() -> void:
	if board:
		_tracker.track(board.cell_clicked, _on_cell_clicked)
		_tracker.track(board.cell_hovered, func(cell): if _is_active: _hover.on_cell_hovered(cell))
		_tracker.track(board.cell_unhovered, func(cell): if _is_active: _hover.on_cell_unhovered(cell))

	if discard_pile:
		_tracker.track(discard_pile.tiles_dropped, _discard.on_discard_pile_tiles_dropped)
		_tracker.track(discard_pile.discard_clicked, _discard.on_discard_pile_clicked)
		_tracker.track(discard_pile.peek_requested, _discard.on_discard_pile_peek_requested)

	if main_hud:
		_tracker.track(main_hud.play_requested, _on_play_requested)

	_tracker.track(_drag_mgr.drag_release_requested, _handle_drag_release)
	_tracker.track(EventBus.hand_count_changed, func(_c): _play.update_play_button_state())
	_tracker.track(EventBus.bag_count_changed, func(_c): _play.update_play_button_state())

	if _cursor:
		_tracker.track(_cursor.cursor_confirmed, _on_cursor_confirmed)
		_tracker.track(_cursor.cursor_cancelled, _on_cursor_cancelled)
		_tracker.track(_cursor.cursor_moved, _on_cursor_moved)
		_tracker.track(_cursor.letter_typed, _on_cursor_letter_typed)
		_tracker.track(_cursor.backspace_pressed, _on_cursor_backspace_pressed)
		_tracker.track(_cursor.orientation_toggled, _on_orientation_toggled)


# =============================================================================
# PUBLIC API
# =============================================================================

func register_tile(tile: Tile) -> void:
	if not tile.tile_selected.is_connected(_on_tile_selected):
		tile.tile_selected.connect(_on_tile_selected)
	if not tile.tile_right_clicked.is_connected(_on_tile_right_clicked):
		tile.tile_right_clicked.connect(_on_tile_right_clicked)
	if not tile.tile_drag_started.is_connected(_on_tile_drag_started):
		tile.tile_drag_started.connect(_on_tile_drag_started)
	if not tile.tile_drag_ended.is_connected(_on_tile_drag_ended):
		tile.tile_drag_ended.connect(_on_tile_drag_ended)


## Sets the current round config for PlayExecutor (called from Main._on_round_ready)
func set_play_executor_round_config(config: RoundConfig) -> void:
	if _play:
		_play.set_round_config(config)


func debug_return_tile_to_hand(tile: Tile) -> void:
	if tile == null or tile.current_cell == null:
		return
	_play_state_manager.remove_tile_at(tile.current_cell.grid_position)
	_placement.return_tile_to_hand(tile)
	_word_highlight.run_scan()
	_play.update_play_button_state()


# =============================================================================
# TILE SELECTION
# =============================================================================

func _on_tile_selected(tile: Tile) -> void:
	if not _is_active:
		return
	if _play.is_sequence_active():
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
	if _play.is_sequence_active():
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

	_play_state_manager.remove_tile_at(tile.current_cell.grid_position)
	_placement.return_tile_to_hand(tile)
	_word_highlight.run_scan()
	_update_interaction_state()
	tile_returned_to_hand.emit(tile)
	_play.update_play_button_state()


# =============================================================================
# CURSOR HANDLERS
# =============================================================================

func _on_cursor_confirmed(pos: CursorPosition) -> void:
	if not _is_active:
		return

	if pos.is_hand():
		var tile: Tile = hand.get_tile_at(pos.hand_index)
		if tile == null:
			return
		if _selection.get_selected_tiles().has(tile):
			_selection.deselect_tile(tile)
		else:
			_selection.select_tile(tile)
		_update_interaction_state()
		return

	if pos.is_board():
		var cell: BoardCell = board.get_cell(pos.board_coords.y, pos.board_coords.x)
		if cell == null:
			return
		if cell.is_occupied():
			var board_tile: Tile = cell.tile
			if board_tile.is_locked:
				TileAnimator.animate_shake(board_tile)
			else:
				_play_state_manager.remove_tile_at(cell.grid_position)
				_placement.return_tile_to_hand(board_tile)
				_word_highlight.run_scan()
				_update_interaction_state()
				tile_returned_to_hand.emit(board_tile)
				_play.update_play_button_state()


func _on_cursor_cancelled(_pos: CursorPosition) -> void:
	if not _is_active:
		return
	_selection.deselect_all()
	_update_interaction_state()
	_play.update_play_button_state()


func _on_cursor_moved(pos: CursorPosition) -> void:
	if not _is_active:
		return
	_placement.clear_all_cell_hovers()
	if pos.is_board():
		var cell: BoardCell = board.get_cell(pos.board_coords.y, pos.board_coords.x)
		if cell:
			_hover.on_cell_hovered(cell)


# =============================================================================
# CURSOR TYPING
# =============================================================================

func _on_cursor_letter_typed(letter: String) -> void:
	if not _is_active or _cursor == null:
		return
	var session := _cursor.get_typing_session()
	if session == null:
		return

	var tile := hand.find_tile_by_letter(letter)
	if tile == null:
		print("[Typing] No '%s' tile in hand" % letter)
		return

	var cell := session.get_cursor_cell()
	if cell == null:
		print("[Typing] Cursor cell is null (session exhausted?)")
		return

	print("[Typing] '%s' → cell %s" % [letter, cell.grid_position])

	var swapped: Tile = null
	if cell.is_occupied() and not cell.tile.is_locked:
		swapped = cell.tile
		_play_state_manager.remove_tile_at(cell.grid_position)
		_placement.return_tile_to_hand(swapped, true)

	_placement.place_tile_on_cell_animated(tile, cell)
	_play_state_manager.place_temporary_tile(tile, cell.grid_position)

	var new_session := session.with_placement(tile, swapped).advance()
	_cursor.set_typing_session(new_session)

	_word_highlight.run_scan()
	_play.update_play_button_state()


func _on_cursor_backspace_pressed() -> void:
	if not _is_active or _cursor == null:
		return
	var session := _cursor.get_typing_session()
	if session == null:
		return

	var entry := session.last_placement()
	if entry.is_empty():
		print("[Typing] Backspace: nothing to undo")
		return

	var tile_placed: Tile = entry.tile_placed
	var tile_swapped: Tile = entry.tile_swapped
	var pos: Vector2i = entry.pos

	print("[Typing] Backspace: returned '%s' from cell %s" % [tile_placed.letter, pos])
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

	_word_highlight.run_scan()
	_play.update_play_button_state()


# =============================================================================
# DRAG HANDLERS
# =============================================================================

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
	if _play.is_sequence_active():
		return

	var valid_tiles := _collect_drag_candidates(tile)
	if valid_tiles.is_empty():
		print("[Gameplay] No valid tiles to drag")
		return

	_drag_mgr.start_drag(tile, valid_tiles)

	for t in valid_tiles:
		if t.location == Tile.TileLocation.ON_BOARD and t.current_cell:
			_play_state_manager.remove_temporary_tile(t.current_cell.grid_position)

	if _any_tiles_on_board(valid_tiles):
		_word_highlight.run_scan()
		_play.update_play_button_state()

	if valid_tiles.size() > 1:
		print("[Gameplay] Multi-drag started with %d tiles" % valid_tiles.size())


func _on_tile_drag_ended(tile: Tile) -> void:
	if not _is_active or not _drag_mgr.is_dragging or tile != _drag_mgr.lead_tile:
		return
	_handle_drag_release(tile)


func _handle_drag_release(tile: Tile) -> void:
	if not _is_active or not _drag_mgr.is_dragging:
		return
	if _play.is_sequence_active():
		return

	var dragged_tiles: Array[Tile] = _drag_mgr.get_dragged_tiles()
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()

	if discard_pile and discard_pile.is_drop_target(mouse_pos):
		_discard.handle_drop_on_discard_pile(dragged_tiles)
		_drag_mgr.end_drag(false)
		return

	var cell: BoardCell = _placement.get_cell_under_mouse(get_viewport())

	# Fast path: same-cell drop (no-op)
	if _is_dropping_on_same_cells(dragged_tiles, cell):
		_handle_same_cell_drop(dragged_tiles)
		_drag_mgr.end_drag(true)
		return

	# Single-tile swap on occupied cell
	if dragged_tiles.size() == 1 and cell != null and cell.is_occupied():
		var tile_to_place: Tile = dragged_tiles[0]
		var tile_on_cell: Tile = cell.tile

		if not tile_on_cell.is_locked:
			_drag_mgr.restore_tiles_to_parents()
			_psm_swap(tile_to_place, tile_on_cell)
			_placement.swap_tiles(tile_to_place, tile_on_cell, cell)
			_selection.deselect_all()
			_psm_restore_swap(tile_to_place, tile_on_cell)
			_word_highlight.run_scan()
			_update_interaction_state()
			_play.update_play_button_state()
			_drag_mgr.end_drag(true)
			return

	# Unified drop handling
	var success := _drop.handle_tile_drop(cell, dragged_tiles)

	if success:
		for t in dragged_tiles:
			if t.current_cell:
				_play_state_manager.place_temporary_tile(t, t.current_cell.grid_position)
	else:
		for t in dragged_tiles:
			if t.location == Tile.TileLocation.ON_BOARD and t.current_cell:
				_play_state_manager.place_temporary_tile(t, t.current_cell.grid_position)

	_word_highlight.run_scan()
	_update_interaction_state()
	_play.update_play_button_state()
	_drag_mgr.end_drag(success)


# =============================================================================
# CELL CLICK
# =============================================================================

func _on_cell_clicked(cell: BoardCell) -> void:
	if not _is_active:
		return
	if _play.is_sequence_active():
		return

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

	# Single-tile swap
	if movable.size() == 1 and cell.is_occupied():
		var tile_to_place: Tile = movable[0]
		var tile_on_cell: Tile = cell.tile

		if tile_on_cell.is_locked:
			print("[Gameplay] Cannot swap with locked tile: %s" % tile_on_cell.name)
			return

		_psm_swap(tile_to_place, tile_on_cell)
		_placement.swap_tiles(tile_to_place, tile_on_cell, cell)
		_selection.deselect_all()
		_psm_restore_swap(tile_to_place, tile_on_cell)
		_word_highlight.run_scan()
		_update_interaction_state()
		_play.update_play_button_state()
		return

	if movable.size() > 1 and cell.is_occupied():
		print("[Gameplay] Cell occupied: %s" % cell.name)
		return

	_place_tiles_on_cell(movable, cell)


# =============================================================================
# PLACEMENT HELPERS
# =============================================================================

func _place_tiles_on_cell(movable: Array[Tile], cell: BoardCell, animated: bool = true) -> void:
	if movable.size() > 1:
		var cells: Array[BoardCell] = _placement.get_sequential_cells(cell, movable.size())
		if cells.is_empty():
			print("[Gameplay] Cannot place %d tiles starting at %s" % [movable.size(), cell.name])
			return
		for i in movable.size():
			if movable[i].current_cell:
				_play_state_manager.remove_tile_at(movable[i].current_cell.grid_position)
		if animated:
			_placement.place_tiles_on_cells_animated(movable, cells)
		else:
			for i in movable.size():
				_placement.place_tile_on_cell_silent(movable[i], cells[i])
		for i in movable.size():
			_play_state_manager.place_temporary_tile(movable[i], cells[i].grid_position)
	else:
		if movable[0].current_cell:
			_play_state_manager.remove_tile_at(movable[0].current_cell.grid_position)
		if animated:
			_placement.place_tile_on_cell_animated(movable[0], cell)
		else:
			_placement.place_tile_on_cell(movable[0], cell)
		_play_state_manager.place_temporary_tile(movable[0], cell.grid_position)
	_selection.deselect_all()
	_word_highlight.run_scan()
	_update_interaction_state()
	_play.update_play_button_state()
	tile_placement_completed.emit(movable[0], cell)


# =============================================================================
# PSM HELPERS
# =============================================================================

func _psm_swap(tile_a: Tile, tile_b: Tile) -> void:
	if tile_a.current_cell:
		_play_state_manager.remove_tile_at(tile_a.current_cell.grid_position)
	if tile_b.current_cell:
		_play_state_manager.remove_tile_at(tile_b.current_cell.grid_position)


func _psm_restore_swap(tile_a: Tile, tile_b: Tile) -> void:
	if tile_a.current_cell:
		_play_state_manager.place_temporary_tile(tile_a, tile_a.current_cell.grid_position)
	if tile_b.current_cell:
		_play_state_manager.place_temporary_tile(tile_b, tile_b.current_cell.grid_position)


# =============================================================================
# DRAG HELPERS
# =============================================================================

func _any_tiles_on_board(tiles: Array[Tile]) -> bool:
	for tile in tiles:
		if tile.location == Tile.TileLocation.ON_BOARD:
			return true
	return false


func _is_dropping_on_same_cells(tiles: Array[Tile], drop_cell: BoardCell) -> bool:
	if drop_cell == null:
		return false

	for i in tiles.size():
		var tile: Tile = tiles[i]
		if tile.location != Tile.TileLocation.ON_BOARD or tile.current_cell == null:
			return false

		var expected_cell: BoardCell
		if tiles.size() == 1:
			expected_cell = drop_cell
		else:
			var lead_tile: Tile = _drag_mgr.lead_tile
			var lead_index: int = tiles.find(lead_tile)
			if lead_index == -1:
				lead_index = 0
			var offset: int = i - lead_index
			var target_pos: Vector2i = drop_cell.grid_position + Vector2i(offset, 0)
			expected_cell = board.get_cell(target_pos.y, target_pos.x)
			if expected_cell == null:
				return false

		if tile.current_cell != expected_cell:
			return false

	return true


func _handle_same_cell_drop(tiles: Array[Tile]) -> void:
	print("[Gameplay] Same-cell drop detected - restoring state for %d tile(s)" % tiles.size())
	_drag_mgr.restore_tiles_to_parents()

	for tile in tiles:
		if tile.location == Tile.TileLocation.ON_BOARD and tile.current_cell:
			_return_to_original_cell(tile)

	_word_highlight.run_scan()
	_play.update_play_button_state()
	_update_interaction_state()
	_placement.clear_all_cell_hovers()


func _return_to_original_cell(tile: Tile) -> void:
	if tile.current_cell == null:
		push_error("[Gameplay] Board tile has no current_cell reference!")
		return
	if not tile.has_active_cell_binding():
		push_warning("[Gameplay] Cell binding not active, restoring...")
		tile.restore_cell_binding()
	_play_state_manager.place_temporary_tile(tile, tile.current_cell.grid_position)
	tile.position = Vector2.ZERO
	tile.modulate = Color.WHITE


# =============================================================================
# PLAY DELEGATION
# =============================================================================

func _on_play_requested() -> void:
	if not _is_active:
		return
	if TileAnimator.is_animating():
		return
	_play.on_play_requested()


func _on_play_completed_internal(tiles: Array[Tile], _words: Array) -> void:
	_play_state_manager.commit_temporary_tiles()
	_word_highlight.clear_all()
	print("[Gameplay] PSM committed %d tiles, highlights cleared" % tiles.size())


# =============================================================================
# STATE
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


# =============================================================================
# ORIENTATION
# =============================================================================

func _on_orientation_toggled(new_state: RunOrientationState) -> void:
	_orientation_state = new_state
	print("[Gameplay] Orientation toggled → %s" % ("horizontal" if new_state.is_horizontal() else "vertical"))

	_cursor.set_orientation_state(new_state)

	if _orientation_button:
		_orientation_button.set_orientation_state(new_state)
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(_orientation_button, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(_orientation_button, "scale", Vector2(1.0, 1.0), 0.1)

	var current_session := _cursor.get_typing_session()
	if current_session != null and not current_session.is_exhausted():
		var new_session := BoardTypingSession.create_with_orientation(
			board,
			current_session.cursor_pos,
			new_state.orientation
		)
		_cursor.set_typing_session(new_session)
