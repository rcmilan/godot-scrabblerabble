# Scripts Directory

Game logic, domain models, controllers, and animation systems. Organized by responsibility into focused subdirectories.

---

## Directory Structure

```
scripts/
├── AGENT.md (THIS FILE - Overview)
├── animation/        - Tile animation strategy/executor pattern
│   ├── AGENT.md
│   ├── base/        - Base classes for animation
│   ├── draw/        - Draw animation (tiles enter from screen edge)
│   ├── glide/       - Glide animation (smooth bezier paths)
│   ├── hand/        - Hand-related animations
│   ├── shake/       - Shake animation (illegal action feedback)
│   ├── spin/        - Spin animation (modifier indicator)
│   └── stomp/       - Stomp animation (placement confirmation)
├── controllers/      - Game flow coordination
│   ├── AGENT.md
│   ├── gameplay_controller.gd   - Tile interaction & gameplay coordination
│   ├── play_handler.gd           - Play submission & scoring
│   ├── tile_placement_handler.gd - Tile placement logic
│   ├── drop_handler.gd           - Drag-and-drop validation
│   └── menu_controller.gd        - Menu screen coordination
├── domain/          - Core game domain models
│   ├── AGENT.md
│   ├── run.gd               - Run aggregate (config + qualities)
│   ├── run_builder.gd       - Fluent builder for Run
│   ├── run_state.gd         - Tracks run progression
│   ├── run_quality.gd       - Base class for run qualities
│   ├── round_config.gd      - Immutable round configuration
│   ├── progression_rules.gd - Difficulty progression logic
│   ├── modifiers/           - Tile modifier system
│   │   ├── AGENT.md
│   │   ├── behaviors/       - Modifier behavior implementations
│   │   ├── modifier_instance.gd
│   │   ├── modifier_pipeline.gd
│   │   ├── modifier_registry.gd
│   │   ├── modifier_scoring.gd
│   │   ├── modifier_types.gd
│   │   └── modifier_visual_pipeline.gd
│   ├── qualities/           - Run quality implementations
│   │   ├── quality_registry.gd
│   │   ├── time_attack_quality.gd
│   │   ├── limited_time_with_increment_quality.gd
│   │   ├── max_hand_size_quality.gd
│   │   ├── max_score_in_n_rounds_quality.gd
│   │   └── random_modifiers_quality.gd
│   └── modifiers/behaviors/ - Modifier behaviors
├── interaction/     - User input helpers
│   └── tile_drag_helper.gd  - Drag operation utilities
└── logic/          - Game logic & validation
    ├── AGENT.md
    └── word_validator.gd    - Word validation & scoring

```

---

## Core Architectural Patterns

### 1. Domain-Driven Design (Domain Models)

**Location:** `scripts/domain/`

Core game entities as immutable value objects:
- `Run` - Game run configuration (bag, plays, hand size, qualities)
- `RoundConfig` - Single round parameters (board size, target, plays)
- `RunState` - Current round/score tracking
- `RunQuality` - Modifier that affects run (timers, restricted tiles, etc.)

**Builder Pattern:**
```
RunBuilder (fluent)
  .set_bag(distribution)
  .set_hand_size(10)
  .add_quality(quality1)
  .build() → Run
```

### 2. Handler/Controller Decomposition

**Location:** `scripts/controllers/`

`GameplayController` delegates to specialized handlers:

```
GameplayController (Orchestrator)
  ├─ TilePlacementHandler  - Tile placement/return logic
  ├─ DropHandler          - Drag validation
  ├─ PlayHandler          - Play submission & scoring
  └─ MenuController       - Menu coordination
```

Benefits:
- Single Responsibility: Each handler owns one concern
- Testable: Handlers can be tested in isolation
- Maintainable: Changes localized to relevant handler

### 3. Strategy Pattern (Animations)

**Location:** `scripts/animation/`

```
TileAnimationStrategy (Abstract)
  ├─ DrawTileAnimation
  ├─ GlideTileAnimation        
  ├─ ShakeTileAnimation
  ├─ StompTileAnimation
  └─ SpinTileAnimation

AnimationExecutor (Abstract)
  ├─ BatchAnimationExecutor
  ├─ ReturnAnimationExecutor
  ├─ ShakeAnimationExecutor
  ├─ StompAnimationExecutor
  └─ SpinAnimationExecutor
```

