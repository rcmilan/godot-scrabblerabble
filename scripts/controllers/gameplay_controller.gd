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

var __interaction_mode: InteractionMode = InteractionMode.IDLE
var __selected_tile: Tile = null
var _is_active: bool = false

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

var _connections: Array[Dictionary] = []


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


## Sets up the controller with required scene references and creates handlers.
func setup(p_board: Board, p_hand: Hand, p_discard_pile: Control, p_discard_dialog: CanvasLayer, p_hud: CanvasLayer, p_selection: SelectionManager) -> void:
	board = p_board
	hand = p_hand
	discard_pile = p_discard_pile
	discard_dialog = p_discard_dialog
	main_hud = p_hud
	_selection = p_selection

	# Create DragManager as local child
	_drag_mgr = DragManager.new()
	_drag_mgr.name = "DragManager"
	add_child(_drag_mgr)

	_placement = TilePlacementHandler.new()
	_placement.setup(board, hand, _selection)

	_drop = DropHandler.new()
	_drop.setup(_placement, hand, _selection, _drag_mgr)

	_play = PlayHandler.new()
	_play.setup(board, main_hud, _selection)
	_play.play_completed.connect(func(tiles, words): play_completed.emit(tiles, words))


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
	_disconnect_all()
	_selection.deselect_all()
	print("[GameplayController] Deactivated")


# =============================================================================
# SIGNAL CONNECTION MANAGEMENT
# =============================================================================

func _safe_connect(sig: Signal, handler: Callable) -> void:
	sig.connect(handler)
	_connections.append({"signal": sig, "handler": handler})


func _disconnect_all() -> void:
	for conn in _connections:
		if conn.signal.is_connected(conn.handler):
			conn.signal.disconnect(conn.handler)
	_connections.clear()


func _connect_signals() -> void:
	# Board signals
	if board:
		_safe_connect(board.cell_clicked, _on_cell_clicked)
		_safe_connect(board.cell_hovered, _on_cell_hovered)
		_safe_connect(board.cell_unhovered, _on_cell_unhovered)

	# Discard signals
	if discard_pile:
		_safe_connect(discard_pile.tiles_dropped, _on_discard_pile_tiles_dropped)
		_safe_connect(discard_pile.discard_clicked, _on_discard_pile_clicked)
		_safe_connect(discard_pile.peek_requested, _on_discard_pile_peek_requested)

	# HUD signals
	if main_hud:
		_safe_connect(main_hud.draw_requested, _on_draw_requested)
		_safe_connect(main_hud.play_requested, _on_play_requested)

	# Drag signals
	_safe_connect(_drag_mgr.drag_release_requested, _handle_drag_release)

	# Tile supply signals (for Play/End Round button state)
	_safe_connect(EventBus.hand_count_changed, _on_tile_supply_changed)
	_safe_connect(EventBus.bag_count_changed, _on_tile_supply_changed)


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
	if _selection.has_selection() and tile.location == Tile.TileLocation.ON_BOARD:
		print("[Gameplay] Cannot stack tiles")
		return

	# Clicking a tile that's already on the board (info only)
	if not _selection.has_selection() and tile.location == Tile.TileLocation.ON_BOARD:
		print("[Gameplay] Board tile at cell: %s" % tile.current_cell.name)
		return

	# Hand tile - use SelectionManager
	if tile.location == Tile.TileLocation.IN_HAND:
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


func _on_tile_drag_started(tile: Tile) -> void:
	if not _is_active:
		return

	# Safety check - tile should have prevented this, but double-check
	if not tile.can_interact():
		print("[Gameplay] Cannot drag non-interactable tile: %s" % tile.name)
		return

	var tiles_to_drag: Array[Tile] = _selection.get__selected_tiles()

	# Filter out any locked/non-interactable tiles from multi-drag
	var valid_tiles: Array[Tile] = []
	for t in tiles_to_drag:
		if t.can_interact():
			valid_tiles.append(t)

	if tile not in valid_tiles:
		_selection.deselect_all()
		_selection.select_tile(tile)
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
	_drop.handle_tile_drop(cell, dragged_tiles)
	_update_interaction_state()
	_play.update_play_button_state()
	_drag_mgr.end_drag(_drop.last_placement_success)


# =============================================================================
# CELL HANDLERS
# =============================================================================

func _on_cell_clicked(cell: BoardCell) -> void:
	if not _is_active:
		return

	var _selected_tiles: Array[Tile] = _selection.get__selected_tiles()

	if _selected_tiles.is_empty():
		print("[Gameplay] No tile selected")
		return

	# Filter out locked tiles - they cannot be moved
	var movable_tiles: Array[Tile] = []
	for tile in _selected_tiles:
		if not tile.is_locked:
			movable_tiles.append(tile)

	if movable_tiles.is_empty():
		print("[Gameplay] All selected tiles are locked")
		_selection.deselect_all()
		_update_interaction_state()
		return

	_selected_tiles = movable_tiles

	if cell.is_occupied():
		print("[Gameplay] Cell occupied: %s" % cell.name)
		return

	if _selected_tiles.size() > 1:
		var cells: Array[BoardCell] = _placement.get_sequential_cells(cell, _selected_tiles.size())
		if cells.is_empty():
			print("[Gameplay] Cannot place %d tiles starting at %s" % [_selected_tiles.size(), cell.name])
			return

		for i in _selected_tiles.size():
			_placement.place_tile_on_cell_silent(_selected_tiles[i], cells[i])

		_selection.deselect_all()
		_update_interaction_state()
		_play.update_play_button_state()
		tile_placement_completed.emit(_selected_tiles[0], cell)
		print("[Gameplay] Placed %d tiles starting at %s" % [_selected_tiles.size(), cell.name])
	else:
		_placement.place_tile_on_cell(_selected_tiles[0], cell)
		_update_interaction_state()
		_play.update_play_button_state()
		tile_placement_completed.emit(_selected_tiles[0], cell)


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
	var _selected_tiles: Array[Tile] = _selection.get__selected_tiles()

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
		_selected_tile = _selection.get__selected_tiles()[0] if _selection.get_selection_count() == 1 else null
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
