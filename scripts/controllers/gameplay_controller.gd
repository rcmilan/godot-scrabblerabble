extends Node
class_name GameplayController

## GameplayController: Thin orchestrator for tile-based gameplay interaction.
## Routes input events and signals to specialized handlers:
##   - BoardStateCoordinator: atomic facade over PlacementExecutor + PlayStateManager
##   - DragInteractionHandler: drag lifecycle (collect, start, end, release)
##   - CursorInteractionHandler: cursor typing and navigation
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

var _drop: DropExecutor = null
var _play: PlayExecutor = null
var _hover: CellHoverHandler = null
var _word_highlight: WordHighlightHandler = null
var _discard: DiscardHandler = null
var _input_router: InputRouter = null

# =============================================================================
# FACADES
# =============================================================================

var _coordinator: BoardStateCoordinator = null
var _drag_handler: DragInteractionHandler = null
var _cursor_handler: CursorInteractionHandler = null

# =============================================================================
# SIGNAL CONNECTION TRACKING
# =============================================================================

var _tracker: SignalTracker = SignalTracker.new()

# =============================================================================
# LIFECYCLE
# =============================================================================

func get_word_validator() -> WordValidator:
	return _play.get_word_validator()


## Game actions run at _input priority so focused UI controls cannot consume
## play/pause keys before this controller sees them.
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
	# Letter-based game actions (Q, Z) - only route when NOT in a typing session,
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

	# Create placement + state tracking objects locally
	var placement := PlacementExecutor.new()
	placement.setup(board, hand, _selection)

	var psm := PlayStateManager.new()
	psm.initialize_grid(board.rows, board.columns)

	var word_validator := WordValidator.new()
	word_validator.load_word_list("res://data/dictionaries/english_words.txt")

	var word_finder := WordFinder.new()
	word_finder.set_validator(word_validator)

	# Coordinator: atomic facade over placement + PSM
	_coordinator = BoardStateCoordinator.new()
	_coordinator.setup(placement, psm)

	# Core handlers
	_drop = DropExecutor.new()
	_drop.setup(placement, hand, _selection, _drag_mgr)

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

	_hover = CellHoverHandler.new()
	_hover.setup(_selection, placement)

	_word_highlight = WordHighlightHandler.new()
	_word_highlight.setup(board, word_finder, psm)

	_discard = DiscardHandler.new()
	_discard.setup(_selection, _drag_mgr, discard_pile, hand, func():
		_update_interaction_state()
		_play.update_play_button_state()
	)

	# Interaction handlers
	_drag_handler = DragInteractionHandler.new()
	_drag_handler.setup(
		_drag_mgr, _drop, _coordinator, _discard, _selection,
		board, _play, _word_highlight, discard_pile, _update_interaction_state
	)

	if _cursor:
		_cursor_handler = CursorInteractionHandler.new()
		_cursor_handler.setup(
			_cursor, hand, board, _coordinator, _word_highlight,
			_play, _selection, _hover,
			_update_interaction_state,
			func(tile): tile_returned_to_hand.emit(tile)
		)

	# Input routing
	_input_router = InputRouter.new()
	_input_router.register(KeyAction.TOGGLE_MULTI, _selection.toggle_mode)
	_input_router.register(KeyAction.DISCARD_TILES, _discard.request_discard)

	for action_name in [KeyAction.TOGGLE_MULTI, KeyAction.DISCARD_TILES]:
		var events := InputMap.action_get_events(action_name)
		var texts: Array[String] = []
		for ev in events:
			texts.append(ev.as_text())
		print("[Gameplay] InputMap '%s': %s" % [action_name, ", ".join(texts)])

	# Initialize orientation
	_orientation_state = RunOrientationState.horizontal()
	if _cursor:
		_cursor.set_orientation_state(_orientation_state)
	_orientation_button = board.setup_orientation_button()
	if _orientation_button:
		_orientation_button.set_orientation_state(_orientation_state)
		_orientation_button.orientation_toggled.connect(_on_orientation_toggled)


## Resets the PSM grid cache for a new board size.
## Call after board.resize_board() on each round transition.
func reset_for_board(rows: int, cols: int) -> void:
	if _coordinator:
		_coordinator.reset_grid(rows, cols)


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

	_tracker.track(_drag_mgr.drag_release_requested, func(_t): _drag_handler.handle_release(get_viewport()))
	_tracker.track(EventBus.hand_count_changed, func(_c): _play.update_play_button_state())
	_tracker.track(EventBus.bag_count_changed, func(_c): _play.update_play_button_state())

	if _cursor and _cursor_handler:
		_tracker.track(_cursor.cursor_confirmed, func(pos): if _can_interact(): _cursor_handler.on_confirmed(pos))
		_tracker.track(_cursor.cursor_cancelled, func(pos): if _is_active: _cursor_handler.on_cancelled(pos))
		_tracker.track(_cursor.cursor_moved, func(pos): if _is_active: _cursor_handler.on_moved(pos))
		_tracker.track(_cursor.letter_typed, func(l): if _can_interact(): _cursor_handler.on_letter_typed(l))
		_tracker.track(_cursor.backspace_pressed, func(): if _can_interact(): _cursor_handler.on_backspace())
		_tracker.track(_cursor.orientation_toggled, _on_orientation_toggled)


