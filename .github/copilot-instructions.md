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

- **Main** (`scenes/main.gd`): Root scene that creates and manages GameplayController, orchestrates component lifecycle
- **GameplayController** (`scripts/controllers/gameplay_controller.gd`): Manages all tile gameplay (selection, drag-drop, placement, discard, play submission)
- **Board** (`scenes/board/board.gd`): 8×8 grid-based board with cell management, hover detection, and sequential cell queries
- **BoardCell** (`scenes/board/board_cell.gd`): Individual cell with occupancy state, multiplier infrastructure, and visual feedback
- **Tile** (`scenes/tile/tile.gd`): Draggable letter tiles with atomic cell binding, location tracking, and selection visuals
- **Hand** (`scenes/hand/hand.gd`): Tile container that manages tile display and delegates selection to SelectionManager

### Controllers

- **GameplayController**: Handles all tile interaction (selection, drag-drop, placement, discard, play). Injected with scene dependencies and can be activated/deactivated based on game state.

### Autoload Managers

| Manager | Purpose | Type |
|---------|---------|------|
| `EventBus` | Global signal hub for decoupled communication | Autoload |
| `GameManager` | Game phases, scoring, round progression | Autoload |
| `TileBag` | Tile pool (deck) creation, shuffling, drawing | Autoload |
| `HandManager` | Draw, discard, refill operations | Autoload |
| `TileAnimator` | Coordinates tile animations using strategy pattern | Autoload |
| `RunManager` | Run lifecycle & progression orchestrator | Autoload |
| `SelectionManager` | Single/multi-select mode and selection state | Local Node (created by Main) |
| `DragManager` | Multi-tile drag operation coordination | Local Node (created by GameplayController) |
| `DebugManager` | Debug console command processing | RefCounted (owned by DebugConsole) |

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

### Atomic Cell Binding (Critical Pattern)

Tiles maintain **atomic bidirectional binding** with board cells to prevent inconsistent state:

```gdscript
# Use atomic binding to ensure tile ↔ cell consistency
tile.attach_to_cell(cell)   # Sets: tile.current_cell = cell AND cell.tile = tile

# For drag operations (temporarily suspend binding):
tile.suspend_cell_binding()  # Clears cell.tile but keeps tile.current_cell
# ... drag operation ...
tile.restore_cell_binding()  # Restores cell.tile reference

# Check binding state:
if tile.has_active_cell_binding():
    # tile.current_cell and cell.tile are synchronized
```

**Design Principle**: Either both references are set (tile ↔ cell synchronized) OR both are cleared. Never a partial state where references diverge.

```gdscript
# Standard tile placement pattern (using atomic binding)
tile.get_parent().remove_child(tile)
cell.tile_anchor.add_child(tile)
tile.position = Vector2.ZERO
tile.attach_to_cell(cell)  # Atomic: sets both references
tile.location = Tile.TileLocation.ON_BOARD
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

## Core Architectural Patterns

### Composition Over Inheritance (GameplayController)
```
Main (Scene)
    │
    └─► GameplayController (Composition)
        ├─ Depends on: Board, Hand, DiscardPile, HUD
        ├─ Handles: Tile selection, drag-drop, placement, discard
        └─ Can be: activated/deactivated based on game state
```

Benefits:
- Gameplay logic separated from scene script
- Easy to pause/resume interaction via activate/deactivate
- Testable in isolation
- Dependencies injected via setup()

### Atomic State Management
All critical operations use atomic patterns:

```gdscript
# Tile placement is atomic
tile.attach_to_cell(cell)        # Both references set together
# ... later
tile.detach_from_cell()          # Both references cleared together

