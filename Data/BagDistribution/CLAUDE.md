# BagDistribution Resources

## Overview
Tile pool (deck) distribution configurations. Defines how many of each letter are included when populating the tile bag.

## Files
- `bag_distribution.gd` - BagDistribution resource class definition
- `bag_default.tres` - Standard Scrabble-style distribution

---

## BagDistribution Resource

### Class Definition
```gdscript
class_name BagDistribution extends Resource

@export var distribution: Dictionary  # String -> int (letter -> count)

func get_total_tiles() -> int
func is_valid() -> bool
```

### Validation
The `is_valid()` method enforces:
- Distribution dictionary is not empty
- All values are non-negative integers
- Returns `false` if any value is negative or not an integer

**Note**: Keys can be any string (not restricted to A-Z), allowing for custom tiles like "WILD" or other symbols.

### TileBag Integration
TileBag uses this validation flow:
```
BagDistribution.is_valid()  # Check validity
    ↓ (if valid)
TileBag.populate_bag()      # Create tiles
    ↓
For each key in distribution:
    Load "tile_<key>.tres"  # Dynamic path from key
    Create N tile instances
    Add to available_tiles
    ↓
TileBag.shuffle_bag()       # Randomize order
```

---

## Default Distribution (bag_default.tres)

### Letter Counts
Standard Scrabble-style distribution with 98 total tiles:

| Letter | Count | Letter | Count | Letter | Count |
|--------|-------|--------|-------|--------|-------|
| A | 9 | J | 1 | S | 4 |
| B | 2 | K | 1 | T | 6 |
| C | 2 | L | 4 | U | 4 |
| D | 4 | M | 2 | V | 2 |
| E | 12 | N | 6 | W | 2 |
| F | 2 | O | 8 | X | 1 |
| G | 3 | P | 2 | Y | 2 |
| H | 2 | Q | 1 | Z | 1 |
| I | 9 | R | 6 | | |

### Distribution Rationale
- Vowels (A, E, I, O, U) have higher counts for word formation
- E is most common (12) as it's the most used letter
- Q, Z, X, J have low counts (1 each) as they're harder to use
- Common consonants (R, S, T, N) have moderate counts

---

## Usage

### Loading Distribution
```gdscript
var config = load("res://Data/BagDistribution/bag_default.tres")
```

### With TileBag
```gdscript
# In GameManager.start_game()
var distribution = load("res://Data/BagDistribution/bag_default.tres")
TileBag.populate_bag(distribution)
```

### Querying Distribution
```gdscript
var config = load("res://Data/BagDistribution/bag_default.tres")

# Total tiles
print("Total: ", config.get_total_tiles())  # 98

# Specific letter count
print("E count: ", config.distribution["E"])  # 12

# Check validity
if config.is_valid():
    TileBag.populate_bag(config)
```

---

## Creating Custom Distributions

### Vowel-Heavy Bag
For easier word formation:
```gdscript
distribution = {
    "A": 12, "B": 1, "C": 1, "D": 2, "E": 15, "F": 1, "G": 1,
    "H": 1, "I": 12, "J": 0, "K": 1, "L": 3, "M": 2, "N": 4,
    "O": 12, "P": 1, "Q": 0, "R": 4, "S": 3, "T": 4, "U": 8,
    "V": 1, "W": 1, "X": 0, "Y": 2, "Z": 0
}
```

### Hard Mode Bag
Fewer vowels, more difficult letters:
```gdscript
distribution = {
    "A": 5, "B": 3, "C": 3, "D": 4, "E": 6, "F": 3, "G": 3,
    "H": 3, "I": 5, "J": 2, "K": 2, "L": 3, "M": 3, "N": 4,
    "O": 5, "P": 3, "Q": 2, "R": 4, "S": 3, "T": 4, "U": 3,
    "V": 3, "W": 3, "X": 2, "Y": 3, "Z": 2
}
```

### Mini Bag (Quick Games)
Smaller total for faster rounds:
```gdscript
distribution = {
    "A": 4, "B": 1, "C": 1, "D": 2, "E": 5, "F": 1, "G": 1,
    "H": 1, "I": 4, "J": 0, "K": 0, "L": 2, "M": 1, "N": 3,
    "O": 4, "P": 1, "Q": 0, "R": 3, "S": 2, "T": 3, "U": 2,
    "V": 1, "W": 1, "X": 0, "Y": 1, "Z": 0
}
```

---

## Integration with Game Flow

```
Game Start
    │
    ▼
GameManager.start_game(distribution)
    │
    ▼
TileBag.populate_bag(distribution)
    │
    ├─► Creates Tile instances for each letter
    ├─► Shuffles bag
    └─► Emits bag_count_changed signal
    │
    ▼
HandManager.refill_hand()
    │
    ▼
Game Ready
```

---

## Future Enhancements
- Special tile distributions (wild cards, bonus tiles)
- Difficulty-based distribution presets
- Progressive distributions (changes per round)
- Seasonal/themed distributions
