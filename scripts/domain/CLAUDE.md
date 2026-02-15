# Domain Model

## Overview
The domain model encapsulates the game's core concepts: runs, rounds, quality modifiers, and progression rules. It's separate from UI and managers to maintain clean architecture and testability.

## Purpose
- Define the game's ruleset without game engine dependencies
- Support roguelike modifier/quality system
- Enable run configuration and progression
- Track run and round state independently from UI

## Structure
```
scripts/domain/
├── run.gd                           # Run data container
├── run_state.gd                     # Runtime state tracking
├── run_quality.gd                   # Quality modifier base class
├── run_builder.gd                   # Run factory/builder
├── round_config.gd                  # Per-round configuration
├── progression_rules.gd             # Difficulty progression formula
├── modifiers/                       # Scoring and tile modifiers
│   ├── modifier_instance.gd         # Individual modifier with state
│   ├── modifier_registry.gd         # Modifier catalog
│   ├── modifier_scoring.gd          # Scoring rule modifications
│   ├── modifier_types.gd            # Type definitions
│   ├── modifier_visual_pipeline.gd  # Visual effect pipeline
│   └── behaviors/                   # Modifier behavior plugins
└── qualities/                       # Quality modifier implementations
    ├── quality_registry.gd          # Quality catalog
    ├── run_quality.gd               # Base class (in parent)
    ├── time_attack_quality.gd       # Timer-based quality
    ├── limited_time_with_increment_quality.gd  # Timer with per-play bonus
    ├── max_hand_size_quality.gd     # Reduce hand capacity
    ├── max_score_in_n_rounds_quality.gd  # Must score within N rounds
    └── random_modifiers_quality.gd  # Apply random modifiers
```

---

## Core Classes

### Run
**File**: `run.gd`  
**Extends**: `Resource`

Container for complete run configuration:
```gdscript
class_name Run extends Resource

@export var bag_config: BagDistribution           # Which tiles to use
@export var hand_size: int = 10                   # Max tiles in hand
@export var plays_per_round: int = 2              # Plays per round
@export var progression_config: ProgressionConfig # How rounds scale
@export var qualities: Array[RunQuality] = []     # Modifiers (time limit, etc)
```

**Purpose:**
- Immutable run configuration (created by RunBuilder)
- Passed to RunManager for initialization
- Could be saved/loaded for runs

---

### RunState
**File**: `run_state.gd`  
**Extends**: `RefCounted`

Runtime state tracking during active run:
```gdscript
class_name RunState extends RefCounted

var plays_per_round: int = 2
var hand_size: int = 10
var bag_config: BagDistribution

var current_round: int = 1
var rounds_completed: Array[Dictionary] = []  # History of each round
var total_score: int = 0
var is_game_over: bool = false
var victory: bool = false

func start_run(plays: int, hand: int, bag: BagDistribution) -> void
func end_round(round_num: int, score: int) -> void
func get_round_history(round_num: int) -> Dictionary
```

**Purpose:**
- Track what round we're on
- Track total score across rounds
- Record history of each round (score, plays used, etc)
- Determine win/loss conditions

---

### RunQuality (Base Class)
**File**: `run_quality.gd`  
**Extends**: `Resource`

Base class for quality modifiers (roguelike-style modifiers):
```gdscript
class_name RunQuality extends Resource

# Lifecycle hooks
func apply_to_run_state(state: RunState) -> void
    """Called when run starts - modify initial state"""

func on_round_started(round_config: RoundConfig) -> void
    """Called when each round starts"""

func on_process(delta: float) -> void
    """Called each frame while playing"""

func on_play_completed(score: int) -> void
    """Called after each play/word submission"""

func on_round_ended(round_config: RoundConfig) -> void
    """Called when round ends"""
```

**Purpose:**
- Enable roguelike modifier system
- Each modifier is a separate quality with its own lifecycle
- Qualities can modify run state, add ui elements, etc

---

### RoundConfig
**File**: `round_config.gd`  
**Extends**: `Resource`

Per-round configuration:
```gdscript
class_name RoundConfig extends Resource

@export var round_number: int = 1
@export var board_rows: int = 8
@export var board_columns: int = 8
@export var target_score: int = 100
@export var plays_available: int = 10  # Copies from RunState.plays_per_round
@export var hand_size: int = 10
```

**Purpose:**
- Configure each round independently
- Allow progression system to scale difficulty
- Debug popup can override board size per round

---

### ProgressionRules  
**File**: `progression_rules.gd`  
**Extends**: `RefCounted`

