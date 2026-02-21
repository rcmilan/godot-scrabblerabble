# Directory Overview

## Purpose
Root directory of Wordatro - a Godot 4.5.1 word game combining Scrabble mechanics with roguelike deck-building elements.

## Key Files
- **project.godot**: Godot engine configuration file defining application settings, autoloads, input actions, and rendering method
- **README.md**: Project documentation with overview, structure, feature list, and development status
- **icon.svg**: Application icon
- **.gitignore**: Git exclusion rules
- **.editorconfig**: Editor configuration for consistent formatting

## Public Interfaces
### Entry Points
- **Main Scene**: `scenes/title_screen/TitleScreen.tscn` (configured in project.godot)
- **Gameplay Scene**: `scenes/Main.tscn`

### Autoloads (Global Singletons)
Defined in project.godot [autoload] section:
- `EventBus`: Global signal hub
- `GameManager`: Game state and phase management
- `TileBag`: Tile pool management
- `HandManager`: Hand operations
- `TileAnimator`: Animation coordination
- `RunManager`: Run lifecycle orchestrator

### Input Actions
Defined in project.godot [input] section:
- `toggle_multi_select` (Q key): Toggle single/multi-select mode
- `discard_tiles` (Z key): Request discard with confirmation
- `pause_game` (Escape): Pause game

## Dependencies
### Engine
- **Godot 4.5.1** (Mobile renderer)

### External Dependencies
None - self-contained project with no third-party libraries.

### Internal Structure
- `autoload/`: Global singleton managers
- `scenes/`: Game scenes and UI components
- `scripts/`: Controllers, domain models, logic, interaction handlers, animation strategies
- `Data/`: Resource definitions (TileData, BagDistribution, ProgressionConfig)
- `Assets/`: Visual assets (tile images)
- `.github/`: Documentation and AI assistant configuration

## Architecture / Patterns
### Core Architecture
- **Event-Driven**: EventBus decouples components via signals
- **Composition Over Inheritance**: Controllers injected with dependencies
- **Strategy Pattern**: Animation system with pluggable strategies
- **Separation of Concerns**: UI scenes handle presentation, Managers handle logic
- **Atomic State Management**: Operations succeed/fail as units (no partial state)
- **Domain-Driven Design**: Game concepts modeled first, UI built around them

### Key Patterns
- **Autoload Managers**: Global game systems
- **Local Nodes**: SelectionManager and DragManager created by scene controllers
- **Resource-Based Data**: TileData, BagDistribution, ProgressionConfig use Godot Resources
- **Signal Communication**: All inter-component communication via EventBus

## Conventions
### File Naming
- **Scripts**: snake_case (e.g., `board_cell.gd`)
- **Scenes**: PascalCase (e.g., `BoardCell.tscn`)
- **Class Names**: Match scene names (e.g., `class_name BoardCell`)
- **Resources**: snake_case with .tres extension

### Code Style
- **Type Hints**: All function parameters and returns
- **Node Paths**: Use `$` notation with typed `@onready` variables
- **Class Names**: All components use `class_name` for type safety
- **Signal Naming**: past_tense (e.g., `tile_placed`, `selection_changed`)

### Project Structure
- One scene per visual component
- Scene scripts in same directory as .tscn files
- Shared logic in scripts/ subdirectories
- Resources in Data/ subdirectories

## Build / Test
### Running the Project
```bash
# From Godot Editor
F5 or Run button

# Main scene auto-loads TitleScreen (configured in project.godot)
```

### Debug Tools
- **Debug Console**: Press `D` in gameplay for command interface
- **Debug Commands**: `spawn`, `clear`, `score`, etc.
- **Debug Overlay**: F12 to toggle runtime stats

### Project Configuration
- **Renderer**: Mobile (configured in project.godot)
- **Target Platforms**: Desktop and Mobile (Godot supports export to multiple platforms)
- **Resolution**: 1536×864px (configured in display settings)
