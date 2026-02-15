# Controllers

## Overview
Controllers encapsulate specific game behaviors that can be activated/deactivated based on game state. They follow the composition pattern to keep scene scripts simple.

## Files
- `gameplay_controller.gd` - Coordinator for tile-based gameplay interaction
- `tile_placement_handler.gd` - Tile placement and return operations
- `drop_handler.gd` - Drag-and-drop validation and execution
- `play_handler.gd` - Play submission, scoring, auto-end-round
- `menu_controller.gd` - Title screen menu navigation and input

---

## GameplayController (Coordinator)

### Purpose
Coordinator that routes input events and signals to specialized handlers. Owns DragManager as a local child node. Retains discard logic, interaction state, tile registration, and signal management.

### Architecture
```
GameplayController (coordinator)
  ├── DragManager             (local child node)
  ├── TilePlacementHandler    (placement, return, cell helpers)
  ├── DropHandler             (drag release, drop validation)
  └── PlayHandler             (play/score, auto-end-round, button state)
```

### Lifecycle
```gdscript
# Created and added as child of Main
var controller = GameplayController.new()
add_child(controller)

# Inject scene dependencies including SelectionManager (creates handlers internally)
controller.setup(board, hand, discard_pile, discard_dialog, main_hud, selection_manager)

# Activate when gameplay should be enabled
controller.activate()

# Deactivate for menus, dialogs, transitions
controller.deactivate()
```

### Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `tile_placement_completed` | `tile, cell` | Tile placed on board |
| `tile_returned_to_hand` | `tile` | Tile returned from board |
| `play_completed` | `tiles, words` | Tiles played (locked) |

### Signal Connection Management
Uses `_safe_connect()` / `_disconnect_all()` pattern with a tracking array to eliminate boilerplate.

### Key Methods
```gdscript
# Setup and lifecycle
setup(board, hand, discard_pile, discard_dialog, hud, selection_manager) -> void
activate() -> void
deactivate() -> void

# Tile registration (called by HandManager via Main)
register_tile(tile: Tile) -> void

# Delegated to PlayHandler
get_word_validator() -> WordValidator
```

### Dependency Injection Chain
```
Main creates SelectionManager
  → Main injects into: hand, discard_pile, multi_select_indicator
  → Main passes to: GameplayController.setup()
      → GameplayController creates DragManager (local child)
      → _placement.setup(board, hand, selection)
      → _drop.setup(_placement, hand, selection, drag_mgr)
      → _play.setup(board, main_hud, selection)
```

---

## TilePlacementHandler

### Purpose
Manages tile placement on board cells and returning tiles to hand. Provides cell query helpers.

### Class: `TilePlacementHandler extends RefCounted`

### Dependencies
- `Board`, `Hand`, `SelectionManager` (injected via `setup()`)

### Key Methods
```gdscript
setup(board: Board, hand: Hand, selection: SelectionManager) -> void
place_tile_on_cell(tile: Tile, cell: BoardCell) -> void
place_tile_on_cell_silent(tile: Tile, cell: BoardCell) -> void
return_tile_to_hand(tile: Tile, preserve_selection: bool = false) -> void
get_sequential_cells(start: BoardCell, count: int) -> Array[BoardCell]
get_sequential_cells_centered(drop_cell, count, lead_index) -> Array[BoardCell]
return_to_original_cell(tile: Tile) -> void
get_cell_under_mouse(viewport: Viewport) -> BoardCell
clear_all_cell_hovers() -> void
```

---

## DropHandler

### Purpose
Handles drag-and-drop release validation and execution. Validates drop targets and delegates placement to TilePlacementHandler.

### Class: `DropHandler extends RefCounted`

### Dependencies
- `TilePlacementHandler`, `Hand`, `SelectionManager`, `DragManager` (injected via `setup()`)

### Key Methods
```gdscript
setup(placement: TilePlacementHandler, hand: Hand, selection: SelectionManager, drag_mgr: DragManager) -> void
handle_tile_drop(drop_cell: BoardCell, tiles: Array[Tile]) -> bool
```

### Properties
```gdscript
var last_placement_success: bool  # Read by coordinator after drop
```

---

## PlayHandler

### Purpose
Manages play submission, word validation, scoring, and auto-end-round logic. Controls Play/End Round button state. Animates ALL board tiles on each play with modifier-aware animation dispatch.

### Class: `PlayHandler extends RefCounted`

### Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `play_completed` | `tiles, words` | Play submitted (forwarded to coordinator) |

### Dependencies
- `Board`, `MainHUD`, `SelectionManager` (injected via `setup()`)
- Uses `GameManager`, `HandManager`, `TileBag`, `TileAnimator`, `EventBus` (global autoloads)

### Key Methods
```gdscript
setup(board: Board, hud: CanvasLayer, selection: SelectionManager) -> void
on_play_requested() -> void
update_play_button_state() -> void
get_word_validator() -> WordValidator
has_valid_moves() -> bool
```

### Play Flow (`on_play_requested`)
1. Lock unplayed tiles via `set_locked(true)` (adds LOCKED modifier)
2. Deselect all tiles
3. Get ALL board tiles (locked + newly locked)
4. Split by animation type BEFORE consuming (modifiers still present):
   - Tiles with RESET → Stomp (denies special animations)
   - Tiles with EXTRA/MULTI/EXPO (no RESET) → Spin
   - Plain tiles → Stomp
5. Hide locked borders during animation
6. Run stomp + spin animations in parallel, await both
7. Consume CONSUMABLE modifiers AFTER animation completes
8. Emit `tiles_played` and `play_completed` signals

### Auto-End-Round Flow (`_auto_end_round`)
When no valid moves remain, auto-plays all remaining plays:
1. Lock all unlocked tiles
2. Calculate score once (board state constant)
3. Split tiles by animation type (once, outside loop)
4. Loop: hide borders → animate → await → commit score per play

---

## MenuController

### Purpose
Manages menu navigation and input handling for the title screen.

### Lifecycle
```gdscript
var controller = MenuController.new()
add_child(controller)
controller.setup(new_game_btn, options_btn, exit_btn)
controller.activate()
```

---

## Design Principles

### Composition Over Inheritance
Controllers are added as children of the scene they control, not extended.

### Dependency Injection
Controllers receive their dependencies via `setup()` rather than finding nodes themselves. SelectionManager and DragManager are injected — not accessed as autoloads.

### Coordinator Pattern
GameplayController delegates to focused handlers (RefCounted objects) while retaining:
- Signal management (connect/disconnect lifecycle)
- Input routing and event dispatching
- Cross-cutting concerns (discard straddles placement + UI)
- DragManager ownership (local child node)

### Signal-Based Communication
Controllers emit signals for completed actions rather than directly calling scene methods.