Difficulty progression formula:
```gdscript
class_name ProgressionRules extends RefCounted

func get_next_round_config(
    round_number: int,
    play_count: int
) -> RoundConfig
    """Generate next round with scaled difficulty"""

func calculate_target_score(round: int, base: int) -> int
    """Scale target score by round"""

func calculate_board_size(round: int) -> Vector2i
    """Scale board size by round"""
```

**Purpose:**
- Define how difficulty scales across rounds
- Central place to tweak progression formula
- Different progression configs for different game modes

---

### RunBuilder
**File**: `run_builder.gd`  
**Extends**: `RefCounted`

Factory pattern for constructing runs with qualities:
```gdscript
class_name RunBuilder extends RefCounted

# Builder methods (return self for chaining)
func with_bag(config: BagDistribution) -> RunBuilder
func with_hand_size(size: int) -> RunBuilder
func with_plays_per_round(plays: int) -> RunBuilder
func with_progression(config: ProgressionConfig) -> RunBuilder
func add_quality(quality: RunQuality) -> RunBuilder

# Build the run
func build() -> Run
```

**Example:**
```gdscript
var builder = RunBuilder.new()
var run = builder \
    .with_bag(default_distribution) \
    .with_hand_size(8) \
    .with_plays_per_round(3) \
    .add_quality(TimeAttackQuality.new(60, -5)) \
    .add_quality(MaxHandSizeQuality.new(7)) \
    .build()

RunManager.initialize_run_from_builder(run)
```

**Purpose:**
- Encapsulate run creation logic
- Support fluent/chainable configuration
- Used by UI to build custom runs

---

## Qualities (Roguelike Modifiers)

### TimeAttackQuality
**Effect:** Add a countdown timer to each round.

```gdscript
class_name TimeAttackQuality extends RunQuality

func _init(initial_time: float, decrement_rate: float) -> void:
    """initial_time: Starting seconds per round"""
    """decrement_rate: Seconds lost each subsequent round"""
```

---

### LimitedTimeWithIncrementQuality
**Effect:** Timer with bonus seconds per successful play.

```gdscript
class_name LimitedTimeWithIncrementQuality extends RunQuality

func _init(initial_time: float, increment_per_play: float) -> void:
    """initial_time: Starting seconds"""
    """increment_per_play: Seconds added per word played"""
```

---

### MaxHandSizeQuality
**Effect:** Reduce maximum hand capacity.

```gdscript
class_name MaxHandSizeQuality extends RunQuality

func _init(max_size: int) -> void:
    """max_size: New max hand size"""
```

---

### MaxScoreInNRoundsQuality
**Effect:** Must reach target score within specific number of rounds.

```gdscript
class_name MaxScoreInNRoundsQuality extends RunQuality

func _init(max_rounds: int, target: int) -> void:
    """max_rounds: Total rounds allowed"""
    """target: Total score to reach"""
```

---

### RandomModifiersQuality
**Effect:** Randomly assigns composable modifiers to bag tiles at round start.

Each tile has a 50% chance to receive a weighted random modifier:
- **Type weights**: EXTRA (45%), MULTI (30%), EXPO (15%), RESET (10%)
- **Tier weights**: BRONZE (60%), SILVER (30%), GOLD (10%)
- **Lifetime**: PER_ROUND (persists for the entire round, visuals and scoring preserved)

Modifiers are composable — a tile can have multiple types (e.g. EXTRA + LOCKED). Visual pipeline resolves tints, badges, and the invert shader. RESET dominates visually (invert, no badges). LOCKED adds a black border without affecting other visuals.

---

## Modifiers System (`modifiers/`)

### Overview
Composable tile modifier system — each tile can carry multiple modifiers that affect scoring, visuals, and behavior. Modifiers are assigned by qualities (e.g. RandomModifiersQuality) and persist for the round (PER_ROUND lifetime).

### Architecture
```
Quality (e.g. RandomModifiersQuality)
    └─ assigns ModifierInstance to tiles at round start
        ├─ ModifierInstance (type, tier, lifetime, behavior)
        │   ├─ behavior.compute()         → Scoring changes
        │   ├─ behavior.get_visual()      → Tint and invert effects
        │   ├─ behavior.get_badge_symbol()→ Badge display
        │   └─ behavior.get_play_animation() → Play animation type
        ├─ ModifierVisualPipeline         → Resolves composited visual
        ├─ ModifierPipeline.execution_order → Scoring & badge order
        └─ ModifierRegistry               → Static factory
```

### Modifier Types

