# Unified Cursor Design

## Summary

Merge typing mode into FocusCursor so there is one cursor system for all input. FocusCursor owns the BoardTypingSession. Any time the cursor is on a board cell and a letter key is pressed, a tile is placed. Mouse clicks move FocusCursor to the clicked position.

## State Machine

FocusCursor has two zones (HAND, BOARD) — no separate "typing mode" state. Typing happens automatically when cursor is in BOARD zone and a letter is pressed.

## Input (all handled in FocusCursor._input)

### Board Zone
- **Arrow keys**: move cursor, skip locked tiles
- **Letter A-Z**: find tile in hand → place on cursor cell → auto-advance
- **Backspace**: undo last placement via session history
- **Confirm**: emit cursor_confirmed (GameplayController triggers Play)
- **Cancel/Escape**: clear session, return to hand zone
- **Switch Zone**: return to hand zone

### Hand Zone
- Unchanged from current behavior

## Mouse Integration

- Click empty board cell → GameplayController calls `_cursor.move_to_board_cell(cell)`
- Click hand tile → GameplayController calls cursor back to hand, existing selection flow

## Visual

- Hand zone: existing CursorRect + hand tile highlight
- Board zone: BoardCell.show_typing_cursor() (blue overlay) — CursorRect hidden
- One cursor visible at all times

## Changes

1. **FocusCursor**: add `_typing_session`, handle letter/backspace in board zone, use typing cursor highlight for board
2. **GameplayController**: remove all `_typing_*` methods, on cell click move cursor to cell, on tile select move cursor to hand
3. **BoardTypingSession**: unchanged
4. **BoardCell**: typing cursor highlight unchanged
