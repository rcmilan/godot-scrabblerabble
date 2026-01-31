# Autoload Managers

## Overview
Global singleton managers that coordinate game-wide systems. These are automatically loaded by Godot and accessible from any script.

## Files
- `event_bus.gd` - Global signal hub
- `game_manager.gd` - Game state and phase management
- `hand_manager.gd` - Hand operations and discard pile
- `tile_bag.gd` - Tile pool (deck) management
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

#### Game State
| Signal | Parameters | Description |
|--------|------------|-------------|
| `game_started` | none | New game began |
| `game_ended` | `victory: bool` | Game finished |
| `round_started` | `round_number: int` | Round began |
| `round_ended` | `round, success` | Round finished |
| `play_completed` | `plays_remaining` | Play committed |

#### Score Events
| Signal | Parameters | Description |
|--------|------------|-------------|
| `score_updated` | `total, delta` | Score changed |
| `score_calculated` | `points, breakdown` | Score computed |

### Usage
```gdscript
# Connect to signals
EventBus.tile_placed.connect(_on_tile_placed)

# Emit signals
EventBus.score_updated.emit(total_score, points_earned)
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

### Key Methods
```gdscript
start_game(bag_config, difficulty) -> void
end_game(victory: bool) -> void
pause_game() -> void
resume_game() -> void
commit_play(score: int) -> void
cancel_play() -> void
start_round(round_num, target, plays) -> void
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

### Key Properties
```gdscript
var hand_size: int = 10  # Target hand size
var discard_pile: Array[Tile]
```

### Key Methods
```gdscript
draw_tiles(count: int) -> int  # Draw from bag
refill_hand() -> int  # Fill to hand_size
discard_tile(tile: Tile) -> bool  # Discard single tile
discard_selected() -> int  # Discard selected tiles
get_hand_size() -> int
get_discard_count() -> int
get_discard_pile() -> Array[Tile]
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

### Key Methods
```gdscript
populate_bag(distribution: BagDistribution) -> bool
shuffle_bag() -> void
reset_bag() -> void
draw_tile() -> Tile
draw_tiles(count: int) -> Array[Tile]
return_tile(tile: Tile) -> void
tiles_remaining() -> int
is_empty() -> bool
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

### Key Features
- Command execution via debug console
- Tile spawning for testing
- Board manipulation
- State inspection

---

## Load Order
Autoloads are loaded in the order specified in `project.godot`:
1. EventBus
2. GameManager
3. DebugManager
4. TileBag
5. HandManager

**Note**: Autoloads load before scenes, so they cannot reference scene types directly at declaration time. Use runtime type checking instead.
