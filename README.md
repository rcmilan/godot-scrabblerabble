# Wordatro - Roguelike Word Game

## Overview

**Wordatro** is a word game combining Scrabble mechanics with roguelike deck-building elements, built with **Godot 4.5.1** (Mobile renderer). Players form words on a grid board using letter tiles, manage their hand through selection and discard mechanics, progress through rounds, and aim to reach target scores within limited plays.

## Quick Start

### Requirements
- **Godot 4.5.1** (Mobile renderer)
- No external dependencies

### Running the Game
1. Open the project in Godot 4.5.1 Editor
2. Run the main scene: `F5` or click **Run**
3. Main scene: `res://scenes/Main.tscn`

### Project Entry Points
- **Title Screen**: `scenes/title_screen/TitleScreen.tscn` - Main menu with New Game, Options, Exit
- **Gameplay**: `scenes/Main.tscn` - Core gameplay scene
- **Debug Console**: Press `D` in gameplay to access developer tools

---

## Project Structure

```
Wordatro/
├── autoload/                   # Global singleton managers (6 active, 3 promoted to local)
│   ├── event_bus.gd           # Signal hub for decoupled communication
│   ├── game_manager.gd        # Game state & phase management (encapsulated)
│   ├── tile_bag.gd            # Tile pool (deck) management
│   ├── hand_manager.gd        # Hand operations & discard pile
│   ├── tile_animator.gd       # Tile animation coordinator
│   ├── run_manager.gd         # Run lifecycle orchestrator
│   ├── selection_manager.gd   # [LOCAL NODE] Tile selection state
│   ├── drag_manager.gd        # [LOCAL NODE] Multi-tile drag coordination
│   └── (no debug_manager - now RefCounted owned by DebugConsole)
│
├── scenes/                     # Game scenes and components
│   ├── Main.tscn              # Gameplay scene (root)
│   ├── main.gd                # Main gameplay orchestrator
│   ├── title_screen/          # Title screen and main menu
│   ├── board/                 # Grid component for word placement
│   │   ├── Board.tscn
│   │   ├── board.gd
│   │   ├── BoardCell.tscn
│   │   └── board_cell.gd
│   ├── hand/                  # Player's tile collection
│   │   ├── Hand.tscn
│   │   └── hand.gd
│   ├── tile/                  # Individual letter tiles
│   │   ├── Tile.tscn
│   │   ├── tile.gd
│   │   └── invert.gdshader    # Visual shader for locked tiles
│   ├── ui/                    # UI overlays, HUD, dialogs
│   │   ├── main_hud/          # Score, plays, round info, action buttons
│   │   ├── discard_pile/      # Drop zone for discarding
│   │   ├── discard_confirmation_dialog/  # Discard confirmation modal
│   │   ├── multi_select_indicator/       # Selection mode display
│   │   ├── game_over_popup/              # Victory/defeat screen
│   │   ├── pause_menu/                   # Pause overlay
│   │   └── debug_overlay/                # Developer debug tools
│   └── debug/                 # Debug console and manager
│
├── scripts/                    # Utility & logic scripts
│   ├── controllers/           # Game behavior coordinators
│   │   ├── gameplay_controller.gd     # Tile interaction coordinator
│   │   ├── tile_placement_handler.gd  # Tile placement logic
│   │   ├── drop_handler.gd            # Drag-and-drop validation
│   │   ├── play_handler.gd            # Play submission & scoring
│   │   └── menu_controller.gd         # Menu navigation
│   ├── animation/             # Tile animation system (Strategy pattern)
│   │   ├── base/              # Abstract animation infrastructure
│   │   ├── draw/              # Draw-from-bag animations
│   │   ├── glide/             # Position transition animations
│   │   ├── shake/             # Illegal action feedback
│   │   ├── stomp/             # Play confirmation effect
│   │   └── hand/              # Hand tile layout & hover
│   ├── interaction/           # Input event helpers
│   └── logic/                 # Game rules & algorithms
│
├── Data/                       # Game configuration resources
│   ├── BagDistribution/       # Tile pool configurations
│   │   ├── bag_distribution.gd           # Resource class
│   │   └── bag_default.tres              # Default tile distribution
│   └── TileData/              # Letter tile definitions
│       ├── tile_data.gd                  # LetterTileData resource class
│       └── tiles/             # Individual tile resources (A-Z)
│
├── Assets/                     # Visual assets
│   ├── Tiles/                 # Letter textures (letter_A.png through letter_Z.png)
│   ├── letter.png             # Generic tile background
│   └── blank_tile.png         # Blank/wild tile texture
│
└── [project.godot, icon.svg]  # Godot project files
```