# Discard is atomic
_hand_ui.remove_tile(tile)       # Remove from hand
tile.move_to_discard()           # Atomic state: location = IN_DISCARD
discard_pile.append(tile)        # Track in array
# Complete or fail as unit—no partial state
```

### Strategy Pattern (Animations)
```
TileAnimator (Facade)
    │
    ├─► DrawTileAnimation (Strategy)
    │   └─ BatchAnimationExecutor (Executor)
    │
    ├─► GlideTileAnimation (Strategy)
    │   └─ ReturnAnimationExecutor (Executor)
    │
    ├─► ShakeTileAnimation (Strategy)
    │   └─ ShakeAnimationExecutor (Executor)
    │
    └─► StompTileAnimation (Strategy)
        └─ StompAnimationExecutor (Executor)
```

Each animation strategy defines WHAT to animate; each executor defines HOW to animate it.

## Common Tasks

### Adding a New Tile Feature
1. Add property to `Tile` class
2. Update `tile.gd` initialization
3. Add signal to EventBus if needed
4. Connect UI to EventBus signal

### Modifying Selection Behavior
Edit `scripts/managers/selection_manager.gd`:
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

### ✅ Completed Phases
- Phase 1: Tile Visual Configuration (LetterTileData system)
- Phase 2: Architecture Foundation (EventBus + GameManager)
- Phase 3: Debug System (Debug console + commands)
- Phase 4: Tile Pool Management (TileBag + BagDistribution)
- Phase 5: Selection System (SelectionManager, multi-select)
- Phase 6: Discard System (confirmation, drop zone, refill)
- Phase 7: Word Detection & Validation (find_formed_words algorithm)
- Phase 8: Scoring System with multipliers (WordValidator service)
- Phase 9: Animation System (draw, glide, shake, stomp, spin)
- Phase 10: Run & Progression System (RoundConfig, ProgressionRules)
- Phase 11: Roguelike Quality Modifiers (RunQuality, RunBuilder, modifier system)
- Phase 12: Title Screen & Game Configuration (RunSetupPopup, MenuController)
- Phase 13: Shop Phase Between Rounds (ShopOverlay, round transitions)
- Phase 14: Game State Management (multi-round runs, victory/defeat conditions)

<<<<<<< HEAD
### 🔄 In Progress
- Phase 15: UI Polish and Game Feel Refinement
- Phase 16: Tile Modifiers System (EXTRA, MULTI, EXPO, RESET, LOCKED with composable behaviors, visual pipeline, play animations)
=======
### In Progress
- 🔄 Phase 6: Word Validation & Real-Time Feedback (Hybrid Grid System)
- 🔄 Phase 7: Scoring System with multipliers
>>>>>>> 4874709 (docs: Add hybrid word validation strategy and implementation plan- Document performance comparison (O(k) vs O(r×c))  - Add 8-step implementation plan for PlayStateManager- Outline real-time validation approach with dual-state tracking- Update Phase 6 roadmap with detailed architecture decisions)

### 📋 Future Phases
- Phase 17: Cell Multipliers on Board (visual + scoring)
- Phase 18: Save/Load Game State
- Phase 19: Multiple Starting Decks/Themes
- Phase 20: Wild Card Tiles (blank tiles with custom letter assignment)
- Phase 21: Additional Modifier Types and Behaviors
- Phase 22: Achievement & Statistics System
- Phase 23: Sound and Music
- Phase 24: Mobile Touch Controls Refinement
- Phase 25: Leaderboard System

---

## Word Validation Strategy: Hybrid Grid System

### Design Philosophy

The game requires **real-time word validation** to provide instant feedback and prevent invalid plays. This requires balancing performance with architecture cleanliness.

### Performance Comparison

| Approach | Tile Placement | Word Finding | Play Button Update | Total Complexity |
|----------|---------------|--------------|-------------------|------------------|
| Old Codebase | O(1) | O(k) | O(1) | **O(k)** |
| Current (Cell-based) | O(1) | O(r×c) | O(r×c) | **O(r×c)** |
| Hybrid Solution | O(1) | O(k) | O(1) | **O(k)** |

Where: k = tiles placed this turn (~5-10), r×c = board size (64-225)

**Performance Gain**: ~10-20x faster on 11×11 board

### Hybrid Architecture

Combines the performance of grid-based lookups with the clean object-oriented design of cell-based architecture.

**Core Concept: Dual-State Tracking**

```gdscript
# PlayStateManager tracks game state efficiently
class PlayStateManager:
    # Fast O(1) lookup grid synced with BoardCells
    var _grid_cache: Array[Array] = []  # [row][col] = tile
    
    # Separate temporary vs permanent tiles
    var _temporary_tiles: Dictionary = {}  # {Vector2i: Tile} - this turn only
    var _permanent_tiles: Dictionary = {}  # {Vector2i: Tile} - locked tiles
    
    # Validation results cache
    var _current_words: Array = []
    var _all_words_valid: bool = false
