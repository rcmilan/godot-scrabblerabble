# Autoload Managers

## Overview
Global singleton managers that coordinate game-wide systems. These are automatically loaded by Godot and accessible from any script.

**Active Autoloads (6):** EventBus, GameManager, TileBag, HandManager, TileAnimator, RunManager

**Related (3):**
- **SelectionManager** → Local node, defined in `scripts/managers/selection_manager.gd`, created by Main, injected via `set_selection_manager()`
- **DragManager** → Local node, defined in `scripts/managers/drag_manager.gd`, created by GameplayController, injected via `setup()`
- **DebugManager** → RefCounted helper owned by DebugConsole

## Autoload Files (6)
- `event_bus.gd` - Global signal hub
- `game_manager.gd` - Game state and phase management (encapsulated behind getters)
- `hand_manager.gd` - Hand operations and discard pile
- `tile_bag.gd` - Tile pool (deck) management
- `tile_animator.gd` - Tile animation coordinator
- `run_manager.gd` - Run lifecycle orchestrator

## Manager Files (in scripts/managers/)
- `selection_manager.gd` - Tile selection state (local node, NOT an autoload)
- `drag_manager.gd` - Multi-tile drag coordination (local node, NOT an autoload)

---

## EventBus

### Purpose
Centralized signal hub for decoupled communication between systems. Acts as a message broker to eliminate tight coupling between game systems.

**Strategies:**
- All inter-scene communication uses signals via EventBus
- Systems connect to signals at `_ready()` rather than calling methods directly
- Non-blocking event propagation ensures systems don't block each other

### Signal Categories

#### Tile Lifecycle (4 signals)
- `tile_drawn(tile: Tile)` - Emitted by TileBag.draw_tile()
- `tile_placed(tile: Tile, cell: BoardCell)` - Emitted when tile placed on board
- `tile_removed(tile: Tile, cell: BoardCell)` - Emitted when tile removed from board
- `tile_discarded(tile: Tile)` - Emitted by HandManager.discard_tile()

#### Hand Management (3 signals)
- `hand_count_changed(count: int)` - Updated after draw/discard operations
- `hand_empty()` - Emitted when hand becomes empty
- `hand_refilled(count: int)` - Emitted by HandManager.refill_hand()

#### Bag/Deck (2 signals)
- `bag_count_changed(count: int)` - Updated after draw
- `bag_empty()` - Emitted by HandManager when TileBag.is_empty()

#### Discard Operations (2 signals)
- `discard_count_changed(count: int)` - Updated after discard
- `discard_pile_changed(tiles: Array)` - Updated when pile modified

#### Round/Turn Events (4 signals)
- `round_started(round_number: int)` - Emitted by GameManager.start_round() or setup_round()
- `round_ended(round_number: int, success: bool)` - Emitted by GameManager._complete_round()
- `play_completed(plays_remaining: int)` - Emitted by GameManager.commit_play()
- `tiles_played(tiles: Array[Tile], words: Array)` - Emitted when tiles locked/played

#### Scoring (2 signals)
- `score_calculated(points: int, breakdown: Dictionary)` - Point calculation details
- `score_updated(total_score: int, delta: int)` - Emitted by GameManager after commit_play()

#### Game State (6 signals)
- `game_started()` - New game initialized
- `game_ended(victory: bool)` - Game finished (win or lose)
- `game_won()` - Emitted by GameManager.end_game(true)
- `game_lost()` - Emitted by GameManager.end_game(false)
- `game_paused()` - Emitted by GameManager.pause_game()
- `game_resumed()` - Emitted by GameManager.resume_game()

#### Drag Operations (2 signals)
- `multi_drag_started(tiles: Array)` - Emitted by DragManager.start_drag()
- `multi_drag_ended(tiles: Array, success: bool)` - Emitted by DragManager.end_drag()

#### Modifier Events (2 signals)
- `modifier_applied(tile: Tile, modifier: ModifierInstance)` - Modifier added to tile
- `modifier_consumed(tile: Tile, modifier_type: int)` - Consumable modifier removed

