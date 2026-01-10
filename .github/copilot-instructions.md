# Copilot Instructions for BoardStructure

## Project Overview

BoardStructure is a Godot 4.5 game project implementing a tile-placement system with drag-and-drop mechanics. The architecture uses a signal-based event system for communication between the main game controller, board, tiles, and hand container.

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

- **Main** ([Scenes/main.gd](Scenes/main.gd)): Central game controller managing multi-tile selection array and coordinating between all components
- **Board** ([Scenes/Board/board.gd](Scenes/Board/board.gd)): Grid-based board containing 17 cells, handles real-time hover detection via `_process()`
- **BoardCell** ([Scenes/Board/board_cell.gd](Scenes/Board/board_cell.gd)): Individual cell with occupancy state and visual feedback overlays
- **Tile** ([Scenes/Tile/tile.gd](Scenes/Tile/tile.gd)): Draggable game pieces with location tracking (IN_HAND, ON_BOARD, etc.)
- **Hand** ([Scenes/Hand/hand.gd](Scenes/Hand/hand.gd)): Simple container for player tiles, acts as signal relay

### State Management Pattern

The game uses an **array-based selection system** in Main for multi-tile selection:
- `selected_tiles: Array[Tile]` - Tracks all currently selected tiles
- Helper functions determine what actions are valid based on array size:
  - `can_place_tile()` - Returns true if exactly 1 tile selected
  - `can_discard()` - Returns true if any tiles selected
  - `has_selection()` - Returns true if selection array not empty

**Selection behavior:**
- Clicking tile in hand toggles selection (add/remove from array)
- Multiple tiles can be selected simultaneously
- Placement only works with exactly 1 selected tile (Phase 5)
- Multi-placement will be added in Phase 10

```gdscript
# Example from main.gd
func can_place_tile() -> bool:
    return selected_tiles.size() == 1

func _on_cell_clicked(cell):
    if not can_place_tile():
        print("Cannot place - need exactly 1 tile selected")
        return
    place_tile_on_cell(selected_tiles[0], cell)
```

### Signal Communication Flow

All inter-component communication uses signals, never direct method calls:

1. Tile emits → `tile_selected`, `tile_right_clicked`, `tile_drag_ended`
2. Main connects to all tiles in `_ready()` and handles logic
3. BoardCell emits → `cell_clicked`, `cell_hovered`, `cell_unhovered`
4. Main manages all placement/removal logic centrally

**Critical**: When adding new tiles/cells, connect their signals in `Main._ready()`.

### Tile Lifecycle & Parenting

Tiles move between parent nodes based on location:
- **In Hand**: Child of `$Hand/TileContainer` (HBoxContainer)
- **On Board**: Child of `cell.tile_anchor` within target BoardCell
- **Position reset**: Always set `position = Vector2.ZERO` after reparenting

## Game Progression & Level Structure

### Roguelike Level Flow

The game follows a **level-based progression system** where each level is a self-contained challenge:

**Level Start State:**
- **Target Score:** Win condition the player must reach
- **Plays Available:** Limited number of word submissions (each scored word = 1 play)
- **Discards Available:** Limited discard actions for the level
- **Fresh Tile Bag:** Tile pool resets each level (discards from previous level cleared)
- **Empty Discard Zone:** Visual tracking area starts empty
- **Modifier Persistence:**
  - Permanent modifiers: Always kept
  - Conditional modifiers: Kept if conditions apply
  - Temporary modifiers: Cleared at level start

**During Level Gameplay:**

1. **Discard Phase (Optional, Anytime):**
   - Player can discard tiles from hand at any point
   - Requires available discards (limited resource)
   - Multi-selection: Player selects multiple tiles to discard at once
   - System immediately draws replacement tiles (same quantity)
   - Discarded tiles shown in discard zone (cosmetic tracking)

2. **Word Formation & Scoring:**
   - Player places tiles on board to form valid words
   - Once valid word detected, "Play/Score" button lights up
   - Player confirms to score the word
   - Tiles are removed from board and redrawn to hand (same quantity)
   - Consumes 1 "play" from available plays

3. **Win Condition:**
   - Player reaches target score within available plays
   - Performance tracked for prize distribution
   - Prizes awarded based on score performance and level difficulty

