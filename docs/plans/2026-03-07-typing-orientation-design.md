# Typing Mode Orientation Design

## Summary

Add orientation toggle (horizontal ↔ vertical) to typing mode. Players can switch directions using TAB or by clicking a small icon in the top-left corner of the board. Orientation persists throughout the run. Uses immutable value object pattern for domain model.

## Domain Model: RunOrientationState

**RunOrientationState** is an immutable value object representing the current typing orientation:

```gdscript
class_name RunOrientationState extends RefCounted

var orientation: Vector2i  # Vector2i(1, 0) = horizontal, Vector2i(0, 1) = vertical

static func horizontal() -> RunOrientationState
static func vertical() -> RunOrientationState
func is_horizontal() -> bool
func toggled() -> RunOrientationState  # Returns new instance with flipped orientation
```

**Design rationale:**
- Immutable: each toggle creates a new instance (no mutation)
- Single responsibility: owns only the orientation vector
- DDD-aligned: orientation is a domain concept at the run level
- Reusable: can be queried by any system (FocusCursor, Board UI, BoardTypingSession)

---

## Architecture

### Components

#### 1. RunOrientationState (Value Object)
- Immutable, RefCounted
- Single field: `orientation: Vector2i`
- Factory methods: `horizontal()`, `vertical()`
- Toggle method: `toggled()` → returns new instance

#### 2. FocusCursor (Dependency Injection)
- Receives `RunOrientationState` reference via `setup()`
- Reads orientation via `get_orientation() -> Vector2i`
- Detects TAB key → emits `orientation_toggled(new_state)` signal
- Does NOT own or mutate orientation state

#### 3. OrientationIconButton (New UI Component)
- Positioned top-left corner, 32x32px (50% cell size)
- Displays current orientation (letter_H.png or letter_V.png)
- Clickable → emits `orientation_toggled(new_state)` signal
- Listens to `orientation_changed` → updates visual, plays stomp animation

#### 4. BoardTypingSession (Updated)
- Reads `orientation: Vector2i` from FocusCursor
- Passes to `advance()` and `_next_valid_pos()` for directional movement
- Word-wrap behavior:
  - **Horizontal (1,0):** end of row → next row start
  - **Vertical (0,1):** end of column → next column start

#### 5. GameplayController (Coordinator)
- Owns current `RunOrientationState` for the run
- Listens to `orientation_toggled` signals from FocusCursor and OrientationIconButton
- Updates FocusCursor's orientation reference
- Recreates BoardTypingSession with new orientation
- Triggers stomp animation on icon for feedback

---

## Data Flow: Orientation Toggle

```
Player presses TAB or clicks icon
    ↓
FocusCursor._input() or OrientationIconButton._on_icon_clicked()
    ↓
Emits: orientation_toggled.emit(new_state)
    ↓
GameplayController._on_orientation_toggled(new_state)
    ├─ Update FocusCursor._orientation_state = new_state
    ├─ Recreate BoardTypingSession with new orientation
    ├─ Animate icon with stomp effect
    └─ Update board UI visual
```

**Key behavior:**
- Placed tiles persist when orientation changes
- Only the *direction* of future placements changes
- Orientation persists across entire run (until next toggle)
- Survives zone switches (hand ↔ board)

---

## Word-Wrap Behavior

### Horizontal Mode (existing)
```
Cell[0,0] → Cell[1,0] → Cell[2,0] → ... → Cell[cols-1,0]
    ↓
Cell[0,1] → Cell[1,1] → Cell[2,1] → ...
```

### Vertical Mode (new)
```
Cell[0,0] → Cell[0,1] → Cell[0,2] → ... → Cell[0,rows-1]
    ↓
Cell[1,0] → Cell[1,1] → Cell[1,2] → ...
```

When end of bounds reached: `is_exhausted()` stops accepting input.

---

## Error Handling

| Edge Case | Handling |
|-----------|----------|
| 1-column board + vertical mode | Wraps past end → `is_exhausted()` stops input |
| 1-row board + horizontal mode | Wraps past end → `is_exhausted()` stops input |
| Toggle while typing | Session recreated with new orientation, placed tiles persist |
| Icon overlap on small screens | Responsive positioning (future enhancement) |

---

## Testing Considerations

1. **State immutability:** Verify `toggled()` returns new instance, doesn't mutate
2. **Persistence:** Toggle orientation, switch zones (hand↔board), verify orientation persists
3. **Word-wrap:** Place tiles to edge in both directions, verify wrap behavior
4. **UI feedback:** Stomp animation plays on icon toggle
5. **Placed tiles:** Switching orientation doesn't affect already-placed tiles
6. **Bounds:** Verify `is_exhausted()` works correctly in both orientations

---

## Constraints & Principles

- **Immutability:** RunOrientationState never mutates; toggle creates new instance
- **OOP/DDD:** Orientation is a domain concept, not a UI concern
- **Single responsibility:** Each component has one reason to change
- **Low cyclomatic complexity:** Toggle logic is simple (Vector2i flip), wrap logic isolated to BoardTypingSession
- **Low verbosity:** Minimal boilerplate, high-frequency patterns (factory methods, immutable updates)

---

## Files to Create/Modify

### Create
- `scripts/domain/run_orientation_state.gd` - Immutable value object

### Modify
- `scenes/ui/focus_cursor/focus_cursor.gd` - Add orientation dependency, TAB handling
- `scenes/board/board.gd` - Add OrientationIconButton child
- `scenes/board/orientation_icon_button.gd` - New UI component (create as separate script)
- `scripts/interaction/board_typing_session.gd` - Update word-wrap for vertical
- `scripts/controllers/gameplay_controller.gd` - Coordinate orientation changes

---

## Status

✅ **APPROVED** - Ready for implementation planning