---

## Core Game Flow

### Gameplay Loop

```
1. Title Screen → Player selects "New Game"
2. Initialize Game → TileBag created, Hand filled (10 tiles)
3. Selection Mode → Q key toggles SINGLE/MULTI-select
4. Tile Placement:
   - Click tile to SELECT (or multi-select in MULTI mode)
   - Click board cell to PLACE
   - Multi-selected tiles place in sequence (left-to-right)
5. Discard (Optional):
   - Press Z or drag to discard pile
   - Confirmation dialog shown
   - Tiles removed, hand refilled from bag
6. Score Phase:
   - Form valid words on board
   - System validates words & calculates score
   - Score applied to run total
   - Consumes 1 play from available plays
7. Check Win Condition:
   - Target score reached? → VICTORY
   - Plays exhausted? → GAME OVER
   - Continue? → Return to step 3
```

### Game States

| State | Description |
|-------|-------------|
| **SETUP** | Game initialization |
| **PLAYING** | Active gameplay (tile selection & placement) |
| **PAUSED** | Game paused (accessible via ESC) |
| **ROUND_END** | Round completed, waiting for input |
| **GAME_OVER** | Loss condition (plays exhausted) |
| **VICTORY** | Win condition (target score reached) |

---

## Key Components

### 1. **Board** (`scenes/board/`)
Grid-based board where tiles are placed to form words.

**Features:**
- Dynamic grid generation (default 8×8, configurable)
- Cell queries: by coordinates, by position, sequential
- Cell types: Normal, Letter Multiplier, Word Multiplier
- Hover feedback: Green (valid), Red (invalid), Sequential (multi-tile preview)

**Key Methods:**
```gdscript
get_cell(row: int, col: int) -> BoardCell
get_cell_at_position(pos: Vector2) -> BoardCell
get_sequential_cells(start: BoardCell, count: int) -> Array[BoardCell]
get_grid_state() -> Array[Array]  # 2D array of tiles
clear_board() -> void
```

### 2. **Tile** (`scenes/tile/`)
Individual letter tiles with drag-and-drop support.

**Features:**
- Click-to-select or drag-and-drop interaction
- Atomic cell binding (tile ↔ cell always synchronized)
- Selection state tracking & visual feedback
- Location tracking: IN_BAG, IN_HAND, ON_BOARD, IN_DISCARD

**Drag Detection:**
- Threshold: 8 pixels
- PRESS → DRAGGING (past threshold) → Release
- Release in PRESSED = Click, Release in DRAGGING = Drag complete

**Key Methods:**
```gdscript
initialize(data: LetterTileData) -> void
set_selected(value: bool) -> void
attach_to_cell(cell: BoardCell) -> void  # Atomic binding
detach_from_cell() -> void
get_points() -> int
```

### 3. **Hand** (`scenes/hand/`)
Container for player's available tiles.

**Features:**
- Horizontal layout (HBoxContainer)
- Auto tile management: add, remove, clear
- Selection delegation to SelectionManager
- Tile queries: by letter, by index

**Key Methods:**
```gdscript
add_tile(tile: Tile) -> bool
remove_tile(tile: Tile) -> bool
get_tiles() -> Array[Tile]
find_tile_by_letter(letter: String) -> Tile
```

### 4. **GameplayController** (`scripts/controllers/`)
Coordinates all tile interaction and gameplay logic.

**Architecture:**
```
GameplayController (Coordinator)
├── DragManager (local child node)
├── TilePlacementHandler (placement & cell queries)
├── DropHandler (drag validation & execution)
└── PlayHandler (play submission & scoring)
```

**Responsibility:**
- Route input events to handlers
- Manage tile registration
- Coordinate drag operations
- Emit gameplay signals

