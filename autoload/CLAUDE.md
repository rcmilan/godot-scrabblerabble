# Autoload Managers

## Overview
Global singleton managers that coordinate game-wide systems. These are automatically loaded by Godot and accessible from any script.

**Active Autoloads (6):** EventBus, GameManager, TileBag, HandManager, TileAnimator, RunManager

**Related (3):**
- **SelectionManager** - Local node, defined in `scripts/managers/selection_manager.gd`, created by Main, injected via `set_selection_manager()`
- **DragManager** - Local node, defined in `scripts/managers/drag_manager.gd`, created by GameplayController, injected via `setup()`
- **DebugManager** - RefCounted helper owned by DebugConsole

## Autoload Files (6)
- `event_bus.gd` - Global signal hub for decoupled cross-system communication
- `game_manager.gd` - Game phase state machine, scoring, round lifecycle (state encapsulated behind getters)
- `hand_manager.gd` - Hand draw/discard operations and discard pile management
- `tile_bag.gd` - Tile pool (deck): creation from distribution, shuffling, drawing
- `tile_animator.gd` - Animation facade: delegates to strategy/executor pairs (lazy-loaded)
- `run_manager.gd` - Multi-round run lifecycle, quality dispatch, progression rules

## Manager Files (in scripts/managers/)
- `selection_manager.gd` - Tile selection state (local node, NOT an autoload)
- `drag_manager.gd` - Multi-tile drag coordination (local node, NOT an autoload)

---

## EventBus

### Purpose
Centralized signal hub for decoupled communication between systems. No logic -- only signal declarations. Systems emit and connect to signals here instead of referencing each other directly.

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
- `bag_empty()` - Emitted by HandManager when TileBag returns null

#### Discard Operations (2 signals)
- `discard_count_changed(count: int)` - Updated after discard
- `discard_pile_changed(tiles: Array)` - Updated when pile modified

#### Round/Turn Events (3 signals)
- `round_started(round_number: int)` - Emitted by GameManager.start_round() or setup_round()
- `round_ended(round_number: int, success: bool)` - Emitted by GameManager._complete_round()
- `play_completed(plays_remaining: int)` - Emitted by GameManager.commit_play()

#### Play Events (1 signal)
- `tiles_played(tiles: Array[Tile], words: Array)` - Emitted when tiles are locked/committed

#### Scoring (2 signals)
- `score_calculated(points: int, breakdown: Dictionary)` - Point calculation details
- `score_updated(total_score: int, delta: int)` - Emitted by GameManager.commit_play()

#### Game State (6 signals)
- `game_started()` - New game initialized
- `game_ended(victory: bool)` - Game finished (win or lose)
- `game_won()` - Emitted by GameManager.end_game(true)
- `game_lost()` - Emitted by GameManager.end_game(false)
- `game_paused()` - Emitted by GameManager.pause_game()
- `game_resumed()` - Emitted by GameManager.resume_game()

#### Modifier Events (2 signals)
- `modifier_applied(tile: Tile, modifier: ModifierInstance)` - Modifier added to tile
- `modifier_consumed(tile: Tile, modifier_type: int)` - Consumable modifier removed

#### Drag Operations (2 signals)
- `multi_drag_started(tiles: Array)` - Emitted by DragManager
- `multi_drag_ended(tiles: Array, success: bool)` - Emitted by DragManager

#### Run Events (3 signals)
- `run_round_ready(config: RoundConfig)` - Emitted by RunManager when round config prepared
- `run_shop_requested(round_number: int)` - Triggers shop transition after successful round
- `run_ended(victory: bool, total_score: int)` - Emitted when run completes

### Implementation Notes
- All signals are strongly typed with parameters
- EventBus contains zero logic -- it is purely signal declarations
- Selection signals (`mode_changed`, `selection_changed`) live on SelectionManager, NOT EventBus
- TileAnimator has its own signals: `animation_started`, `animation_completed`, `single_tile_animated`

---

## GameManager

### Purpose
Central game state controller. Implements a phase state machine, manages scoring, round setup, and win/lose evaluation. All state fields are private, accessed only through getters.

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

### State (all private)
| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `_current_phase` | GamePhase | SETUP | |
| `_current_round` | int | 1 | |
| `_current_score` | int | 0 | Reset by setup_round(), NOT by start_round() |
| `_target_score` | int | 100 | |
| `_plays_remaining` | int | 10 | |
| `_plays_per_round` | int | 10 | |
| `_difficulty` | int | 0 | |