#### Run Events (3 signals)
- `run_round_ready(config: RoundConfig)` - Emitted by RunManager when round config prepared
- `run_shop_requested(round_number: int)` - Triggers shop transition after successful round
- `run_ended(victory: bool, total_score: int)` - Emitted when run completes

### Implementation Notes
- All signals are strongly typed with parameters
- EventBus extends Node for singleton behavior
- EventBus is autoloaded (registered in project.godot)
- Selection signals (`mode_changed`, `selection_changed`) are on SelectionManager (local node), NOT EventBus
- TileAnimator manages its own animation signals: `animation_started`, `animation_completed`, `single_tile_animated`

### Usage Pattern
```gdscript
# Connect once during initialization
func _ready() -> void:
    EventBus.tile_placed.connect(_on_tile_placed)
    EventBus.score_updated.connect(_on_score_updated)

# Systems emit signals via EventBus
func do_something() -> void:
    var score = calculate_score()
    EventBus.score_updated.emit(new_total, score)
```

---

## SelectionManager (Local Node — NOT Autoload)

### Purpose
Central source of truth for tile selection state. Manages single-select and multi-select modes with ordered selection tracking.

### Lifecycle
Created by Main and injected into consumers:
```gdscript
# In Main._ready():
_selection_manager = SelectionManager.new()
_selection_manager.name = "SelectionManager"
add_child(_selection_manager)

hand.set_selection_manager(_selection_manager)
discard_pile.set_selection_manager(_selection_manager)
multi_select_indicator.set_selection_manager(_selection_manager)
gameplay_controller.setup(..., _selection_manager)
```

### Signals (on SelectionManager instance, not EventBus)
| Signal | Parameters | Description |
|--------|------------|-------------|
| `mode_changed` | `is_multi: bool` | Single/multi mode toggled |
| `selection_changed` | `tiles: Array` | Selection changed |

### Selection Modes
```gdscript
enum SelectionMode {
    SINGLE,  # Click deselects others, one tile at a time
    MULTI    # Click toggles, multiple tiles can be selected
}
```

### Key Methods
```gdscript
toggle_mode() -> void
set_mode(new_mode: SelectionMode)
is_multi_select_enabled() -> bool
select_tile(tile: Tile) -> void
deselect_tile(tile: Tile) -> void
deselect_all() -> void
get_selected_tiles() -> Array[Tile]
get_selection_count() -> int
has_selection() -> bool
```

---

## GameManager

### Purpose
Central game state controller and phase machine. Manages game phases, scoring, round progression, and win/lose conditions. State is encapsulated behind getters.

**Type:** State Manager & Phase Machine

### Game Phases
```gdscript
enum GamePhase {
    SETUP,       # Initial setup, loading resources
    PLAYING,     # Active gameplay
    PAUSED,      # Game paused
    ROUND_END,   # Round ended, processing results
    GAME_OVER,   # Game lost
    VICTORY      # Game/run won
}
```

### Core State (All Private)
```gdscript
_current_phase: GamePhase = GamePhase.SETUP
_current_round: int = 1
_current_score: int = 0
_target_score: int = 100
_plays_remaining: int = 10
_plays_per_round: int = 10
_difficulty: int = 0
```

### Configuration Constants
- `DEFAULT_PLAYS_PER_ROUND: int = 2`
- `DEFAULT_TARGET_SCORE: int = 1000000`

### Getter API (Read-Only Access)
```gdscript
get_current_phase() -> GamePhase
get_current_round() -> int
get_current_score() -> int
get_target_score() -> int
get_plays_remaining() -> int
get_plays_per_round() -> int
get_difficulty() -> int
```

### Lifecycle Methods

#### Game Control
- `end_game(victory: bool) -> void`
  - Sets phase to VICTORY (if true) or GAME_OVER (if false)
  - Emits `EventBus.game_ended(victory)`
  - Emits `EventBus.game_won()` or `EventBus.game_lost()` depending on victory
  - Prints final score to console

