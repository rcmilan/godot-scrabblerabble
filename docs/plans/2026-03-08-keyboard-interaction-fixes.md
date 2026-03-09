# Keyboard Interaction Fixes — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix 5 keyboard interaction bugs by simplifying the cursor model: remove held-tile/ghost, separate Enter (Play) from Spacebar (Confirm), let game actions fall through to InputRouter.

**Architecture:** FocusCursor `_input()` handles only cursor-local concerns (navigation, confirm via spacebar, typing letters, cancel, zone switch). Game-wide actions (Play, Discard) are NOT consumed by FocusCursor — they fall through to GameplayController `_unhandled_input()` → InputRouter.

**Tech Stack:** GDScript (Godot 4.x), InputEvent system, `_input()` vs `_unhandled_input()` priority

**Tests:** Skip (no test framework in project)

---

### Task 1: Unbind Enter from confirm_action

**Files:**
- Modify: `project.godot` (lines 79-85)

**Step 1: Remove Enter key from confirm_action**

In `project.godot`, the `confirm_action` input map has 3 events: Spacebar (keycode 32), Enter (keycode 4194309), Joypad A. Remove the Enter entry (the entire second `Object(InputEventKey,...)` line with keycode 4194309).

Before:
```
confirm_action={
"deadzone": 0.5,
"events": [Object(InputEventKey,...,"keycode":32,...)
, Object(InputEventKey,...,"keycode":4194309,...)
, Object(InputEventJoypadButton,...,"button_index":0,...)
]
}
```

After:
```
confirm_action={
"deadzone": 0.5,
"events": [Object(InputEventKey,...,"keycode":32,...)
, Object(InputEventJoypadButton,...,"button_index":0,...)
]
}
```

**Step 2: Commit**

```bash
git add project.godot
git commit -m "Unbind Enter from confirm_action — Enter is Play only"
```

---

### Task 2: Skip game-action keys in FocusCursor typing handler

**Files:**
- Modify: `scenes/ui/focus_cursor/focus_cursor.gd` (lines 367-375)

**Step 1: Guard `_handle_typing_key` against game actions**

In `_handle_typing_key()`, before checking if the unicode is a letter, check if the event matches a game action. If so, return `false` so it falls through to `_unhandled_input`.

```gdscript
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
```

**Step 2: Commit**

```bash
git add scenes/ui/focus_cursor/focus_cursor.gd
git commit -m "Let game-action keys fall through typing handler to InputRouter"
```

---

### Task 3: Remove held-tile / ghost system from FocusCursor

**Files:**
- Modify: `scenes/ui/focus_cursor/focus_cursor.gd`

**Step 1: Simplify `set_held_tile` and `clear_held_tile`**

These methods are still called by mouse/drag flows via GameplayController. Make them no-ops for the cursor display but keep the state method signatures so callers don't break.

Replace `set_held_tile()` (lines 106-111):
```gdscript
func set_held_tile(_tile: Tile) -> void:
	pass
```

Replace `clear_held_tile()` (lines 115-121):
```gdscript
func clear_held_tile() -> void:
	pass
```

**Step 2: Remove ghost display methods**

Replace `_update_ghost_display()` (lines 220-228):
```gdscript
func _update_ghost_display() -> void:
	_ghost_label.hide()
```

Replace `_update_cursor_tint()` (lines 208-217):
```gdscript
func _update_cursor_tint() -> void:
	_cursor_rect.modulate = Color.WHITE
```

**Step 3: Remove `_update_ghost_display()` calls**

Remove all calls to `_update_ghost_display()` throughout the file. These are at:
- `set_held_tile()` — already replaced above
- `clear_held_tile()` — already replaced above
- `_navigate_board()` line 319
- `_switch_to_board_zone()` line 334
- `_switch_to_hand_zone()` line 348

Remove the `_update_ghost_display()` call from each of those methods.

**Step 4: Commit**

```bash
git add scenes/ui/focus_cursor/focus_cursor.gd
git commit -m "Remove held-tile/ghost system from FocusCursor"
```

---

### Task 4: Simplify GameplayController `_on_cursor_confirmed`

**Files:**
- Modify: `scripts/controllers/gameplay_controller.gd` (lines 294-332)

**Step 1: Rewrite `_on_cursor_confirmed`**

Replace the entire method with the simplified version:

```gdscript
func _on_cursor_confirmed(pos: CursorPosition) -> void:
	if not _is_active:
		return

	if pos.is_hand():
		var tile: Tile = hand.get_tile_at(pos.hand_index)
		if tile == null:
			return
		_selection.toggle_tile(tile)
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
		# Empty cell: typing session handles it (started on navigation)
```

**Step 2: Check if `SelectionManager.toggle_tile()` exists**

Read `scripts/managers/selection_manager.gd` to verify. If `toggle_tile()` doesn't exist, use this logic instead:
```gdscript
if _selection.is_selected(tile):
    _selection.deselect_tile(tile)
else:
    _selection.select_tile(tile)
```

**Step 3: Remove `_cursor.set_held_tile()` and `_cursor.clear_held_tile()` calls**

Search the file for remaining calls and remove them. Known locations:
- `_on_cursor_confirmed` (already rewritten above)
- `_on_cursor_cancelled` (line 339-340) — remove `_cursor.clear_held_tile()`

In `_on_cursor_cancelled`, remove the held tile line:
```gdscript
func _on_cursor_cancelled(_pos: CursorPosition) -> void:
	if not _is_active:
		return
	_selection.deselect_all()
	_update_interaction_state()
	_play.update_play_button_state()
```

**Step 4: Commit**

```bash
git add scripts/controllers/gameplay_controller.gd
git commit -m "Simplify cursor confirmed: toggle select in hand, return tile on board"
```

---

### Task 5: Fix orientation button positioning

**Files:**
- Modify: `scenes/board/board.gd` (lines 50-62, 169)

**Step 1: Use double-deferred call for position update**

In `_initialize_grid()`, change the deferred call at line 169 from:
```gdscript
_update_orientation_button_position.call_deferred()
```
to:
```gdscript
(func(): _update_orientation_button_position.call_deferred()).call_deferred()
```

This ensures the GridContainer has fully laid out before we read cell positions.

Also apply the same fix in `setup_orientation_button()` (line 46):
```gdscript
(func(): _update_orientation_button_position.call_deferred()).call_deferred()
```

**Step 2: Commit**

```bash
git add scenes/board/board.gd
git commit -m "Fix orientation button position with double-deferred layout wait"
```

---

## Execution Order

Tasks 1-5 are independent and can be executed in any order. Task 2 and Task 3 both modify `focus_cursor.gd` so should be done sequentially. Suggested order: 1 → 2 → 3 → 4 → 5.
