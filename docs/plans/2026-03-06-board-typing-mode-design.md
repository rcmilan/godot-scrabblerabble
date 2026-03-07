# Board Typing Mode Design

## Summary

Replace keyboard interaction with two XOR modes: **Typing Mode** (click empty board cell, type letters to place hand tiles sequentially) and **Selection Mode** (click hand tiles for multi-select drag-and-drop). Only one mode is active at a time.

## Interaction Modes (XOR)

```
InteractionState = IDLE | TYPING(session) | SELECTING(tiles)
```

- Entering TYPING exits SELECTING (deselect all)
- Entering SELECTING exits TYPING (destroy session)
- IDLE is the neutral state

## Typing Mode (Mode 1)

### Entry
- Click an empty board cell when no hand selection is active

### Behavior
- **Letter keys (A-Z)**: Find matching tile in hand via `hand.find_tile_by_letter()`. If found, place on cursor cell. If cell has a non-locked tile, swap it back to hand. Auto-advance cursor per orientation.
- **Arrow keys**: Move cursor freely on board (skip locked tiles in that direction). Does not auto-advance.
- **Backspace**: Undo last placement — return tile to hand, restore any swapped tile, retreat cursor.
- **No match in hand**: Ignore keystroke silently.

### Exit
- Escape
- Click a hand tile (switches to Selection Mode)
- Click outside board
- Session exhausted (no more valid cells)

### Cursor Advancement
- After placing a tile, advance cursor in `orientation` direction (default: left-to-right, `Vector2i(1, 0)`)
- If out of row bounds: wrap to first column of next row
- If out of grid bounds: session exhausted, exit typing mode
- Skip locked tiles during advancement

### Visual
- Distinct "typing cursor" highlight on active cell (different from hover style)

## Selection Mode (Mode 2)

Unchanged from current behavior. Click hand tile → select → click cell or drag to place.

## BoardTypingSession (RefCounted, immutable-style)

Holds: `board`, `orientation`, `cursor_pos`, `history` stack.

Methods return new instances:
- `move(direction: Vector2i) -> BoardTypingSession` — arrow key movement
- `advance() -> BoardTypingSession` — auto-advance after placement per orientation
- `retreat() -> BoardTypingSession` — backspace, pop history
- `with_placement(tile_placed, tile_swapped) -> BoardTypingSession` — push to history
- `get_cursor_cell() -> BoardCell` — current cell
- `is_exhausted() -> bool` — no more valid cells

History entries: `{pos: Vector2i, tile_placed: Tile, tile_swapped: Tile}`

### Orientation Extensibility
- `Vector2i(1, 0)` = left-to-right (default)
- `Vector2i(0, 1)` = top-to-bottom (future)
- Wrap logic derived from orientation: row-wrap for horizontal, column-wrap for vertical

## GameplayController Integration

- `_typing_session: BoardTypingSession` — null when not in typing mode
- `_on_cell_clicked(cell)` — if empty and no hand selection → create session
- `_unhandled_input()` — if session active, intercept letter/arrow/backspace keys
- `_on_tile_selected()` — if session active, end it
- Side effects (place tile, update visual) executed by controller after receiving new session from method calls

## Unchanged
- Hand tile click/multi-select/drag-and-drop
- FocusCursor system (gamepad navigation — orthogonal)
- Board cell hover/click signals
- TilePlacementHandler for actual placement operations
