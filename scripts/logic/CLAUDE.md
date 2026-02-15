# Scripts/Logic Directory

Game logic and validation services.

---

## Overview

The Logic subsystem contains reusable game logic services:
- Word validation and dictionary checking
- Score calculation with multipliers and modifiers  
- Word finding and direction detection

---

## WordValidator

**Type:** RefCounted service (instantiate where needed, typically in PlayHandler)

**Purpose:** Word validation, scoring calculation, and word detection on board.

---

## Configuration

### Minimum Word Length
```gdscript
const MIN_WORD_LENGTH: int = 2
```
Words must be at least 2 letters long to be considered valid.

### Point Values (Scrabble-Style)
```gdscript
const LETTER_POINTS: Dictionary = {
    "A": 1, "B": 3, "C": 3, "D": 2, "E": 1, "F": 4, "G": 2, "H": 4,
    "I": 1, "J": 8, "K": 5, "L": 1, "M": 3, "N": 1, "O": 1, "P": 3,
    "Q": 10, "R": 1, "S": 1, "T": 1, "U": 1, "V": 4, "W": 4, "X": 8,
    "Y": 4, "Z": 10
}
```

| Points | Letters |
|--------|---------|
| 1 | A, E, I, O, U, L, N, S, T, R |
| 2 | D, G |
| 3 | B, C, M, P |
| 4 | F, H, V, W, Y |
| 5 | K |
| 8 | J, X |
| 10 | Q, Z |

---

## Public API

### Word Validation

#### `is_valid_word(word: String) -> bool`
Checks if a word is valid.

**Parameters:**
- `word`: Word to validate (case-insensitive)

**Returns:**
- `true` if word is valid (≥ 2 letters and in dictionary or fallback mode)
- `false` if word is invalid or too short

**Behavior:**
```
If dictionary is loaded (_is_loaded == true):
    Return whether word is in _valid_words dictionary
Otherwise:
    Return true if length >= MIN_WORD_LENGTH (fallback mode)
```

#### `load_word_list(path: String) -> bool`
Loads a dictionary from a file (one word per line).

**Parameters:**
- `path`: File path to dictionary (e.g., `res://data/english_words.txt`)

**Returns:**
- `true` if file was successfully loaded
- `false` if file could not be opened

**Behavior:**
1. Opens file and reads all lines
2. Converts each word to uppercase and strips whitespace
3. Adds words ≥ MIN_WORD_LENGTH to internal _valid_words dictionary
4. Closes file and sets `_is_loaded = true`
5. Prints "[WordValidator] Loaded N words" message

**Example:**
```gdscript
var validator = WordValidator.new()
if validator.load_word_list("res://data/english_words.txt"):
    print("Dictionary ready")
```

---

### Scoring

#### `calculate_base_score(word: String) -> int`
Calculates the base point value for a word without any multipliers.

**Parameters:**
- `word`: Word to score (case-insensitive)

**Returns:**
- Sum of letter point values for all letters in the word

**Example:**
```gdscript
validator.calculate_base_score("CAT")  # Returns: 3 + 1 + 1 = 5
validator.calculate_base_score("QUIZ")  # Returns: 10 + 1 + 1 + 10 = 22
```

#### `calculate_total_score(words: Array, board: Board) -> int`
Calculate score for all words formed.

**Parameters:**
- `words`: Array of word_info dictionaries:
  ```gdscript
  [{
      word: "CAT",
      direction: "horizontal",  # or "vertical"
      cells: [cell1, cell2, cell3]
  }]
  ```
- `board`: Board reference for cell multipliers

**Returns:**
- Sum of all word scores (with multipliers applied)

**Algorithm:**
```
1. For each word_info in words:
   a. Calculate base score using calculate_base_score()
   b. For each cell in word_info.cells:
      - Apply letter multiplier from cell
   c. Apply word multiplier to total
   d. Add to running total
2. Return total
```

