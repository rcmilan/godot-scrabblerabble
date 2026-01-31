# Copilot Instructions for Wordatro

## Project Overview

Wordatro is a Godot 4.5.1 word game combining Scrabble mechanics with roguelike deck-building elements. Players form words on a grid board using letter tiles, manage their hand through selection and discard mechanics, and progress through rounds.

## Development Principles (CRITICAL - READ FIRST)

### Godot-First Thinking
- **Scripts are for logic and behavior, NOT UI configuration**
- Node hierarchy, positioning, and visual setup should be done in Godot's Scene Editor
- Leverage Godot's built-in capabilities and utilities whenever possible
- Handle node manipulation dynamically in scripts when necessary (e.g., reparenting tiles)
- Avoid manual UI configuration in script files unless strictly necessary or dynamic

### Learning >> Doing
- **DO NOT change files without explicit user direction**
- Prioritize teaching over completing tasks quickly
- If changes can be made using Godot's Scene/Node Editor, instruct rather than implement
- Explain the "why" behind architectural decisions and patterns
- Provide context for each step before suggesting implementation

### More Steps is Better
- **Break down implementations into the most granular instructions possible**
- Each step should be simple and clearly understandable
- Favor verbosity and clarity over brevity and efficiency
- Provide step-by-step guidance for every task, no matter how trivial
- The goal is deep understanding of game development and Godot, not speed

### Hands-On Development
- **DO NOT directly modify files for boilerplate code**
- Let the user handle:
  - Signal connection wiring
  - Class and variable declarations
  - `@onready` statements and node references
  - Basic function scaffolding
  - Import statements and dependencies
- Only suggest code changes, provide the exact code to add, and explain where it goes
- The user needs to physically type code to build muscle memory and internalize patterns

### Separation of UI and Game Logic
- **Systems should cleanly separate presentation from business logic**
- UI Components (Scenes):
  - Handle visual presentation and user interaction
  - Own the node hierarchy and Control nodes
  - Example: `hand.gd` adds/removes tiles from TileContainer
- System Managers (Autoloads):
  - Handle game rules, state, and logic
  - Provide clean API for other systems
  - Example: `HandManager` manages draw rules, capacity, signal connections
- Pattern: Manager owns logic, Scene owns presentation
- Benefits: Testability, maintainability, clear responsibilities

### Response Format for Changes
When changes are needed:
1. **Explain why** the change is necessary
2. **Describe where** in the file to make changes
3. **Show the exact code** to add/modify
4. **Wait for user confirmation** before proceeding
5. Never batch multiple file changes without explicit permission

## Architecture & Data Flow

### Core Components

- **Main** (`scenes/main.gd`): Central game controller coordinating all components, handles input, selection, placement, and discard flows
- **Board** (`scenes/board/board.gd`): 8x8 grid-based board with cell management and hover detection
- **BoardCell** (`scenes/board/board_cell.gd`): Individual cell with occupancy state, multipliers, and visual feedback
- **Tile** (`scenes/tile/tile.gd`): Draggable letter tiles with location tracking and selection visuals
- **Hand** (`scenes/hand/hand.gd`): Tile container that delegates selection to SelectionManager

### Autoload Managers

| Manager | Purpose |
|---------|---------|
| `EventBus` | Global signal hub for decoupled communication |
| `GameManager` | Game phases, scoring, round progression |
| `TileBag` | Tile pool (deck) creation, shuffling, drawing |
| `HandManager` | Draw, discard, refill operations |
| `SelectionManager` | Single/multi-select mode and selection state |
| `DebugManager` | Debug console command processing |

### Selection System

The game uses **SelectionManager** as the single source of truth for selection:

```gdscript
# Selection modes
enum SelectionMode { SINGLE, MULTI }

# Mode management
SelectionManager.toggle_mode()  # Called when Q key pressed
SelectionManager.is_multi_select_enabled() -> bool

# Selection operations (mode-aware)
SelectionManager.select_tile(tile)  # In SINGLE: deselects others; in MULTI: toggles
SelectionManager.deselect_tile(tile)
SelectionManager.deselect_all()
SelectionManager.get_selected_tiles() -> Array[Tile]  # Ordered by selection time
SelectionManager.get_selection_count() -> int
SelectionManager.has_selection() -> bool
```

**Selection behavior:**
- **SINGLE mode**: Clicking a tile deselects all others, only one selected at a time
- **MULTI mode**: Clicking toggles tile selection, multiple tiles can be selected
- **Leaving MULTI mode**: All tiles are automatically deselected
- **Selection order**: Maintained in array, used for multi-tile placement

### Signal Communication Flow

All inter-component communication uses signals via EventBus:

```
User Input (Main)
    │
    ├─► Q key ──► SelectionManager.toggle_mode()
    │                  │
    │                  ▼
    │             EventBus.selection_mode_changed
    │
    ├─► Tile click ──► Main._on_tile_selected()
    │                       │
    │                       ▼
    │                 SelectionManager.select_tile()
    │                       │
    │                       ▼
    │                 EventBus.selection_changed
    │
    ├─► Z key ──► Main._request_discard_confirmation()
    │                  │
    │                  ▼
    │             DiscardConfirmationDialog
    │                  │
    │       ┌──────────┴──────────┐
    │       ▼                     ▼
    │   confirmed             cancelled
    │       │                     │
    │       ▼                     ▼
    │   _discard_tiles()     (selection preserved)
    │       │
    │       ▼
    │   HandManager.discard_tile() → EventBus.tile_discarded
    │   HandManager.refill_hand() → EventBus.hand_count_changed
    │
    └─► Cell click ──► Main._on_cell_clicked()
                            │
                            ▼
                      place_tile_on_cell() or _handle_multi_tile_drop()
                            │
                            ▼
                      EventBus.tile_placed
```

