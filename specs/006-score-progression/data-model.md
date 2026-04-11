# Data Model: Score Progression and Scoring System Overhaul

## Modified Entities

### GameManager (modified)

**New field**: `_previous_rounds_total: int = 0`
- Stores the cumulative total from all completed rounds before this one
- Set at round start via `setup_round()` or `start_round()`
- Used to compute `get_cumulative_score()`

**New getter**: `get_cumulative_score() -> int`
- Returns `_current_score + _previous_rounds_total`
- Used for win condition, score display, and `score_updated` signal

**Modified behavior**:
- `setup_round(config)` now accepts a `previous_total: int = 0` parameter
- `score_updated` signal now emits cumulative score, not per-round score
- Win condition: `get_cumulative_score() >= _target_score`

---

### ProgressionConfig (modified)

```gdscript
@export var base_target_score: int = 25       # was 1000000
@export var target_score_increment: int = 15  # was 50 (semantics changed to quadratic formula)
```

The `target_score_increment` now feeds a quadratic formula instead of linear, so its semantic meaning changes from "add N per round" to "per-round growth rate."

---

### ProgressionRules (modified)

**`_calculate_target_score(round_number: int) -> int`** replaces linear formula:
```gdscript
return _config.base_target_score * round_number + \
       _config.target_score_increment * round_number * (round_number - 1) / 2
```
Returns the *cumulative* score threshold that must be reached by end of `round_number`.

**`_apply_boss_target_modifiers(boss, base_target, round_num)`** gains `round_num` parameter:
- Multiplier now applies only to the per-round delta, not the full cumulative amount
- Override behavior unchanged

---

### RunState (no structural changes)

Existing `_total_score` and `complete_round(round_score)` already accumulate correctly.
The only behavioral change is that `run_ended` on failure now includes the current round's score via `GameManager.get_current_score()` at the emit site (in `RunManager`).

---

### ScorePanel (new scene)

**File**: `scenes/ui/score_panel/score_panel.gd` + `.tscn`

**Node type**: `CanvasLayer`

**Scene tree**:
```
ScorePanel (CanvasLayer)
└── HBoxContainer
    ├── ScoreLabel (Label)         # "Y pts / X"
    └── Particles (CPUParticles2D) # celebration particles, hidden by default
```

**Fields**:
```gdscript
var _target: int = 0            # current round target (X)
var _cumulative: int = 0        # current cumulative score (Y) - the "true" value
var _displayed_score: float = 0 # animating toward _cumulative
var _countup_tween: Tween = null
var _pulse_tween: Tween = null
```

**Signals listened to** (via EventBus):
- `run_round_ready(config)` -> set `_target`, reset display
- `score_updated(total_score, delta)` -> start countup + pulse + particles if needed

**Particle intensity thresholds** (ratio = (Y - X) / X):
- ratio < 0.05: no particles
- 0.05 <= ratio < 0.15: `amount = 8`, `initial_velocity_min = 40`
- 0.15 <= ratio < 0.30: `amount = 20`, `initial_velocity_min = 70`
- ratio >= 0.30: `amount = 40`, `initial_velocity_min = 110`

---

### HardBossHooks (new domain class)

**File**: `scripts/domain/bosses/hard_boss.gd`

```gdscript
class_name HardBossHooks
extends BossHooks

func get_target_score_multiplier() -> float:
    return 2.0
```

No other hooks overridden. No Godot node dependencies (domain layer compliant).

**Boss registration** (`boss_registry.gd`):
```gdscript
var hard_boss = Boss.new(
    &"hard",
    "Hard",
    Color(0.6, 0.6, 0.65),  # metallic gray
    HardBossHooks.new()
)
```

---

### RunResult (logical, not a new class)

The "run result" is implicitly carried by the `run_ended(victory, total_score)` signal. No new class is needed for this feature. The `total_score` in this signal is now the full cumulative score including the final round.

For future leaderboard support, the signal already has the required fields: `victory: bool` and `total_score: int`. The `round_number` (how far the player reached) is available via `RunManager.run_state.current_round` at the time of `run_ended`. No structural changes needed.

---

## State Transitions

### Round Start
```
RunManager._advance_to_next_round()
  → run_state.total_score = accumulated previous rounds
  → GameManager.setup_round(config, run_state.total_score)
    → _previous_rounds_total = run_state.total_score
    → _current_score = 0
    → _target_score = config.target_score  (cumulative threshold)
```

### During Play
```
GameManager.commit_play(per_play_score)
  → _current_score += per_play_score
  → cumulative = _current_score + _previous_rounds_total
  → EventBus.score_updated.emit(cumulative, per_play_score)
  → if cumulative >= _target_score: _complete_round(true)
```

### Round End (success)
```
RunManager._on_round_ended(round, success=true)
  → run_state.complete_round(GameManager.get_current_score())  # per-round score
  → run_state.total_score += per_round_score
  → shop transition
```

### Round End (failure)
```
RunManager._on_round_ended(round, success=false)
  → run_state.end_run()
  → final = run_state.total_score + GameManager.get_current_score()  # include current round
  → EventBus.run_ended.emit(false, final)
```
