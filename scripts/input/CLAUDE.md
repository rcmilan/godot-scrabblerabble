# Input Directory

## Purpose
Input handling utilities for keyboard navigation and cursor positioning. Provides data structures and constants for managing keyboard-based UI navigation and hand/board selection.

## Key Files
- `cursor_position.gd` - Value object representing cursor location (hand or board)
- `cursor_state.gd` - Cursor state tracking for keyboard navigation
- `key_action.gd` - Input action constants and mappings
- `modal_input_guard.gd` - Utility for blocking input during modals

## Public Interfaces

### CursorPosition (Value Object)
```gdscript
class_name CursorPosition extends RefCounted

enum Zone { HAND, BOARD }
var zone: Zone
var hand_index: int
var board_coords: Vector2i

# Factory methods
static func hand(index: int) -> CursorPosition
static func board(coords: Vector2i) -> CursorPosition
```

Represents a position in either the player's hand (by index) or on the board (by grid coordinates). Used by keyboard navigation for maintaining focus state.

### CursorState
State machine for keyboard navigation tracking hand/board position and direction.

### KeyAction
Constants for input action names mapped to Godot InputMap:
```gdscript
const NAVIGATE_LEFT  := &"navigate_left"
const NAVIGATE_RIGHT := &"navigate_right"
const NAVIGATE_UP    := &"navigate_up"
const NAVIGATE_DOWN  := &"navigate_down"
const CONFIRM        := &"confirm_action"
const CANCEL         := &"cancel_action"
const SWITCH_ZONE    := &"switch_zone"      # Hand ↔ Board
const PLAY_HAND      := &"play_hand"        # Play submitted
const DRAW_TILES     := &"draw_tiles"
const DISCARD_TILES  := &"discard_tiles"
const PAUSE_GAME     := &"pause_game"
const TOGGLE_MULTI   := &"toggle_multi_select"
```

### ModalInputGuard
Utility for blocking input when modal dialogs are displayed. Prevents accidental interactions with underlying game while modal is active.

## Dependencies
- **Internal:** None (pure data structures)
- **External:** Godot InputMap for action mapping

## Architecture / Patterns
- **Value Object Pattern:** CursorPosition is immutable after creation
- **Factory Pattern:** CursorPosition uses static factory methods for construction
- **Constants:** KeyAction uses static string constants (StringName type)
- **Separation of Concerns:** Input data structures separate from input handling logic

## Constraints
- CursorPosition must be valid (hand_index ≥ 0 or board_coords valid)
- All input actions must be registered in project.godot InputMap
- Modal input guard must be checked before processing gameplay input

## Build / Test
No build step. Input actions defined in project.godot. Test keyboard layouts and action mappings in project settings.

---

## Conventions
- **Constants:** UPPERCASE names using StringName (&"action_name")
- **Naming:** Action names use snake_case
- **Pattern:** CursorPosition uses factory methods instead of constructors
- **Value Objects:** Immutable after creation, use static factories

## Usage Example
```gdscript
# Create cursor position in hand
var hand_pos = CursorPosition.hand(3)

# Create cursor position on board
var board_pos = CursorPosition.board(Vector2i(3, 5))

# Query position type
if hand_pos.is_hand():
    var index = hand_pos.hand_index
elif board_pos.is_board():
    var coords = board_pos.board_coords
```