### Constants
- `DEFAULT_PLAYS_PER_ROUND: int = 2`
- `DEFAULT_TARGET_SCORE: int = 1000000`

### Getters
`get_current_phase()`, `get_current_round()`, `get_current_score()`, `get_target_score()`, `get_plays_remaining()`, `get_plays_per_round()`, `get_difficulty()`

### Key Methods

#### Game Control
- `end_game(victory: bool)` - Sets phase to VICTORY or GAME_OVER; emits `game_ended`, `game_won`/`game_lost`
- `pause_game()` - PLAYING -> PAUSED; emits `game_paused`
- `resume_game()` - PAUSED -> PLAYING; emits `game_resumed`

#### Round Management
- `start_round(round_num, target, plays)` - Configures round from parameters, sets phase to PLAYING, emits `round_started`. Does NOT reset `_current_score`.
- `setup_round(config: RoundConfig)` - Configures round from RoundConfig object, resets `_current_score = 0`, sets phase to PLAYING, emits `round_started`.

#### Play
- `commit_play(score: int)` - Adds score, decrements plays. Emits `score_updated` and `play_completed`. Triggers `_complete_round(true)` on target reached, `_complete_round(false)` when plays exhausted (unless debug auto-win is on).
- `force_round_end(success: bool)` - Used by timer qualities to end round immediately.

#### Queries
- `is_playing()` - True when phase == PLAYING
- `is_game_over()` - True when phase in [GAME_OVER, VICTORY]

### Signals Emitted (via EventBus)
`game_ended`, `game_won`, `game_lost`, `game_paused`, `game_resumed`, `round_started`, `round_ended`, `play_completed`, `score_updated`

Note: `game_started` exists on EventBus but is NOT emitted by GameManager.

### Signals Listened To
None. GameManager does not connect to any external signals.

### Private Helpers
- `_set_phase(new_phase)` - Updates phase, logs transition
- `_complete_round(success)` - Sets phase to ROUND_END, emits `round_ended`. RunManager handles what happens next.

---

## HandManager

### Purpose
Manages the player's hand of tiles. Coordinates drawing from TileBag, placing into Hand UI, and discarding. Provides the discard pile.

### Signals
- `initialized` - Emitted after set_references() completes
- `tile_ready(tile: Tile)` - Emitted per tile drawn; Main connects this to register_tile()

### State
| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `hand_size` | int | 10 | Target capacity; set via set_hand_size() |
| `discard_pile` | Array[Tile] | [] | Tiles discarded this run |
| `_hand_ui` | Node | null | Reference to Hand UI component |
| `_is_initialized` | bool | false | Valid after set_references() |

### Initialization
- `set_references(hand_ui: Node)` - The ONLY initialization path. Called by Main._ready(). Sets `_hand_ui` and syncs `max_hand_size`.
- `is_initialized()` - Validates that `_hand_ui` is still a valid instance.

### Drawing
- `draw_tiles(count: int) -> int` - Draws up to `count` tiles from TileBag into hand. Stops when hand is full or bag is empty. Emits `tile_ready` per tile, `hand_count_changed`, `bag_count_changed`. Triggers `TileAnimator.animate_draw_batch()`.
- `refill_hand() -> int` - Draws tiles until hand reaches `hand_size`. Emits `hand_refilled` if any drawn.

### Discarding
- `discard_tile(tile: Tile) -> bool` - Validates tile is IN_HAND, removes from hand UI, calls `tile.move_to_discard()`, appends to discard_pile. Emits `tile_discarded`, `discard_count_changed`, `hand_count_changed`.
- `discard_selected() -> int` - Discards all selected tiles from hand UI.

### Discard Pile
- `get_discard_pile() -> Array[Tile]` - Returns duplicate of discard_pile
- `get_discard_count() -> int` - Returns discard_pile.size()
- `clear_discard_pile() -> Array[Tile]` - Clears and returns tiles; emits `discard_count_changed(0)` and `discard_pile_changed([])`

### Queries
- `get_hand_size() -> int` - Current tile count in hand (not max capacity)
- `is_hand_empty() -> bool`
- `is_hand_full() -> bool`
- `set_hand_size(size: int)` - Sets target capacity (minimum 1), syncs to Hand UI

