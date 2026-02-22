# Focus Cursor Component

## Purpose
Keyboard and controller navigation cursor for hand and board zones. Provides a visual highlight and manages cursor state machine for navigation through tiles on the board and in hand.

## Key Files
- `focus_cursor.gd` - Cursor controller and state machine
- `FocusCursor.tscn` - Cursor visual scene with highlight rect

## Public Interfaces

### FocusCursor (Editor Component)
```gdscript
class_name FocusCursor extends Control

# Zone enum exported for external reference
const Zone := CursorPosition.Zone  # HAND or BOARD

# Setup cursor for navigation
func setup(board: Board, hand: Hand) -> void

# Signals
signal cursor_confirmed(pos: CursorPosition)  # Enter/confirm action
signal cursor_cancelled(pos: CursorPosition)  # ESC/cancel action
signal cursor_moved(pos: CursorPosition)      # Cursor moved to new position
```

## State Management

### CursorState (Internal State Machine)
Manages cursor position and navigation logic:
- **Hand Zone:** Navigate through hand tiles by index (left/right keys)
- **Board Zone:** Navigate through board cells by coordinates (arrow keys)
- **Zone Switching:** Switch between hand and board zones (dedicated key)

### Position Types
- **Hand Position:** Index from 0 to hand.get_tile_count()-1
- **Board Position:** Vector2i coordinates (0,0) to (cols-1, rows-1)

## Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `cursor_confirmed` | `pos: CursorPosition` | Enter/confirm pressed on current position |
| `cursor_cancelled` | `pos: CursorPosition` | ESC/cancel pressed |
| `cursor_moved` | `pos: CursorPosition` | Cursor moved to new valid position |

## Key Methods

### Setup & Lifecycle
```gdscript
setup(board: Board, hand: Hand) -> void  # Receive scene dependencies
activate() -> void                        # Enable cursor input processing
deactivate() -> void                      # Disable cursor input processing
```

### Navigation
```gdscript
get_current_position() -> CursorPosition  # Get where cursor is
move_relative(direction: Vector2i) -> void # Attempt to move in direction
move_to_position(pos: CursorPosition) -> void # Jump to specific position
switch_zone() -> void                     # Toggle between hand and board
```

### Visual State
```gdscript
highlight_tile(tile: Tile) -> void       # Show cursor on tile
clear_highlight() -> void                 # Hide cursor highlight
```

## Dependencies
- **Internal:** Board, Hand (injected via setup)
- **External:** CursorPosition, CursorState, KeyAction constants

## Architecture / Patterns
- **State Machine:** CursorState manages navigation logic independently
- **Signal-Based:** Emits position changes; GameplayController listens and executes actions
- **Activation Pattern:** Can be activated/deactivated based on game state
- **Dependency Injection:** Board and Hand injected during setup

## Constraints
- Must have valid Board and Hand references (set in setup)
- Cursor position must always be within valid ranges
- Navigation wraps at boundaries (e.g., right-most tile wraps to left-most)
- Cursor is disabled during modals and menu overlays

## Build / Test
Test cursor movement in hand and board zones. Verify boundary behavior and zone switching.

---

## Conventions
- **Naming:** Cursor methods use verb phrases (move_to, switch_zone, highlight)
- **Position:** Always valid CursorPosition, never out of bounds
- **Signal Pattern:** Emit signals for all navigation state changes
- **Visual:** Highlight rect follows cursor position updates

## Usage in Context
```gdscript
# In Main._setup_controllers():
var cursor_scene = preload("res://scenes/ui/focus_cursor/FocusCursor.tscn")
_focus_cursor = cursor_scene.instantiate()
add_child(_focus_cursor)
_focus_cursor.setup(board, hand)

# In GameplayController:
_focus_cursor.cursor_confirmed.connect(_on_cursor_confirmed)
_focus_cursor.cursor_moved.connect(_on_cursor_moved)
```
