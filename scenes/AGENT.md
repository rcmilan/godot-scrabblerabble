# Scenes Directory

## Overview
Contains all game scenes and their associated scripts. Each subdirectory represents a major component of the game.

## Structure
```
scenes/
├── title_screen/          # Title screen and main menu
├── Main.tscn              # Gameplay scene (root)
├── main.gd                # Main controller script
├── board/                 # Board and cell components
├── hand/                  # Hand component
├── tile/                  # Tile component
├── shop/                  # Between-round shop and configuration
├── ui/                    # UI overlays, HUD, and dialogs
└── debug/                 # Debug tools
```

---

## Title Screen

### Purpose
Entry point for the game. Main menu with navigation to start new game, configure options, or exit.

See [title_screen/AGENT.md](title_screen/AGENT.md) for detailed documentation.

### Features
- **Menu Navigation**: Keyboard (WASD/arrows) and mouse support
- **Quick Navigation**: A/D to jump to first/last menu item
- **Run Setup Popup**: Game configuration (bag, hand size, plays per round, progression)
- **Options Popup**: Modal dialog with game settings
- **Scene Transition**: Loads Main.tscn when "New Game" is selected

### Architecture
Uses `MenuController` following the same controller pattern as `GameplayController`:
- Composition over inheritance
- Dependency injection
- Signal-based communication
- Activate/deactivate lifecycle

---

## Main Scene

### Purpose
Gameplay scene that orchestrates all game components. Handles tile selection, placement, drag-and-drop, and discard operations.

### Class: `Main extends Control`

### Node Structure
```
Main (Control)
├── Board                           # Game grid
├── Hand                            # Player's tiles
├── DebugConsole                    # Debug commands (hidden)
├── MultiSelectIndicator            # Selection mode indicator
├── MainHUD                         # Game state display (CanvasLayer)
├── DiscardPile                     # Discard drop zone
├── DiscardConfirmationDialog       # Discard confirmation popup (CanvasLayer)
├── ShopOverlay                     # Between-round shop/summary (CanvasLayer)
├── PauseMenu                       # Pause menu overlay (CanvasLayer)
└── GameOverPopup                   # Victory/defeat screen (CanvasLayer)

# Local nodes (created dynamically)
├── SelectionManager                # Selection state (created by Main)
└── GameplayController
    └── DragManager                 # Multi-tile drag (created by controller)
```

### Round Lifecycle
```
1. Main._start_run() → RunManager.start_run()
2. RunManager._advance_to_next_round() → generates RoundConfig
3. EventBus.run_round_ready emitted → Main._on_round_ready()
4. Main configures board size, hand size from RoundConfig
5. Gameplay loop: tile placement, discard, plays
6. PlayHandler detects win/lose condition
7. GameManager.end_game() → EventBus.game_ended
8. Main._on_run_ended() → show GameOverPopup or transition to shop
9. If shop: EventBus.run_shop_requested → Main._on_shop_requested()
10. ShopOverlay shows round summary, "Continue" button
11. ShopOverlay.continue_requested → Main._on_shop_continue()
12. Go back to step 2 for next round
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
- **Dependency Injection**: Creates GameplayController and injects dependencies (Board, Hand, etc.)
- **Orchestration**: Coordinates between Board, Hand, Tiles, and UI components
- **Selection**: Delegates to SelectionManager for single/multi-select operations
- **Placement**: Handles single-tile and multi-tile placement with validation
- **Drag-and-Drop**: Manages drag operations via DragManager, including cell binding state
- **Discard Flow**: Orchestrates discard with confirmation dialog, animation, and refill
- **Input Handling**: Processes Q (toggle multi-select) and Z (discard) actions
- **Game State**: Tracks tiles placed, communicates with GameManager for scoring

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

### title_screen/
Title screen and main menu. See [title_screen/AGENT.md](title_screen/AGENT.md)
- Menu navigation with keyboard and mouse
- Options popup with settings
- Game entry point
- Future: Game configuration (board size, hand size, etc.)

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
- **Drag-and-drop**: Threshold-based drag detection (8px minimum)
- **Click-to-select**: Toggles tile selection state
- **Visual States**: Scale animation for selection, modulation for drag
- **Location Tracking**: Maintains state (IN_BAG, IN_HAND, ON_BOARD, IN_DISCARD)
- **Atomic Cell Binding**: Ensures tile ↔ cell references stay synchronized
  - `attach_to_cell()`: Bidirectional binding
  - `detach_from_cell()`: Clear both references
  - `suspend_cell_binding()`: For drag operations
  - `restore_cell_binding()`: Restore after cancelled drag
  - Prevents inconsistent state where tile.current_cell ≠ cell.tile

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
- Victory/defeat screens
- Game configuration screen (customize board size, hand size, etc.)
- Statistics/achievements screen