| Type | Scoring | Visual | Badge | Play Animation | Notes |
|------|---------|--------|-------|----------------|-------|
| **EXTRA** | +2/5/10 (by tier) | Tier-based tint | `+` | Spin | Additive bonus |
| **MULTI** | x2/5/10 (by tier) | Tier-based tint | `x` | Spin | Multiplicative |
| **EXPO** | ^2/3/5 (by tier) | Tier-based tint + spark effect | `^` | Spin | Exponential |
| **RESET** | → 0 | Invert shader (no badges) | — | Stomp (denies spin) | Short-circuits score |
| **LOCKED** | No effect | Black border (via `is_locked`) | — | Default | Locks tile to cell |

### Modifier Tiers
- **BRONZE**: Base effect (e.g. +2, x2, ^2)
- **SILVER**: Medium effect (e.g. +5, x5, ^3)
- **GOLD**: Strong effect (e.g. +10, x10, ^5)

### Modifier Lifetimes
- **CONSUMABLE**: Removed after one play (currently unused)
- **PER_ROUND**: Persists for the entire round, removed at round end
- **PERMANENT**: Never removed automatically

### Execution Order (Scoring & Badges)
Defined in `ModifierPipeline.execution_order`:
1. RESET — short-circuits to 0
2. EXTRA — additive bonus
3. EXPO — exponential
4. MULTI — multiplicative

LOCKED is excluded from the pipeline (no scoring/visual effect).

### Visual Pipeline
`ModifierVisualPipeline.compute_tile_visual(modifiers)` resolves composited visuals:
- **RESET dominates**: Returns invert shader, no badges, white tint
- **Tint**: First non-white tint in execution order wins
- **Badges**: All non-RESET modifier symbols in execution order
- **LOCKED**: Not in pipeline — border handled by `Tile._update_visual()` via `is_locked`

### Play Animation Strategy
Each behavior defines its play animation via `get_play_animation()` and `denies_play_animation()`:
- `Tile.resolve_play_animation()` checks all modifiers: denying modifiers force DEFAULT, otherwise first special animation wins
- EXTRA, MULTI, EXPO → Spin animation
- RESET → `denies_play_animation()` forces Stomp (DEFAULT) regardless of other modifiers
- LOCKED → No opinion (inherits DEFAULT)

### Key Files

| File | Purpose |
|------|---------|
| **modifier_types.gd** | Enums: Type, Tier, Lifetime, PlayAnimation |
| **modifier_instance.gd** | Value object: type + tier + lifetime + behavior reference |
| **modifier_behavior.gd** | Strategy base class with `compute()`, `get_visual()`, `get_badge_symbol()`, `get_play_animation()`, `denies_play_animation()` |
| **modifier_registry.gd** | Static factory: `create_modifier(type, tier, lifetime)` → ModifierInstance |
| **modifier_scoring.gd** | Iterates `execution_order`, applies `behavior.compute()` in sequence |
| **modifier_visual_pipeline.gd** | Resolves composited tint, invert, and badges from all modifiers |
| **modifier_pipeline.gd** | Defines `execution_order` array (scoring AND badge display order) |
| **behaviors/*.gd** | Concrete behaviors: ExtraBehavior, MultiBehavior, ExpoBehavior, ResetBehavior, LockedBehavior |

### Tile Integration
Tiles manage modifiers via `Tile.modifiers` dictionary (keyed by `ModifierTypes.Type`):
```gdscript
tile.add_modifier(modifier)        # Add/replace modifier by type
tile.remove_modifier(type)         # Remove specific type
tile.has_modifier(type)            # Check presence
tile.consume_modifiers()           # Remove CONSUMABLE only
tile.clear_round_modifiers()       # Remove CONSUMABLE + PER_ROUND
tile.clear_modifiers()             # Remove all
tile.resolve_play_animation()      # Query behaviors for play animation
tile.set_locked(true)              # Adds LOCKED modifier (PER_ROUND)
```

The `is_locked` bool is synced automatically when LOCKED modifier is added/removed. `set_locked()` creates/removes the modifier through the modifier system for backward compatibility.

---

## Usage in RunManager

```gdscript
# RunManager._on_round_started()
for quality in _active_run.qualities:
    quality.on_round_started(round_config)

# RunManager._process()
if _active_run:
    for quality in _active_run.qualities:
        quality.on_process(delta)  # Timer countdown happens here

# RunManager._on_play_completed()
for quality in _active_run.qualities:
    quality.on_play_completed(score)
```

---

## Design Decisions

### Why Separate Domain from UI?
- Domain classes have no Godot node dependencies
- Qualities can be tested in isolation
- Run configuration can be serialized/loaded
- Clear separation between "what the game is" vs "how it looks"

### Why RunBuilder?
- Encapsulates complex run construction
- Fluent API improves readability
- Easy to add new configuration options
- Run remains immutable after build

### Why Qualities Over Inheritance?
- Each modifier is independent
- Multiple qualities can stack
- Qualities are runtime-configurable
- New qualities don't require core code changes

