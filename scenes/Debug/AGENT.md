# Debug Components

## Overview
Debug tools for development and testing. Provides in-game console for commands and visual debugging overlays.

## Files
- `DebugConsole.tscn` / `debug_console.gd` - In-game command console

---

## DebugConsole

### Purpose
In-game command console for executing debug commands during development. Accepts text input and displays command output.

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

### Available Commands

| Command | Arguments | Description |
|---------|-----------|-------------|
| `help` | none | Show all available commands |
| `close` / `exit` | none | Hide the console |
| `spawn` | `<letter> [count]` | Spawn tiles in hand (e.g., `spawn A 3`) |
| `draw` | `[count]` | Draw tiles from bag (default: 1) |
| `clear_board` | none | Remove all tiles from board |

### Usage Examples
```
> spawn A         # Spawn 1 'A' tile
> spawn E 5       # Spawn 5 'E' tiles
> draw 3          # Draw 3 tiles from bag
> clear_board     # Clear all board tiles
> help            # Show command list
```

### Command Processing & Integration

**Flow:**
1. User types command in InputLine and presses Enter
2. `_on_command_submitted()` called with command string
3. Command echoed to OutputLog with `> ` prefix
4. `DebugManager.execute_command()` called with string
5. DebugManager parses, validates, and executes command
6. DebugManager calls `DebugConsole.print_line()` (via callback) with results
7. Output displayed in OutputLog

**Callback System:**
```gdscript
# In DebugConsole._ready():
DebugManager.console_print = print_line

# In DebugManager:
func log_output(message: String) -> void:
    if console_print.is_valid():
        console_print.call(message)  # Calls DebugConsole.print_line()
```

**Auto-scrolling:**
After each output line, `print_line()` waits for process_frame, then scrolls OutputLog to bottom for continuous visibility.

---

## Debug Features

### Debug Logging
Throughout the codebase, debug prints follow the pattern:
```gdscript
print("[ComponentName] Action: details")
```

Examples:
- `[Main] Tile selected: Tile_A`
- `[TileBag] Drew: E | Remaining: 42`
- `[HandManager] Discarded tile: X | Discard pile: 5`

### Board Hover Debug
Board component has optional hover debugging:
```gdscript
board.debug_hover = true  # Logs hover detection every 15 frames
```

---

## Future Debug Features
- State inspector (view all manager states)
- Event logger (track EventBus signals)
- Performance metrics overlay
- Tile bag contents viewer
- Selection state visualizer