**Lifecycle:**
```gdscript
controller = GameplayController.new()
controller.setup(board, hand, discard_pile, discard_dialog, hud, selection_manager)
controller.activate()    # Enable interaction
controller.deactivate()  # Disable interaction
```

### 5. **SelectionManager** (Autoload → Local Node)
Single source of truth for tile selection state.

**Features:**
- **SINGLE mode**: Only one tile selected at a time
- **MULTI mode** (Q key): Multiple tiles, ordered by selection time
- Auto-deselect on mode change

**Key Methods:**
```gdscript
select_tile(tile: Tile) -> void
deselect_tile(tile: Tile) -> void
deselect_all() -> void
get_selected_tiles() -> Array[Tile]  # Ordered by selection time
toggle_mode() -> void  # SINGLE ↔ MULTI
is_multi_select_enabled() -> bool
```

**Signal:**
```
EventBus.selection_changed(tiles: Array[Tile])
EventBus.selection_mode_changed(is_multi: bool)
```

### 6. **EventBus** (Autoload)
Global signal hub for decoupled component communication.

**Signal Categories:**

| Category | Signals |
|----------|---------|
| **Tile Lifecycle** | `tile_drawn`, `tile_placed`, `tile_removed`, `tile_discarded` |
| **Hand Events** | `hand_count_changed`, `hand_empty`, `hand_refilled` |
| **Bag/Deck** | `bag_count_changed` |
| **Selection** | `selection_changed`, `selection_mode_changed` |
| **Interaction** | `interaction_mode_changed` |
| **Game State** | `game_phase_changed`, `score_changed`, `play_count_changed` |
| **Animation** | `animation_started`, `animation_completed` |

### 7. **TileAnimator** (Autoload)
Coordinates all tile animations using Strategy pattern.

**Animation Types:**
- **DrawTileAnimation**: Rise + fade-in when drawn from bag
- **GlideTileAnimation**: Smooth position transitions (return, cancel, discard)
- **ShakeTileAnimation**: Left-right shake for illegal actions
- **StompTileAnimation**: Rise-slam effect + particles for play confirmation
- **HandFanLayout**: Fan-spread + hover effects in hand

**Key Methods:**
```gdscript
animate_draw(tiles: Array[Tile], speed: float) -> void
animate_glide(tile: Tile, target_pos: Vector2, duration: float) -> void
animate_shake(tile: Tile) -> void
animate_stomp(tiles: Array[Tile]) -> void
```

### 8. **TileBag** (Autoload)
Manages the tile pool (deck).

**Responsibilities:**
- Create/shuffle tiles from BagDistribution
- Draw tiles
- Track remaining count

**Key Methods:**
```gdscript
initialize(distribution: BagDistribution) -> void
draw_tile() -> Tile
draw_tiles(count: int) -> Array[Tile]
get_tile_count() -> int
get_all_remaining() -> Array[Tile]
```

### 9. **HandManager** (Autoload)
Manages hand operations (draw, discard, refill).

**Responsibilities:**
- Hand capacity (default: 10 tiles)
- Draw from bag
- Discard to pile
- Refill after discard
- Track discard pile

**Key Methods:**
```gdscript
draw_tile() -> Tile
draw_tiles(count: int) -> Array[Tile]
discard_tile(tile: Tile) -> void
refill_hand() -> void
set_hand_size(size: int) -> void
get_hand_size() -> int
```

---

## Architectural Patterns

### 1. **Atomic Cell Binding (Critical)**
Tiles maintain bidirectional atomic binding with board cells to prevent inconsistent state.

```gdscript
# Ensure tile ↔ cell synchronization
tile.attach_to_cell(cell)      # Sets: tile.current_cell = cell AND cell.tile = tile

# For drag operations (temporarily suspend binding):
tile.suspend_cell_binding()    # Clears cell.tile only
# ... drag operation ...
tile.restore_cell_binding()    # Restores cell.tile

# Verify binding is active:
if tile.has_active_cell_binding():
    # Both references synchronized
```

**Design Principle:** Either both references are set (synchronized) OR both are cleared. Never partial state.

### 2. **Composition Over Inheritance**
Controllers use composition to encapsulate specific behaviors without inheritance.

