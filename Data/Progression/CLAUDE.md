# Data/Progression Directory

Progression configuration system that defines difficulty scaling rules and per-round parameters.

---

## Overview

The Progression subsystem defines how game difficulty evolves across rounds. It provides:
- Round-by-round configuration generation (board size, target score, plays)
- Difficulty modeling and scaling
- Win condition parameters

---

## Core Classes

### ProgressionConfig (Resource)

Container for progression formula and parameters.

```gdscript
class_name ProgressionConfig extends Resource

@export var base_target_score: int = 100
@export var target_score_growth: float = 1.5  # Multiplier per round
@export var min_board_size: int = 4
@export var max_board_size: int = 10
@export var board_size_growth: float = 0.2

@export var default_hand_size: int = 10
@export var default_plays_per_round: int = 2
```

### ProgressionRules

Service class that generates `RoundConfig` from progression formulas.

```gdscript
class_name ProgressionRules

func get_round_config(round_num: int) -> RoundConfig:
    # Calculate board size based on round
    var board_size = calculate_board_size(round_num)
    
    # Calculate target score based on round
    var target_score = calculate_target_score(round_num)
    
    # Wrap in RoundConfig
    return RoundConfig.new(
        round_num,
        board_size, board_size,
        target_score,
        config.default_plays_per_round,
        config.default_hand_size
    )

func calculate_target_score(round_num: int) -> int:
    return int(config.base_target_score * pow(config.target_score_growth, round_num - 1))

func calculate_board_size(round_num: int) -> int:
    var base_size = config.min_board_size
    var growth = int(round_num * config.board_size_growth)
    return mini(base_size + growth, config.max_board_size)
```

---

## Files

| File | Purpose |
|------|---------|
| `progression_config.gd` | ProgressionConfig resource class definition |
| `progression_default.tres` | Default progression configuration (loaded by RunManager) |

---

## Usage

### Loading Progression Config

```gdscript
# In RunManager or RunBuilder
var progression = load("res://Data/Progression/progression_default.tres") as ProgressionConfig

# Create ProgressionRules instance
var rules = ProgressionRules.new(progression)

# Get config for round 3
var round_config = rules.get_round_config(3)
print(round_config)  # "Round 3: 6x6 board, target=225, plays=2"
```

### Custom Progression

To create custom progression:

1. Duplicate `progression_default.tres`
2. Adjust @export parameters:
   - `base_target_score` - Starting score goal
   - `target_score_growth` - Score multiplier per round
   - `board_size_growth` - Board expansion rate
   - `default_hand_size` - Starting hand capacity
   - `default_plays_per_round` - Starting plays per round

3. Use in RunBuilder:
   ```gdscript
   var builder = RunBuilder.new()
   builder.set_progression(custom_progression)
   var run = builder.build()
   ```

---

## Typical Progression Curves

### Easy (Slow Growth)
- Base target: 50
- Growth multiplier: 1.2
- Board growth: 0.1

**Progression:**
- Round 1: 6x6, target=50
- Round 2: 6x6, target=60
- Round 3: 7x7, target=72

### Medium (Standard Growth)
- Base target: 100
- Growth multiplier: 1.5
- Board growth: 0.2

**Progression:**
- Round 1: 4x4, target=100
- Round 2: 5x5, target=150
- Round 3: 6x6, target=225

### Hard (Fast Growth)
- Base target: 200
- Growth multiplier: 2.0
- Board growth: 0.3

**Progression:**
- Round 1: 5x5, target=200
- Round 2: 6x6, target=400
- Round 3: 7x7, target=800

---

## Integration with RunManager

```
RunManager.initialize_run_from_builder(run)
    ├─ Creates RunState
    ├─ Creates ProgressionRules from run.progression_config
    └─ Ready to generate round configs

RunManager.start_run()
    └─ _advance_to_next_round()
        ├─ ProgressionRules.get_round_config(round_num)
        ├─ Stores in current_round_config
        └─ Emits EventBus.run_round_ready(config)

Main._on_round_ready(config: RoundConfig)
    ├─ Board.resize(config.board_rows, config.board_columns)
    ├─ GameManager.setup_round(config)
    └─ HandManager.set_hand_size(config.hand_size)
    └─ GameManager.setup_round(config)
    └─ HandManager.refill_hand()
```

---

## Future Enhancements

- **Adaptive difficulty** - Adjust progression based on player performance
- **Run modifiers** - Qualities that modify progression (harder/easier)
- **Preset progressions** - Save/load different progression curves
- **Milestone rewards** - Achievements at progression milestones
