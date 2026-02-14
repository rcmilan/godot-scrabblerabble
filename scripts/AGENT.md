# Scripts Directory

## Overview
Contains utility scripts and game logic services that aren't tied to specific scenes.

## Structure
```
scripts/
├── controllers/
│   ├── gameplay_controller.gd       # Coordinator for gameplay interaction
│   ├── tile_placement_handler.gd    # Tile placement/return operations
│   ├── drop_handler.gd              # Drag-and-drop validation
│   ├── play_handler.gd              # Play submission and scoring
│   └── menu_controller.gd           # Title screen menu navigation
├── domain/                          # Game domain model
│   ├── run.gd                       # Run data container
│   ├── run_state.gd                 # Run gameplay state tracking
│   ├── run_quality.gd               # Quality modifier base class
│   ├── run_builder.gd               # Run construction factory
│   ├── round_config.gd              # Round-specific configuration
│   ├── progression_rules.gd         # Progression formula and difficulty
│   ├── modifiers/                   # Modifier system for qualities
│   │   ├── modifier_instance.gd     # Individual modifier instance
│   │   ├── modifier_registry.gd     # Modifier catalog and creation
│   │   ├── modifier_scoring.gd      # Scoring modification logic
│   │   ├── modifier_types.gd        # Modifier type definitions
│   │   ├── modifier_visual_pipeline.gd  # Visual effects for modifiers
│   │   └── behaviors/               # Specific modifier behaviors
│   └── qualities/                   # Quality implementations
│       ├── quality_registry.gd      # Quality catalog
│       ├── time_attack_quality.gd
│       ├── limited_time_with_increment_quality.gd
│       ├── max_hand_size_quality.gd
│       └── ... (other qualities)
├── animation/                       # Tile animation system (Strategy pattern)
│   ├── base/
│   │   ├── tile_animation_strategy.gd  # Base strategy (Resource)
│   │   ├── animation_context.gd        # Shared animation state
│   │   └── animation_executor.gd       # Base executor class
│   ├── draw/                        # Draw-from-bag animation
│   ├── glide/                       # Smooth transitions
│   ├── shake/                       # Illegal action feedback
│   ├── stomp/                       # Play confirmation effect
│   ├── spin/                        # Tile spin effect
│   └── hand/                        # Hand layout & hover effects
├── interaction/
│   └── tile_drag_helper.gd          # Drag state machine for tiles
└── logic/
    └── word_validator.gd            # Word validation and scoring service
```

---

## Domain Model (`scripts/domain/`)

### Overview
The domain model encapsulates the game's ruleset, progression, and modifier system. It's separate from UI to maintain clean architecture.

### Core Classes

| Class | Purpose |
|-------|---------|
| **Run** | Container for a complete run configuration (bag, hand size, qualities, progression) |
| **RunState** | Runtime state tracking (current round, scores, plays remaining) |
| **RunBuilder** | Factory for constructing runs with quality combinations |
| **RunQuality** | Base class for quality modifiers (time limits, hand size changes, etc.) |
| **RoundConfig** | Per-round configuration (board size, target score, plays available) |
| **ProgressionRules** | Formula for difficulty scaling across rounds |
| **ModifierInstance** | Individual modifier with active effects |
| **ModifierRegistry** | Catalog of all available modifiers |

### Run Builder Example
```gdscript
var builder = RunBuilder.new()
builder.with_bag(default_distribution)
builder.with_hand_size(10)
builder.with_plays_per_round(2)
builder.add_quality(TimeAttackQuality.new(60, 45))  # Start: 60s, decrement: 45s
var run = builder.build()

RunManager.initialize_run_from_builder(run)
```

### Quality System
Custom game modifiers that apply rules to a run:

| Quality | Effect |
|---------|--------|
| **TimeAttackQuality** | Add time limits and timer countdown |
| **MaxHandSizeQuality** | Reduce maximum hand capacity |
| **MaxScoreInNRoundsQuality** | Must reach target within N rounds |
| **RandomModifiersQuality** | Apply random tile/board modifiers each round |
| **LimitedTimeWithIncrementQuality** | Timer with per-play increment |

---

## Controllers (`scripts/controllers/`)

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

## TileDragHelper

### Purpose
Encapsulates the drag state machine extracted from Tile.gd. Handles press detection, drag threshold, and state transitions.

### Class: `TileDragHelper extends RefCounted`

### Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `drag_threshold_reached` | none | Mouse moved past drag threshold |
| `drag_ended` | none | Drag operation ended (mouse released) |

### State Machine
```
IDLE → PRESSED (on mouse press)
PRESSED → DRAGGING (on threshold reached)
PRESSED → IDLE (on release = click)
DRAGGING → IDLE (on release = drag end)
```

### Key Methods
```gdscript
on_press(pos, global_mouse, tile_global_pos) -> void  # Start tracking
on_motion(pos: Vector2) -> bool     # Returns true if drag just started
on_release() -> bool                # Returns true if was click (not drag)
force_end() -> void                 # Reset all state
set_as_follower() -> bool           # Set as multi-drag follower
is_dragging() -> bool
is_idle() -> bool
```

### Usage in Tile.gd
```gdscript
# Created in _ready()
_drag = TileDragHelper.new()
_drag.drag_threshold_reached.connect(_on_drag_threshold_reached)
_drag.drag_ended.connect(_on_drag_ended)

# Input delegation
func _handle_mouse_button(event):
    if event.is_pressed():
        _drag.on_press(event.position, get_global_mouse_position(), global_position)
    else:
        if _drag.on_release():
            tile_selected.emit(self)  # Was click

func _handle_mouse_motion(event):
    _drag.on_motion(event.position)
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

## Animation System

See [animation/AGENT.md](animation/AGENT.md) for detailed documentation.

### Quick Reference
- **TileAnimationStrategy** - Base class for animation behaviors
- **DrawTileAnimation** - Tiles animate into hand from below
- **GlideTileAnimation** - Tiles glide smoothly between positions (return, discard)
- **ShakeTileAnimation** - Tiles shake for illegal action feedback
- **StompTileAnimation** - Tiles stomp when played (locked)

### Usage
```gdscript
# Animations are triggered via TileAnimator autoload
TileAnimator.animate_draw_batch(tiles)
TileAnimator.animate_return_to_hand(tile, hand, cell)
TileAnimator.animate_cancel_to_hand(tiles, hand)
TileAnimator.animate_discard_batch(tiles, target_pos, callback)
TileAnimator.animate_shake(tile)
TileAnimator.animate_stomp_batch(tiles)
```

---

## Controllers
See [controllers/AGENT.md](controllers/AGENT.md) for detailed documentation on:
- GameplayController (coordinator pattern)
- TilePlacementHandler, DropHandler, PlayHandler
- MenuController

## Future Scripts
- `animation/discard_tile_animation.gd` - Discard animation
- `animation/place_tile_animation.gd` - Board placement animation
- `modifier_system.gd` - Tile/cell modifier effects
- `achievement_tracker.gd` - Achievement system
- `save_manager.gd` - Save/load functionality
