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
func setup(board: Board, hand: Hand) -> void:
	_board = board
	_hand = hand


## Postcondition: cursor becomes visible and processes input.
func activate() -> void:
	_is_active = true
	_state = CursorState.at_hand(0)
	set_process_input(true)
	_update_hand_tile_highlight()


## Postcondition: cursor hides, stops processing input, held tile restored.
## INVARIANT: caller MUST call deactivate() before showing any modal.
## FocusCursor uses _input (not _unhandled_input), so while active it intercepts
## confirm_action before modals see it. Main.deactivate_for_modal() enforces this.
func deactivate() -> void:
	_is_active = false
	_clear_hand_tile_highlight()
	clear_held_tile()
	_cursor_rect.hide()
	set_process_input(false)


## Postcondition: held_tile set; cursor highlight removed, tile faded to 50% alpha.
func set_held_tile(tile: Tile) -> void:
	_clear_hand_tile_highlight()
	_state = _state.with_held_tile(tile)
	if tile:
		tile.self_modulate.a = 0.5
	_update_ghost_display()


## Postcondition: held_tile cleared; tile alpha restored to 1.0.
func clear_held_tile() -> void:
	if _state == null:
		return
	if _state.held_tile:
		_state.held_tile.self_modulate.a = 1.0
	_state = _state.cleared_tile()
	_update_ghost_display()


## Returns the BoardCell at board_coords, or null if zone is HAND.
func get_current_cell() -> BoardCell:
	if _state == null or not _state.position.is_board() or _board == null:
		return null
	return _board.get_cell(_state.position.board_coords.y, _state.position.board_coords.x)

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
	# BOARD zone: use cursor rect, ensure hand tile is not highlighted
	if _highlighted_hand_tile:
		_clear_hand_tile_highlight()
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
	_update_cursor_tint()


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


func _update_cursor_tint() -> void:
	if _state.position.is_board() and _state.held_tile != null:
		var cell := _board.get_cell(
			_state.position.board_coords.y,
			_state.position.board_coords.x
		)
		if cell and cell.is_occupied():
			_cursor_rect.modulate = Color(1.0, 0.3, 0.3)
			return
	_cursor_rect.modulate = Color.WHITE


func _update_ghost_display() -> void:
	if _state == null:
		_ghost_label.hide()
		return
	if _state.held_tile != null and _state.position.is_board():
		_ghost_label.text = _state.held_tile.letter
		_ghost_label.show()
	else:
		_ghost_label.hide()

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	if not _is_active:
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
	cursor_moved.emit(_state.position)
	_update_ghost_display()


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
	cursor_moved.emit(_state.position)
	_update_ghost_display()


func _switch_to_hand_zone() -> void:
	var count := _hand.get_tile_count()
	var index := 0
	if count > 0:
		index = clampi(
			int(float(_state.position.board_coords.x) / float(_board.columns) * float(count)),
			0, count - 1
		)
	_state = _state.with_hand_index(index)
	cursor_moved.emit(_state.position)
	_update_ghost_display()


func _confirm() -> void:
	cursor_confirmed.emit(_state.position)


func _cancel() -> void:
	cursor_cancelled.emit(_state.position)
	if _state.position.is_board():
		_switch_to_hand_zone()
