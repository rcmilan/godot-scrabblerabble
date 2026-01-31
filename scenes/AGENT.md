# Scenes Directory

## Overview
Contains all game scenes and their associated scripts. Each subdirectory represents a major component of the game.

## Structure
```
scenes/
├── Main.tscn              # Root game scene
├── main.gd                # Main controller script
├── board/                 # Board and cell components
├── hand/                  # Hand component
├── tile/                  # Tile component
├── ui/                    # UI overlays, HUD, and dialogs
└── debug/                 # Debug tools
```

---

## Main Scene

### Purpose
Root scene that orchestrates all game components. Handles tile selection, placement, drag-and-drop, and discard operations.

### Class: `Main extends Control`

### Node Structure
```
Main (Control)
├── Board                           # Game grid
├── Hand                            # Player's tiles
├── DebugConsole                    # Debug commands (hidden)
├── MultiSelectIndicator            # Selection mode indicator
├── MainHUD                         # Game state display
├── DiscardPile                     # Discard drop zone
└── DiscardConfirmationDialog       # Discard confirmation popup
```

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
- Handle tile selection via SelectionManager
- Process single and multi-tile drag-and-drop
- Manage cell hover feedback
- Handle discard flow with confirmation
- Input handling for Q (multi-select) and Z (discard)

### Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `tile_placement_completed` | `tile, cell` | Tile placed successfully |
| `tile_returned_to_hand` | `tile` | Tile returned from board |

### Key Methods
```gdscript
# Tile operations
place_tile_on_cell(tile, cell) -> void
return_tile_to_hand(tile) -> void

# Multi-tile operations
_handle_single_tile_drop(tile, cell) -> void
_handle_multi_tile_drop(start_cell) -> void
_get_sequential_cells(start, count) -> Array[BoardCell]

# Discard operations
_request_discard_confirmation() -> void
_discard_tiles(tiles: Array[Tile]) -> void
_handle_drop_on_discard_pile() -> void
```

### Input Handling
```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("toggle_multi_select"):
        SelectionManager.toggle_mode()
    if event.is_action_pressed("discard_tiles"):
        _request_discard_confirmation()
```

---

## Component Directories

### board/
Game grid management. See [board/AGENT.md](board/AGENT.md)
- Dynamic grid generation (configurable rows/columns)
- Cell state management
- Placement validation
- Hover feedback system

### hand/
Player's tile collection. See [hand/AGENT.md](hand/AGENT.md)
- Tile container (HBoxContainer)
- Delegates selection to SelectionManager
- Hand queries and management

### tile/
Letter tile component. See [tile/AGENT.md](tile/AGENT.md)
- Drag-and-drop behavior with threshold
- Click-to-select
- Visual states and scale animation
- Location tracking

### ui/
User interface components. See [ui/AGENT.md](ui/AGENT.md)
- `MainHUD` - Score, plays, game info display
- `DiscardPile` - Visual drop zone for discarding
- `DiscardConfirmationDialog` - Modal confirmation popup
- `MultiSelectIndicator` - Selection mode indicator

### debug/
Debug utilities. See [debug/AGENT.md](debug/AGENT.md)
- `DebugConsole` - Command console (D key)

---

## Scene Communication Flow

```
User Input
    │
    ├─► Q key ────────────────────► SelectionManager.toggle_mode()
    │                                      │
    │                                      ▼
    │                              EventBus.selection_mode_changed
    │                                      │
    │                                      ▼
    │                              MultiSelectIndicator updates
    │
    ├─► Tile click ───────────────► Main._on_tile_selected()
    │                                      │
    │                                      ▼
    │                              SelectionManager.select_tile()
    │                                      │
    │                                      ▼
    │                              EventBus.selection_changed
    │
    ├─► Cell click ───────────────► Main._on_cell_clicked()
    │                                      │
    │                                      ▼
    │                              place_tile_on_cell() or _handle_multi_tile_drop()
    │                                      │
    │                                      ▼
    │                              EventBus.tile_placed
    │
    ├─► Z key ────────────────────► Main._request_discard_confirmation()
    │                                      │
    │                                      ▼
    │                              DiscardConfirmationDialog.show_confirmation()
    │                                      │
    │                     ┌────────────────┴────────────────┐
    │                     ▼                                 ▼
    │               confirmed                          cancelled
    │                     │                                 │
    │                     ▼                                 ▼
    │            _discard_tiles()                    (selection preserved)
    │                     │
    │                     ▼
    │            HandManager.discard_tile() + refill_hand()
    │                     │
    │                     ▼
    │            EventBus signals → UI updates
    │
    └─► Tile drag to DiscardPile ─► Same discard flow
```

---

## Game Flow

1. **Game Start**: `GameManager.start_game()` is called
2. **Hand Fill**: `HandManager.refill_hand()` draws tiles
3. **Tile Selection**: User clicks tile, `SelectionManager.select_tile()` handles
4. **Placement**: User clicks cell, `Main.place_tile_on_cell()` executes
5. **Multi-select**: User presses Q, can select multiple tiles
6. **Discard**: User presses Z or drags to pile, confirmation shown
7. **Play Commit**: Score calculated, `GameManager.commit_play()` called
8. **Round End**: Win/lose conditions checked

---

## Future Scenes
- Shop scene (between rounds)
- Deck builder scene
- Title/menu scene
- Victory/defeat screens
- Settings menu