- **Strategy** defines WHAT to animate (properties, timings, curves)
- **Executor** defines HOW (tween sequencing, batching)
- **TileAnimator** (autoload) facade delegates to strategy/executor pairs

### 4. Quality/Modifier System

**Location:** `scripts/domain/qualities/` and `scripts/domain/modifiers/`

Qualities modify run behavior (applied to entire run):
- `TimeAttackQuality` - Timer-based failure
- `MaxHandSizeQuality` - Restricted hand size
- `MaxScoreInNRoundsQuality` - Win condition (max score in N rounds)
- `RandomModifiersQuality` - Adds random tile modifiers

Modifiers affect individual tiles (applied to tiles during play):
- **Extra** - Bonus points
- **Multi** - Multiply points
- **Expo** - Exponential scaling
- **Locked** - Tile locked to cell
- **Reset** - Score reset

---

## Key Files by Responsibility

### Domain Models (`scripts/domain/`)
- `run.gd` - Game run (RefCounted value object, aggregate root)
- `run_builder.gd` - Fluent builder for Run with defaults
- `run_state.gd` - Run progression tracking (rounds, scores, plays)
- `run_quality.gd` - Base class for qualities (pure virtual)
- `round_config.gd` - Immutable round parameters (value object)
- `progression_rules.gd` - Difficulty scaling formulas

### Controllers & Handlers (`scripts/controllers/`)
- `gameplay_controller.gd` - Main gameplay coordinator (delegates to handlers)
- `play_handler.gd` - Play submission & word validation
- `tile_placement_handler.gd` - Tile placement/removal logic
- `drop_handler.gd` - Drag-and-drop validation (can tiles be placed?)
- `menu_controller.gd` - Menu/title screen controller

### Animation System (`scripts/animation/`)
- Base:
  - `base/tile_animation_strategy.gd` - Base strategy (Resource-based)
  - `base/animation_executor.gd` - Base executor class
  - `base/animation_context.gd` - Shared animation infrastructure (context)
- Implementations:
  - `draw/draw_tile_animation.gd` + `batch_animation_executor.gd` - Entry animation
  - `glide/glide_tile_animation.gd` + `return_animation_executor.gd` - Smooth transitions
  - `shake/shake_tile_animation.gd` + `shake_animation_executor.gd` - Negative feedback
  - `stomp/stomp_tile_animation.gd` + `stomp_animation_executor.gd` - Placement confirmation
  - `spin/spin_tile_animation.gd` + `spin_animation_executor.gd` - Modifier indicator
  - `hand/hand_fan_layout.gd` - Hand layout calculations

### Game Logic (`scripts/logic/`)
- `word_validator.gd` - Word validation database, scoring calculation, multiplier application

### Interaction Helpers (`scripts/interaction/`)
- `tile_drag_helper.gd` - Drag state machine for individual tiles

### Modifiers & Qualities
- `modifiers/modifier_instance.gd` - Runtime modifier data + state
- `modifiers/modifier_pipeline.gd` - Apply modifiers to tile
- `modifiers/modifier_registry.gd` - Registry of all modifier types
- `modifiers/modifier_scoring.gd` - Score calculation with modifiers
- `modifiers/modifier_types.gd` - ModifierType enum
- `modifiers/modifier_visual_pipeline.gd` - Visual effects pipeline
- `modifiers/behaviors/*_behavior.gd` - Individual behavior implementations
- `qualities/quality_registry.gd` - Registry of all quality types
- `qualities/*_quality.gd` - Individual quality implementations

---

## Data Flow: Play Submission