- `pause_game() -> void`
  - Only works if phase is PLAYING
  - Sets phase to PAUSED
  - Emits `EventBus.game_paused()`

- `resume_game() -> void`
  - Only works if phase is PAUSED
  - Sets phase back to PLAYING
  - Emits `EventBus.game_resumed()`

#### Round Management
- `start_round(round_num: int, target: int = DEFAULT_TARGET_SCORE, plays: int = DEFAULT_PLAYS_PER_ROUND) -> void`
  - Sets _current_round, _target_score, _plays_per_round, _plays_remaining
  - Sets phase to PLAYING
  - Emits `EventBus.round_started(_current_round)`
  - Prints "[GameManager] Round N started - Target: X | Plays: Y"

- `setup_round(config: RoundConfig) -> void`
  - Uses RoundConfig object for configuration
  - Sets round_number, target_score, plays_per_round from config
  - Resets _current_score = 0
  - Emits `EventBus.round_started(_current_round)`
  - Same behavior as start_round() but config-driven

#### Play Commitment
- `commit_play(score: int) -> void`
  - Only works if phase is PLAYING
  - Increments _current_score by score
  - Decrements _plays_remaining by 1
  - Emits `EventBus.score_updated(_current_score, score)`
  - Emits `EventBus.play_completed(_plays_remaining)`
  - Calls `_complete_round(true)` if _current_score >= _target_score (WIN)
  - Calls `_complete_round(false)` if _plays_remaining <= 0 (LOSE)
  - Unless debug auto-win is enabled, then treats as WIN
  - Prints "[GameManager] Play committed: +X pts | Total: Y | Plays left: Z"

#### Special Control
- `force_round_end(success: bool) -> void`
  - Only works if phase is PLAYING
  - Called by timer qualities to force round end
  - Calls `_complete_round(success)`

### Query Methods
- `is_playing() -> bool` - Returns true if phase == PLAYING
- `is_game_over() -> bool` - Returns true if phase in [GAME_OVER, VICTORY]

### Private Helpers
```gdscript
_set_phase(new_phase: GamePhase) -> void
    # Updates _current_phase
    # Prints phase transition: "Phase: SETUP -> PLAYING"

_complete_round(success: bool) -> void
    # Sets phase to ROUND_END
    # Emits EventBus.round_ended(_current_round, success)
    # (Further round handling delegated to RunManager)
```

### Signal Integration
- Emits: `game_started`, `game_ended`, `game_won`, `game_lost`, `game_paused`, `game_resumed`
- Emits: `round_started`, `round_ended`, `play_completed`, `score_updated`
- Listens: (No external signals connected)

### Win/Lose Logic
1. **Win Condition:** `_current_score >= _target_score`
   - Checked after each play commitment
   - Triggers _complete_round(true)

2. **Lose Condition:** `_plays_remaining <= 0 AND _current_score < _target_score`
   - Checked after each play commitment
   - Triggers _complete_round(false)
   - UNLESS RunManager.is_debug_auto_win() returns true (debug override)

### Usage Examples
```gdscript
# Start a round
GameManager.start_round(1, 1000, 10)

# During gameplay, commit a play with scoring
GameManager.commit_play(50)  # Emits score_updated and play_completed

# Query state
if GameManager.get_plays_remaining() == 0:
    print("No more plays!")

# Control game flow
GameManager.pause_game()
GameManager.resume_game()
GameManager.end_game(true)  # Victory!
```

---

## HandManager

### Purpose
Manages the player's hand of tiles and interactions between bag, hand, and discard pile. Coordinates between TileBag, Hand UI, and Main scene.

**Type:** Hand Coordinator

### Core State
```gdscript
hand_size: int = 10                 # Target hand capacity
discard_pile: Array[Tile] = []      # Discarded tiles storage
_hand_ui: Node = null               # Reference to Hand scene component
_is_initialized: bool = false       # Scene references valid
```

### Signals
- `initialized` - Emitted when references are set and ready
- `tile_ready(tile: Tile)` - Emitted when new tile is drawn, ready for registration

### Key Methods

