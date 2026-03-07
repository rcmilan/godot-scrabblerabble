# Board Typing Mode Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a typing mode where clicking an empty board cell lets you type letters to place hand tiles sequentially, XOR with existing selection mode.

**Architecture:** Immutable `BoardTypingSession` (RefCounted) encapsulates cursor state, orientation, and undo history. `TypingCursorHighlight` handles the visual. GameplayController owns the session and routes input.

**Tech Stack:** GDScript, Godot 4.x

---

### Task 1: Create BoardTypingSession

Immutable-style RefCounted. Methods return new instances. No side effects — pure data transformations.

**Files:**
- Create: `scripts/interaction/board_typing_session.gd`

**Step 1: Create the session class**

```gdscript
class_name BoardTypingSession
extends RefCounted

## Immutable typing session. Methods return new instances.

const _HORIZONTAL := Vector2i(1, 0)

var board: Board
var cursor_pos: Vector2i
var orientation: Vector2i
var history: Array[Dictionary]  # [{pos, tile_placed, tile_swapped}]


static func create(p_board: Board, start_pos: Vector2i) -> BoardTypingSession:
	var s := BoardTypingSession.new()
	s.board = p_board
	s.cursor_pos = start_pos
	s.orientation = _HORIZONTAL
	s.history = []
	return s


func _clone() -> BoardTypingSession:
	var s := BoardTypingSession.new()
	s.board = board
	s.cursor_pos = cursor_pos
	s.orientation = orientation
	s.history = history.duplicate()
	return s


func get_cursor_cell() -> BoardCell:
	return board.get_cell(cursor_pos.y, cursor_pos.x)


func is_exhausted() -> bool:
	return get_cursor_cell() == null


func with_placement(tile_placed: Tile, tile_swapped: Tile) -> BoardTypingSession:
	var s := _clone()
	s.history.append({pos = cursor_pos, tile_placed = tile_placed, tile_swapped = tile_swapped})
	return s


func advance() -> BoardTypingSession:
	var s := _clone()
	s.cursor_pos = _next_valid_pos(cursor_pos + orientation)
	return s


func retreat() -> BoardTypingSession:
	if history.is_empty():
		return self
	var s := _clone()
	var entry: Dictionary = s.history.pop_back()
	s.cursor_pos = entry.pos
	return s


func last_placement() -> Dictionary:
	if history.is_empty():
		return {}
	return history.back()


func move(direction: Vector2i) -> BoardTypingSession:
	var target := cursor_pos + direction
	var resolved := _skip_locked(target, direction)
	if resolved == Vector2i(-1, -1):
		return self
	var s := _clone()
	s.cursor_pos = resolved
	return s


func _next_valid_pos(from: Vector2i) -> Vector2i:
	var pos := from
	# Wrap at row end
	if pos.x >= board.columns:
		pos = Vector2i(0, pos.y + 1)
	# Out of grid
	if pos.y >= board.rows:
		return pos  # is_exhausted() will catch this
	return _skip_locked(pos, orientation)


func _skip_locked(pos: Vector2i, direction: Vector2i) -> Vector2i:
	var limit: int = board.rows * board.columns
	var steps := 0
	while steps < limit:
		var cell := board.get_cell(pos.y, pos.x)
		if cell == null:
			return Vector2i(-1, -1)
		if not cell.is_occupied() or not cell.tile.is_locked:
			return pos
		pos += direction
		# Wrap for advancement direction
		if direction == _HORIZONTAL and pos.x >= board.columns:
			pos = Vector2i(0, pos.y + 1)
		if pos.y >= board.rows or pos.x < 0 or pos.y < 0:
			return Vector2i(-1, -1)
		steps += 1
	return Vector2i(-1, -1)
```

**Step 2: Commit**

```bash
git add scripts/interaction/board_typing_session.gd
git commit -m "feat: add BoardTypingSession immutable value object"
```

---

### Task 2: Create TypingCursorHighlight

A simple visual indicator on the board cell. Uses BoardCell's existing overlay system with a distinct color + pulse animation.

**Files:**
- Modify: `scenes/board/board_cell.gd` — add `show_typing_cursor()` and `clear_typing_cursor()`

**Step 1: Add typing cursor methods to BoardCell**

Add a new color constant and two methods. The typing cursor takes priority over hover but respects word highlights when cleared.

In `board_cell.gd`, add after the existing color constants (line 16):

```gdscript
const COLOR_TYPING_CURSOR: Color = Color(0.3, 0.6, 1.0, 0.55)  # Blue for typing cursor
```

