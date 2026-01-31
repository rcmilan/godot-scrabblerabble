# Autoload Managers

## Overview
Global singleton managers that coordinate game-wide systems. These are automatically loaded by Godot and accessible from any script.

## Files
- `event_bus.gd` - Global signal hub
- `game_manager.gd` - Game state and phase management
- `hand_manager.gd` - Hand operations and discard pile
- `tile_bag.gd` - Tile pool (deck) management
- `selection_manager.gd` - Tile selection state (single/multi-select)
- `tile_animator.gd` - Tile animation coordinator
- `debug_manager.gd` - Debug commands and logging

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
| `discard_confirmation_requested` | `tile_count: int` | Discard confirmation shown |
| `discard_confirmed` | none | User confirmed discard |
| `discard_cancelled` | none | User cancelled discard |

#### Selection Events
| Signal | Parameters | Description |
|--------|------------|-------------|
| `selection_mode_changed` | `is_multi: bool` | Single/multi mode toggled |
| `selection_changed` | `tiles: Array` | Selection changed |
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

### Usage
```gdscript
# Connect to signals
EventBus.tile_placed.connect(_on_tile_placed)
EventBus.selection_changed.connect(_on_selection_changed)

# Emit signals
EventBus.score_updated.emit(total_score, points_earned)
```

---

## SelectionManager

### Purpose
Central source of truth for tile selection state. Manages single-select and multi-select modes with ordered selection tracking.

### Selection Modes
```gdscript
enum SelectionMode {
    SINGLE,  # Click deselects others, one tile at a time
    MULTI    # Click toggles, multiple tiles can be selected
}
```

### Key Properties
```gdscript
var mode: SelectionMode = SelectionMode.SINGLE
var _selected_tiles: Array[Tile]  # Ordered by selection time
```

### Key Methods
```gdscript
# Mode management
toggle_mode() -> void               # Switch between single/multi
set_mode(new_mode: SelectionMode)   # Set mode explicitly
is_multi_select_enabled() -> bool   # Check if multi-select active

# Selection operations
select_tile(tile: Tile) -> void     # Select (mode-aware)
deselect_tile(tile: Tile) -> void   # Deselect specific tile
deselect_all() -> void              # Clear all selection

# Queries
get_selected_tiles() -> Array[Tile] # Get selected in order
get_selection_count() -> int        # Number selected
get_tile_order(tile: Tile) -> int   # Position in selection (-1 if not)
has_selection() -> bool             # Check if any selected
```

### Mode Behavior
- **SINGLE mode**: Clicking selects only that tile, deselects others
- **MULTI mode**: Clicking toggles tile selection, order preserved
- **Leaving MULTI mode**: All tiles are deselected

### Usage
```gdscript
# Toggle multi-select
SelectionManager.toggle_mode()

# Select tiles
SelectionManager.select_tile(tile1)
SelectionManager.select_tile(tile2)

# Get selection for discard/placement
var tiles = SelectionManager.get_selected_tiles()
```

---

## GameManager

### Purpose
Central game state controller. Manages phases, scoring, and round progression.

### Game Phases
```gdscript
enum GamePhase {
    SETUP,      # Loading/initialization
    PLAYING,    # Active gameplay
    PAUSED,     # Game paused
    ROUND_END,  # Processing round results
    GAME_OVER,  # Game lost
    VICTORY     # Game won
}
```

### Key Properties
```gdscript
var current_phase: GamePhase
var current_round: int
var current_score: int
var target_score: int
var plays_remaining: int
var tiles_placed_this_turn: Array[Tile]
```

### Configuration Constants
```gdscript
const DEFAULT_HAND_SIZE: int = 10
const DEFAULT_PLAYS_PER_ROUND: int = 10
const DEFAULT_TARGET_SCORE: int = 100
```

### Key Methods
```gdscript
start_game(bag_config, difficulty) -> void
end_game(victory: bool) -> void
pause_game() -> void
resume_game() -> void
commit_play(score: int) -> void
cancel_play() -> void
start_round(round_num, target, plays) -> void
is_playing() -> bool
```

### Usage
```gdscript
# Start a new game
var bag = load("res://Data/BagDistribution/bag_default.tres")
GameManager.start_game(bag, 0)

# Commit a play
GameManager.commit_play(calculated_score)

# Check state
if GameManager.is_playing():
    # Accept input
```

---

## HandManager

### Purpose
Manages tile flow between bag, hand, and discard pile.

### Configuration
```gdscript
const DEFAULT_HAND_SIZE: int = 10
const MAX_HAND_SIZE: int = 15
```

### Key Properties
```gdscript
var hand_size: int = 10  # Target hand size
var discard_pile: Array[Tile]
```