#### Drawing
- `draw_tiles(count: int) -> int` - Draw count tiles to fill hand
  - Respects hand capacity (`_hand_ui.is_full()`)
  - Stops if bag becomes empty (`TileBag.draw_tile()` returns null)
  - Animated via `TileAnimator.animate_draw_batch(drawn_tiles)`
  - Returns count of actually drawn tiles
  - Emits:
    - `EventBus.tile_drawn(tile)` per tile (by TileBag)
    - `tile_ready(tile)` per tile for Main to process
    - `EventBus.hand_count_changed(count)`
    - `EventBus.bag_count_changed(remaining)`
  - Prints "[HandManager] Drew N tile(s) | Hand: X | Bag: Y"

- `refill_hand() -> int` - Draw tiles until reaching `hand_size`
  - Calculates needed = hand_size - get_hand_size()
  - Returns 0 if already at capacity
  - Calls `draw_tiles(needed)`
  - Emits `EventBus.hand_refilled(count)` if drew any tiles
  - Returns count of drawn tiles

#### Discarding
- `discard_tile(tile: Tile) -> bool` - Discard single tile from hand
  - Checks tile.location == IN_HAND (returns false if not)
  - Removes from hand UI via `_hand_ui.remove_tile(tile)`
  - Calls `tile.move_to_discard()` (atomic state update)
  - Appends to discard_pile array
  - Emits:
    - `EventBus.tile_discarded(tile)`
    - `EventBus.discard_count_changed(pile_size)`
    - `EventBus.hand_count_changed(new_count)`
  - Returns true on success, false on failure
  - Prints "[HandManager] Discarded tile: A | Discard pile: N"

- `discard_selected() -> int` - Discard all currently selected tiles
  - Gets selected tiles from `_hand_ui.get_selected_tiles()`
  - Calls `discard_tile()` for each
  - Returns count of successfully discarded tiles

#### Discard Pile Management
- `get_discard_pile() -> Array[Tile]` - Returns copy of discard_pile
- `get_discard_count() -> int` - Returns discard_pile.size()
- `clear_discard_pile() -> Array[Tile]` - Clear pile and return tiles
  - Useful for special effects or round resets
  - Emits `EventBus.discard_count_changed(0)`
  - Emits `EventBus.discard_pile_changed([])`
  - Returns copy of cleared tiles

#### Queries
- `get_hand_size() -> int` - Current tiles in hand (0 if not initialized)
- `is_hand_empty() -> bool` - True if get_hand_size() == 0
- `is_hand_full() -> bool` - True if hand is at capacity (false if not initialized)
- `is_initialized() -> bool` - True if _hand_ui is valid reference

### Configuration & Lifecycle
- `hand_size` defaults to 10 but can be modified before drawing
- `set_hand_size(size: int)` - Set target capacity (enforces minimum 1)
  - Updates internal hand_size
  - Syncs to Hand UI: `_hand_ui.max_hand_size = hand_size`
  - Used when run modifiers change hand capacity

- `set_references(hand_ui: Node)` - ONLY initialization path
  - Called by Main._ready()
  - Sets _hand_ui reference
  - Sets _hand_ui.max_hand_size = hand_size
  - Must be called before any draw/refill operations

### Animation Integration
- When tiles are drawn, HandManager calls:
  ```gdscript
  TileAnimator.animate_draw_batch(drawn_tiles)
  ```
- Tiles animate from below screen to their final hand positions

### Usage Pattern
```gdscript
# In Main._ready():
HandManager.set_references($Hand)

# During gameplay:
HandManager.refill_hand()  # Draw up to hand_size

# After validation:
GameManager.commit_play(score)

# Then prepare for next play:
HandManager.refill_hand()
```

---

## DragManager (Local Node — NOT Autoload)

### Purpose
Coordinates multi-tile drag operations. Handles visual positioning and state management of dragged tiles. Separates drag logic from individual tile behavior.

**Type:** Drag State Manager

**Lifecycle:** Created by GameplayController in setup() method

