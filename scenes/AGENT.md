# Scenes Directory

## Overview
Contains all game scenes and their associated scripts. Each subdirectory represents a major component of the game.

## Structure
```
scenes/
├── Main.tscn          # Root game scene
├── main.gd            # Main controller script
├── board/             # Board and cell components
├── hand/              # Hand component
├── tile/              # Tile component
├── ui/                # UI overlays and HUD
└── debug/             # Debug tools
```

---

## Main Scene

### Purpose
Root scene that orchestrates all game components. Handles tile placement, selection, and game flow coordination.

### Class: `Main extends Node`

### Interaction State Machine
```gdscript
enum InteractionMode {
    IDLE,           # No tile selected
    TILE_SELECTED,  # Tile selected, waiting for placement
    DRAGGING        # Tile being dragged
}
```

### Key Responsibilities
- Coordinate between Board, Hand, and Tiles
- Handle tile selection and placement
- Process drag-and-drop operations
- Manage hover feedback

### Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `tile_placement_completed` | `tile, cell` | Tile placed successfully |
| `tile_returned_to_hand` | `tile` | Tile returned from board |

### Key Methods
```gdscript
place_tile_on_cell(tile, cell) -> void
return_tile_to_hand(tile) -> void
```

---

## Component Directories

### board/
Game grid management. See [board/AGENT.md](board/AGENT.md)
- Dynamic grid generation (configurable rows/columns)
- Cell state management
- Placement validation

### hand/
Player's tile collection. See [hand/AGENT.md](hand/AGENT.md)
- Tile container
- Single/multi-select support
- Hand queries

### tile/
Letter tile component. See [tile/AGENT.md](tile/AGENT.md)
- Drag-and-drop behavior
- Click-to-select
- Visual states

### ui/
User interface overlays.
- `MainHUD.tscn` - Score, plays, game info
- `DebugOverlay.tscn` - Debug tools panel

### debug/
Debug utilities.
- `DebugConsole.tscn` - Command console (D key)

---

## Scene Communication Flow

```
User Input
    │
    ▼
  Main ◄──────── EventBus (global signals)
    │
    ├─► Board ──► BoardCell
    │
    ├─► Hand ──► Tile
    │
    └─► UI (MainHUD)
```

## Game Flow

1. **Game Start**: `GameManager.start_game()` is called
2. **Hand Fill**: `HandManager.refill_hand()` draws tiles
3. **Tile Selection**: User clicks tile, `Main._on_tile_selected()` handles
4. **Placement**: User clicks cell, `Main.place_tile_on_cell()` executes
5. **Play Commit**: Score calculated, `GameManager.commit_play()` called
6. **Round End**: Win/lose conditions checked

## Future Scenes
- Shop scene (between rounds)
- Deck builder scene
- Title/menu scene
- Victory/defeat screens
