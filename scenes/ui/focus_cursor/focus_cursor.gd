extends Control
class_name FocusCursor

## FocusCursor: keyboard/controller navigation cursor for hand and board zones.
## Owns cursor position state, renders a highlight rect, and emits signals.
## GameplayController connects to signals and executes game actions.

# =============================================================================
# SIGNALS
# =============================================================================

## position is int (hand index) for HAND zone, Vector2i (col, row) for BOARD zone.
signal cursor_confirmed(zone: Zone, position: Variant)
signal cursor_cancelled(zone: Zone, position: Variant)
signal cursor_moved(zone: Zone, position: Variant)

# =============================================================================
# ENUMS
# =============================================================================

enum Zone { HAND, BOARD }

# =============================================================================
# STATE
# =============================================================================

## Invariant: _hand_index in [0, hand.get_tile_count()-1] when HAND zone active.
## Invariant: _board_coords within board bounds when BOARD zone active.
## Invariant: _held_tile is null when no tile has been confirmed for placement.
var _zone: Zone = Zone.HAND
var _hand_index: int = 0
var _board_coords: Vector2i = Vector2i(0, 0)
var _held_tile: Tile = null
var _is_active: bool = false

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
	set_process_unhandled_input(false)
	_cursor_rect.hide()


## Precondition: board and hand are valid non-null references.
func setup(board: Board, hand: Hand) -> void:
	_board = board
	_hand = hand


## Postcondition: cursor becomes visible and processes input.
func activate() -> void:
	_is_active = true
	_hand_index = 0
	_zone = Zone.HAND
	_cursor_rect.show()
	set_process_unhandled_input(true)


## Postcondition: cursor hides, stops processing input, held tile restored.
func deactivate() -> void:
	_is_active = false
	clear_held_tile()
	_cursor_rect.hide()
	set_process_unhandled_input(false)


## Postcondition: _held_tile set; tile faded to 50% alpha in hand.
func set_held_tile(tile: Tile) -> void:
	_held_tile = tile
	if tile:
		tile.modulate.a = 0.5
	_update_ghost_display()


## Postcondition: _held_tile cleared; tile alpha restored to 1.0.
func clear_held_tile() -> void:
	if _held_tile:
		_held_tile.modulate.a = 1.0
	_held_tile = null
	_update_ghost_display()


## Returns the BoardCell at _board_coords, or null if zone is HAND.
func get_current_cell() -> BoardCell:
	if _zone != Zone.BOARD or _board == null:
		return null
	return _board.get_cell(_board_coords.y, _board_coords.x)

# =============================================================================
# VISUAL UPDATE
# =============================================================================

func _process(_delta: float) -> void:
	if not _is_active:
		return
	_update_cursor_rect()


func _update_cursor_rect() -> void:
	var target_rect := _get_target_rect()
	if target_rect == Rect2():
		_cursor_rect.hide()
		return
	_cursor_rect.show()
	_cursor_rect.position = target_rect.position - global_position
	_cursor_rect.size = target_rect.size
	_update_cursor_tint()


func _get_target_rect() -> Rect2:
	match _zone:
		Zone.HAND:
			var tile := _hand.get_tile_at(_hand_index)
			if tile == null:
				return Rect2()
			return tile.get_global_rect()
		Zone.BOARD:
			var cell := _board.get_cell(_board_coords.y, _board_coords.x)
			if cell == null:
				return Rect2()
			return cell.get_global_rect()
	return Rect2()


func _update_cursor_tint() -> void:
	if _zone == Zone.BOARD and _held_tile != null:
		var cell := _board.get_cell(_board_coords.y, _board_coords.x)
		if cell and cell.is_occupied():
			_cursor_rect.modulate = Color(1.0, 0.3, 0.3)
			return
	_cursor_rect.modulate = Color.WHITE


func _update_ghost_display() -> void:
	if _held_tile != null and _zone == Zone.BOARD:
		_ghost_label.text = _held_tile.letter
		_ghost_label.show()
	else:
		_ghost_label.hide()

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not _is_active:
		return
	if event.is_action_pressed("navigate_left"):
		_navigate(Vector2i.LEFT)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("navigate_right"):
		_navigate(Vector2i.RIGHT)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("navigate_up"):
		_navigate(Vector2i.UP)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("navigate_down"):
		_navigate(Vector2i.DOWN)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm_action"):
		_confirm()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel_action"):
		_cancel()
		get_viewport().set_input_as_handled()


func _navigate(direction: Vector2i) -> void:
	match _zone:
		Zone.HAND:  _navigate_hand(direction)
		Zone.BOARD: _navigate_board(direction)


func _navigate_hand(direction: Vector2i) -> void:
	var count := _hand.get_tile_count()
	if count == 0:
		return
	match direction:
		Vector2i.LEFT:
			_hand_index = (_hand_index - 1 + count) % count
			cursor_moved.emit(Zone.HAND, _hand_index)
		Vector2i.RIGHT:
			_hand_index = (_hand_index + 1) % count
			cursor_moved.emit(Zone.HAND, _hand_index)
		Vector2i.UP:
			_switch_to_board_zone()


func _navigate_board(direction: Vector2i) -> void:
	if direction == Vector2i.DOWN and _board_coords.y >= _board.rows - 1:
		_switch_to_hand_zone()
		return
	_board_coords = Vector2i(
		clampi(_board_coords.x + direction.x, 0, _board.columns - 1),
		clampi(_board_coords.y + direction.y, 0, _board.rows - 1)
	)
	cursor_moved.emit(Zone.BOARD, _board_coords)
	_update_ghost_display()


func _switch_to_board_zone() -> void:
	_zone = Zone.BOARD
	var count := _hand.get_tile_count()
	var col := 0
	if count > 0:
		col = clampi(
			int(float(_hand_index) / float(count) * float(_board.columns)),
			0, _board.columns - 1
		)
	_board_coords = Vector2i(col, _board.rows - 1)
	cursor_moved.emit(Zone.BOARD, _board_coords)
	_update_ghost_display()


func _switch_to_hand_zone() -> void:
	_zone = Zone.HAND
	var count := _hand.get_tile_count()
	if count > 0:
		_hand_index = clampi(
			int(float(_board_coords.x) / float(_board.columns) * float(count)),
			0, count - 1
		)
	else:
		_hand_index = 0
	cursor_moved.emit(Zone.HAND, _hand_index)
	_update_ghost_display()


func _confirm() -> void:
	match _zone:
		Zone.HAND:  cursor_confirmed.emit(Zone.HAND, _hand_index)
		Zone.BOARD: cursor_confirmed.emit(Zone.BOARD, _board_coords)


func _cancel() -> void:
	match _zone:
		Zone.HAND:
			cursor_cancelled.emit(Zone.HAND, _hand_index)
		Zone.BOARD:
			cursor_cancelled.emit(Zone.BOARD, _board_coords)
			_switch_to_hand_zone()