```
Player clicks "Play" button
  ↓
Main._on_play_button_pressed()
  ↓
GameplayController.on_play_button_pressed()
  ↓
PlayHandler.on_play_requested()
       ├─ Gets unplayed board tiles via _get_unplayed_board_tiles()
       ├─ Finds formed words: WordValidator.find_formed_words()
       │   └─ Returns: [{ word:"CAT", direction:"horizontal", cells:[...] }]
       ├─ Locks tiles: tile.set_locked(true)
       ├─ Deselects all: _selection.deselect_all()
       ├─ Animates tiles:
       │   ├─ If has RESET modifier: stomp (denies special animation)
       │   ├─ If has EXTRA/MULTI/EXPO: spin
       │   └─ Otherwise: stomp
       ├─ Hides locked borders for animation
       ├─ Awaits animation completion
       ├─ Consumes consumable modifiers: tile.consume_modifiers()
       ├─ Emits EventBus.tiles_played(tiles, words)
       └─ Emits play_completed signal

Main._on_tiles_played(tiles, words)
  ├─ Validate words via WordValidator
  ├─ Calculate score:
  │   └─ WordValidator.calculate_total_score(words, board)
  │       ├─ For each word:
  │       │   ├─ Sum base letter values (LETTER_POINTS)
  │       │   ├─ Apply letter multipliers (cell.multiplier)
  │       │   ├─ Apply word multipliers (cell.multiplier_type)
  │       │   └─ Apply modifier scoring (tile.modifiers)
  │       └─ Return total
  ├─ Lock down tiles via modifier pipeline
  ├─ Commit play:
  │   └─ GameManager.commit_play(score)
  │       ├─ Updates _current_score += score
  │       ├─ Decrements _plays_remaining -= 1
  │       ├─ Emits EventBus.score_updated(total, delta)
  │       ├─ Emits EventBus.play_completed(plays_remaining)
  │       └─ Checks win condition:
  │           ├─ If score >= target: _complete_round(true)
  │           ├─ If plays_remaining <= 0: _complete_round(false)
  │           └─ Emits EventBus.round_ended(round, success)
  └─ Refill hand & prepare for next play
```

---

## Data Flow: Drawing Tiles

```
Game initialized
  ↓
Main._ready()
  ├─ HandManager.set_references($Hand)
  ├─ HandManager.set_hand_size(10)
  └─ HandManager.refill_hand()
       ↓
       Loop: for i in 10
         ├─ TileBag.draw_tile()
         │   ├─ Pops from available_tiles
         │   ├─ Appends to drawn_tiles
         │   ├─ Emits EventBus.tile_drawn(tile)
         │   └─ Returns Tile instance
         ├─ Hand.add_tile(tile)  ← Reparents to hand UI
         ├─ HandManager emits tile_ready(tile)
         │   └─ Caught by Main.register_tile()
         │       └─ Wires tile signals to GameplayController
         └─ Queued for animation
       ├─ TileAnimator.animate_draw_batch([tiles])
       │   └─ BatchAnimationExecutor.execute(tiles, DrawTileAnimation)
       └─ Tiles animate from below screen to final hand positions
```

---

## Animation Architecture Deep Dive

### Pattern: Strategy + Executor Composition

Each animation type uses two classes working together:

**1. Strategy Class (Defines WHAT to animate)**

Extends `TileAnimationStrategy` (Resource):
```gdscript
class_name DrawTileAnimation extends TileAnimationStrategy

@export var duration: float = 0.3
@export var ease_type: Tween.EaseType = Tween.EASE_OUT
@export var stagger_delay: float = 0.05

func get_start_position_offset() -> Vector2:
    return Vector2(0, get_tree().get_root().content_scale.y + 100)

func get_start_properties() -> Dictionary:
    return { "modulate:a": 0 }  # Start transparent

func get_end_properties() -> Dictionary:
    return { "modulate:a": 1 }  # End opaque

func build_custom_tweens(tile: Tile, tween: Tween, delay: float) -> void:
    # Additional tweens beyond standard properties
    pass
```

**2. Executor Class (Defines HOW to animate)**

Extends `AnimationExecutor`:
```gdscript
class_name BatchAnimationExecutor extends AnimationExecutor

func execute(tiles: Array[Tile], strategy: TileAnimationStrategy) -> void:
    # Batch animate multiple tiles
    var tween = context.create_tween()
    
    for i in tiles.size():
        var tile = tiles[i]
        var delay = i * strategy.stagger_delay
        # Create tween at relative start position
        # Apply start properties
        # Tween to final position and end properties
```

### Animation Context (Shared Infrastructure)

