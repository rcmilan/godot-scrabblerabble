# Title Screen

## Overview
Title screen / main menu scene for the game. Entry point that allows players to start a new game, configure options, or exit.

## Files
- `TitleScreen.tscn` - Main title screen scene
- `title_screen.gd` - Title screen controller
- `OptionsPopup.tscn` - Options popup dialog
- `options_popup.gd` - Options popup controller

---

## TitleScreen

### Purpose
Main entry point for the game. Displays the game title "Scrabblerabble" and provides menu navigation with keyboard and mouse support.

### Controls

#### Keyboard
| Key | Action |
|-----|--------|
| W / Up Arrow | Navigate up |
| S / Down Arrow | Navigate down |
| A | Jump to first menu item |
| D | Jump to last menu item |
| Enter / Space | Activate selected item |

#### Mouse
- Click any menu button to activate it
- Hover over buttons to focus them

### Menu Options

1. **New Game** - Starts the gameplay loop (loads Main.tscn)
2. **Options** - Opens the options popup
3. **Exit** - Quits the application

### Architecture

Follows the controller pattern used in the rest of the codebase:

```gdscript
# Controller setup
_menu_controller = MenuController.new()
add_child(_menu_controller)
_menu_controller.setup(new_game_btn, options_btn, exit_btn)
_menu_controller.activate()

# Signals
_menu_controller.new_game_requested.connect(_on_new_game_requested)
_menu_controller.options_requested.connect(_on_options_requested)
_menu_controller.exit_requested.connect(_on_exit_requested)
```

### Future Extensions

The New Game option is designed to support passing configuration parameters to the gameplay scene:

```gdscript
# Future implementation
var config = GameConfiguration.new()
config.board_size = Vector2i(8, 8)
config.hand_size = 10
config.max_rounds = 10
config.target_score = 100

# Pass config to gameplay scene
GameManager.start_game_with_config(config)
```

---

## MenuController

### Purpose
Handles menu navigation and input processing. Separates input logic from UI presentation following the controller pattern.

### Lifecycle
```gdscript
# Setup
var controller = MenuController.new()
add_child(controller)
controller.setup(new_game_btn, options_btn, exit_btn)

# Activate/Deactivate
controller.activate()   # Enable input processing
controller.deactivate() # Disable input processing (e.g., when options popup is open)
```

### Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `menu_item_selected` | `index: int` | Menu item focused/highlighted |
| `new_game_requested` | - | New Game button activated |
| `options_requested` | - | Options button activated |
| `exit_requested` | - | Exit button activated |

### Features
- Keyboard navigation with wrapping (up from first item goes to last)
- Mouse hover support (hovering focuses item)
- A/D shortcuts for quick navigation to first/last items
- Focus tracking for visual feedback

---

## OptionsPopup

### Purpose
Modal popup dialog displaying game options. Currently shows mocked settings as placeholders.

### Contents

#### Graphics (Mocked)
- Fullscreen checkbox (non-functional placeholder)
- V-Sync checkbox (non-functional placeholder)

#### Audio (Mocked)
- Volume slider (non-functional placeholder, displays 0-100%)

### Controls
- **ESC** - Close popup
- **Close Button** - Close popup
- Mouse interaction with checkboxes and slider

### API
```gdscript
# Show popup
options_popup.show_popup()  # Shows and grabs focus

# Close popup
options_popup.close_popup()  # Hides and emits 'closed' signal

# Signal
options_popup.closed.connect(_on_options_closed)
```

### Design
- Semi-transparent overlay (70% black) behind popup
- Centered panel with settings
- Automatically grabs focus when opened
- Emits `closed` signal when dismissed

---

## Design Principles

### Domain-Driven Design (DDD)

The title screen follows DDD principles:

**Presentation Layer** (UI)
- `TitleScreen` - Main menu view
- `OptionsPopup` - Options dialog view

**Application Layer** (Controllers)
- `MenuController` - Menu navigation and input handling
- Future: `GameConfiguration` - Game setup parameters

**Domain Layer** (Future)
- `GameConfiguration` - Game setup parameters (board size, hand size, etc.)
- Configuration validation and defaults

### Object-Oriented Principles

1. **Single Responsibility**
   - `TitleScreen` manages scene structure
   - `MenuController` handles input/navigation
   - `OptionsPopup` manages options UI

2. **Dependency Injection**
   - Controller receives button references via `setup()`
   - Makes dependencies explicit and testable

3. **Composition Over Inheritance**
   - Controller is added as child node, not extended
   - Allows easy activation/deactivation

4. **Signal-Based Communication**
   - Controller emits signals for actions
   - Decouples controller from specific implementations

---

## Integration

### Making TitleScreen the Entry Point

Update `project.godot`:
```ini
[application]
run/main_scene="res://scenes/title_screen/TitleScreen.tscn"
```

### Scene Transition Flow
```
TitleScreen
    ↓ (New Game)
Main (Gameplay)
```

Future flow with configuration:
```
TitleScreen
    ↓ (New Game with config)
Main (Gameplay with parameters)
    ↓ (Round End)
Shop/Upgrade Scene
    ↓ (Continue)
Main (Next Round)
```

---

## Future Enhancements

### Planned Features
- [ ] Game configuration UI (board size, hand size, etc.)
- [ ] Multiple game modes (Classic, Daily Challenge, etc.)
- [ ] Save/Load game selection
- [ ] Statistics display (games played, high scores)
- [ ] Tutorial/How to Play option
- [ ] Credits screen
- [ ] Settings persistence (actual options implementation)
- [ ] Animated transitions between scenes
- [ ] Background music toggle
- [ ] Difficulty selection

### Configuration System

Future domain model for game configuration:

```gdscript
class_name GameConfiguration
extends Resource

@export var board_size: Vector2i = Vector2i(8, 8)
@export var hand_size: int = 10
@export var max_hand_size: int = 15
@export var max_rounds: int = 10
@export var target_score: int = 100
@export var plays_per_round: int = 10
@export var bag_distribution: BagDistribution

func validate() -> bool:
    # Validation logic
    pass

func get_defaults() -> GameConfiguration:
    # Return default configuration
    pass
```