### Tile Lifecycle & Parenting

Tiles move between parent nodes based on location:
- **In Bag**: Managed by TileBag (not in scene tree)
- **In Hand**: Child of `$Hand/TileContainer` (HBoxContainer)
- **On Board**: Child of `cell.tile_anchor` within target BoardCell
- **In Discard**: Tracked in `HandManager.discard_pile` array
- **Position reset**: Always set `position = Vector2.ZERO` after reparenting

```gdscript
# Standard tile placement pattern
tile.get_parent().remove_child(tile)
cell.tile_anchor.add_child(tile)
tile.position = Vector2.ZERO
tile.current_cell = cell
tile.location = Tile.TileLocation.ON_BOARD
cell.tile = tile
```

## Game Progression & Level Structure

### Level Flow

**Level Start State:**
- **Target Score:** Win condition the player must reach
- **Plays Available:** Limited word submissions (default: 10)
- **Fresh Tile Bag:** Resets each level from distribution config
- **Empty Discard Pile:** Starts fresh

**During Gameplay:**

1. **Tile Selection:**
   - Single mode: One tile at a time
   - Multi mode (Q key): Multiple tiles, ordered selection

2. **Tile Placement:**
   - Click cell to place single tile
   - Multi-select places tiles in sequence (left-to-right)

3. **Discard (Z key or drag to pile):**
   - Shows confirmation dialog
   - Discards selected hand tiles
   - Refills hand from tile bag

4. **Word Formation & Scoring:**
   - Player places tiles on board
   - (Future) System validates word and calculates score
   - Consumes 1 play from available plays

5. **Win Condition:**
   - Reach target score within available plays

### Key Resource Management

- **Plays:** Primary resource, each word scored consumes 1 play
- **Tiles:** Auto-refill after discard, managed by TileBag + HandManager
- **Score:** Accumulates throughout level, must reach target

## Key Patterns & Conventions

### Input Actions (project.godot)

| Action | Key | Purpose |
|--------|-----|---------|
| `toggle_multi_select` | Q | Toggle single/multi-select mode |
| `discard_tiles` | Z | Request discard with confirmation |

### Hover Feedback System

BoardCell has **overlay-based visual system**:
- Valid placement: Green overlay (0.45 alpha)
- Invalid placement: Red overlay (0.65 alpha)
- Multi-tile hover: All sequential cells highlighted

### Drag vs Click Discrimination

Tile implements **state-based drag detection** with `DRAG_THRESHOLD = 8.0` pixels:
- `PRESSED`: Mouse down, waiting to see if it's a drag
- `DRAGGING`: Moved beyond threshold, tile follows cursor
- Release in PRESSED: Emit `tile_selected` (click)
- Release in DRAGGING: Emit `tile_drag_ended` (drag complete)

### Node Path Conventions

Use `$` notation for direct children, typed references for safety:
- ✅ `@onready var board: Board = $Board`
- ✅ `@onready var hand: Hand = $Hand`
- ❌ Avoid untyped or hardcoded NodePaths

### Type Hints & Class Names

All components use **class_name** for type safety:
```gdscript
class_name Board    # Enables strong typing: var board: Board
class_name BoardCell
class_name Tile
class_name Main
```

Always type hint signals: `func _on_tile_selected(tile: Tile) -> void:`

## Common Tasks

### Adding a New Tile Feature
1. Add property to `Tile` class
2. Update `tile.gd` initialization
3. Add signal to EventBus if needed
4. Connect UI to EventBus signal

### Modifying Selection Behavior
Edit `selection_manager.gd`:
- Mode behavior in `_select_single()` and `_toggle_multi()`
- Selection order in `_update_selection_orders()`

### Adding New Input Action
1. Add to `project.godot` `[input]` section
2. Handle in `Main._unhandled_input()`
3. Call appropriate manager method

### Debugging State Issues
- Enable debug console with D key
- Use `spawn A 3` to add tiles
- Check EventBus signal flow
- Verify tile.location and cell.tile synchronization

## Running the Project

**Engine**: Godot 4.5.1 (Mobile renderer)
**Main Scene**: `res://scenes/Main.tscn`

Run from Godot Editor (F5) or build for mobile target. No external dependencies.

## File Naming Conventions

- Scripts: snake_case (`board_cell.gd`, `tile.gd`)
- Scenes: PascalCase (`BoardCell.tscn`, `Tile.tscn`)
- Class names match scene names: `class_name BoardCell` in `board_cell.gd`
- AGENT.md files in each directory document that component

## Development Roadmap

### Completed
- ✅ Phase 1: Tile Visual Configuration (LetterTileData system)
- ✅ Phase 2: Architecture Foundation (EventBus + GameManager)
- ✅ Phase 3: Debug System
- ✅ Phase 4: Tile Pool Management (TileBag + BagDistribution)
- ✅ Phase 5: Selection System (SelectionManager, multi-select)
- ✅ Discard System (confirmation, drop zone, refill)

### In Progress
- 🔄 Phase 6: Word Detection & Validation
- 🔄 Phase 7: Scoring System with multipliers

### Future
- Phase 8: Turn Management
- Phase 9: Multi-Turn & Round System
- Phase 10: UI Polish & Game Feel

**Architecture Philosophy:**
- Each phase builds on previous phases
- EventBus provides loose coupling between systems
- Managers own logic, Scenes own presentation
- Debug code isolated in DebugManager/DebugConsole
- UI polish deferred until core gameplay works
