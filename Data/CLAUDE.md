# Data Resources

## Overview
Contains game data resources: tile definitions and bag distributions. Resources are Godot Resource files (.tres) that define game configuration without code changes.

## Structure
```
Data/
├── TileData/               # Letter tile definitions
│   ├── tile_data.gd        # LetterTileData resource class
│   ├── tiles/              # Individual tile resources (A-Z)
│   └── AGENT.md
│
├── BagDistribution/        # Tile pool configurations
│   ├── bag_distribution.gd # BagDistribution resource class
│   ├── bag_default.tres    # Default tile distribution
│   └── AGENT.md
│
└── Progression/            # Game progression configurations (NEW)
    ├── progression_config.gd   # ProgressionConfig resource class
    ├── progression_default.tres # Default progression rules
    └── (potentially AGENT.md)
```

---

## TileData Subsystem

### Purpose
Define individual letter tiles with their properties: letter, point value, and visual texture.

### LetterTileData Resource
```gdscript
class_name LetterTileData extends Resource

@export var letter: String        # Single letter (A-Z)
@export var base_points: int      # Point value
@export var texture: Texture2D    # Visual representation
```

### Tile Files
26 resource files in `tiles/` folder:
- `tile_a.tres` through `tile_z.tres`
- Each contains letter-specific data and texture reference

### Point Values (Scrabble-style)
| Points | Letters |
|--------|---------|
| 1 | A, E, I, O, U, L, N, S, T, R |
| 2 | D, G |
| 3 | B, C, M, P |
| 4 | F, H, V, W, Y |
| 5 | K |
| 8 | J, X |
| 10 | Q, Z |

### Usage
```gdscript
# Load tile data
var tile_data = load("res://Data/TileData/tiles/tile_a.tres")

# Use with Tile component
tile.initialize(tile_data)
```

---

## BagDistribution Subsystem

### Purpose
Define how many of each letter tile are included in the bag (deck) at game start.

### BagDistribution Resource
```gdscript
class_name BagDistribution extends Resource

@export var distribution: Dictionary  # Letter -> count mapping

func get_total_tiles() -> int
func is_valid() -> bool
```

### Default Distribution (bag_default.tres)
Standard Scrabble-style distribution:
| Letter | Count | Letter | Count |
|--------|-------|--------|-------|
| A | 9 | N | 6 |
| B | 2 | O | 8 |
| C | 2 | P | 2 |
| D | 4 | Q | 1 |
| E | 12 | R | 6 |
| F | 2 | S | 4 |
| G | 3 | T | 6 |
| H | 2 | U | 4 |
| I | 9 | V | 2 |
| J | 1 | W | 2 |
| K | 1 | X | 1 |
| L | 4 | Y | 2 |
| M | 2 | Z | 1 |

**Total**: 98 tiles

### Usage
```gdscript
# Load distribution
var config = load("res://Data/BagDistribution/bag_default.tres")

# Populate tile bag
TileBag.populate_bag(config)

# Query
print("Total tiles: ", config.get_total_tiles())
```

---

## Creating Custom Distributions

### New Bag Configuration
1. Create new `.tres` file in `BagDistribution/`
2. Set resource type to `BagDistribution`
3. Define distribution dictionary (keys match tile file names):
```gdscript
# Example: vowel-heavy distribution
{
    "A": 15, "E": 15, "I": 15, "O": 15, "U": 10,
    "B": 1, "C": 1, "D": 2, "F": 1, "G": 1,
    "H": 1, "J": 0, "K": 1, "L": 3, "M": 2,
    "N": 4, "P": 1, "Q": 0, "R": 4, "S": 3,
    "T": 4, "V": 1, "W": 1, "X": 0, "Y": 2, "Z": 0
}
```

### Custom Tile Data
To add special tiles (e.g., wild cards):
1. Create new `.tres` file in `TileData/tiles/` (e.g., `tile_wild.tres`)
2. Set resource type to `LetterTileData`
3. Configure:
   - **letter**: Symbol for the tile (e.g., "*")
   - **base_points**: Point value (0 for wild cards)
   - **texture**: Path to custom tile texture
4. Add to distribution with custom key:
   ```gdscript
   distribution = {
       # ... normal tiles ...
       "WILD": 2  # 2 wild card tiles in bag
   }
   ```
5. TileBag will load `tile_wild.tres` from `TileData/tiles/`

---

## Progression Subsystem

### Purpose
Define how difficulty scales across rounds (board size, target score, plays available).

### ProgressionConfig Resource
**Class**: `ProgressionConfig extends Resource`

Stores formulas for calculating difficulty at each round:
```gdscript
@export var board_size_curve: Curve        # How board scales per round
@export var target_score_curve: Curve      # How target score scales
@export var plays_available_curve: Curve   # How many plays allowed
@export var base_board_size: Vector2i      # Starting grid size
@export var base_target_score: int         # Starting target score
```

### ProgressionRules (Domain Model)
**File**: `scripts/domain/progression_rules.gd`  
**Extends**: `RefCounted`

Takes a `ProgressionConfig` and calculates per-round configuration:
```gdscript
class_name ProgressionRules extends RefCounted

func get_next_round_config(
    round_number: int,
    play_count: int
) -> RoundConfig
    """Generate next round with scaled difficulty from curves"""
```

### Usage
```gdscript
# Load default progression
var progression_config = load("res://Data/Progression/progression_default.tres")

# Create rules calculator
var rules = ProgressionRules.new(progression_config)

# Get next round config
var next_round = rules.get_next_round_config(round_number, play_count)
# → RoundConfig with scaled board size, target score, etc.
```

### Default Progression (progression_default.tres)
- **Starting Board**: 8×8
- **Starting Target Score**: 500-1000 (escalates)
- **Plays Per Round**: 2-3
- **Scaling**: Progressive increase in difficulty each round

---

## Future Data Resources
- Special tile types (wild cards, bonus tiles)
- Board layout configurations
- Difficulty presets
- Achievement definitions
- Shop item catalogs