### Core State
```gdscript
is_dragging: bool = false                      # Drag in progress
dragged_tiles: Array[Tile] = []                # All tiles being dragged
lead_tile: Tile = null                         # Tile directly under cursor

_original_parents: Dictionary = {}             # Tile → original parent node
_original_positions: Dictionary = {}           # Tile → original Vector2 position
_original_indices: Dictionary = {}             # Tile → original child index
_relative_offsets: Dictionary = {}             # Tile → offset from lead tile
_drag_container: Control = null                # Temporary parent during drag
```

### Configuration
- `DRAG_Z_INDEX: int = 100` - Z-index for dragged tiles (above everything)
- `TILE_SPACING: float = 68.0` - Spacing between tiles in drag preview

### Key Methods

#### Drag Control
- `start_drag(lead: Tile, tiles: Array[Tile]) -> void` - Begin multi-tile drag
  - lead: The tile being directly dragged (must be in tiles array)
  - tiles: All tiles to drag (including lead)
  - Stores original state (parents, positions, indices)
  - Calculates relative offsets from lead tile
  - Reparents all tiles to _drag_container
  - Sets is_dragging = true
  - Emits `drag_started(dragged_tiles)`
  - Emits `EventBus.multi_drag_started(dragged_tiles)`
  - Errors if lead tile not in tiles array
  - Prints "[DragManager] Started drag with N tiles (lead: A)"

- `end_drag(success: bool) -> void` - Complete drag operation
  - Emits `drag_ended(dragged_tiles, success)`
  - Emits `EventBus.multi_drag_ended(dragged_tiles, success)`
  - Sets is_dragging = false
  - Cleanup delegated to caller (Main handles placement or restoration)
  - Prints "[DragManager] Ended drag (success: true/false)"

- `cancel_drag() -> void` - Cancel drag and restore tiles
  - Restores tiles to original parents and positions
  - Emits `drag_cancelled(dragged_tiles)`
  - Calls _cleanup_drag_state()
  - Used when drag is invalid or cancelled mid-operation

- `restore_tiles_to_parents() -> void` - Return tiles to original parents
  - Sorts tiles by original index to maintain order
  - Removes from _drag_container
  - Re-adds to original parents in original order
  - For board tiles, calls `tile.restore_cell_binding()` (atomic state)
  - Calls `tile.force_end_drag()` on each tile
  - Used before placement or when restoring after failed drop

#### Queries
- `get_drag_position() -> Vector2` - Lead tile's global position (for visual tracking)
- `get_dragged_tiles() -> Array[Tile]` - Copy of dragged_tiles (prevents mutation)
- `get_original_parent(tile: Tile) -> Node` - Original parent of tile
- `get_original_position(tile: Tile) -> Vector2` - Original position of tile

### Signals
- `drag_started(tiles: Array[Tile])` - Drag initiated
- `drag_ended(tiles: Array[Tile], success: bool)` - Drag completed
- `drag_cancelled(tiles: Array[Tile])` - Drag cancelled/failed
- `drag_release_requested(lead_tile: Tile)` - Mouse released during drag (for handling outside Input)

### Frame Updates
- `_process(_delta)` - Update drag positions every frame
  - Calls `_update_drag_positions()` if is_dragging
  - Updates all tile positions relative to lead_tile cursor movement

- `_input(event: InputEvent)` - Catch mouse release during drag
  - Listens for InputEventMouseButton MOUSE_BUTTON_LEFT release
  - Emits `drag_release_requested(lead_tile)` if released during drag
  - Necessary because tiles are reparented and may not receive input events directly

### EventBus Integration
- Emits `EventBus.multi_drag_started(tiles)` when drag begins
- Emits `EventBus.multi_drag_ended(tiles, success)` when drag ends
- Used by DiscardPile to receive drag enter/exit notifications

### Atomic State Management
- Before drag: Clears cell.tile binding via `tile.suspend_cell_binding()`
- After successful placement: Maintains new binding via `tile.attach_to_cell(new_cell)`
- On cancelled drag: Restores original binding via `tile.restore_cell_binding()`
- Never leaves partial state where tile.current_cell and cell.tile are desynchronized