```gdscript
class_name AnimationContext

var _context: AnimationContext = null

_context.setup(
    on_started: func(tiles): animation_started.emit(tiles),
    on_completed: func(tiles): animation_completed.emit(tiles),
    on_single: func(tile): single_tile_animated.emit(tile),
    create_tween: create_tween,     # Tween factory
    get_tree_func: get_tree         # Tree access
)
```

### Animation Lifecycle

```
1. TileAnimator.animate_draw_batch([tiles])
2. Lazily load strategy + executor if needed
3. Executor.execute(tiles, strategy):
   a. For each tile:
      - Call strategy.on_animation_start(tile)
      - Get start position offset & properties
      - Create tween from start → final position/properties
      - Call strategy.build_custom_tweens()
   b. Emit animation_started(tiles)
4. Tween completion:
   a. For each tile: Call strategy.on_animation_complete(tile)
   b. Emit animation_completed(tiles), single_tile_animated(tile)
```

---

## Quality System

### How Qualities Work

1. **Run Builder applies qualities:**
   ```gdscript
   var run = RunBuilder.new() \
       .set_bag(bag_distribution)
       .add_quality(TimeAttackQuality.new(30))  # 30 second timer
       .add_quality(MaxHandSizeQuality.new(5))  # Max 5 tiles
       .build()
   ```

2. **RunManager initializes with quality modifications:**
   ```gdscript
   RunManager.initialize_run_from_builder(run)
   # For each quality:
   #   1. Call quality.apply_to_run_state(run_state)  # Config modifications
   #   2. Connect quality signals (if any)
   ```

3. **During gameplay:**
   ```
   _process(delta):
       for quality in _active_run.qualities:
           quality.on_process(delta)  # All frame updates
   
   EventBus.round_started.connect(quality.on_round_started)
   EventBus.tiles_played.connect(quality.on_tiles_played)
   # etc.
   ```

4. **Qualities can:**
   - Modify RunState (hand size, plays per round, target score)
   - Override win conditions via `has_custom_win_condition()`
   - Process each frame (timers, counters, animations)
   - Listen to game events (round_ended, tiles_played, etc.)
   - Force round end via `GameManager.force_round_end()`

---

## Extension Points

### Adding a New Animation Type

1. **Create strategy:**
   `scripts/animation/myanimation/my_tile_animation.gd`
   - Extend `TileAnimationStrategy`
   - Override lifecycle methods

2. **Create executor:**
   `scripts/animation/myanimation/my_animation_executor.gd`
   - Extend `AnimationExecutor`
   - Implement `execute()` method

3. **Register in TileAnimator:**
   ```gdscript
   var _my_animation: MyTileAnimation = null
   var _my_executor: MyAnimationExecutor = null
   
   func animate_myanimation(tile: Tile) -> void:
       _ensure_myanimation_resources()
       _my_executor.execute_single(tile, _my_animation)
   ```

### Adding a New Quality

1. **Create class:**
   `scripts/domain/qualities/my_quality.gd`
   - Extend `RunQuality`
   - Implement required abstract methods

2. **Register in QualityRegistry:**
   ```gdscript
   func create_from_dict(data: Dictionary) -> RunQuality:
       if data.get("_type") == "my_quality":
           return MyQuality.new()
   ```

3. **Use in RunBuilder:**
   ```gdscript
   builder.add_quality(MyQuality.new(param1, param2))
   ```

---

## Common Tasks

### Adjusting Animation Timings

Edit strategy's @export properties:
```gdscript
# In scripts/animation/draw/draw_tile_animation.gd
@export var duration: float = 0.5  # Increase for slower draw
@export var stagger_delay: float = 0.1  # Increase for more spacing
```

### Changing Scoring Rules

Edit `WordValidator`:
```gdscript
# Modify LETTER_POINTS dictionary
const LETTER_POINTS: Dictionary = {
    "A": 2,  # Changed from 1
    ...
}

func calculate_base_score(word: String) -> int:
    # Override calculation logic
```

### Adding Play Restrictions

Create new `RunQuality`:
```gdscript
class_name SinglePlayQuality extends RunQuality
    func apply_to_run_state(state: RunState) -> void:
        state.plays_per_round = 1  # Only 1 play per round
```

---

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
