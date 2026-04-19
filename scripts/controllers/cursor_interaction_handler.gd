class_name CursorInteractionHandler
extends RefCounted

## CursorInteractionHandler: Owns all cursor typing and navigation logic.
## Extracted from GameplayController to satisfy SRP. Handles confirmed/cancelled/moved
## cursor events and keyboard typing (letter typed, backspace).

var _cursor: FocusCursor = null
var _hand: Hand = null
var _board: Board = null
var _coordinator: BoardStateCoordinator = null
var _word_highlight: WordHighlightHandler = null
var _play: PlayExecutor = null
var _selection: SelectionManager = null
var _hover: CellHoverHandler = null

## Called after state-mutating operations to sync interaction mode.
var _post_action: Callable
## Called when a tile is returned to hand (propagates tile_returned_to_hand signal up to GC).
var _on_tile_returned: Callable


func setup(
	cursor: FocusCursor,
	hand: Hand,
	board: Board,
	coordinator: BoardStateCoordinator,
	word_highlight: WordHighlightHandler,
	play: PlayExecutor,
	selection: SelectionManager,
	hover: CellHoverHandler,
	post_action: Callable,
	on_tile_returned: Callable
) -> void:
	_cursor = cursor
	_hand = hand
	_board = board
	_coordinator = coordinator
	_word_highlight = word_highlight
	_play = play
	_selection = selection
	_hover = hover
	_post_action = post_action
	_on_tile_returned = on_tile_returned


# =============================================================================
# CURSOR NAVIGATION
# =============================================================================

## FocusCursor.cursor_confirmed handler.
func on_confirmed(pos: CursorPosition) -> void:
	if pos.is_hand():
		var tile: Tile = _hand.get_tile_at(pos.hand_index)
		if tile == null:
			return
		if _selection.get_selected_tiles().has(tile):
			_selection.deselect_tile(tile)
		else:
			_selection.select_tile(tile)
		_post_action.call()
		return

	if pos.is_board():
		var cell: BoardCell = _board.get_cell(pos.board_coords.y, pos.board_coords.x)
		if cell == null:
			return
		if cell.is_occupied():
			var board_tile: Tile = cell.tile
			if board_tile.is_locked:
				TileAnimator.animate_shake(board_tile)
			else:
				_coordinator.return_tile(board_tile)
				_word_highlight.run_scan()
				_post_action.call()
				_on_tile_returned.call(board_tile)
				_play.update_play_button_state()


## FocusCursor.cursor_cancelled handler.
func on_cancelled(_pos: CursorPosition) -> void:
	_selection.deselect_all()
	_post_action.call()
	_play.update_play_button_state()


## FocusCursor.cursor_moved handler.
func on_moved(pos: CursorPosition) -> void:
	_coordinator.clear_all_cell_hovers()
	if pos.is_board():
		var cell: BoardCell = _board.get_cell(pos.board_coords.y, pos.board_coords.x)
		if cell:
			_hover.on_cell_hovered(cell)


# =============================================================================
# CURSOR TYPING
# =============================================================================

## FocusCursor.letter_typed handler.
func on_letter_typed(letter: String) -> void:
	var session := _cursor.get_typing_session()
	if session == null:
		return

	var tile := _hand.find_tile_by_letter(letter)
	if tile == null:
		print("[Typing] No '%s' tile in hand" % letter)
		return

	var cell := session.get_cursor_cell()
	if cell == null:
		print("[Typing] Cursor cell is null (session exhausted?)")
		return

	print("[Typing] '%s' -> cell %s" % [letter, cell.grid_position])

	# Capture swapped reference BEFORE return_tile clears the cell reference.
	var swapped: Tile = null
	if cell.is_occupied() and not cell.tile.is_locked:
		swapped = cell.tile
		_coordinator.return_tile(swapped, true)

	_coordinator.place_tile(tile, cell, true)

	var new_session := session.with_placement(tile, swapped).advance()
	_cursor.set_typing_session(new_session)

	_word_highlight.run_scan()
	_play.update_play_button_state()


## FocusCursor.backspace_pressed handler.
func on_backspace() -> void:
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
	_coordinator.return_tile(tile_placed)

	# If the swapped tile was returned to hand during typing, put it back on the board.
	# Uses hand.remove_tile for proper hand signal emission, then raw reparenting.
	if tile_swapped and tile_swapped.location == Tile.TileLocation.IN_HAND:
		var cell := _board.get_cell(pos.y, pos.x)
		if cell and not cell.is_occupied():
			_hand.remove_tile(tile_swapped)
			cell.tile_anchor.add_child(tile_swapped)
			tile_swapped.position = Vector2.ZERO
			tile_swapped.attach_to_cell(cell)
			_coordinator.register_tile_at(tile_swapped, pos)

	_cursor.set_typing_session(session.retreat())

	_word_highlight.run_scan()
	_play.update_play_button_state()