### Usage Pattern (in GameplayController)
```gdscript
# Create DragManager
_drag_mgr = DragManager.new()
add_child(_drag_mgr)

# Start drag with lead tile
_drag_mgr.start_drag(lead_tile, selected_tiles)

# On drop success:
_drag_mgr.end_drag(true)
_drag_mgr.restore_tiles_to_parents()
# ... place tiles on cells ...

# On drop failure or cancel:
_drag_mgr.cancel_drag()  # Auto-restores tiles
```

---

## TileBag

### Purpose
Manages the pool of available tiles (the deck). Acts as tile factory and pool manager. Responsible for tile creation from LetterTileData, shuffling, and distribution.

**Type:** Tile Factory & Pool Manager

### Core State
```gdscript
available_tiles: Array[Tile] = []      # Drawable tiles
drawn_tiles: Array[Tile] = []          # Tiles that have been drawn
current_distribution: BagDistribution  # Active tile distribution config
_initial_count: int = 0                # Initial population size
```

### Key Methods

#### Bag Setup
- `populate_bag(distribution: BagDistribution) -> bool` - Populate from distribution config
  - Clears existing tiles
  - Creates Tile instances from LetterTileData for each letter in distribution
  - Loads data from `res://Data/TileData/tiles/tile_%s.tres`
  - Sets `tile.location = IN_BAG` on each tile
  - Shuffles bag and prints "Populated with N tiles"
  - Returns true if successful, false if invalid distribution

- `shuffle_bag() -> void` - Randomize tile order using `Array.shuffle()`

- `reset_bag() -> void` - Return all drawn tiles to available pool
  - Called when resetting round or clearing state
  - Calls `tile.reset()` on each drawn tile
  - Clears drawn_tiles array
  - Shuffles bag

#### Drawing from Bag
- `draw_tile() -> Tile` - Draw single tile
  - Pops from end of available_tiles array
  - Appends to drawn_tiles
  - Emits `EventBus.tile_drawn(tile)`
  - Returns tile or null if bag empty
  - Prints "[TileBag] Drew: A | Remaining: 50"

- `draw_tiles(count: int) -> Array[Tile]` - Draw multiple tiles
  - Calls `draw_tile()` count times
  - Breaks if bag becomes empty mid-draw
  - Returns array of drawn tiles (may be less than count if bag insufficient)

- `return_tile(tile: Tile) -> void` - Return tile to bag (for special effects)
  - Removes from drawn_tiles if present
  - Calls `tile.reset()`
  - Re-adds to available_tiles
  - Shuffles bag

#### Query Methods
- `tiles_remaining() -> int` - Count of drawable tiles in available_tiles
- `is_empty() -> bool` - True if available_tiles is empty
- `get_initial_count() -> int` - Returns _initial_count (for progress tracking)
- `get_drawn_count() -> int` - Returns drawn_tiles.size()
- `peek_tiles(count: int) -> Array[Tile]` - Debug only: preview top N tiles without drawing

### Tile Creation Pipeline (Private)
```gdscript
_load_tile_data(letter: String) -> LetterTileData
    # Path: res://Data/TileData/tiles/tile_%s.tres % letter.to_lower()
    # Returns loaded LetterTileData or null with error

_create_tile(data: LetterTileData) -> Tile
    # Instantiates res://scenes/tile/Tile.tscn
    # Calls tile.initialize(data)
    # Sets tile.location = IN_BAG
    # Returns Tile instance

_clear_all_tiles() -> void
    # Queues all tiles for deletion
    # Clears arrays
    # Resets state
```

### Resources
- TILE_SCENE_PATH = `"res://scenes/tile/Tile.tscn"`
- TILE_DATA_PATH = `"res://Data/TileData/tiles/tile_%s.tres"`

### Autoload Registration
- No special initialization needed
- Loaded automatically by Godot at startup
- Available as global `TileBag` singleton

---

## TileAnimator