```
Main (Scene) → GameplayController (Composition)
                ├─ DragManager (local child)
                ├─ TilePlacementHandler (RefCounted)
                ├─ DropHandler (RefCounted)
                └─ PlayHandler (RefCounted)
```

**Benefits:**
- Separation of concerns
- Easy to activate/deactivate
- Testable in isolation
- Dependency injection

### 3. **Strategy Pattern (Animations)**
Animations define WHAT happens; Executors define HOW.

```
TileAnimator (facade)
    ├── DrawTileAnimation (strategy) + BatchAnimationExecutor (HOW)
    ├── GlideTileAnimation (strategy) + ReturnAnimationExecutor (HOW)
    ├── ShakeTileAnimation (strategy) + ShakeAnimationExecutor (HOW)
    └── StompTileAnimation (strategy) + StompAnimationExecutor (HOW)
```

Each strategy is a Resource defining animation properties; each executor manages tween creation.

### 4. **Signal-Based Communication**
All inter-component communication uses EventBus signals for loose coupling.

```
User Input → Main → SelectionManager → EventBus.selection_changed
                                            ↓
                                     All systems react
```

### 5. **Manager vs Scene Separation**
- **Managers** (Autoloads): Own game logic & state
- **Scenes** (UI): Own visual presentation & hierarchy

Example: HandManager owns draw/discard logic; Hand scene owns tile display.

---

## Input Actions & Controls

| Action | Key | Purpose |
|--------|-----|---------|
| `toggle_multi_select` | Q | Toggle SINGLE/MULTI-select mode |
| `discard_tiles` | Z | Request discard with confirmation |
| `pause` | ESC | Pause/Resume game |
| `debug_console` | D | Toggle debug console |

---

## Game Configuration

### Tile Distribution (`Data/BagDistribution/bag_default.tres`)
Defines initial tile pool with letter frequencies (Scrabble-style).

**Point Values:**
| Points | Letters |
|--------|---------|
| 1 | A, E, I, O, U, L, N, S, T, R |
| 2 | D, G |
| 3 | B, C, M, P |
| 4 | F, H, V, W, Y |
| 5 | K |
| 8 | J, X |
| 10 | Q, Z |

### Board Configuration (`scenes/Main.tscn`)
- **Rows**: 8 (configurable)
- **Columns**: 8 (configurable)
- **Cell Size**: 64 pixels
- **Cell Spacing**: 4 pixels

---

## UI Components

| Component | Layer | Purpose |
|-----------|-------|---------|
| **MainHUD** | 0 | Score display, plays remaining, round info, action buttons |
| **DiscardPile** | - | Visual drop zone for discarding tiles |
| **DiscardConfirmationDialog** | 10 | Modal confirmation for discard action |
| **MultiSelectIndicator** | - | Shows current selection mode (SINGLE/MULTI) |
| **GameOverPopup** | 10 | Victory/defeat screen with next action |
| **PauseMenu** | 10 | Pause overlay with resume/quit options |
| **DebugOverlay** | 100 | Developer console and testing tools |

---

## Tile Lifecycle

```
Tile Birth:      TileBag creates tile, location = IN_BAG
    ↓
Draw:           HandManager.draw_tile() → Hand.add_tile()
                Animate: DrawTileAnimation
                location = IN_HAND
    ↓
Select:         Tile.tile_selected signal → SelectionManager
    ↓
Placement:      GameplayController.place_tile_on_cell()
                Reparent: Hand → BoardCell.tile_anchor
                Animate: GlideTileAnimation
                location = ON_BOARD
                attach_to_cell()
    ↓
Discard:        HandManager.discard_tile()
                Reparent: ??? → (not in scene tree)
                Animate: GlideTileAnimation
                location = IN_DISCARD
    ↓
Refill:         HandManager.refill_hand()
                Draw new tiles to replace discarded
```

---

## Common Development Tasks

### Adding a New Tile Animation
1. Create a strategy in `scripts/animation/my_animation/my_animation.gd` (extends `TileAnimationStrategy`)
2. Create an executor if complex (extends `AnimationExecutor`), or reuse `BatchAnimationExecutor`
3. Wire into TileAnimator with a public method: `animate_my_effect(tiles: Array[Tile]) -> void`