```

**Key Principles:**

1. **BoardCell remains source of truth** - Tiles are still parented to cell.tile_anchor
2. **Grid cache for performance** - Fast lookups without scanning all cells
3. **Separate temporary/permanent** - Clear distinction between current turn and locked tiles
4. **Immediate validation** - Validate words on every tile placement
5. **Play button reflects validity** - Enabled ONLY when valid words detected

### Gameplay Flow

```
Tile Placed → Update grid_cache & temporary_tiles →
Run word_finder on combined state (temp + permanent) →
Validate all words → Update Play button state →
User presses Play (only if valid) →
Lock tiles (temp → permanent) → Calculate score →
Commit to GameManager → Refill hand
```

### Implementation Plan

#### Step 1: Create PlayStateManager Class
**File**: `scripts/logic/play_state_manager.gd`

**Responsibilities:**
- Maintain grid cache synchronized with Board
- Track temporary vs permanent tile placements
- Provide O(1) tile lookup by position
- Expose combined grid state for word finding

**Key Methods:**
```gdscript
func initialize_grid(rows: int, cols: int)
func place_temporary_tile(tile: Tile, pos: Vector2i)
func remove_temporary_tile(pos: Vector2i)
func commit_temporary_tiles()  # Lock all temp → permanent
func clear_temporary_tiles()  # Cancel placement
func get_combined_grid() -> Array[Array]  # Temp + permanent for validation
func get_temporary_positions() -> Array[Vector2i]
```

#### Step 2: Port Word Finding Logic
**File**: `scripts/logic/word_finder.gd` (new)

**Purpose**: Grid-based word detection (from old codebase)

**Core Logic:**
- Scan rows for horizontal words (consecutive tiles)
- Scan columns for vertical words (consecutive tiles)
- Only check positions with tiles (not entire grid)
- Return word dictionaries with positions and direction

**Signature:**
```gdscript
func find_words(grid: Array[Array]) -> Array:
    # Returns: [{"word": String, "start": Vector2i, "end": Vector2i, "direction": String}]
```

#### Step 3: Create Word Validator Integration
**File**: Update `scripts/logic/word_validator.gd`

**Changes:**
- Add `validate_words_from_grid(grid: Array[Array]) -> Dictionary` method
- Integrate with PlayStateManager for combined state
- Return validation results with detailed feedback
- Support dictionary loading (already implemented)

**Return Format:**
```gdscript
{
    "valid": bool,
    "words": Array,  # All detected words
    "invalid_words": Array,  # Words not in dictionary
    "score": int  # Total score if valid
}
```

#### Step 4: Add Dictionary Loading
**File**: `Data/Dictionaries/english_words.txt`

**Actions:**
- Copy dictionary file from old codebase
- Ensure UTF-8 encoding, one word per line
- Load in GameplayController._ready() or GameManager.start_game()

**Loading Code:**
```gdscript
func _ready():
    _word_validator = WordValidator.new()
    _word_validator.load_word_list("res://Data/Dictionaries/english_words.txt")
```

#### Step 5: Integrate PlayStateManager with GameplayController
**File**: `scripts/controllers/gameplay_controller.gd`

**Changes:**
- Create PlayStateManager instance
- Update `_place_tile_on_cell_silent()` to update PlayStateManager
- Call validation after every placement
- Update Play button based on validation results
- Remove `_get_unplayed_board_tiles()` - use PlayStateManager instead

**Key Integration Points:**
```gdscript
var _play_state_manager: PlayStateManager = null