---

## TileBag

### Purpose
Manages the tile pool (deck). Factory for Tile instances from LetterTileData resources and BagDistribution config. Handles population, shuffling, drawing, and returning tiles.

### Resources
- `TILE_SCENE_PATH = "res://scenes/tile/Tile.tscn"` (preloaded in _ready)
- `TILE_DATA_PATH = "res://Data/TileData/tiles/tile_%s.tres"`

### State
| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `available_tiles` | Array[Tile] | [] | Tiles available to draw |
| `drawn_tiles` | Array[Tile] | [] | Tiles already drawn |
| `current_distribution` | BagDistribution | null | Active distribution config |
| `_initial_count` | int | 0 | Total tiles at population time |

### Key Methods

#### Setup
- `populate_bag(distribution: BagDistribution) -> bool` - Clears existing tiles, creates Tile instances for each letter in distribution, shuffles, stores `_initial_count`. Returns false if distribution is invalid.
- `shuffle_bag()` - Randomizes available_tiles order.
- `reset_bag()` - Returns all drawn tiles to available pool (calls tile.reset() on each), then shuffles.

#### Drawing
- `draw_tile() -> Tile` - Pops from end of available_tiles, appends to drawn_tiles, emits `EventBus.tile_drawn(tile)`. Returns null if empty.
- `draw_tiles(count: int) -> Array[Tile]` - Draws multiple tiles via draw_tile(). Returns array (may be shorter than count if bag runs out).
- `return_tile(tile: Tile)` - Returns a tile to the bag. Removes from drawn_tiles, calls tile.reset(), appends to available, reshuffles.

#### Queries
- `tiles_remaining() -> int`
- `is_empty() -> bool`
- `get_initial_count() -> int`
- `get_drawn_count() -> int`
- `peek_tiles(count: int) -> Array[Tile]` - Preview top N tiles without drawing (for debugging)

### Tile Creation (private)
- `_load_tile_data(letter)` - Loads LetterTileData from `tile_%s.tres`
- `_create_tile(data)` - Instantiates Tile.tscn, calls `tile.initialize(data)`, sets `tile.location = IN_BAG`
- `_clear_all_tiles()` - queue_free() all tiles, clears arrays, resets count

---

## TileAnimator

### Purpose
Animation facade. Delegates to lazy-loaded strategy/executor pairs. Each animation type has a Strategy (what to animate) and an Executor (how to sequence it).

### Architecture
```
TileAnimator (Facade)
    DrawTileAnimation  (Strategy) -> BatchAnimationExecutor  (Executor)
    GlideTileAnimation (Strategy) -> ReturnAnimationExecutor (Executor)
    ShakeTileAnimation (Strategy) -> ShakeAnimationExecutor  (Executor)
    StompTileAnimation (Strategy) -> StompAnimationExecutor  (Executor)
    SpinTileAnimation  (Strategy) -> SpinAnimationExecutor   (Executor)
```

### Signals
- `animation_started(tiles: Array[Tile])` - Batch animation began
- `animation_completed(tiles: Array[Tile])` - Batch animation finished
- `single_tile_animated(tile: Tile)` - Individual tile completed

### Animation APIs
- `animate_draw_batch(tiles)` - Tiles enter from below screen to hand positions. Called by HandManager.draw_tiles().
- `animate_return_to_hand(tile, hand, cell)` - Glides tile from board cell to hand. Call BEFORE moving the tile -- the method handles the move.
- `animate_shake(tile)` - Shake feedback for illegal actions.
- `animate_stomp_batch(tiles)` - Stomp effect to confirm play. Used for plain/locked tiles and RESET modifier tiles.
- `animate_spin_batch(tiles)` - Spin effect for modifier tiles (EXTRA, MULTI, EXPO).
- `animate_cancel_to_hand(tiles, hand, restore_fn)` - Glides tiles back to hand from cancelled drag. Optional `restore_fn` callback.
- `animate_discard_batch(tiles, target_position, on_complete)` - Glides tiles to discard pile position, then invokes callback.

### Control
- `is_animating() -> bool` - True if any animations are active
- `cancel_all()` - Kills all active tweens immediately
- `cancel_tile_animation(tile)` - Cancels animation for a specific tile

