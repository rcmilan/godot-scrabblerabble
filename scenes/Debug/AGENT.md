# Debug Components

## Overview
Debug tools for development and testing. Provides in-game console for commands and visual debugging overlays.

## Files
- `DebugConsole.tscn` / `debug_console.gd` - In-game command console

---

## DebugConsole

### Purpose
In-game command console for executing debug commands during development.

### Class: `DebugConsole extends Control`

### Activation
- Press **D** key to toggle visibility
- Console appears as overlay on top of game

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

### Command Processing
Commands are processed by `DebugManager` autoload:
1. Console sends command string to DebugManager
2. DebugManager parses and validates command
3. Command executed with appropriate managers (TileBag, HandManager, etc.)
4. Result message displayed in console

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