func _ready():
    _play_state_manager = PlayStateManager.new()
    # Initialize grid when board ready

func _place_tile_on_cell_silent(tile: Tile, cell: BoardCell):
    # ... existing placement code ...
    _play_state_manager.place_temporary_tile(tile, cell.grid_position)
    _validate_current_placement()  # NEW: Real-time validation

func _validate_current_placement():
    var grid = _play_state_manager.get_combined_grid()
    var validation = _word_validator.validate_words_from_grid(grid)
    _update_play_button_from_validation(validation)
```

#### Step 6: Update Play Button Logic
**File**: `scripts/controllers/gameplay_controller.gd`

**New Logic:**
```gdscript
func _update_play_button_from_validation(validation: Dictionary):
    var enabled = validation.valid and not _play_state_manager.get_temporary_positions().is_empty()
    main_hud.set_play_button_enabled(enabled)
    
    # Optional: Show invalid word feedback
    if not validation.valid and not validation.invalid_words.is_empty():
        print("[Gameplay] Invalid words: %s" % validation.invalid_words)
```

#### Step 7: Update Play Commit Flow
**File**: `scripts/controllers/gameplay_controller.gd`

**Changes to `_on_play_requested()`:**
```gdscript
func _on_play_requested():
    # Get validated words and score (already computed)
    var validation = _play_state_manager.get_last_validation()
    
    if not validation.valid:
        return  # Should never happen - button disabled
    
    var temp_tiles = _play_state_manager.get_temporary_tiles()
    
    # Lock all tiles
    for tile in temp_tiles:
        tile.set_locked(true)
    
    # Commit to permanent state
    _play_state_manager.commit_temporary_tiles()
    
    # Animate and emit events
    TileAnimator.animate_stomp_batch(temp_tiles)
    EventBus.tiles_played.emit(temp_tiles, validation.words)
    
    # Update game state with score
    GameManager.commit_play(validation.score)
    
    # Refill hand
    HandManager.refill_hand()
```

#### Step 8: Testing & Validation
**Test Cases:**
1. Place valid word → Play button enables ✅
2. Place invalid word → Play button disabled ❌
3. Add letter to make valid → Play button enables ✅
4. Remove letter to make invalid → Play button disables ❌
5. Multiple words → All must be valid for Play to enable
6. Cross-words → Validate both main word and cross-words
7. Locked tiles + new tiles → Only validate complete words

---

### Key Design Decisions

**Why Dual-State (Temporary/Permanent)?**
- Clear separation of "this turn" vs "previous turns"
- Easy to cancel placement (just clear temporary)
- Efficient word finding (only check relevant tiles)
- Supports undo/redo in future

**Why Grid Cache?**
- O(1) lookup vs O(r×c) scan
- WordFinder needs grid format anyway
- Synced with BoardCells for consistency
- Minimal memory overhead (just references)

**Why Validate on Placement?**
- Instant feedback to player
- No invalid plays possible
- Better UX than post-validation
- Negligible performance cost (O(k) where k is small)

**Why Keep BoardCell as Source of Truth?**
- Visual representation tied to cells
- Drag-drop logic uses cell references
- Clean separation: Board = UI, PlayStateManager = Logic
- Atomic cell binding prevents inconsistency

**Architecture Philosophy:**
- Each phase builds on previous phases
- EventBus provides loose coupling between systems
- Managers own logic, Scenes own presentation
- Controllers coordinate gameplay with dependency injection
- Debug code isolated in DebugManager/DebugConsole
- UI polish deferred until core gameplay works
- Domain-Driven Design: Model the game domain first (tiles, cells, words), then implement UI around it
- Object-Oriented Principles: Clear responsibilities, single purpose per class
- Atomic Operations: Every action either succeeds completely or fails cleanly—no partial/inconsistent state
  - Example: Cell binding is atomic (tile ↔ cell always synchronized)
  - Example: Tile placement either completes fully or is cancelled with animation