### Shared Context
`AnimationContext` holds tween factory (`create_tween`), tree reference (`get_tree`), signal callbacks, and active tween tracking. Created once in `_ready()` via `_setup_context()`.

### Lazy Loading
All strategies and executors are null until first use. Each `_ensure_*_resources()` method creates them on demand. This avoids allocating objects for animation types that may never be used in a session.

### Animation Rule
Animations must NEVER tween `modulate` (it carries modifier tint). Use scale, position, rotation. Only `modulate:a` (alpha) is safe for fade effects.

---

## RunManager

### Purpose
Orchestrates multi-round run lifecycle. Owns RunState and ProgressionRules. Dispatches lifecycle events to RunQuality modifiers. Handles round transitions, quality signal forwarding, and run end conditions.

### State
| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `run_state` | RunState | null | Tracks round count, scores, active flag |
| `progression_rules` | ProgressionRules | null | Computes RoundConfig from RunState |
| `current_round_config` | RoundConfig | null | Config for the current round |
| `_active_run` | Run | null | Run object from RunBuilder (null if legacy init) |
| `_quality_connections` | Array[Dictionary] | [] | Signal connections for cleanup |
| `_debug_override_board_size` | Vector2i | ZERO | One-shot board size override; zeroed after use |
| `_debug_auto_win` | bool | false | Checked by GameManager.commit_play() |

### Initialization (two paths)
- `initialize_run(bag_config, plays_per_round, hand_size, progression_config)` - Legacy path. Creates RunState and ProgressionRules directly. Sets `_active_run = null`.
- `initialize_run_from_builder(run: Run)` - Builder path. Stores Run, creates RunState, applies `quality.apply_to_run_state()` for each quality, connects quality lifecycle signals.

### Run Flow
- `start_run()` - Called by Main._ready() after scene loads. Calls `_advance_to_next_round()`.
- `get_current_round_config() -> RoundConfig` - Returns config for Main to set up the board.
- `proceed_from_shop()` - Called after shop phase; advances to next round.
- `get_active_run() -> Run` - Returns _active_run (null if legacy init).
- `reset()` - Clears all state, disconnects quality signals. Used when returning to title.

### Round Advancement (_advance_to_next_round)
1. Gets RoundConfig from progression_rules using current run_state
2. Advances run_state.current_round
3. Applies quality modifications to round config (if _active_run exists)
4. Applies debug board size override (one-shot, zeroed after)
5. Emits `EventBus.run_round_ready(config)`

### Round End Handling (_on_round_ended)
Connected to `EventBus.round_ended`. On success:
1. Forwards to quality.on_round_ended()
2. Records score via run_state.complete_round()
3. Checks custom win conditions from qualities (may end run)
4. Emits `EventBus.run_shop_requested()` if run continues

On failure:
1. Forwards to quality.on_round_ended()
2. Ends run via run_state.end_run()
3. Emits `EventBus.run_ended(false, total_score)`

### Quality Signal Forwarding
RunManager bridges EventBus signals to quality lifecycle hooks:
- `EventBus.round_started` -> `quality.on_round_started(round_number)`
- `EventBus.play_completed` -> `quality.on_play_completed(plays_remaining)`
- `EventBus.score_updated` -> `quality.on_score_updated(total_score, delta)`
- `quality.time_expired` -> `GameManager.force_round_end(false)`

### _process(delta)
Forwards delta to `quality.on_process(delta)` for each quality, but only when `_active_run` exists and `GameManager.is_playing()` is true.

### Debug API
- `set_debug_board_override(size: Vector2i)` / `clear_debug_board_override()` - One-shot board size override
- `set_debug_auto_win(enabled: bool)` / `is_debug_auto_win() -> bool` - Auto-win mode

### Signals Emitted (via EventBus)
`run_round_ready`, `run_shop_requested`, `run_ended`

### Signals Listened To
`EventBus.round_ended` (connected in _ready)

---

## Load Order
Autoloads are loaded in the order specified in `project.godot`:
1. EventBus
2. GameManager
3. TileBag
4. HandManager
5. TileAnimator
6. RunManager

DebugManager, SelectionManager, and DragManager are NOT autoloads.

---

## Input Actions

| Action | Key | Consumer |
|--------|-----|---------|
| `toggle_multi_select` | Q | GameplayController -> SelectionManager |
| `discard_tiles` | Z | GameplayController -> discard flow |