### Key Methods
```gdscript
# Drawing
draw_tiles(count: int) -> int       # Draw from bag
refill_hand() -> int                # Fill to hand_size

# Discarding
discard_tile(tile: Tile) -> bool    # Discard single tile
discard_selected() -> int           # Discard selected tiles
get_discard_pile() -> Array[Tile]   # Get discarded tiles
get_discard_count() -> int          # Count discarded
clear_discard_pile() -> Array[Tile] # Clear and return pile

# Queries
get_hand_size() -> int
is_hand_empty() -> bool
is_hand_full() -> bool
set_hand_size(size: int) -> void
```

### Usage
```gdscript
# Refill hand at round start
HandManager.refill_hand()

# Discard a tile
HandManager.discard_tile(unwanted_tile)

# Get discard pile for effects
var discarded = HandManager.get_discard_pile()
```

---

## TileBag

### Purpose
Manages the pool of available tiles (the deck). Handles tile creation, shuffling, and drawing.

### Key Properties
```gdscript
var available_tiles: Array[Tile]
var drawn_tiles: Array[Tile]
var current_distribution: BagDistribution
```

### Key Methods
```gdscript
# Bag management
populate_bag(distribution: BagDistribution) -> bool
shuffle_bag() -> void
reset_bag() -> void

# Drawing
draw_tile() -> Tile
draw_tiles(count: int) -> Array[Tile]
return_tile(tile: Tile) -> void

# Queries
tiles_remaining() -> int
is_empty() -> bool
get_initial_count() -> int
get_drawn_count() -> int
peek_tiles(count: int) -> Array[Tile]
```

### Usage
```gdscript
# Populate bag with distribution
var config = load("res://Data/BagDistribution/bag_default.tres")
TileBag.populate_bag(config)

# Draw tiles
var tile = TileBag.draw_tile()
if tile:
    hand.add_tile(tile)

# Check remaining
print("Tiles left: ", TileBag.tiles_remaining())
```

---

## DebugManager

### Purpose
Debug commands and logging utilities for development.

### Commands
- `help` - Show available commands
- `close/exit` - Hide console
- `spawn <letter> [count]` - Spawn tiles
- `draw [count]` - Draw from bag
- `clear_board` - Clear board tiles

---

## TileAnimator

### Purpose
Coordinates tile animations across the game. Uses the Strategy pattern for flexible animation types.

### Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `animation_started` | `tiles: Array[Tile]` | Batch animation began |
| `animation_completed` | `tiles: Array[Tile]` | Batch animation finished |
| `single_tile_animated` | `tile: Tile` | Individual tile completed |

### Key Methods
```gdscript
# Main API
animate_draw_batch(tiles: Array[Tile]) -> void          # Draw animation
animate_return_to_hand(tile, hand, cell) -> void        # Return from board
animate_shake(tile: Tile) -> void                       # Illegal action feedback

# State queries
is_animating() -> bool                                  # Check if animating

# Control
cancel_all() -> void                                    # Cancel all animations
cancel_tile_animation(tile: Tile) -> void               # Cancel specific tile
```

### Animation Flow
```
1. HandManager.draw_tiles() collects drawn tiles
2. TileAnimator.animate_draw_batch(tiles) called
3. await process_frame (layout calculates positions)
4. For each tile (staggered):
   - Capture final position
   - Set to start position/properties
   - Tween to final state
5. Emit completion signals
```

### Usage
```gdscript
# Draw animation is automatic via HandManager
HandManager.draw_tiles(5)  # Tiles animate automatically

# Listen for animation events
TileAnimator.animation_completed.connect(_on_draw_complete)

# Check if animating
if TileAnimator.is_animating():
    # Wait or skip interaction
```

### Strategy Pattern
TileAnimator uses animation strategies from `scripts/animation/`:
- **DrawTileAnimation** - Tiles rise from below, scale up, fade in
- **ReturnToHandAnimation** - Tiles glide from board to hand with bounce
- **ShakeTileAnimation** - Tiles shake left-right for illegal action feedback

See [scripts/animation/AGENT.md](../scripts/animation/AGENT.md) for creating custom animations.

---

## Load Order
Autoloads are loaded in the order specified in `project.godot`:
1. EventBus
2. GameManager
3. DebugManager
4. TileBag
5. HandManager
6. SelectionManager
7. TileAnimator

**Note**: Autoloads load before scenes, so they cannot reference scene types directly at declaration time. Use runtime type checking instead.

---

## Input Actions
These input actions are used by the autoload systems:

| Action | Key | Manager |
|--------|-----|---------|
| `toggle_multi_select` | Q | SelectionManager (via Main) |
| `discard_tiles` | Z | HandManager (via Main) |