### Purpose
Coordinates tile animations across the game. Uses Strategy pattern with Executor composition for flexibility and maintainability. Acts as animation facade delegating to specialized strategy/executor pairs.

**Type:** Animation Facade

**Architecture:**
```
TileAnimator (Facade)
    ├─ DrawTileAnimation (Strategy) → BatchAnimationExecutor (Executor)
    ├─ GlideTileAnimation (Strategy) → ReturnAnimationExecutor (Executor)  
    ├─ ShakeTileAnimation (Strategy) → ShakeAnimationExecutor (Executor)
    ├─ StompTileAnimation (Strategy) → StompAnimationExecutor (Executor)
    └─ SpinTileAnimation (Strategy) → SpinAnimationExecutor (Executor)
```

### Pattern Explanation
- **Strategy:** Defines WHAT to animate (tile properties, timings, curves)
- **Executor:** Defines HOW to animate (using Tweens, sequencing, batching)
- **AnimationContext:** Shared infrastructure (tween factory, callbacks, tree access)

### Core State
```gdscript
_context: AnimationContext          # Shared tween/callback infrastructure

# Strategies (lazy-loaded on first use)
_draw_animation: DrawTileAnimation = null
_glide_animation: GlideTileAnimation = null
_shake_animation: ShakeTileAnimation = null
_stomp_animation: StompTileAnimation = null
_spin_animation: SpinTileAnimation = null

# Executors (lazy-loaded on first use)
_batch_executor: BatchAnimationExecutor = null
_return_executor: ReturnAnimationExecutor = null
_shake_executor: ShakeAnimationExecutor = null
_stomp_executor: StompAnimationExecutor = null
_spin_executor: SpinAnimationExecutor = null
```

### Signals
- `animation_started(tiles: Array[Tile])` - Batch animation began
- `animation_completed(tiles: Array[Tile])` - Batch animation finished
- `single_tile_animated(tile: Tile)` - Individual tile completed

### Key Methods

#### Animation APIs
- `animate_draw_batch(tiles: Array[Tile]) -> void` - Tiles animate from below screen to hand
  - Used by HandManager.draw_tiles()
  - Calls BatchAnimationExecutor.execute(tiles, DrawTileAnimation)
  
- `animate_return_to_hand(tile: Tile, hand: Node, cell: Node) -> void` - Tile glides from board to hand
  - Call BEFORE moving tile to hand (method handles movement)
  - Calls ReturnAnimationExecutor.execute_single()
  
- `animate_shake(tile: Tile) -> void` - Shake effect for illegal actions
  - Visual feedback without movement
  - Calls ShakeAnimationExecutor.execute()
  
- `animate_stomp_batch(tiles: Array[Tile]) -> void` - Stomp effect for placement confirmation
  - Used by PlayHandler to confirm tile placement
  - Calls StompAnimationExecutor.execute()
  
- `animate_spin_batch(tiles: Array[Tile]) -> void` - Spin effect for MULTI modifier tiles
  - Indicates special modifier behavior
  - Calls SpinAnimationExecutor.execute()

#### Context Setup
```gdscript
_setup_context() -> void
    # Creates AnimationContext with callbacks:
    _context.setup(
        func(tiles): animation_started.emit(tiles),
        func(tiles): animation_completed.emit(tiles),
        func(tile): single_tile_animated.emit(tile),
        create_tween,           # Tween factory for animations
        get_tree                # Tree for accessing node hierarchy
    )
```

### Integration with Scenes
- *DrawTileAnimation*: Tiles enter from Screen.get_rect().position.y offset
- *GlideTileAnimation*: Smooth bezier curves from board cell to hand
- *ShakeAnimationExecutor*: Uses `tile.shake()` method for effect
- Uses `tile.modulate:a` for fade effects (preserves modifier tints)

### Autoload Registration
- Loaded automatically by Godot
- Available as global `TileAnimator` singleton

---

## RunManager

### Purpose
Orchestrates the run lifecycle across multiple rounds. Owns RunState and ProgressionRules. Coordinates round transitions and quality lifecycle.

**Type:** Run Coordinator & Lifecycle Manager

