# Controllers

## Overview
Controllers encapsulate specific game behaviors that can be activated/deactivated based on game state. They follow the composition pattern to keep scene scripts simple.

## Files
- `gameplay_controller.gd` - All tile-based gameplay interaction

---

## GameplayController

### Purpose
Manages all tile-based gameplay interaction including:
- Tile selection and multi-select
- Drag and drop (single and multi-tile)
- Tile placement on board
- Discard pile interaction
- Play/submit action

### Lifecycle
```gdscript
# Created and added as child of Main
var controller = GameplayController.new()
add_child(controller)

# Inject scene dependencies
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

### Key Methods
```gdscript
# Setup and lifecycle
setup(board, hand, discard_pile, discard_dialog, hud) -> void
activate() -> void
deactivate() -> void

# Tile registration (called by HandManager via Main)
register_tile(tile: Tile) -> void
```

### State
```gdscript
enum InteractionMode { IDLE, TILE_SELECTED, DRAGGING }

var interaction_mode: InteractionMode
var selected_tile: Tile
var _is_active: bool
```

### Usage in Main.gd
```gdscript
func _ready():
    _gameplay_controller = GameplayController.new()
    add_child(_gameplay_controller)
    _gameplay_controller.setup(board, hand, discard_pile, discard_dialog, main_hud)
    _gameplay_controller.activate()

func pause_gameplay():
    _gameplay_controller.deactivate()

func resume_gameplay():
    _gameplay_controller.activate()

func register_tile(tile: Tile):
    _gameplay_controller.register_tile(tile)
```

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

### Signal-Based Communication
Controllers emit signals for completed actions rather than directly calling scene methods. This:
- Decouples controller from specific scene implementation
- Allows multiple listeners
- Makes data flow explicit

---

## Future Controllers

As the game grows, additional controllers may be added:

- **MenuController** - Main menu navigation
- **SettingsController** - Settings UI interaction
- **TutorialController** - Tutorial flow management
- **ScoreController** - Score display and animations

Each follows the same pattern: setup, activate, deactivate, signals.
