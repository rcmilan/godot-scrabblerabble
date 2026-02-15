# Title Screen

## Overview
Title screen / main menu scene for the game. Entry point that allows players to start a new game, configure options, or exit.

## Files
- `TitleScreen.tscn` - Main title screen scene
- `title_screen.gd` - Title screen controller
- `RunSetupPopup.tscn` - Game configuration dialog (NEW)
- `run_setup_popup.gd` - Game configuration controller (NEW)
- `OptionsPopup.tscn` - Game options dialog
- `options_popup.gd` - Game options controller

---

## TitleScreen

### Purpose
Main entry point for the game. Displays the game title and provides menu navigation with keyboard and mouse support. Allows players to configure a new game before starting.

### Menu Options

1. **New Game** - Opens RunSetupPopup for game configuration, then loads Main.tscn
2. **Options** - Opens OptionsPopup for settings
3. **Exit** - Quits the application

### Controls

#### Keyboard
| Key | Action |
|-----|--------|
| W / Up Arrow | Navigate menu up |
| S / Down Arrow | Navigate menu down |
| A | Jump to first menu item |
| D | Jump to last menu item |
| Enter / Space | Activate selected item |

#### Mouse
- Click menu buttons to activate
- Hover to focus buttons

### Architecture

Uses `MenuController` following the same pattern as `GameplayController`:
- Composition over inheritance
- DependencyInjection
- Activate/deactivate lifecycle
- Signal-based communication

### Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `new_game_configured` | `config: Run` | Game configured and ready |
| `options_requested` | none | Options popup opened |
| `exit_requested` | none | Exit button pressed |
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

## RunSetupPopup

### Purpose
Game configuration dialog for customizing a new run before starting. Allows players to adjust tile distribution, hand size, plays per round, and difficulty settings.

### Class: `RunSetupPopup extends CanvasLayer`

### Features
- **Bag Selection**: Choose tile distribution (default, experimental, etc.)
- **Hand Size**: Configure maximum tiles in hand (typically 8-12)
- **Plays Per Round**: Set how many word formations allowed per round (1-5)
- **Progression**: Select difficulty scaling curve
- **Preview**: Show next round configuration preview
- **Defaults Button**: Reset to default configuration
- **Start Button**: Build run and start game

### Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `game_started` | `run: Run` | Game configured, player clicked Start |
| `cancelled` | none | Player closed popup without starting |
| `config_changed` | `config: Run` | Configuration was modified |

### Flow
```gdscript
1. TitleScreen._on_new_game() → show_popup()
2. Player adjusts settings
3. Player clicks "Start" → game_started signal emitted
4. TitleScreen receives signal → RunManager.initialize_run_from_builder(run)
5. TitleScreen loads Main.tscn → gameplay starts
```

### Integration with RunBuilder
```gdscript
# RunSetupPopup builds a Run object
var run = RunBuilder.new() \
    .with_bag(selected_bag) \
    .with_hand_size(hand_size_value) \
    .with_plays_per_round(plays_value) \
    .with_progression(chosen_progression) \
    .build()

game_started.emit(run)
```

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
