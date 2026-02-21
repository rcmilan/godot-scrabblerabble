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


# =============================================================================
# LIFECYCLE
# =============================================================================

## Returns the word validator instance for external scoring.
func get_word_validator() -> WordValidator:
	return _play.get_word_validator()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_active:
		return

	if event.is_action_pressed("pause_game"):
		pause_requested.emit()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("toggle_multi_select"):
		_selection.toggle_mode()

	if event.is_action_pressed("discard_tiles"):
		_request_discard()

	if event.is_action_pressed("play_hand"):
		_on_play_requested()
		get_viewport().set_input_as_handled()

	if event.is_action_pressed("draw_tiles"):
		_on_draw_requested()
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
	_play.play_completed.connect(func(tiles, words): play_completed.emit(tiles, words))
	_play.draw_blocked_changed.connect(
		func(blocked): main_hud.set_draw_button_blocked(blocked)
	)
	_play.play_button_changed.connect(
		func(enabled, mode):
			main_hud.set_play_button_enabled(enabled)
			main_hud.set_play_button_mode(mode)
	)


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
		_tracker.track(main_hud.draw_requested, _on_draw_requested)
		_tracker.track(main_hud.play_requested, _on_play_requested)

	_tracker.track(_drag_mgr.drag_release_requested, _handle_drag_release)
	_tracker.track(EventBus.hand_count_changed, _on_tile_supply_changed)
	_tracker.track(EventBus.bag_count_changed, _on_tile_supply_changed)

	if _cursor:
		_tracker.track(_cursor.cursor_confirmed, _on_cursor_confirmed)
		_tracker.track(_cursor.cursor_cancelled, _on_cursor_cancelled)
		_tracker.track(_cursor.cursor_moved,     _on_cursor_moved)


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

	match tile.location:
		Tile.TileLocation.ON_BOARD:
			if _selection.has_selection():
				print("[Gameplay] Cannot stack tiles")
			else:
				print("[Gameplay] Board tile at cell: %s" % tile.current_cell.name)
		Tile.TileLocation.IN_HAND:
			_selection.select_tile(tile)
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

	_placement.return_tile_to_hand(tile)
	_update_interaction_state()
	tile_returned_to_hand.emit(tile)
	_play.update_play_button_state()


func _on_cursor_confirmed(zone: FocusCursor.Zone, position: Variant) -> void:
	if not _is_active:
		return
	match zone:
		FocusCursor.Zone.HAND:
			var tile: Tile = hand.get_tile_at(int(position))
			if tile == null:
				return
			_on_tile_selected(tile)
			if _selection.has_selection() and _cursor:
				_cursor.set_held_tile(tile)

		FocusCursor.Zone.BOARD:
			var coords := position as Vector2i
			var cell: BoardCell = board.get_cell(coords.y, coords.x)
			if cell == null:
				return
			if _selection.has_selection():
				var movable: Array[Tile] = _selection.get_selected_tiles().filter(
					func(t: Tile) -> bool: return not t.is_locked
				)
				if not movable.is_empty() and not cell.is_occupied():
					_place_tiles_on_cell(movable, cell)
					if _cursor:
						_cursor.clear_held_tile()
				elif cell.is_occupied():
					print("[Gameplay] Cursor: target cell occupied at %s" % coords)
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


func _on_cursor_cancelled(_zone: FocusCursor.Zone, _position: Variant) -> void:
	if not _is_active:
		return
	_selection.deselect_all()
	if _cursor:
		_cursor.clear_held_tile()
	_update_interaction_state()
	_play.update_play_button_state()


func _on_cursor_moved(zone: FocusCursor.Zone, position: Variant) -> void:
	if not _is_active:
		return
	_placement.clear_all_cell_hovers()
	if zone == FocusCursor.Zone.BOARD:
		var coords := position as Vector2i
		var cell: BoardCell = board.get_cell(coords.y, coords.x)
		if cell:
			_on_cell_hovered(cell)


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

	# Unified drop handling for single and multi-tile
	var success := _drop.handle_tile_drop(cell, dragged_tiles)
	_update_interaction_state()
	_play.update_play_button_state()
	_drag_mgr.end_drag(success)


# =============================================================================
# CELL HANDLERS
# =============================================================================

## Places one or more movable tiles starting at the target cell.
func _place_tiles_on_cell(movable: Array[Tile], cell: BoardCell) -> void:
	if movable.size() > 1:
		var cells: Array[BoardCell] = _placement.get_sequential_cells(cell, movable.size())
		if cells.is_empty():
			print("[Gameplay] Cannot place %d tiles starting at %s" % [movable.size(), cell.name])
			return
		for i in movable.size():
			_placement.place_tile_on_cell_silent(movable[i], cells[i])
		print("[Gameplay] Placed %d tiles starting at %s" % [movable.size(), cell.name])
	else:
		_placement.place_tile_on_cell(movable[0], cell)
	_selection.deselect_all()
	_update_interaction_state()
	_play.update_play_button_state()
	tile_placement_completed.emit(movable[0], cell)


func _on_cell_clicked(cell: BoardCell) -> void:
	if not _is_active:
		return

	var selected: Array[Tile] = _selection.get_selected_tiles()
	if selected.is_empty():
		print("[Gameplay] No tile selected")
		return

	var movable: Array[Tile] = selected.filter(func(t): return not t.is_locked)
	if movable.is_empty():
		print("[Gameplay] All selected tiles are locked")
		_selection.deselect_all()
		_update_interaction_state()
		return

	if cell.is_occupied():
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
		if cell.is_occupied():
			cell.show_invalid_hover()
		else:
			cell.show_valid_hover()


func _on_cell_unhovered(cell: BoardCell) -> void:
	if not _is_active:
		return
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


# =============================================================================
# DRAW HANDLER
# =============================================================================

func _on_draw_requested() -> void:
	if not _is_active:
		return

	var drawn: int = HandManager.refill_hand()
	print("[Gameplay] Draw requested: refilled %d tiles" % drawn)


func _on_tile_supply_changed(_count: int) -> void:
	_play.update_play_button_state()


# =============================================================================
# PLAY HANDLER DELEGATION
# =============================================================================

func _on_play_requested() -> void:
	if not _is_active:
		return

	_play.on_play_requested()
	_update_interaction_state()


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
