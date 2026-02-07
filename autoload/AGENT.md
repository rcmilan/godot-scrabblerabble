# Autoload Managers

## Overview
Global singleton managers that coordinate game-wide systems. These are automatically loaded by Godot and accessible from any script.

**Active Autoloads (6):** EventBus, GameManager, TileBag, HandManager, TileAnimator, RunManager

**Demoted (3):**
- **SelectionManager** → Local node created by Main, injected via `set_selection_manager()`
- **DragManager** → Local node created by GameplayController, injected via `setup()`
- **DebugManager** → RefCounted helper owned by DebugConsole

## Files
- `event_bus.gd` - Global signal hub
- `game_manager.gd` - Game state and phase management (encapsulated behind getters)
- `hand_manager.gd` - Hand operations and discard pile
- `tile_bag.gd` - Tile pool (deck) management
- `selection_manager.gd` - Tile selection state (NOT an autoload — local node)
- `tile_animator.gd` - Tile animation coordinator
- `drag_manager.gd` - Multi-tile drag coordination (NOT an autoload — local node)
- `run_manager.gd` - Run lifecycle orchestrator

---

## EventBus

### Purpose
Centralized signal hub for decoupled communication between systems.

### Signal Categories

#### Tile Lifecycle
| Signal | Parameters | Description |
|--------|------------|-------------|
| `tile_drawn` | `tile: Tile` | Tile drawn from bag |
| `tile_placed` | `tile, cell` | Tile placed on board |
| `tile_removed` | `tile, cell` | Tile removed from board |
| `tile_discarded` | `tile: Tile` | Tile sent to discard |

#### Hand Events
| Signal | Parameters | Description |
|--------|------------|-------------|
| `hand_count_changed` | `count: int` | Hand size changed |
| `hand_empty` | none | Hand became empty |
| `hand_refilled` | `count: int` | Hand was refilled |

#### Bag/Deck Events
| Signal | Parameters | Description |
|--------|------------|-------------|
| `bag_count_changed` | `count: int` | Bag tile count changed |
| `bag_empty` | none | Bag became empty |

#### Discard Events
| Signal | Parameters | Description |
|--------|------------|-------------|
| `discard_count_changed` | `count: int` | Discard pile size changed |
| `discard_pile_changed` | `tiles: Array` | Discard pile modified |

#### Drag Events
| Signal | Parameters | Description |
|--------|------------|-------------|
| `multi_drag_started` | `tiles: Array` | Multi-tile drag began |
| `multi_drag_ended` | `tiles, success` | Multi-tile drag ended |

#### Game State
| Signal | Parameters | Description |
|--------|------------|-------------|
| `game_started` | none | New game began |
| `game_ended` | `victory: bool` | Game finished |
| `game_won` | none | Player won |
| `game_lost` | none | Player lost |
| `round_started` | `round_number: int` | Round began |
| `round_ended` | `round, success` | Round finished |
| `play_completed` | `plays_remaining` | Play committed |

#### Score Events
| Signal | Parameters | Description |
|--------|------------|-------------|
| `score_updated` | `total, delta` | Score changed |
| `score_calculated` | `points, breakdown` | Score computed |

#### Animation Events (via TileAnimator)
| Signal | Parameters | Description |
|--------|------------|-------------|
| `animation_started` | `tiles: Array[Tile]` | Batch animation began |
| `animation_completed` | `tiles: Array[Tile]` | Batch animation finished |
| `single_tile_animated` | `tile: Tile` | Individual tile completed |

#### Play Events
| Signal | Parameters | Description |
|--------|------------|-------------|
| `tiles_played` | `tiles, words` | Tiles locked, words formed |

#### Run Events
| Signal | Parameters | Description |
|--------|------------|-------------|
| `run_round_ready` | `config: RoundConfig` | Next round config prepared |
| `run_shop_requested` | `round_number: int` | Shop transition triggered |
| `run_ended` | `victory, total_score` | Run ended (win or lose) |

### Usage
```gdscript
# Connect to signals
EventBus.tile_placed.connect(_on_tile_placed)

# Emit signals
EventBus.score_updated.emit(total_score, points_earned)
```

**Note:** Selection signals (`mode_changed`, `selection_changed`) are now on SelectionManager (local node), not EventBus.

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
Central game state controller. Manages phases, scoring, and round progression. State is encapsulated behind getters.

### Game Phases
```gdscript
enum GamePhase {
    SETUP, PLAYING, PAUSED, ROUND_END, GAME_OVER, VICTORY
}
```

### Getters (state is private)
```gdscript
get_current_phase() -> GamePhase
get_current_round() -> int
get_current_score() -> int
get_target_score() -> int
get_plays_remaining() -> int
get_plays_per_round() -> int
get_difficulty() -> int
```

### Key Methods
```gdscript
end_game(victory: bool) -> void
pause_game() -> void
resume_game() -> void
commit_play(score: int) -> void
start_round(round_num, target, plays) -> void
setup_round(config: RoundConfig) -> void
is_playing() -> bool
is_game_over() -> bool
```

---

## HandManager

### Purpose
Manages tile flow between bag, hand, and discard pile.

### Initialization
Single initialization path via `set_references(hand_ui: Node)` called from Main._ready().

### Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `initialized` | none | References are set and ready |
| `tile_ready` | `tile: Tile` | New tile drawn, ready for registration |

### Key Methods
```gdscript
set_references(hand_ui: Node) -> void
draw_tiles(count: int) -> int
refill_hand() -> int
discard_tile(tile: Tile) -> bool
get_hand_size() -> int
is_hand_empty() -> bool
set_hand_size(size: int) -> void
```

### Tile Registration
When tiles are drawn, HandManager emits `tile_ready(tile)`. Main connects this to `register_tile()` which wires tile signals to GameplayController.

---

## DragManager (Local Node — NOT Autoload)

### Purpose
Coordinates multi-tile drag operations. Created by GameplayController.

### Lifecycle
```gdscript
# In GameplayController.setup():
_drag_mgr = DragManager.new()
_drag_mgr.name = "DragManager"
add_child(_drag_mgr)
```

### Key Methods
```gdscript
start_drag(lead: Tile, tiles: Array[Tile]) -> void
end_drag(success: bool) -> void
cancel_drag() -> void
restore_tiles_to_parents() -> void
get_dragged_tiles() -> Array[Tile]
```

### EventBus Integration
DragManager still emits `EventBus.multi_drag_started` and `EventBus.multi_drag_ended` for DiscardPile to receive.

---

## TileBag

### Purpose
Manages the pool of available tiles (the deck).

### Key Methods
```gdscript
populate_bag(distribution: BagDistribution) -> bool
draw_tile() -> Tile
tiles_remaining() -> int
is_empty() -> bool
```

---

## TileAnimator

### Purpose
Coordinates tile animations. Uses Strategy pattern with Executor composition.

### Key Methods
```gdscript
animate_draw_batch(tiles: Array[Tile]) -> void
animate_return_to_hand(tile, hand, cell) -> void
animate_cancel_to_hand(tiles, hand, restore_fn: Callable) -> void
animate_shake(tile: Tile) -> void
animate_stomp_batch(tiles: Array[Tile]) -> void
animate_discard_batch(tiles, target, callback) -> void
cancel_all() -> void
```

**Note:** `animate_cancel_to_hand` now accepts a `restore_fn` callable parameter instead of calling DragManager directly.

---

## Load Order
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