### Modifying Selection Behavior
Edit `autoload/selection_manager.gd`:
- `_select_single()`: Single-select logic
- `_toggle_multi()`: Multi-select logic
- `_update_selection_orders()`: Selection ordering

### Adding New Input Action
1. Add to `project.godot` `[input]` section
2. Handle in `Main._unhandled_input()`
3. Call appropriate manager/controller method

### Debugging State Issues
- Press `D` to open debug console
- Commands: `spawn A 3` (add 3 A tiles), `fill` (fill hand), `draw` (draw tile)
- Check tile.location and cell.tile synchronization for binding issues

---

## Development Philosophy

### Core Principles
1. **Godot-First Thinking**: Leverage built-in capabilities; scripts handle logic, not UI config
2. **Learning Over Speed**: Prioritize understanding; provide granular step-by-step guidance
3. **Separation of Concerns**: Managers own logic, Scenes own presentation
4. **Atomic Operations**: All critical actions either complete fully or fail cleanly
5. **Signal-Based Communication**: Decouple systems via EventBus

### Code Organization
- **Scripts**: snake_case (`board_cell.gd`, `tile.gd`)
- **Scenes**: PascalCase (`BoardCell.tscn`, `Tile.tscn`)
- **Classes**: Match scene names (`class_name BoardCell` in `board_cell.gd`)
- **Type Hints**: Always use type hints for safety

---

## Development Roadmap

### ✅ Completed Phases
- Phase 1: Tile Visual Configuration (LetterTileData system)
- Phase 2: Architecture Foundation (EventBus + GameManager)
- Phase 3: Debug System (Debug console + commands)
- Phase 4: Tile Pool Management (TileBag + BagDistribution)
- Phase 5: Selection System (SelectionManager, multi-select)
- Phase 6: Discard System (confirmation, drop zone, refill)

### 🔄 In Progress
- Phase 7: Word Detection & Validation
- Phase 8: Scoring System with multipliers

### 📋 Future Phases
- Phase 9: Turn Management
- Phase 10: Multi-Turn & Round System
- Phase 11: UI Polish & Game Feel
- Phase 12: Roguelike Elements (upgrades, shops, relics)

---

## File Naming Conventions

| Type | Format | Example |
|------|--------|---------|
| Scripts | snake_case | `board_cell.gd`, `tile.gd` |
| Scenes | PascalCase | `BoardCell.tscn`, `Tile.tscn` |
| Classes | PascalCase | `class_name BoardCell` |
| AGENT.md | Lowercase | `autoload/AGENT.md` |
| Data Resources | snake_case | `bag_distribution.gd` |

---

## Key Files Reference

| File | Purpose |
|------|---------|
| `scenes/Main.tscn` | Main gameplay scene (entry point) |
| `scenes/main.gd` | Main gameplay orchestrator |
| `scenes/board/board.gd` | Board grid management |
| `scenes/tile/tile.gd` | Tile interaction & state |
| `scenes/hand/hand.gd` | Hand container management |
| `scripts/controllers/gameplay_controller.gd` | Gameplay coordinator |
| `autoload/event_bus.gd` | Global signal hub |
| `autoload/selection_manager.gd` | Selection state (local node) |
| `autoload/tile_animator.gd` | Animation coordinator |
| `Data/BagDistribution/bag_default.tres` | Tile distribution config |

---

## Resources for Contributors

- **Project Instructions**: See root `AGENT.md` for detailed architecture guidance
- **Component Docs**: Each directory contains `AGENT.md` with component-specific documentation
- **Godot Documentation**: https://docs.godotengine.com/en/stable/
- **Debug Console**: Press `D` to access developer testing tools

---

## License & Credits

**Engine**: Godot 4.5.1 (Mobile renderer)
**Language**: GDScript
**Development Focus**: Game mechanics and architecture (before UI polish)

---

## Summary

Wordatro is a well-architected game project built on solid design patterns: atomic state management, signal-based communication, separation of concerns, and composition over inheritance. The project structure scales well from current mechanics to planned roguelike features. Refer to component-specific `AGENT.md` files for deep dives into particular systems.

**Start here**: Run `Main.tscn` and explore the Debug Console (D key) to understand gameplay mechanics and test features.
