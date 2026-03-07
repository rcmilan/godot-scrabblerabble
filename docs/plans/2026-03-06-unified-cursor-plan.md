# Unified Cursor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Merge typing mode into FocusCursor so there is one cursor system for all input — no dual cursors.

**Architecture:** FocusCursor gains a `_typing_session: BoardTypingSession` and handles letter/backspace input when in BOARD zone. It emits new signals (`letter_typed`, `backspace_pressed`) so GameplayController executes placement logic. GameplayController's typing section is removed; cell clicks call `_cursor.move_to_board_cell()`. Board zone visual uses `BoardCell.show_typing_cursor()` instead of CursorRect.

**Tech Stack:** GDScript 4.x, Godot Engine, immutable value objects (CursorState, BoardTypingSession)

---

### Task 1: Add typing signals and `move_to_board_cell()` to FocusCursor

**Files:**
- Modify: `scenes/ui/focus_cursor/focus_cursor.gd`

**Step 1: Add new signals and typing state**

Add after line 14 (after `cursor_moved`):

```gdscript
signal letter_typed(letter: String)
signal backspace_pressed
```

Add after line 28 (after `_highlighted_hand_tile`):

```gdscript
var _typing_session: BoardTypingSession = null
```

**Step 2: Add `move_to_board_cell()` public method**

Add after `get_current_cell()` (after line 103):

```gdscript
## Moves cursor to a specific board cell. Used by mouse click integration.
func move_to_board_cell(coords: Vector2i) -> void:
	_clear_hand_tile_highlight()
	_state = _state.with_board_coords(coords)
	_start_typing_at(coords)
	cursor_moved.emit(_state.position)
```

**Step 3: Add typing session lifecycle methods**

Add at end of file (private section):

```gdscript
# =============================================================================
# TYPING SESSION
# =============================================================================

func _start_typing_at(coords: Vector2i) -> void:
	_typing_session = BoardTypingSession.create(_board, coords)
	_update_typing_cursor_visual()


func _end_typing_session() -> void:
	if _typing_session == null:
		return
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
```

**Step 4: Commit**

```bash
git add scenes/ui/focus_cursor/focus_cursor.gd
git commit -m "feat: add typing signals and move_to_board_cell to FocusCursor"
```

---

### Task 2: Handle letter and backspace input in FocusCursor board zone

**Files:**
- Modify: `scenes/ui/focus_cursor/focus_cursor.gd`

**Step 1: Add letter/backspace handling to `_input()`**

Replace the `_input()` method (lines 186-212) with:

```gdscript
func _input(event: InputEvent) -> void:
	if not _is_active:
		return

	# Letter/backspace input when typing on board
	if _typing_session != null and event is InputEventKey and event.is_pressed() and not event.is_echo():
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
```

**Step 2: Add `_handle_typing_key()` private method**

```gdscript
func _handle_typing_key(event: InputEventKey) -> bool:
	if event.keycode == KEY_BACKSPACE:
		backspace_pressed.emit()
		return true
	var unicode := event.unicode
	if unicode >= 65 and unicode <= 90 or unicode >= 97 and unicode <= 122:
		letter_typed.emit(char(unicode).to_upper())
		return true
	return false
```

**Step 3: Commit**

```bash
git add scenes/ui/focus_cursor/focus_cursor.gd
git commit -m "feat: handle letter and backspace input in FocusCursor board zone"
```

---

### Task 3: Use typing cursor visual instead of CursorRect for board zone

**Files:**
- Modify: `scenes/ui/focus_cursor/focus_cursor.gd`

**Step 1: Update `_update_cursor_rect()` to hide CursorRect when typing**

Replace `_update_cursor_rect()` (lines 115-135) with:

```gdscript
func _update_cursor_rect() -> void:
	if _state == null:
		return
	if _state.position.is_hand():
		_cursor_rect.hide()
		_update_hand_tile_highlight()
		return
	# BOARD zone: typing cursor takes over — hide CursorRect
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
	_update_cursor_tint()
```

**Step 2: Start typing when switching to board zone**

Update `_switch_to_board_zone()` (line 251) — add `_start_typing_at()` call:

```gdscript
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
	_update_ghost_display()
```

**Step 3: End typing when switching to hand zone**

Update `_switch_to_hand_zone()` (line 265) — add `_end_typing_session()` call:

```gdscript
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
	_update_ghost_display()
```

**Step 4: Sync typing session when navigating board with arrows**

Update `_navigate_board()` (line 238) — sync typing cursor after move:

```gdscript
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
		_typing_session = BoardTypingSession.create(_board, coords)
		_update_typing_cursor_visual()
	cursor_moved.emit(_state.position)
	_update_ghost_display()
```

**Step 5: End typing on cancel**

Update `_cancel()` (line 282):

```gdscript
func _cancel() -> void:
	_end_typing_session()
	cursor_cancelled.emit(_state.position)
	if _state.position.is_board():
		_switch_to_hand_zone()
```

**Step 6: Clean up typing on deactivate**

Update `deactivate()` (line 72) — add `_end_typing_session()`:

```gdscript
func deactivate() -> void:
	_is_active = false
	_end_typing_session()
	_clear_hand_tile_highlight()
	clear_held_tile()
	_cursor_rect.hide()
	set_process_input(false)
```

**Step 7: Add public methods for typing session state**

Add after `get_current_cell()`:

```gdscript
## Returns the current typing session, or null if not typing.
func get_typing_session() -> BoardTypingSession:
	return _typing_session


## Updates the typing session (called by GameplayController after placement/undo).
func set_typing_session(session: BoardTypingSession) -> void:
	_typing_session = session
	if _typing_session == null or _typing_session.is_exhausted():
		_end_typing_session()
		return
	_state = _state.with_board_coords(_typing_session.cursor_pos)
	_update_typing_cursor_visual()
```

**Step 8: Confirm on board triggers play**

Update `_confirm()`:

```gdscript
func _confirm() -> void:
	if _typing_session != null:
		_end_typing_session()
	cursor_confirmed.emit(_state.position)
```

**Step 9: Commit**

```bash
git add scenes/ui/focus_cursor/focus_cursor.gd
git commit -m "feat: use typing cursor visual for board zone, sync session on navigate"
```

---

### Task 4: Wire FocusCursor typing signals in GameplayController

**Files:**
- Modify: `scripts/controllers/gameplay_controller.gd`

**Step 1: Connect new signals in `_connect_signals()`**

Add after line 200 (after `_tracker.track(_cursor.cursor_moved, _on_cursor_moved)`):

```gdscript
		_tracker.track(_cursor.letter_typed, _on_cursor_letter_typed)
		_tracker.track(_cursor.backspace_pressed, _on_cursor_backspace_pressed)
```

**Step 2: Add handler methods**

Add in a new section after the cursor handler section (after `_on_cursor_moved`):

```gdscript
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

	_placement.place_tile_on_cell(tile, cell)
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
```

**Step 3: Commit**

```bash
git add scripts/controllers/gameplay_controller.gd
git commit -m "feat: wire FocusCursor typing signals in GameplayController"
```

---

### Task 5: Remove old typing mode from GameplayController

**Files:**
- Modify: `scripts/controllers/gameplay_controller.gd`

**Step 1: Remove `_typing_session` field**

Delete line 69:

```gdscript
var _typing_session: BoardTypingSession = null
```

**Step 2: Remove typing intercept from `_unhandled_input()`**

Delete lines 103-105:

```gdscript
	if _is_typing():
		_handle_typing_input(event)
		return
```

**Step 3: Remove `_end_typing()` from `deactivate()`**

Delete line 169:

```gdscript
	_end_typing()
```

**Step 4: Remove typing exit from `_on_tile_selected()`**

Delete lines 239-240:

```gdscript
	if _is_typing() and tile.location == Tile.TileLocation.IN_HAND:
		_end_typing()
```

**Step 5: Remove typing mode entry from `_on_cell_clicked()`**

Replace lines 532-539:

```gdscript
	# Enter typing mode on empty cell click when no hand selection active
	if not cell.is_occupied() and not _selection.has_selection():
		_start_typing(cell)
		return

	# Exit typing mode if clicking while typing
	if _is_typing():
		_end_typing()
```

With:

```gdscript
	# Move cursor to cell on empty cell click when no hand selection active
	if not cell.is_occupied() and not _selection.has_selection():
		if _cursor:
			_cursor.move_to_board_cell(cell.grid_position)
		return
```

**Step 6: Delete entire TYPING MODE section**

Delete lines 886-1018 (the entire typing mode section):

```gdscript
# =============================================================================
# TYPING MODE
# =============================================================================
# ... all methods: _is_typing, _start_typing, _end_typing, _update_typing_cursor,
# _clear_typing_cursor, _handle_typing_input, _try_typing_letter,
# _handle_typing_letter, _handle_typing_backspace, _handle_typing_arrow
```

**Step 7: Update `_on_cursor_confirmed` for board zone**

The current `_on_cursor_confirmed` at line 290 handles board confirm by placing held tiles. Add play trigger when no selection is active. Replace the `elif pos.is_board():` block (lines 302-326) with:

```gdscript
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
			# No selection, empty cell, confirm = Play
			_on_play_requested()
```

**Step 8: Move cursor to hand on tile select**

Update `_on_tile_selected()` — when a hand tile is selected, move cursor to hand:

After the existing `_selection.select_tile(tile)` line in the `IN_HAND` branch, add:

```gdscript
		Tile.TileLocation.IN_HAND:
			_selection.select_tile(tile)
			if _cursor and _cursor.get_typing_session() != null:
				_cursor.set_typing_session(null)
			_update_interaction_state()
```

**Step 9: Commit**

```bash
git add scripts/controllers/gameplay_controller.gd
git commit -m "feat: remove old typing mode, wire cell clicks to cursor"
```

---

### Task 6: Verify and test

**Step 1: Run the game**

```bash
# Launch Godot project and test:
# 1. Click empty board cell → blue typing cursor appears, CursorRect hidden
# 2. Type letters → tiles placed from hand onto board sequentially
# 3. Backspace → undo last placement
# 4. Arrow keys → single cursor moves (no dual cursors)
# 5. Escape → cursor returns to hand, typing cursor clears
# 6. Tab (switch zone) → enters board with typing cursor
# 7. Click hand tile → typing ends, selection mode activates
# 8. Confirm (Enter) on board with no selection → triggers Play
# 9. Confirm on board with held tile → places tile
```

**Step 2: Verify no dual cursors**

- Arrow keys on board: only blue typing cursor visible (CursorRect hidden)
- Moving to hand: CursorRect hidden, hand tile highlight active
- No scenario where both CursorRect and typing cursor are visible simultaneously

**Step 3: Commit final cleanup if needed**

```bash
git add -A
git commit -m "fix: unified cursor cleanup"
```