4. **Shop Phase:**
   - Player enters shop area to purchase upgrades
   - Modifiers/items purchased affect future levels

**Level Failure:**
- Runs out of plays before reaching target score
- Player returns to menu or restarts run (roguelike loss)

### Key Resource Management:

- **Plays:** Primary resource, each word scored consumes 1 play
- **Discards:** Secondary resource, refreshing hand costs discards
- **Tiles:** Auto-refill after scoring, managed by TileBag
- **Score:** Accumulates throughout level, must reach target

### System Responsibilities:

- **GameManager:** Tracks plays_remaining, discards_remaining, target_score, current_score
- **TileBag:** Manages tile pool per level, resets on level start
- **DiscardManager:** Handles multi-selection and discard execution
- **HandManager:** Coordinates tile drawing after discards/scoring
- **Scoring System:** Validates words and calculates scores

```gdscript
# Standard tile placement pattern from main.gd
tile.get_parent().remove_child(tile)
cell.tile_anchor.add_child(tile)
tile.position = Vector2.ZERO
tile.current_cell = cell  # Maintain bidirectional reference
cell.occupied = true
cell.tile = tile
```

## Key Patterns & Conventions

### Hover Feedback System

BoardCell has **three-layer visual system**:
- `ContentLayer`: Contains the cell visual and tile anchor
- `OverlayLayer`: Colored overlays for valid (green 0.45 alpha) / invalid (red 0.65 alpha) placement
- Overlays use `move_to_front()` to ensure visibility

Board continuously checks mouse position in `_process()` and updates cell hovers based on `Main.selected_tiles` array state (only shows valid placement hover when exactly 1 tile selected).

### Drag vs Click Discrimination

Tile implements **state-based drag detection** with `DRAG_THRESHOLD = 8.0` pixels:
- `PRESSED`: Mouse down, waiting to see if it's a drag
- `DRAGGING`: Moved beyond threshold, tile follows cursor
- `NONE`: Released, emit `tile_selected` if it was a click, `tile_drag_ended` if drag

### Node Path Conventions

Use `$` notation for direct children, `get_node()` for absolute paths:
- ✅ `$Hand/TileContainer.get_children()` 
- ✅ `get_node("/root/Main").selected_tile`
- ❌ Avoid hardcoded NodePaths that break when restructuring

### Type Hints & Class Names

All components use **class_name** for type safety:
```gdscript
class_name Board  # Enables strong typing: var board: Board
class_name BoardCell
class_name Tile
```

Always type hint signals: `func _on_tile_selected(tile: Tile) -> void:`

## Common Tasks

### Adding a New Tile
1. Instantiate Tile scene in Main.tscn under `Hand/TileContainer`
2. Connect signals in `Main._ready()`: `tile.tile_selected.connect(_on_tile_selected)`
3. All placement/drag logic is already handled

### Modifying Placement Rules
Edit `board_cell.can_place_tile(tile: Tile, cell: BoardCell) -> bool` for validation logic. Main checks this before placement.

### Debugging State Issues
- Enable `Board.debug_hover = true` to see hover detection logs every 15 frames
- Check interaction_mode transitions in Main
- Verify tile.current_cell and cell.tile references stay synchronized

## Running the Project

**Engine**: Godot 4.5 (Mobile renderer)
**Main Scene**: res://Scenes/Main.tscn

Run from Godot Editor (F5) or build for mobile target. No external dependencies beyond Godot engine.

## File Naming Conventions

- Scripts: snake_case (board_cell.gd, tile.gd)
- Scenes: PascalCase (BoardCell.tscn, Tile.tscn)
- Class names match scene names: `class_name BoardCell` in board_cell.gd

## Development Roadmap

### Phase 1: Tile Visual Configuration ✅
- [x] 1.1: Create LetterTileData Resource system
- [x] 1.2: Update Tile scene with letter and points labels
- [x] 1.3: Implement Tile.initialize() with validation
- [x] 1.4: Create all 26 letter configuration files (A-Z)

### Phase 2: Architecture Foundation (EventBus + GameManager) ✅
- [x] 2.1: Create EventBus autoload singleton
- [x] 2.2: Create GameManager autoload singleton
- [x] 2.3: Refactor main.gd to use EventBus signals

