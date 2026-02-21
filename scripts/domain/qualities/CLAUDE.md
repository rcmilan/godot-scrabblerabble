# Directory Overview

## Purpose
Contains RunQuality implementations that define roguelike game modifiers/challenges. Each quality alters gameplay rules, progression, or scoring. Qualities are selected at run start and persisted throughout the run.

## Key Files
- **quality_registry.gd**: Static factory registry mapping quality IDs to RunQuality constructors
- **auto_win_quality.gd**: Debug quality that instantly wins rounds (skips target score check)
- **max_hand_size_quality.gd**: Increases hand capacity from default 10 to a higher value
- **time_attack_quality.gd**: Adds a per-round time limit; round fails when timer expires
- **limited_time_with_increment_quality.gd**: Time limit that increases slightly with each successful round
- **max_score_in_n_rounds_quality.gd**: Custom win condition requiring a target score within N rounds
- **random_modifiers_quality.gd**: Randomly assigns EXTRA/MULTI/EXPO/RESET modifiers to tiles each round

## Public Interfaces
### QualityRegistry (Static Factory)
```gdscript
class_name QualityRegistry

static func register(id: StringName, factory: Callable) -> void
static func create_from_dict(data: Dictionary) -> RunQuality
static func create_default(id: StringName) -> RunQuality
static func get_all_quality_ids() -> Array[StringName]
```

#### Registered Quality IDs
| ID | Class | Description |
|----|-------|-------------|
| `&"max_hand_size"` | MaxHandSizeQuality | Increases hand capacity |
| `&"time_attack"` | TimeAttackQuality | Fixed time limit per round |
| `&"limited_time_with_increment"` | LimitedTimeWithIncrementQuality | Time limit with growth |
| `&"max_score_in_n_rounds"` | MaxScoreInNRoundsQuality | Custom win condition |
| `&"random_modifiers"` | RandomModifiersQuality | Tile modifiers each round |
| `&"auto_win"` | AutoWinQuality | Debug instant win |

### RunQuality Base Class
All qualities extend `RunQuality` (defined in `scripts/domain/run_quality.gd`):
```gdscript
class_name RunQuality

# Identity
func get_quality_id() -> StringName
func get_quality_name() -> String
func get_description() -> String

# Lifecycle hooks
func apply_to_run_state(state: RunState) -> void
func modify_round_config(config: RoundConfig, round_num: int) -> void
func on_round_started(round_number: int) -> void
func on_round_ended(round_number: int, success: bool) -> void
func on_play_completed(plays_remaining: int) -> void
func on_score_updated(total_score: int, delta: int) -> void
func on_process(delta: float) -> void

# Custom win conditions
func check_custom_win_condition(run_state: RunState) -> bool

# Signals
signal time_expired()  # Emitted by timer qualities
```

## Dependencies
### Internal Dependencies
- **scripts/domain/run_quality.gd**: Base class for all qualities
- **scripts/domain/run_state.gd**: Run state tracking
- **scripts/domain/round_config.gd**: Round configuration object
- **scripts/domain/modifiers/modifier_types.gd**: Modifier enums
- **scripts/domain/modifiers/modifier_instance.gd**: Modifier data structure
- **scripts/domain/modifiers/modifier_registry.gd**: Modifier factory

### External Dependencies
- **autoload/TileBag**: Used by RandomModifiersQuality to assign modifiers to tiles
- **autoload/HandManager**: Used by MaxHandSizeQuality to set hand capacity
- **autoload/GameManager**: Used by timer qualities to force round end via `force_round_end()`

### Consumers
- **scripts/domain/run_builder.gd**: Adds qualities to Run via `add_quality()`
- **autoload/run_manager.gd**: Forwards lifecycle events to qualities, checks win conditions
- **scenes/title_screen/run_setup_popup.gd**: Allows player to select qualities

## Architecture / Patterns
### Factory Registry Pattern
QualityRegistry uses static registration to map quality IDs to constructor callables:
```gdscript
static func _ensure_initialized() -> void:
    _factories[&"max_hand_size"] = func() -> RunQuality: return MaxHandSizeQuality.new()
    _factories[&"time_attack"] = func() -> RunQuality: return TimeAttackQuality.new()
    # ... etc
```

### Lifecycle Hook Pattern
RunManager forwards EventBus signals to each quality's lifecycle methods:
```gdscript
# In RunManager._on_round_started()
for quality in _active_run.qualities:
    quality.on_round_started(round_number)
```

### Signal-Based Timer Expiration
Timer qualities emit `time_expired` signal, which RunManager connects to force round failure:
```gdscript
quality.time_expired.connect(func(): GameManager.force_round_end(false))
```

### Composable Behaviors
Multiple qualities can be active simultaneously:
- MaxHandSize + RandomModifiers: Larger hand with modified tiles
- TimeAttack + MaxScoreInNRounds: Time limit AND score threshold

## Conventions
### Quality Implementation Checklist
1. Extend RunQuality base class
2. Implement identity methods: `get_quality_id()`, `get_quality_name()`, `get_description()`
3. Override relevant lifecycle hooks
4. Register in QualityRegistry._ensure_initialized()
5. Add to RunSetupPopup UI if user-selectable
6. Document configuration constants at top of file

### Naming Convention
- File: `[descriptive_name]_quality.gd` (snake_case)
- Class: `[DescriptiveName]Quality` (PascalCase)
- Quality ID: `&"[descriptive_name]"` (snake_case StringName)

### Configuration Constants
Define tunable parameters as constants at top of class:
```gdscript
const TIME_LIMIT: float = 90.0
const TIME_INCREMENT: float = 15.0
const TARGET_SCORE: int = 5000
```

## Build / Test
N/A - GDScript files loaded at runtime. No compilation required.

### Testing
1. Create a new game via TitleScreen -> RunSetupPopup
2. Select desired quality (e.g., RandomModifiers)
3. Start game and observe quality effects:
   - RandomModifiers: Tiles have colored tints (modifiers)
   - MaxHandSize: Hand capacity displayed in HUD
   - TimeAttack: Timer appears in HUD, counts down
4. Verify lifecycle hooks fire correctly (use print statements)
5. Test custom win conditions with MaxScoreInNRounds

### Debug Quality
AutoWinQuality is included for testing round transitions without playing:
- Bypasses target score check in GameManager.commit_play()
- Immediately completes rounds successfully
- Useful for testing shop transitions and multi-round flow
