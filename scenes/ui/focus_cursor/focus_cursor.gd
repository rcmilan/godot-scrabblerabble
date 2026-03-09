extends Control
class_name FocusCursor

## FocusCursor: keyboard/controller navigation cursor for hand and board zones.
## Owns cursor position state, renders a highlight rect, and emits signals.
## GameplayController connects to signals and executes game actions.

# =============================================================================
# SIGNALS
# =============================================================================

signal cursor_confirmed(pos: CursorPosition)
signal cursor_cancelled(pos: CursorPosition)
signal cursor_moved(pos: CursorPosition)
signal letter_typed(letter: String)
signal backspace_pressed
signal orientation_toggled(new_state: RunOrientationState)

# =============================================================================
# CONSTANTS
# =============================================================================

## Re-export so external code can still write FocusCursor.Zone if needed.
const Zone := CursorPosition.Zone

# =============================================================================
# STATE
# =============================================================================

var _state: CursorState = null  ## Initialised in activate().
var _is_active: bool = false
var _highlighted_hand_tile: Tile = null
var _typing_session: BoardTypingSession = null
var _orientation_state: RunOrientationState = null

# =============================================================================
# DEPENDENCIES (injected via setup)
# =============================================================================

var _board: Board = null
var _hand: Hand = null

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _cursor_rect: Panel = $CursorRect
@onready var _ghost_label: Label = $CursorRect/GhostLabel

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	set_process_input(false)
	_cursor_rect.hide()


## Precondition: board and hand are valid non-null references.
func setup(board: Board, hand: Hand, orientation_state: RunOrientationState) -> void:
	_board = board
	_hand = hand
	_orientation_state = orientation_state


func get_orientation() -> Vector2i:
	if _orientation_state == null:
		return Vector2i(1, 0)  # Default to horizontal
	return _orientation_state.orientation


func set_orientation_state(new_state: RunOrientationState) -> void:
	if new_state == null or new_state == _orientation_state:
		return
	_orientation_state = new_state
	if _typing_session != null:
		print("[Cursor] Recreating typing session with new orientation at %s" % _typing_session.cursor_pos)
		_typing_session = BoardTypingSession.create_with_orientation(_board, _typing_session.cursor_pos, new_state.orientation)
		_update_typing_cursor_visual()


## Postcondition: cursor becomes visible and processes input.
func activate() -> void:
	_is_active = true
	_state = CursorState.at_hand(0)
	set_process_input(true)
	_update_hand_tile_highlight()
	if _orientation_state == null:
		_orientation_state = RunOrientationState.horizontal()


## Postcondition: cursor hides, stops processing input.
## INVARIANT: caller MUST call deactivate() before showing any modal.
## FocusCursor uses _input (not _unhandled_input), so while active it intercepts
## confirm_action before modals see it. Main.deactivate_for_modal() enforces this.
func deactivate() -> void:
	_is_active = false
	_end_typing_session()
	_clear_hand_tile_highlight()
	_cursor_rect.hide()
	set_process_input(false)


## Returns the BoardCell at board_coords, or null if zone is HAND.
func get_current_cell() -> BoardCell:
	if _state == null or not _state.position.is_board() or _board == null:
		return null
	return _board.get_cell(_state.position.board_coords.y, _state.position.board_coords.x)


func move_to_board_cell(coords: Vector2i) -> void:
	_clear_hand_tile_highlight()
	_state = _state.with_board_coords(coords)
	_start_typing_at(coords)
	cursor_moved.emit(_state.position)


func get_typing_session() -> BoardTypingSession:
	return _typing_session


func set_typing_session(session: BoardTypingSession) -> void:
	_typing_session = session
	if _typing_session == null or _typing_session.is_exhausted():
		_end_typing_session()
		return
	_state = _state.with_board_coords(_typing_session.cursor_pos)
	_update_typing_cursor_visual()

# =============================================================================
# VISUAL UPDATE
# =============================================================================

func _process(_delta: float) -> void:
	if not _is_active:
		return
	_update_cursor_rect()


func _update_cursor_rect() -> void:
	if _state == null:
		return
	if _state.position.is_hand():
		_cursor_rect.hide()
		_update_hand_tile_highlight()
		return
	# BOARD zone: ensure hand tile is not highlighted
	if _highlighted_hand_tile:
		_clear_hand_tile_highlight()
	if _typing_session != null:
		_cursor_rect.hide()
		return
	var cell := _board.get_cell(
		_state.position.board_coords.y,
		_state.position.board_coords.x
	)
	if cell == null:
		_cursor_rect.hide()
		return
	_cursor_rect.show()
	_cursor_rect.position = cell.get_global_rect().position - global_position
	_cursor_rect.size     = cell.get_global_rect().size
	_cursor_rect.modulate = Color.WHITE


func _update_hand_tile_highlight() -> void:
	if _state == null:
		return
	var new_tile: Tile = _hand.get_tile_at(_state.position.hand_index) if _hand != null else null
	if new_tile == _highlighted_hand_tile:
		return
	if _highlighted_hand_tile and is_instance_valid(_highlighted_hand_tile):
		_highlighted_hand_tile.set_cursor_highlighted(false)
		_hand.get_fan_layout().remove_hover_effect(_highlighted_hand_tile)
	_highlighted_hand_tile = new_tile
	if _highlighted_hand_tile:
		_highlighted_hand_tile.set_cursor_highlighted(true)
		_hand.get_fan_layout().apply_hover_effect(_highlighted_hand_tile)


func _clear_hand_tile_highlight() -> void:
	if _highlighted_hand_tile and is_instance_valid(_highlighted_hand_tile):
		_highlighted_hand_tile.set_cursor_highlighted(false)
		_hand.get_fan_layout().remove_hover_effect(_highlighted_hand_tile)
	_highlighted_hand_tile = null


# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if not _is_active:
		return
	# TAB to toggle orientation (works in hand or board zone)
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_TAB:
			var new_state := _orientation_state.toggled()
			print("[Cursor] TAB: orientation → %s" % ("horizontal" if new_state.is_horizontal() else "vertical"))
			set_orientation_state(new_state)
			orientation_toggled.emit(new_state)
			get_viewport().set_input_as_handled()
			return
	# Letter/backspace input when typing on board
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		# Auto-start typing session on board if a letter is pressed
		if _state.position.is_board() and _typing_session == null:
			var unicode: int = event.unicode
			if (unicode >= 65 and unicode <= 90) or (unicode >= 97 and unicode <= 122):
				_start_typing_at(_state.position.board_coords)
		if _typing_session != null:
			if _handle_typing_key(event):
				get_viewport().set_input_as_handled()
				return
	if event.is_action_pressed(KeyAction.NAVIGATE_LEFT):
		_navigate(Vector2i.LEFT)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(KeyAction.NAVIGATE_RIGHT):
		_navigate(Vector2i.RIGHT)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(KeyAction.NAVIGATE_UP):
		_navigate(Vector2i.UP)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(KeyAction.NAVIGATE_DOWN):
		_navigate(Vector2i.DOWN)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(KeyAction.CONFIRM):
		_confirm()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(KeyAction.CANCEL):
		_cancel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(KeyAction.SWITCH_ZONE):
		if _state.position.is_hand():
			_switch_to_board_zone()
		else:
			_switch_to_hand_zone()
		get_viewport().set_input_as_handled()


func _navigate(direction: Vector2i) -> void:
	if _state.position.is_hand():
		_navigate_hand(direction)
	else:
		_navigate_board(direction)


func _navigate_hand(direction: Vector2i) -> void:
	var count := _hand.get_tile_count()
	if count == 0:
		return
	match direction:
		Vector2i.LEFT:
			_state = _state.with_hand_index((_state.position.hand_index - 1 + count) % count)
			cursor_moved.emit(_state.position)
		Vector2i.RIGHT:
			_state = _state.with_hand_index((_state.position.hand_index + 1) % count)
			cursor_moved.emit(_state.position)
		Vector2i.UP:
			_switch_to_board_zone()
		# DOWN in HAND zone: intentional no-op (hand is at the bottom of the layout)


func _navigate_board(direction: Vector2i) -> void:
	if direction == Vector2i.DOWN and _state.position.board_coords.y >= _board.rows - 1:
		_switch_to_hand_zone()
		return
	var coords := Vector2i(
		clampi(_state.position.board_coords.x + direction.x, 0, _board.columns - 1),
		clampi(_state.position.board_coords.y + direction.y, 0, _board.rows - 1)
	)
	_state = _state.with_board_coords(coords)
	if _typing_session != null:
		_typing_session = BoardTypingSession.create_with_orientation(_board, coords, get_orientation())
		_update_typing_cursor_visual()
	cursor_moved.emit(_state.position)


func _switch_to_board_zone() -> void:
	_clear_hand_tile_highlight()
	var count := _hand.get_tile_count()
	var col   := 0
	if count > 0:
		col = clampi(
			int(float(_state.position.hand_index) / float(count) * float(_board.columns)),
			0, _board.columns - 1
		)
	_state = _state.with_board_coords(Vector2i(col, _board.rows - 1))
	_start_typing_at(_state.position.board_coords)
	cursor_moved.emit(_state.position)


func _switch_to_hand_zone() -> void:
	_end_typing_session()
	var count := _hand.get_tile_count()
	var index := 0
	if count > 0:
		index = clampi(
			int(float(_state.position.board_coords.x) / float(_board.columns) * float(count)),
			0, count - 1
		)
	_state = _state.with_hand_index(index)
	cursor_moved.emit(_state.position)


func _confirm() -> void:
	if _typing_session != null:
		_end_typing_session()
	cursor_confirmed.emit(_state.position)


func _cancel() -> void:
	_end_typing_session()
	cursor_cancelled.emit(_state.position)
	if _state.position.is_board():
		_switch_to_hand_zone()

# =============================================================================
# TYPING SESSION
# =============================================================================

func _handle_typing_key(event: InputEventKey) -> bool:
	if event.keycode == KEY_BACKSPACE:
		backspace_pressed.emit()
		return true
	# Let game actions fall through (e.g. Z = discard, L = draw)
	if event.is_action(KeyAction.DISCARD_TILES) or event.is_action(KeyAction.DRAW_TILES):
		return false
	var unicode := event.unicode
	if (unicode >= 65 and unicode <= 90) or (unicode >= 97 and unicode <= 122):
		letter_typed.emit(char(unicode).to_upper())
		return true
	return false


func _start_typing_at(coords: Vector2i) -> void:
	var orientation := get_orientation()
	var orient_label := "H" if orientation == Vector2i(1, 0) else "V"
	print("[Cursor] Typing session started at %s [%s]" % [coords, orient_label])
	_typing_session = BoardTypingSession.create_with_orientation(_board, coords, orientation)
	_update_typing_cursor_visual()


func _end_typing_session() -> void:
	if _typing_session == null:
		return
	print("[Cursor] Typing session ended")
	_clear_typing_cursor_visual()
	_typing_session = null


func _update_typing_cursor_visual() -> void:
	_clear_typing_cursor_visual()
	if _typing_session == null or _typing_session.is_exhausted():
		return
	var cell := _typing_session.get_cursor_cell()
	if cell:
		cell.show_typing_cursor()


func _clear_typing_cursor_visual() -> void:
	if _board == null:
		return
	for c in _board.get_all_cells():
		c.clear_typing_cursor()