### Core State
```gdscript
run_state: RunState = null                     # Tracks run progression
progression_rules: ProgressionRules = null     # Difficulty/progression logic
current_round_config: RoundConfig = null       # Current round configuration
_active_run: Run = null                        # Run object from RunBuilder (if built)
_quality_connections: Array[Dictionary] = []   # Quality signal connections

# Debug overrides
_debug_override_board_size: Vector2i = Vector2i.ZERO  # Zero = no override
_debug_auto_win: bool = false
```

### Lifecycle Methods

#### Run Initialization
- `initialize_run(bag_config: BagDistribution, plays_per_round: int = 2, hand_size: int = 10, progression_config: ProgressionConfig = null) -> void`
  - Simple run initialization from config
  - Creates RunState and ProgressionRules
  - Sets _active_run = null (no run builder used)
  - Progression defaults to `res://Data/Progression/progression_default.tres`
  - Prints "[RunManager] Run initialized - Plays/round: N | Hand: N"

- `initialize_run_from_builder(run: Run) -> void` - Initialize with Run object
  - Used when RunBuilder creates custom run with qualities
  - Stores run in _active_run
  - Creates RunState and applies quality modifications:
    ```gdscript
    for quality in run.qualities:
        quality.apply_to_run_state(run_state)
    ```
  - Sets up progression from run.progression_config
  - Connects quality lifecycle signals via `_connect_quality_signals()`
  - Prints "[RunManager] Run initialized from builder - ... | Qualities: N"

#### Run Flow
- `start_run() -> void` - Start run (called by Main after scene loads)
  - Errors if run_state not initialized
  - Calls `_advance_to_next_round()` to start first round

- `get_current_round_config() -> RoundConfig` - Get current round config
  - Returns current_round_config for Main to configure gameplay

### Debug Control
- `is_debug_auto_win() -> bool` - Returns _debug_auto_win flag
  - When true: GameManager treats play limit expiration as WIN (not LOSE)
  - Used for testing progression without hitting targets

- `set_debug_auto_win(enabled: bool)` - Enable/disable auto-win

- `get_debug_board_size_override() -> Vector2i` - Get board size override (0,0 = no override)
- `set_debug_board_size_override(size: Vector2i)` - Set custom board size for testing

### Quality System Integration
- Calls `quality.apply_to_run_state(run_state)` during initialization
  - Allows qualities to modify difficulty, hand size, play count, etc.
  
- Calls `quality.on_process(delta)` every frame if running
  - Allows time-based qualities (timers, counters) to update
  
- Connects quality signals for lifecycle events
  - Receives callbacks for round events, score events, etc.

### Event Integration
- Emits: `EventBus.run_round_ready(config)` - Round config prepared
- Emits: `EventBus.run_shop_requested(round_number)` - Shop transition
- Emits: `EventBus.run_ended(victory, total_score)` - Run finished

- Listens: `EventBus.round_ended(round, success)` - Advances to next round
  - Calls `_on_round_ended(round, success)` to handle:
    - Failed rounds (reset attempts)
    - Successful rounds (advance to shop or next round)
    - Run completion (victory or defeat)

### Lifecycle Hooks
```gdscript
func _ready() -> void:
    EventBus.round_ended.connect(_on_round_ended)
    print("[RunManager] Ready")

func _process(delta: float) -> void:
    if _active_run == null:
        return
    if not GameManager.is_playing():
        return
    for quality in _active_run.qualities:
        quality.on_process(delta)
```

### Autoload Registration
- Loaded automatically by Godot
- Available as global `RunManager` singleton

---
Autoloads are loaded in the order specified in `project.godot`:
1. EventBus
2. GameManager
3. TileBag
4. HandManager
5. TileAnimator
6. RunManager

**Note**: DebugManager, SelectionManager, and DragManager are no longer autoloads.

---

## Input Actions

| Action | Key | Consumer |
|--------|-----|---------|
| `toggle_multi_select` | Q | GameplayController → SelectionManager |
| `discard_tiles` | Z | GameplayController → discard flow |
