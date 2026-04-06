# Data Model: Boss Rounds and Round Counter

**Branch**: `004-boss-rounds` | **Date**: 2026-04-06

## Entities

### RoundConfig (modified)

**File**: `scripts/domain/round_config.gd`
**Role**: Immutable value object describing all parameters for a single Round. Created by `ProgressionRules`, consumed by `GameManager`, `Main`, `MainHUD`, and any subscriber of `EventBus.run_round_ready`.

**Current fields**:
```
round_number:    int   -- 1-based round index within the run
board_rows:      int   -- board height in cells
board_columns:   int   -- board width in cells
target_score:    int   -- score the player must reach to win the round
plays_per_round: int   -- number of Plays allowed in this round
hand_size:       int   -- number of tiles in hand
```

**New field**:
```
is_boss_round:   bool  -- true if this is a Boss Round (round_number % 3 == 0)
                          false for Normal Rounds
```

**Constructor change**: Add `p_is_boss: bool = false` as the last parameter. Default false ensures backward compatibility with any direct `RoundConfig.new()` call (e.g., in debug overrides).

**Immutability**: `is_boss_round` is assigned once in `_init()` and never modified afterward. Callers must not mutate it. (`RoundConfig` fields are technically mutable in GDScript; the immutability contract is enforced by convention, matching the existing pattern for all other fields.)

---

### ProgressionRules (modified)

**File**: `scripts/domain/progression_rules.gd`
**Role**: Stateless domain service that computes `RoundConfig` from `RunState`. No Godot engine dependencies.

**New private method**:
```
_is_boss_round(round_number: int) -> bool
    return round_number % 3 == 0
```

**Modified method** `get_round_config(run_state: RunState) -> RoundConfig`:
```
-- existing: computes round_num, board_size, target, plays, hand
-- new: computes is_boss = _is_boss_round(round_num)
-- passes is_boss as final argument to RoundConfig.new(...)
```

**Boss cycle constant**: The divisor (3) is embedded directly in `_is_boss_round`. If it becomes configurable, extract to `ProgressionConfig` resource at that time.

---

## State Flows

### Round Startup (Normal Round)

```
RunManager._advance_to_next_round()
  -> ProgressionRules.get_round_config(run_state)
       -> _is_boss_round(round_num)  -- returns false
       -> RoundConfig.new(..., is_boss_round = false)
  -> EventBus.run_round_ready.emit(config)
       -> Main._on_round_ready(config)
            -> _background.color = Color.WHITE   -- normal bg
            -> GameManager.setup_round(config)
                 -> EventBus.round_started.emit(round_number)
       -> MainHUD._on_run_round_ready(config)
            -> _current_is_boss = false
            -> round_label.text = "Round 1"
```

### Round Startup (Boss Round, e.g. Round 3)

```
RunManager._advance_to_next_round()
  -> ProgressionRules.get_round_config(run_state)
       -> _is_boss_round(3)  -- returns true
       -> RoundConfig.new(..., is_boss_round = true)
  -> EventBus.run_round_ready.emit(config)
       -> Main._on_round_ready(config)
            -> _background.color = Color(1.0, 0.85, 0.85)  -- boss bg
            -> GameManager.setup_round(config)
                 -> EventBus.round_started.emit(3)
       -> MainHUD._on_run_round_ready(config)
            -> _current_is_boss = true
            -> round_label.text = "Boss Round"
```

### New Game Start (background reset)

```
Main._start_run()
  -> RunManager.start_run()
       -> _advance_to_next_round() for Round 1
            -> is_boss_round = false (1 % 3 != 0)
            -> EventBus.run_round_ready.emit(config)
                 -> Main._on_round_ready: bg = white
                 -> MainHUD: label = "Round 1"
```

---

## Visual State Table

| Round | is_boss_round | Label text   | Background              |
|-------|---------------|--------------|-------------------------|
| 1     | false         | "Round 1"    | white (1.0, 1.0, 1.0)  |
| 2     | false         | "Round 2"    | white                   |
| 3     | true          | "Boss Round" | light red (1.0, 0.85, 0.85) |
| 4     | false         | "Round 4"    | white                   |
| 5     | false         | "Round 5"    | white                   |
| 6     | true          | "Boss Round" | light red               |
| ...   | ...           | ...          | ...                     |

---

## AutoWinQuality Text Changes

**File**: `scripts/domain/qualities/auto_win_quality.gd`

| Method           | Before                                                              | After                                                               |
|------------------|---------------------------------------------------------------------|---------------------------------------------------------------------|
| `get_description` | `"Exhaust your 10 plays to win each round. Run ends after 10 rounds."` | `"Exhaust your 10 Plays to win each Round. Run ends after 10 Rounds."` |

`get_quality_name()` already returns `"Auto Win (10 Plays)"` — no change needed.
