# Debug Components

## Overview
Debug tools for development and testing. Provides in-game console for commands and visual debugging overlays.

## Files
- `DebugConsole.tscn` / `debug_console.gd` - In-game command console
- `debug_manager.gd` - Debug command executor (RefCounted, owned by DebugConsole)

---

## DebugConsole

### Purpose
In-game command console for executing debug commands during development. Accepts text input and displays command output. Owns a DebugManager instance.

### Class: `DebugConsole extends CanvasLayer`

### Node Structure
```
DebugConsole (CanvasLayer, layer=1)
└── Panel (Panel)
    └── VBoxContainer
        ├── OutputLog (RichTextLabel)  # Command output display
        └── InputLine (LineEdit)        # Command input field
```

### Activation & Interaction
- **Visibility**: Press **D** key to toggle visibility
- **Input**: Type command in InputLine and press Enter
- **Output**: Responses appear in OutputLog with auto-scroll to bottom
- **Focus**: Console automatically grabs focus when shown

### DebugManager Ownership
DebugConsole creates and owns a DebugManager instance in `_ready()`:
```gdscript
_debug_mgr = DebugManager.new()
_debug_mgr.setup(get_parent(), print_line)  # get_parent() = Main
```

---

## DebugManager

### Purpose
Command-based debug system. RefCounted helper owned by DebugConsole (not an autoload).

### Class: `DebugManager extends RefCounted`

### Setup
```gdscript
func setup(main: Node, log_fn: Callable) -> void
```
Receives Main scene reference and console print callback.

### Commands
| Command | Arguments | Description |
|---------|-----------|-------------|
| `help` | none | Show all available commands |
| `spawn` | `<letter> [count]` | Spawn tiles in hand (e.g., `spawn A 3`) |
| `draw` | `[count]` | Draw tiles from bag (default: 1) |
| `clear_board` | none | Remove all tiles from board |
| `close/exit` | none | Hide the debug console |

### Dependencies
- Uses `HandManager` (autoload) for draw operations
- Uses `EventBus` (autoload) for hand count signals
- Receives Main scene reference via `setup()` for board/hand access

---

## Debug Features

### Debug Logging
Throughout the codebase, debug prints follow the pattern:
```gdscript
print("[ComponentName] Action: details")
```

---

## Future Debug Features
- State inspector (view all manager states)
- Event logger (track EventBus signals)
- Performance metrics overlay
- Tile bag contents viewer
- Selection state visualizer
