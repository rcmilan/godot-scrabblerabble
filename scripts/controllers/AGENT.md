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
Coordinator that routes input events and signals to specialized handlers. Retains discard logic, interaction state, tile registration, and signal management.

### Architecture
```
GameplayController (coordinator)
  ├── TilePlacementHandler  (placement, return, cell helpers)
  ├── DropHandler            (drag release, drop validation)
  └── PlayHandler            (play/score, auto-end-round, button state)
```

### Lifecycle
```gdscript
# Created and added as child of Main
var controller = GameplayController.new()
add_child(controller)

# Inject scene dependencies (creates handlers internally)
controller.setup(board, hand, discard_pile, discard_dialog, main_hud)

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
Uses `_safe_connect()` / `_disconnect_all()` pattern with a tracking array to eliminate boilerplate:
```gdscript
var _connections: Array[Dictionary] = []

func _safe_connect(sig: Signal, handler: Callable) -> void:
    sig.connect(handler)
    _connections.append({"signal": sig, "handler": handler})

func _disconnect_all() -> void:
    for conn in _connections:
        if conn.signal.is_connected(conn.handler):
            conn.signal.disconnect(conn.handler)
    _connections.clear()
```

### Key Methods
```gdscript
# Setup and lifecycle
setup(board, hand, discard_pile, discard_dialog, hud) -> void
activate() -> void
deactivate() -> void

# Tile registration (called by HandManager via Main)
register_tile(tile: Tile) -> void

# Delegated to PlayHandler
get_word_validator() -> WordValidator
```

### Responsibilities Retained
- Signal connection management (activate/deactivate)
- Input routing (`_unhandled_input` for toggle_multi_select, discard_tiles)
- Tile selection (`_on_tile_selected`, `_on_tile_right_clicked`)
- Drag coordination (`_on_tile_drag_started`, `_on_tile_drag_ended`, `_handle_drag_release`)
- Cell interaction (`_on_cell_clicked`, `_on_cell_hovered`, `_on_cell_unhovered`)
- Discard handlers (`_request_discard`, `_discard_tiles_animated`, `_complete_discard`)
- Interaction state (`_update_interaction_state`, `_set_hand_tiles_hover_enabled`)
- Tile registration (`register_tile`)

---

## TilePlacementHandler

### Purpose
Manages tile placement on board cells and returning tiles to hand. Provides cell query helpers.

### Class: `TilePlacementHandler extends RefCounted`

### Dependencies
- `Board` and `Hand` (injected via `setup()`)
- Uses `SelectionManager`, `TileAnimator`, `EventBus` (global autoloads)

### Key Methods
```gdscript
setup(board: Board, hand: Hand) -> void
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
- `TilePlacementHandler` and `Hand` (injected via `setup()`)
- Uses `DragManager`, `SelectionManager`, `TileAnimator` (global autoloads)

### Key Methods
```gdscript
setup(placement: TilePlacementHandler, hand: Hand) -> void
handle_tile_drop(drop_cell: BoardCell, tiles: Array[Tile]) -> bool
```

### Properties
```gdscript
var last_placement_success: bool  # Read by coordinator after drop
```

---

## PlayHandler

### Purpose
Manages play submission, word validation, scoring, and auto-end-round logic. Controls Play/End Round button state.

### Class: `PlayHandler extends RefCounted`

### Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `play_completed` | `tiles, words` | Play submitted (forwarded to coordinator) |

### Dependencies
- `Board` and `MainHUD` (injected via `setup()`)
- Uses `GameManager`, `HandManager`, `TileBag`, `TileAnimator`, `SelectionManager`, `EventBus` (global autoloads)

### Key Methods
```gdscript
setup(board: Board, hud: CanvasLayer) -> void
on_play_requested() -> void
update_play_button_state() -> void
get_word_validator() -> WordValidator
has_valid_moves() -> bool
```

---

## MenuController

### Purpose
Manages menu navigation and input handling for the title screen including:
- Keyboard navigation (WASD and arrow keys)
- Mouse interaction (clicks and hover)
- Quick navigation shortcuts (A/D for first/last)
- Focus management and visual feedback

### Lifecycle
```gdscript
# Created and added as child of TitleScreen
var controller = MenuController.new()
add_child(controller)

# Inject menu button dependencies
controller.setup(new_game_btn, options_btn, exit_btn)

# Activate when menu should be enabled
controller.activate()

# Deactivate for popups or transitions
controller.deactivate()
```

### Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `menu_item_selected` | `index` | Menu item focused/highlighted |
| `new_game_requested` | - | New Game option selected |
| `options_requested` | - | Options option selected |
| `exit_requested` | - | Exit option selected |

---

## Design Principles

### Composition Over Inheritance
Controllers are added as children of the scene they control, not extended. This allows:
- Easy activation/deactivation
- Clean separation of concerns
- Testability in isolation

### Dependency Injection
Controllers receive their dependencies via `setup()` rather than finding nodes themselves. This:
- Makes dependencies explicit
- Allows different configurations
- Enables testing with mock objects

### Coordinator Pattern
GameplayController delegates to focused handlers (RefCounted objects) while retaining:
- Signal management (connect/disconnect lifecycle)
- Input routing and event dispatching
- Cross-cutting concerns (discard straddles placement + UI)

### Signal-Based Communication
Controllers emit signals for completed actions rather than directly calling scene methods. This:
- Decouples controller from specific scene implementation
- Allows multiple listeners
- Makes data flow explicit
