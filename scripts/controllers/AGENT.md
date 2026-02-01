# Controllers

## Overview
Controllers encapsulate specific game behaviors that can be activated/deactivated based on game state. They follow the composition pattern to keep scene scripts simple.

## Files
- `gameplay_controller.gd` - All tile-based gameplay interaction
- `menu_controller.gd` - Title screen menu navigation and input

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

### Key Methods
```gdscript
# Setup and lifecycle
setup(new_game_btn, options_btn, exit_btn) -> void
activate() -> void
deactivate() -> void
```

### Input Mapping
| Input | Action |
|-------|--------|
| W / Up Arrow | Navigate up (wraps) |
| S / Down Arrow | Navigate down (wraps) |
| A | Jump to first item |
| D | Jump to last item |
| Enter / Space | Activate current item |
| Mouse Click | Activate clicked item |
| Mouse Hover | Focus hovered item |

### Usage in TitleScreen.gd
```gdscript
func _ready():
    _menu_controller = MenuController.new()
    add_child(_menu_controller)
    _menu_controller.setup(_new_game_button, _options_button, _exit_button)
    _menu_controller.new_game_requested.connect(_on_new_game_requested)
    _menu_controller.options_requested.connect(_on_options_requested)
    _menu_controller.exit_requested.connect(_on_exit_requested)
    _menu_controller.activate()

func _on_options_requested():
    _menu_controller.deactivate()  # Disable menu while options popup is open
    _options_popup.show_popup()

func _on_options_closed():
    _menu_controller.activate()  # Re-enable menu when popup closes
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

- **SettingsController** - Settings UI interaction (for actual options implementation)
- **TutorialController** - Tutorial flow management
- **ScoreController** - Score display and animations
- **ConfigurationController** - Game setup and customization

Each follows the same pattern: setup, activate, deactivate, signals.