### Phase 3: Debug System ✅
- [x] 3.1: Implement basic debug system (spawn_tile, clear_board)
- [ ] 3.2: Add debug toggle and visual indicators (SKIPPED - console sufficient)

### Phase 4: Tile Pool Management ✅
- [x] 4.1: Create BagDistribution Resource for tile pool
- [x] 4.2: Implement TileBag autoload
- [x] 4.3: Connect draw system to hand

### Phase 5: Discard System 🔄
- [ ] 5.1: Implement multi-tile selection system (click-toggle)
- [ ] 5.2: Create DiscardManager autoload and discard mechanics
- [ ] 5.3: Add basic discard zone UI (placeholder/barebones)

**Phase 5 Design:**

**Universal Selection System:**
- Click tile → toggle selection (green border)
- Multiple tiles can be selected simultaneously
- Selection is universal - different actions consume selection as needed
- Discard button operates on all selected tiles
- Placement only works with exactly 1 tile selected (Phase 5 restriction)

**Batch Discard/Draw Flow:**
- Player selects multiple tiles (e.g., 5 tiles)
- Clicks "Discard" button
- System executes atomically:
  1. Collect all selected tiles data (for effect triggers)
  2. Remove all from hand simultaneously
  3. Add all to discard pile simultaneously
  4. Draw same quantity from bag simultaneously
  5. Emit single `tiles_discarded` event with array
- No per-tile iteration - batch operation for speed and clarity

**Placement Restrictions (Phase 5):**
- 0 tiles selected: Cannot place
- 1 tile selected: Can place on board (current behavior)
- 2+ tiles selected: Cannot place (blocks action)
- Evolution: Phase 10 will add smart multi-placement (select word, place all at once)

**UX Philosophy:**
- Minimize player clicks and dragging
- Reduce "housekeeping" time with tiles
- Maximize time spent forming words and scoring
- Batch operations wherever possible
- Optimize for flow over granular control

**EventBus Signals:**
- `tiles_discarded.emit(tiles: Array[Tile])` - Batch discard event for effects
- Single event per discard action, not per tile

**Phase 5 Implementation Approach (Option B):**
- Uses array-based selection (`selected_tiles: Array[Tile]`) instead of enum-based state machine
- Helper functions express rules explicitly: `can_place_tile()`, `can_discard()`, `has_selection()`
- Phase 10 extension: Simply add `can_multi_place()` function
- Rationale: Direct checks are more explicit, easier to extend, and avoid enum ambiguity when multiple tiles selected

### Phase 6: Word Detection & Validation
- [ ] 6.1: Implement word detection (find placed tiles)
- [ ] 6.2: Load and integrate dictionary
- [ ] 6.3: Implement word validation logic

### Phase 7: Scoring System
- [ ] 7.1: Implement base scoring calculation
- [ ] 7.2: Connect scoring to validated words

### Phase 8: Turn Management
- [ ] 8.1: Implement basic turn system in GameManager
- [ ] 8.2: Add submit/pass turn actions

### Phase 9: Multi-Turn & Round System
- [ ] 9.1: Add multi-turn and round tracking
- [ ] 9.2: Implement win conditions

### Phase 10: UI Layer & Polish
- [ ] 10.1: Create score display UI
- [ ] 10.2: Create action panel UI
- [ ] 10.3: Create game info display UI
- [ ] 10.4: Implement hand fan layout (overlapping tiles with dynamic spacing)
- [ ] 10.5: Optional: Implement duplicate tile stacking with counters (max 26 unique letters)

**Current Status:** Starting Phase 5 (Phases 1-4 Complete)

**Architecture Philosophy:**
- Each phase builds on previous phases
- Test and validate after each phase
- EventBus provides loose coupling between systems
- GameManager owns game state, not individual scenes
- Debug code isolated in DebugManager autoload and DebugConsole scene
- Defer multipliers/modifiers until core gameplay works
- UI polish and game feel improvements are saved for Phase 10 after core systems work
- Current hand layout uses simple HBoxContainer - fan layout/overlapping deferred to Phase 10
