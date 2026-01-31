# Scripts Directory

## Overview
Contains utility scripts and game logic services that aren't tied to specific scenes.

## Structure
```
scripts/
└── logic/
    └── word_validator.gd   # Word validation and scoring service
```

---

## WordValidator

### Purpose
Service class for word validation and score calculation. Can be instantiated anywhere needed.

### Class: `WordValidator extends RefCounted`

### Features
- Word validation against dictionary
- Scrabble-style letter point values
- Placement score calculation with multipliers
- Placement validation (linear check)
- Word extraction from tiles

### Configuration
```gdscript
const MIN_WORD_LENGTH: int = 2
```

### Letter Point Values
```gdscript
const LETTER_POINTS = {
    "A": 1, "B": 3, "C": 3, "D": 2, "E": 1, "F": 4, "G": 2, "H": 4,
    "I": 1, "J": 8, "K": 5, "L": 1, "M": 3, "N": 1, "O": 1, "P": 3,
    "Q": 10, "R": 1, "S": 1, "T": 1, "U": 1, "V": 4, "W": 4, "X": 8,
    "Y": 4, "Z": 10
}
```

### Key Methods

#### Validation
```gdscript
is_valid_word(word: String) -> bool    # Check if word is valid
load_word_list(path: String) -> bool   # Load dictionary from file
```

#### Scoring
```gdscript
calculate_base_score(word: String) -> int           # Sum of letter points
calculate_word_score(word: String) -> int           # Wrapper for base score
calculate_placement_score(tiles, cells) -> Dictionary  # With multipliers
```

#### Placement
```gdscript
validate_placement(positions: Array[Vector2i]) -> Dictionary
extract_word(tiles: Array) -> String
find_formed_words(board, placed_positions) -> Array  # TODO
```

### Usage Example
```gdscript
# Create validator
var validator = WordValidator.new()

# Load dictionary (optional)
validator.load_word_list("res://Data/words.txt")

# Check a word
if validator.is_valid_word("HELLO"):
    var score = validator.calculate_word_score("HELLO")

# Calculate placement score with multipliers
var score_info = validator.calculate_placement_score(placed_tiles, cells)
print("Total: ", score_info.total)
print("Word multiplier: ", score_info.word_multiplier)
```

### Score Calculation Result
```gdscript
{
    "total": 42,           # Final score
    "letter_score": 21,    # Before word multiplier
    "word_multiplier": 2,  # Word mult applied
    "breakdown": [         # Per-tile breakdown
        {"letter": "H", "base": 4, "letter_mult": 1, "tile_score": 4},
        {"letter": "E", "base": 1, "letter_mult": 2, "tile_score": 2},
        # ...
    ]
}
```

### Placement Validation Result
```gdscript
{
    "valid": true,
    "direction": "horizontal",  # or "vertical" or "single"
    "positions": [Vector2i(0,0), Vector2i(0,1), Vector2i(0,2)]
}

# Invalid placement
{
    "valid": false,
    "reason": "Tiles not in a line"
}
```

---

## Integration Points

### With GameManager
```gdscript
# In GameManager or Main
var validator = WordValidator.new()
var word = validator.extract_word(placed_tiles)
if validator.is_valid_word(word):
    var score = validator.calculate_placement_score(tiles, cells)
    GameManager.commit_play(score.total)
```

### With Board
```gdscript
# Get placement cells for scoring
var cells: Array[BoardCell] = []
for tile in placed_tiles:
    cells.append(tile.current_cell)
var score = validator.calculate_placement_score(placed_tiles, cells)
```

---

## Future Scripts
- `deck_manager.gd` - Deck building and management
- `modifier_system.gd` - Tile/cell modifier effects
- `achievement_tracker.gd` - Achievement system
- `save_manager.gd` - Save/load functionality
- `cross_word_detector.gd` - Find all words formed by placement