#### `apply_multipliers(word_info: Dictionary, board: Board) -> int`
Apply letter and word multipliers from board cells.

**Parameters:**
- `word_info`: Dictionary with word, direction, cells
- `board`: Board reference for cell properties

**Returns:**
- Score with multipliers applied

---

### Word Detection

#### `find_formed_words(board: Board, positions: Array[Vector2i]) -> Array`
Find all words formed by tiles at given positions.

**Parameters:**
- `board`: Board reference
- `positions`: Array of grid positions where tiles were placed

**Returns:**
Array of word_info dictionaries:
```gdscript
[{
    word: "CAT",
    direction: "horizontal",
    cells: [cell1, cell2, cell3]
}, ...]
```

**Algorithm:**
```
For each position in positions:
  1. Look left/right to find horizontal word
     - Include the newly placed tile(s)
     - Collect all connected tiles horizontally
     - If word length >= MIN_WORD_LENGTH, add to results
  
  2. Look up/down to find vertical word
     - Include the newly placed tile(s)
     - Collect all connected tiles vertically
     - If word length >= MIN_WORD_LENGTH, add to results
  
  3. Skip single-letter "words"
  
  4. Validate each word via is_valid_word()
  
Return all valid words found
```

**Example:**
```
Board visualization (X = placed this turn):
  0 1 2 3 4
0 . X A T .
1 . A . . .
2 . T . . .

positions = [(0,1), (0,2), (0,3)]
Horizontal scan from (0,1): XAT → "CAT" ✓
Vertical scan from (0,1): XAA → "CAA" (invalid)
Vertical scan from (0,2): AT → "AT" (only 2 letters, valid)
Vertical scan from (0,3): T → single letter, skip

Results: [
  { word: "CAT", direction: "horizontal", cells: [...] },
  { word: "AT", direction: "vertical", cells: [...] }
]
```

---

## Usage in PlayHandler

```gdscript
class_name PlayHandler extends RefCounted

var _word_validator: WordValidator = null

func setup(p_board: Board, p_hud: CanvasLayer, p_selection: SelectionManager) -> void:
    board = p_board
    main_hud = p_hud
    _selection = p_selection
    _word_validator = WordValidator.new()  # Create instance


func on_play_requested() -> void:
    # Get newly placed tiles
    var unplayed_tiles = _get_unplayed_board_tiles()
    
    # Get their positions
    var positions: Array[Vector2i] = []
    for tile in unplayed_tiles:
        positions.append(tile.current_cell.grid_position)
    
    # Find formed words
    var words = _word_validator.find_formed_words(board, positions)
    
    # Validate all words
    var valid_words = []
    for word_info in words:
        if _word_validator.is_valid_word(word_info.word):
            valid_words.append(word_info)
        else:
            print("Invalid word rejected: %s" % word_info.word)
            return  # Reject play if any word is invalid
    
    # Calculate score
    var score = _word_validator.calculate_total_score(valid_words, board)
    
    # Commit play
    GameManager.commit_play(score)
```

---

## Modifier Integration

Tile modifiers can affect scoring:

```gdscript
# In calculate_total_score or similar
if tile.has_modifier(ModifierTypes.Type.EXTRA):
    score += 5  # Bonus points

if tile.has_modifier(ModifierTypes.Type.MULTI):
    score *= 2  # Double points

if tile.has_modifier(ModifierTypes.Type.EXPO):
    score = pow(score, 1.5)  # Exponential scaling
```

---

## Testing & Validation

### Debug Mode (Without Dictionary)

For development, word validation operates in fallback mode:
- Accept any word >= MIN_WORD_LENGTH
- Useful for testing with arbitrary words
- No external word list required

```gdscript
var validator = WordValidator.new()
# Without calling load_word_list(), operates in fallback mode
validator.is_valid_word("XYZ")  # Returns: true (≥ 2 letters)
validator.is_valid_word("Q")    # Returns: false (< 2 letters)
```

