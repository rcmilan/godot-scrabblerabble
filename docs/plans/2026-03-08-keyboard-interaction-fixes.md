# Keyboard Interaction Fixes

## Problems

1. Z (discard) doesn't work with keyboard selection — FocusCursor consumes Z as typed letter
2. No dedicated way to remove board tiles via keyboard
3. Enter doesn't Play when all tiles on board — dual-bound to confirm_action and play_hand
4. Ghost letter on cursor causes softlocks — held-tile system adds complexity
5. Orientation button mispositioned on larger boards after round transition

## Approach: Simplify Keyboard Interaction Model

Remove held-tile/ghost system. Establish clear input priority. Typing mode is the primary keyboard interaction for board placement.

### Input Priority

FocusCursor `_input()` handles only: navigation, confirm (spacebar), cancel, letters, backspace, TAB, zone switch. Game actions (Enter→Play, Z→Discard) fall through to GameplayController `_unhandled_input()` → InputRouter.

### Key Binding Changes (project.godot)

- `confirm_action`: Remove Enter (4194309). Keep Spacebar (32) + Joypad A only.
- `play_hand`: Keep Enter (4194309) + Joypad Y.
- No conflict — Enter = Play, Spacebar = Confirm.

### Remove Held-Tile / Ghost System

Remove from FocusCursor:
- `_ghost_label` usage (always hidden)
- `_update_ghost_display()` (remove or no-op)
- `_update_cursor_tint()` held_tile check (cursor always white)

Remove from GameplayController `_on_cursor_confirmed`:
- `_cursor.set_held_tile()` / `_cursor.clear_held_tile()` calls
- "Pick up board tile, hold it, place elsewhere" flow

### New `_on_cursor_confirmed` Behavior

| Cursor Zone | Cell State | Action |
|---|---|---|
| HAND | tile exists | Toggle selection (select/deselect) |
| BOARD | empty, no typing session | Start typing session |
| BOARD | occupied, unlocked | Return tile to hand |
| BOARD | occupied, locked | Shake animation |

### Play via Enter

Enter no longer bound to `confirm_action`, so FocusCursor doesn't consume it. Falls through to InputRouter → `_on_play_requested()`. PlayExecutor already handles: unplayed tiles → play, no valid moves → auto-end round. Works regardless of cursor position.

### Discard via Z

In FocusCursor `_handle_typing_key()`: if `event.is_action(KeyAction.DISCARD_TILES)`, return false. Z falls through to InputRouter → `_discard.request_discard()`. Discards selected hand tiles even during typing session.

### Orientation Button Positioning

Use double-deferred call in `_initialize_grid()` to ensure GridContainer layout is complete before positioning. Standard Godot pattern for post-layout work.

## Files to Modify

- `project.godot` — unbind Enter from confirm_action
- `scenes/ui/focus_cursor/focus_cursor.gd` — remove ghost/held-tile, skip discard key in typing
- `scripts/controllers/gameplay_controller.gd` — simplify `_on_cursor_confirmed`, remove held-tile calls
- `scenes/board/board.gd` — double-deferred orientation button positioning
