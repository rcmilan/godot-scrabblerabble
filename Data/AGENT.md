# Data Resources

## Overview
Contains game data resources: tile definitions and bag distributions. Resources are Godot Resource files (.tres) that define game configuration without code changes.

## Structure
```
Data/
├── TileData/           # Letter tile definitions
│   ├── tile_data.gd    # LetterTileData resource class
│   └── tiles/          # Individual tile resources (A-Z)
│
└── BagDistribution/    # Tile pool configurations
    ├── bag_distribution.gd  # BagDistribution resource class
    └── bag_default.tres     # Default distribution
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
3. Define distribution dictionary:
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
To add special tiles:
1. Create new `.tres` file in `TileData/tiles/`
2. Set resource type to `LetterTileData`
3. Configure letter, points, and texture
4. Add to distribution with custom key

---

## Future Data Resources
- Special tile types (wild cards, bonus tiles)
- Board layout configurations
- Difficulty presets
- Achievement definitions
- Shop item catalogs