### Production Mode (With Dictionary)

```gdscript
var validator = WordValidator.new()
if validator.load_word_list("res://data/english_words.txt"):
    # Strict validation now enabled
    validator.is_valid_word("CAT")   # Returns: true (in dictionary)
    validator.is_valid_word("XYZQ")  # Returns: false (not in dictionary)
```

---

## Future Enhancements

- **Multiple languages** - Support different language dictionaries
- **Common word bonuses** - Extra points for frequently used words
- **Word length bonuses** - Bonus for longer words (7+ letters)
- **First play rules** - Special rules for opening move (must include center)
- **Bingo bonuses** - Bonus for using all tiles in hand
- **Prefix/suffix detection** - Recognize word formations
- **Cross-word validation** - Validate all cross-words formed

```

#### `calculate_word_score(word: String) -> int`
Calculates score for a word string (simple, no multipliers). Alias for `calculate_base_score()`.

#### `calculate_placement_score(tiles: Array, cells: Array) -> Dictionary`
Calculates full score for placed tiles with cell multipliers (future feature).

**Parameters:**
- `tiles`: Array of Tile objects placed
- `cells`: Array of BoardCell objects where tiles were placed

**Returns:**
```gdscript
{
    "total": int,              # Final score with multipliers applied
    "letter_score": int,       # Sum of (base * letter_multiplier) for each tile
    "word_multiplier": int,    # Product of all word multipliers
    "breakdown": Array[Dict]   # Per-tile breakdown:
                               # {letter, base, letter_mult, tile_score}
}
```

**Calculation:**
```
For each tile:
    letter_mult = cell.get_letter_multiplier() or 1
    tile_score = base_points * letter_mult
    letter_score += tile_score
    word_multiplier *= cell.get_word_multiplier()

total = letter_score * word_multiplier
```

**Note:** Cell multiplier infrastructure exists but multipliers are not yet implemented (all return 1).

---

### Placement Validation

#### `validate_placement(positions: Array[Vector2i]) -> Dictionary`
Validates that tiles form a valid linear placement (straight line).

**Parameters:**
- `positions`: Array of grid positions where tiles are placed

**Returns:**
```gdscript
{
    "valid": bool,             # Whether placement is valid
    "error": String,           # Error message if invalid
    "direction": String,       # "horizontal", "vertical", or "single"
    "sorted_positions": Array  # Sorted positions (if valid)
}
```

**Validation Rules:**
1. If empty → invalid ("No tiles placed")
2. If single tile → valid (direction = "single")
3. If multiple tiles:
   - All must have same Y (horizontal) OR same X (vertical)
   - If neither → invalid ("Tiles must be in a straight line")
   - Otherwise → valid (direction = "horizontal" or "vertical")

**Example:**
```gdscript
# Valid - horizontal placement
var result = validator.validate_placement([Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)])
# Returns: {valid: true, direction: "horizontal", sorted_positions: [...]}