# =============================================================================
# PUBLIC API
# =============================================================================

func register_tile(tile: Tile) -> void:
	if not tile.tile_selected.is_connected(_on_tile_selected):
		tile.tile_selected.connect(_on_tile_selected)
	if not tile.tile_right_clicked.is_connected(_on_tile_right_clicked):
		tile.tile_right_clicked.connect(_on_tile_right_clicked)
	if not tile.tile_drag_started.is_connected(_on_tile_drag_started_guarded):
		tile.tile_drag_started.connect(_on_tile_drag_started_guarded)
	if not tile.tile_drag_ended.is_connected(_on_tile_drag_ended_guarded):
		tile.tile_drag_ended.connect(_on_tile_drag_ended_guarded)


## Sets the current round config for PlayExecutor (called from Main._on_round_ready).
func set_play_executor_round_config(config: RoundConfig) -> void:
	if _play:
		_play.set_round_config(config)


func debug_return_tile_to_hand(tile: Tile) -> void:
	if tile == null or tile.current_cell == null:
		return
	_coordinator.return_tile(tile)
	_refresh_board_state()


# =============================================================================
# TILE SELECTION
# =============================================================================

func _on_tile_selected(tile: Tile) -> void:
	if not _can_interact():
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
	if not _can_interact():
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

	_coordinator.return_tile(tile)
	_refresh_board_state()
	_update_interaction_state()
	tile_returned_to_hand.emit(tile)


# =============================================================================
# DRAG WRAPPERS (guard stays in GC; logic in DragInteractionHandler)
# =============================================================================

func _on_tile_drag_started_guarded(tile: Tile) -> void:
	if not _can_interact() or not tile.can_interact():
		return
	_drag_handler.on_drag_started(tile)


func _on_tile_drag_ended_guarded(tile: Tile) -> void:
	if not _is_active:
		return
	_drag_handler.on_drag_ended(tile)


# =============================================================================
# CELL CLICK
# =============================================================================

func _on_cell_clicked(cell: BoardCell) -> void:
	if not _can_interact():
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

	# Single-tile swap on occupied cell
	if movable.size() == 1 and cell.is_occupied():
		var tile_on_cell: Tile = cell.tile
		if tile_on_cell.is_locked:
			print("[Gameplay] Cannot swap with locked tile: %s" % tile_on_cell.name)
			return
		_coordinator.swap_tiles(movable[0], tile_on_cell, cell)
		_selection.deselect_all()
		_refresh_board_state()
		_update_interaction_state()
		return

	if movable.size() > 1 and cell.is_occupied():
		print("[Gameplay] Cell occupied: %s" % cell.name)
		return

	_place_tiles_on_cell(movable, cell)


# =============================================================================
# PLACEMENT
# =============================================================================

func _place_tiles_on_cell(movable: Array[Tile], cell: BoardCell, animated: bool = true) -> void:
	if movable.size() > 1:
		var cells: Array[BoardCell] = _coordinator.place_tiles(movable, cell, animated)
		if cells.is_empty():
			print("[Gameplay] Cannot place %d tiles starting at %s" % [movable.size(), cell.name])
			return
	else:
		_coordinator.place_tile(movable[0], cell, animated)
	_selection.deselect_all()
	_refresh_board_state()
	_update_interaction_state()
	tile_placement_completed.emit(movable[0], cell)


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
	_coordinator.commit()
	_word_highlight.clear_all()
	print("[Gameplay] PSM committed %d tiles, highlights cleared" % tiles.size())


# =============================================================================
# STATE
# =============================================================================

func _can_interact() -> bool:
	return _is_active and not _play.is_sequence_active()


func _refresh_board_state() -> void:
	_word_highlight.run_scan()
	_play.update_play_button_state()


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
		_coordinator.clear_all_cell_hovers()


func _set_hand_tiles_hover_enabled(enabled: bool) -> void:
	if hand:
		for tile in hand.get_tiles():
			tile.allow_hover_feedback = enabled


# =============================================================================
# ORIENTATION
# =============================================================================

func _on_orientation_toggled(new_state: RunOrientationState) -> void:
	_orientation_state = new_state
	print("[Gameplay] Orientation toggled -> %s" % ("horizontal" if new_state.is_horizontal() else "vertical"))

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