Add a state flag next to `_word_highlight_active` (line 26):

```gdscript
var _typing_cursor_active: bool = false
```

Add methods after `clear_word_highlight()` (after line 115):

```gdscript
func show_typing_cursor() -> void:
	_typing_cursor_active = true
	_show_overlay(COLOR_TYPING_CURSOR)


func clear_typing_cursor() -> void:
	_typing_cursor_active = false
	if _word_highlight_active:
		_show_overlay(COLOR_WORD_HIGHLIGHT)
		return
	hover_overlay.visible = false
```

Update `clear_hover()` to respect typing cursor (replace existing clear_hover):

```gdscript
func clear_hover() -> void:
	if _typing_cursor_active:
		_show_overlay(COLOR_TYPING_CURSOR)
		return
	if _word_highlight_active:
		_show_overlay(COLOR_WORD_HIGHLIGHT)
		return
	hover_overlay.visible = false
```

**Step 2: Commit**

```bash
git add scenes/board/board_cell.gd
git commit -m "feat: add typing cursor highlight to BoardCell"
```

---

### Task 3: Integrate typing mode into GameplayController

Wire up the session lifecycle: enter on empty cell click, exit on hand tile click / Escape / click outside, handle letter keys, arrow keys, and backspace.

**Files:**
- Modify: `scripts/controllers/gameplay_controller.gd`

**Step 1: Add typing session state**

Add after `_play_state_manager` (around line 68):

```gdscript
var _typing_session: BoardTypingSession = null
```

**Step 2: Add typing session lifecycle methods**

Add a new section before the `# STATE MANAGEMENT` section:

```gdscript
# =============================================================================
# TYPING MODE
# =============================================================================

func _start_typing(cell: BoardCell) -> void:
	_selection.deselect_all()
	var pos := cell.grid_position
	_typing_session = BoardTypingSession.create(board, Vector2i(pos.x, pos.y))
	_update_typing_cursor()


func _end_typing() -> void:
	if _typing_session == null:
		return
	_clear_typing_cursor()
	_typing_session = null


func _is_typing() -> bool:
	return _typing_session != null


func _update_typing_cursor() -> void:
	_clear_typing_cursor()
	if _typing_session == null or _typing_session.is_exhausted():
		return
	var cell := _typing_session.get_cursor_cell()
	if cell:
		cell.show_typing_cursor()


func _clear_typing_cursor() -> void:
	for c in board.get_all_cells():
		c.clear_typing_cursor()


func _handle_typing_letter(letter: String) -> void:
	var tile := hand.find_tile_by_letter(letter.to_upper())
	if tile == null:
		return

	var cell := _typing_session.get_cursor_cell()
	if cell == null:
		return

	var swapped: Tile = null
	if cell.is_occupied() and not cell.tile.is_locked:
		swapped = cell.tile
		_placement.return_tile_to_hand(swapped, true)

	_placement.place_tile_on_cell(tile, cell)
	_play_state_manager.place_temporary_tile(tile, cell.grid_position)

	_typing_session = _typing_session.with_placement(tile, swapped).advance()

	if _typing_session.is_exhausted():
		_end_typing()
	else:
		_update_typing_cursor()

	_run_realtime_word_scan()
	_play.update_play_button_state()


func _handle_typing_backspace() -> void:
	var entry := _typing_session.last_placement()
	if entry.is_empty():
		return

	var tile_placed: Tile = entry.tile_placed
	var tile_swapped: Tile = entry.tile_swapped
	var pos: Vector2i = entry.pos

	# Return placed tile to hand
	_play_state_manager.remove_tile_at(pos)
	_placement.return_tile_to_hand(tile_placed)

	# Restore swapped tile if any
	if tile_swapped and tile_swapped.location == Tile.TileLocation.IN_HAND:
		var cell := board.get_cell(pos.y, pos.x)
		if cell and not cell.is_occupied():
			hand.remove_tile(tile_swapped)
			cell.tile_anchor.add_child(tile_swapped)
			tile_swapped.position = Vector2.ZERO
			tile_swapped.attach_to_cell(cell)
			_play_state_manager.place_temporary_tile(tile_swapped, pos)

	_typing_session = _typing_session.retreat()
	_update_typing_cursor()
	_run_realtime_word_scan()
	_play.update_play_button_state()


func _handle_typing_arrow(direction: Vector2i) -> void:
	_typing_session = _typing_session.move(direction)
	_update_typing_cursor()
```

**Step 3: Modify _on_cell_clicked to enter typing mode**

At the top of `_on_cell_clicked()`, before the existing selection check, add:

```gdscript
func _on_cell_clicked(cell: BoardCell) -> void:
	if not _is_active:
		return

	# Enter typing mode on empty cell click (when no hand selection)
	if not cell.is_occupied() and not _selection.has_selection():
		_start_typing(cell)
		return

	# Exit typing mode if clicking while typing
	if _is_typing():
		_end_typing()

	# ... existing code continues unchanged
```

**Step 4: Modify _on_tile_selected to exit typing mode**

At the top of `_on_tile_selected()`, add:

```gdscript
func _on_tile_selected(tile: Tile) -> void:
	if not _is_active:
		return

	# Exit typing mode when selecting hand tile
	if _is_typing():
		_end_typing()

	# ... existing code continues unchanged
```

**Step 5: Modify _unhandled_input for typing mode keys**

Add typing mode input handling at the top of `_unhandled_input()`, after the active check and pause check:

```gdscript
	# Typing mode input
	if _is_typing():
		if event is InputEventKey and event.is_pressed() and not event.is_echo():
			if event.keycode == KEY_ESCAPE:
				_end_typing()
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_BACKSPACE:
				_handle_typing_backspace()
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_LEFT:
				_handle_typing_arrow(Vector2i(-1, 0))
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_RIGHT:
				_handle_typing_arrow(Vector2i(1, 0))
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_UP:
				_handle_typing_arrow(Vector2i(0, -1))
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_DOWN:
				_handle_typing_arrow(Vector2i(0, 1))
				get_viewport().set_input_as_handled()
				return
			var unicode := event.unicode
			if unicode >= 65 and unicode <= 90 or unicode >= 97 and unicode <= 122:
				_handle_typing_letter(char(unicode))
				get_viewport().set_input_as_handled()
				return
		return  # Consume all input while typing
```

**Step 6: Exit typing mode on deactivate**

In `deactivate()`, add `_end_typing()`:

```gdscript
func deactivate() -> void:
	if not _is_active:
		return
	_is_active = false
	_end_typing()
	_tracker.disconnect_all()
	_selection.deselect_all()
	print("[GameplayController] Deactivated")
```

**Step 7: Commit**

```bash
git add scripts/controllers/gameplay_controller.gd
git commit -m "feat: integrate board typing mode into GameplayController"
```

---

### Task 4: Handle click-outside-board to exit typing mode

When clicking outside the board while typing, exit the session. Board clicks already handled by `_on_cell_clicked`. Hand tile clicks handled by `_on_tile_selected`. We need to catch clicks on the background.

**Files:**
- Modify: `scripts/controllers/gameplay_controller.gd`

**Step 1: Add background click detection in _unhandled_input**

In the typing mode input block (added in Task 3), add mouse button handling before the key handling:

```gdscript
	if _is_typing():
		if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
			# If click didn't hit a board cell (would have been handled by _on_cell_clicked),
			# and didn't hit a hand tile (would have been handled by _on_tile_selected),
			# then it's a background click — exit typing mode
			_end_typing()
			get_viewport().set_input_as_handled()
			return
		# ... existing key handling
```

Note: This works because `_unhandled_input` only fires for events NOT consumed by GUI controls. Board cells and tiles consume their clicks via `_gui_input`, so if a mouse click reaches `_unhandled_input` while typing, it means it hit the background.

**Step 2: Commit**

```bash
git add scripts/controllers/gameplay_controller.gd
git commit -m "feat: exit typing mode on background click"
```

---

### Task 5: Verify and test

**Step 1: Manual test checklist**

- [ ] Click empty board cell → typing cursor (blue highlight) appears
- [ ] Type letter that exists in hand → tile placed, cursor advances right
- [ ] Type letter not in hand → nothing happens
- [ ] Cursor wraps to next row at end of row
- [ ] Cursor skips locked tiles
- [ ] Typing on occupied cell with non-locked tile → swap (tile returns to hand)
- [ ] Arrow keys move cursor freely
- [ ] Backspace undoes last placement (tile returns to hand)
- [ ] Backspace restores swapped tile
- [ ] Escape exits typing mode (cursor disappears)
- [ ] Click hand tile exits typing mode, enters selection mode
- [ ] Click outside board exits typing mode
- [ ] While typing, cannot multi-select or drag (XOR)
- [ ] While in selection mode, cannot type (XOR)
- [ ] Word scan updates after each typed placement
- [ ] Play button updates after each typed placement

**Step 2: Final commit if fixups needed**

```bash
git add -A
git commit -m "feat: complete board typing mode"
```