# Invalid - diagonal
var result = validator.validate_placement([Vector2i(0,0), Vector2i(1,1)])
# Returns: {valid: false, error: "Tiles must be in a straight line"}
```

#### `extract_word(tiles: Array[Tile]) -> String`
Extracts a word from a list of tiles (concatenates letters).

**Parameters:**
- `tiles`: Array of Tile objects

**Returns:**
- Concatenated word formed by tile letters

---

### Word Finding

#### `find_formed_words(board: Board, placed_positions: Array[Vector2i]) -> Array`
Finds all words formed by a placement on the board (main word + cross-words).

**Parameters:**
- `board`: Board instance
- `placed_positions`: Grid positions of the newly placed tiles

**Returns:**
- Array of word dictionaries:
  ```gdscript
  [{
      "word": String,           # The word text
      "tiles": Array[Tile],     # Tiles forming the word
      "cells": Array[BoardCell], # Cells where tiles are placed
      "positions": Array[Vector2i], # Grid positions
      "direction": String       # "horizontal" or "vertical"
  }, ...]
  ```

**Behavior:**
1. Validates placement direction (must be straight line)
2. Finds the **main word** formed by the placed tiles
   - Extends in both directions to find full word
   - Includes any existing tiles adjacent to placement
3. Finds **cross-words** formed by each placed tile (perpendicular to main direction)
4. Filters words to only those ≥ MIN_WORD_LENGTH
5. Removes duplicate cross-words

**Example:**
```gdscript
# Player places [T, A, C] horizontally at positions (0,0), (1,0), (2,0)
# With an 'S' below the T at (0,1)
var words = validator.find_formed_words(board, [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)])
# Returns:
# [
#   {word: "TAC", direction: "horizontal", ...},
#   {word: "TS", direction: "vertical", ...}
# ]
```

---

## Private Methods (Internal Implementation)

### `_find_word_at_positions(board: Board, positions: Array[Vector2i], direction: String) -> Dictionary`
Finds a word formed by connected tiles at given positions. Extends in both directions to find full word.

### `_find_word_through_position(board: Board, pos: Vector2i, direction: String) -> Dictionary`
Finds a word passing through a specific position in a given direction.

### `_extend_word_position(board: Board, pos: Vector2i, direction: String, step: int) -> Vector2i`
Extends a position in a direction (-1 = backward, 1 = forward) until no more adjacent tiles are found.

### `_collect_word_between(board: Board, start: Vector2i, end: Vector2i, direction: String) -> Dictionary`
Collects all tiles and their properties between two positions into a word dictionary.

**Safety:** Includes a 100-tile safety limit to prevent infinite loops.

---

## State Management

```gdscript
var _valid_words: Dictionary = {}    # Loaded dictionary (word -> true)
var _is_loaded: bool = false         # Whether dictionary is loaded
```

**Modes:**
- **Dictionary Mode** (`_is_loaded = true`): Validates against loaded word list
- **Fallback Mode** (`_is_loaded = false`): Accepts any word ≥ MIN_WORD_LENGTH

---

## Integration with GameplayController

GameplayController uses WordValidator to find words when player submits:

```gdscript
# In GameplayController._on_play_requested():
var unplayed_tiles: Array[Tile] = _get_unplayed_board_tiles()
var positions: Array[Vector2i] = [...]  # Grid positions of tiles
var words: Array = _word_validator.find_formed_words(board, positions)

# Lock tiles and animate
for tile in unplayed_tiles:
    tile.set_locked(true)
TileAnimator.animate_stomp_batch(unplayed_tiles)

EventBus.tiles_played.emit(unplayed_tiles, words)
```

---

## Future Enhancements

### Dictionary Loading
Currently, WordValidator includes fallback mode (accept any ≥ 2-letter word). Future work:
- Load English dictionary at game startup
- Cache dictionary in memory for fast validation
- Support multiple language dictionaries

### Word Validation
- Implement bingo/blank tile detection
- Validate cross-words exist in dictionary
- Track used words to prevent repeats

### Scoring
- Implement cell multipliers (DOUBLE_LETTER, TRIPLE_WORD, etc.)
- Calculate full scoring with multipliers
- Track score history

---

## Design Notes

### RefCounted Pattern
WordValidator extends RefCounted instead of Node:
- No scene tree dependency
- Automatic garbage collection when reference count reaches 0
- Lighter weight than Node-based classes
- Easy to instantiate and pass around

### Stateless Design
WordValidator contains no mutable state (except loaded dictionary):
- All methods are deterministic (same input = same output)
- Safe to use across scenes
- Easy to test in isolation

### O(1) Dictionary Lookup
Word validation uses dictionary hash lookup:
```gdscript
if _valid_words.has(upper_word):  # O(1) lookup
    return true
```
Much faster than iterating array or checking individual characters.
