# Research: Score Progression and Scoring System Overhaul

## Scoring Formula (confirmed from codebase)

**Decision**: Scoring pipeline is already correct and does not need redesign.

**How it works**:
```
tile_score = (letter_value * modifier_factor) * letter_cell_multiplier * boss_cell_multiplier
word_score = sum(tile_scores) * word_cell_multiplier
play_score = sum(word_scores)
```

Letter values (Scrabble standard, `scripts/logic/word_validator.gd:16-21`):
- Common letters (A/E/I/O/U/N/S/T/L/R): 1 pt
- Mid letters (D/G=2, B/C/M/P=3, F/H/V/W/Y=4, K=5)
- Rare (J/X=8, Q/Z=10)

**Typical unaided play** (4-5 letter common word, one multiplier cell):
- CAST = C(3)+A(1)+S(1)+T(1) = 6 base, x2 word cell = 12 pts
- STONE = S(1)+T(1)+O(1)+N(1)+E(1) = 5 base, x2 word cell = 10 pts
- MUSIC = M(3)+U(1)+S(1)+I(1)+C(3) = 9 base, x2 word cell = 18 pts

Realistic range per play: **8-25 pts** (unassisted), up to **60-100 pts** with special tiles/cells.

With `default_plays_per_round = 2`:
- Conservative round total: ~16-30 pts
- Good round total: ~40-80 pts

---

## Cumulative Scoring Model

**Decision**: GameManager tracks per-round score; cumulative score is computed via `_current_score + _previous_rounds_total`.

**Rationale**: Minimum change to existing architecture. RunState already accumulates `total_score` correctly. The cleanest approach is to pass the previous total into GameManager at round start so it can expose a `get_cumulative_score()` getter and emit cumulative values on `score_updated`.

**How it fits**:
- `GameManager.setup_round(config)` is extended to accept `previous_total: int`
- Stored as `_previous_rounds_total`
- `get_cumulative_score()` = `_current_score + _previous_rounds_total`
- `score_updated` signal emits cumulative value (not per-round)
- Win condition: `get_cumulative_score() >= _target_score`
- `run_state.complete_round(GameManager.get_current_score())` still receives per-round score -- no change needed there

**Failure case fix**: When run ends in failure, `run_state.total_score` only contains completed rounds. Current round's score must be included in the final score emitted to the game over screen. Fix: emit `run_state.total_score + GameManager.get_current_score()` on failure.

---

## Target Score Calibration

**Decision**: Replace 1,000,000 base with `base_target_score = 25`, `target_score_increment = 15` and switch from linear to quadratic cumulative formula.

**Formula** (replaces linear in `progression_rules.gd`):
```gdscript
# Quadratic: each round requires more than the previous
func _calculate_target_score(round_number: int) -> int:
    # Cumulative target = sum of per-round requirements R1..RN
    # Per-round requirement for round N = base + (N-1) * increment
    # Cumulative = base*N + increment * N*(N-1)/2
    return _config.base_target_score * round_number + \
           _config.target_score_increment * round_number * (round_number - 1) / 2
```

With `base=25, increment=15`:
- R1: 25 cumulative (need 25 this round)
- R2: 65 cumulative (need 40 this round)
- R3: 120 cumulative (need 55 this round)
- R4: 190 cumulative (need 70 this round)
- R5: 275 cumulative (need 85 this round)
- R6: 375 cumulative (need 100 this round)

Per-round requirement grows by `increment=15` each round. Rounds 1 and 2 remain easy.
First boss at R3 requires 55 pts in 2 plays (~27.5/play) - challenging but doable.

**Rationale**: Linear formula with constant increment means per-round difficulty never grows. Quadratic formula makes later rounds progressively harder without an exponential spike.

---

## Boss Target Modifier with Cumulative Model

**Problem**: Applying boss multiplier to cumulative target is disproportionate. A ×2 multiplier at R3 turns target from 120 to 240, requiring 175 more pts in one round -- impossible with 2 plays.

**Decision**: Boss multiplier applies only to the per-round delta (not the cumulative total).

**Implementation** in `ProgressionRules._apply_boss_target_modifiers`:
```gdscript
func _apply_boss_target_modifiers(boss: Boss, base_target: int, round_num: int) -> int:
    var override: int = boss.hooks.get_target_score_override()
    if override > 0:
        return override
    var multiplier: float = boss.hooks.get_target_score_multiplier()
    if multiplier == 1.0:
        return base_target
    # Apply multiplier only to the per-round portion
    var prev_cumulative: int = _calculate_target_score(round_num - 1) if round_num > 1 else 0
    var per_round_delta: int = base_target - prev_cumulative
    return prev_cumulative + int(per_round_delta * multiplier)
```

With HardBoss ×2 at R3: `65 + int(55 * 2) = 65 + 110 = 175 cumulative` (need 110 pts this round, ~55/play). Hard but possible with good tiles/multipliers.

---

## Hard Boss

**Decision**: `HardBossHooks` is a new class in `scripts/domain/bosses/hard_boss.gd`, registered 5th in `BossRegistry`.

**Mechanics**: Overrides `get_target_score_multiplier()` to return `2.0`. No other hooks needed.

**Background**: Metallic gray = `Color(0.6, 0.6, 0.65)` (neutral steel gray).

**Position in rotation**: 5th boss. With 4 existing bosses, HardBoss is encountered at round 15 (5th boss round = round 15). To encounter it earlier in playtesting, register it 2nd or 3rd in the pool. Final position is a tuning detail -- register it 5th for now.

---

## Score Panel UI

**Decision**: New `ScorePanel` scene (`scenes/ui/score_panel/`) as a `CanvasLayer` sibling to `MainHUD`.

**Layout**: Horizontal labels -- `[Y pts / X target]`. Y is current cumulative score, X is round target.

**Animations**:
- **Countup**: On `score_updated`, tween Y label text from old value to new over 0.7s using `_displayed_score` interpolation with `create_tween()`.
- **Pulse**: Scale panel from 1.0 to 1.15 and back over 0.25s alongside countup.
- **Particles**: `CPUParticles2D` node on the panel, reusing the same pattern as `StompAnimationExecutor`. Intensity controlled by 4 threshold levels (0%, 5%, 15%, 30% above target).

**Particle approach**: One `CPUParticles2D` child node. On target beaten, adjust `amount` and `initial_velocity` based on ratio and call `restart()`. Simpler than spawning multiple emitters.

**No Constitution violations**: ScorePanel is a UI element (scenes layer). No modal, no domain logic.

---

## HUD Cleanup

**Decision**: Remove `ScoreLabel` and `TargetLabel` nodes from `main_hud.tscn`. Remove `score_label`, `target_label` onready vars and their update methods from `main_hud.gd`. Remove `_initialize_display` calls for those two. Remove `_on_score_updated` and `_on_run_round_ready` partial updates for score/target.

**EventBus connection `score_updated`**: MainHUD currently connects `score_updated` only to update `ScoreLabel`. After removal, `score_updated` connection in MainHUD is dropped entirely (ScorePanel will own it).

---

## Game Over / Victory Score

**Decision**: Pass `run_state.total_score + GameManager.get_current_score()` when emitting `run_ended` on failure.

**Current bug**: `RunManager._on_round_ended()` calls `run_state.end_run()` then `EventBus.run_ended.emit(false, run_state.total_score)`. The current round's score was never added to `run_state.total_score` for a failed round, so the game over screen shows an artificially low score.

**Fix** in `RunManager._on_round_ended()`:
```gdscript
if not success:
    run_state.end_run()
    var final_score: int = run_state.total_score + GameManager.get_current_score()
    EventBus.run_ended.emit(false, final_score)
```

---

## Score Countup Animation

**Decision**: Tween the displayed value after `score_updated` fires (after stomp animation ends). No per-tile synchronization needed.

**Flow**: stomp animation -> `play_completed` -> `_on_play_completed` in main.gd -> `commit_play` -> `score_updated` -> ScorePanel countup.

The countup animates over ~0.7s using a tween on a `_displayed_score: float` variable, updating the label each frame via `_process`. This gives the "score ticking up" feel immediately after stomps complete.

---

## Alternatives Considered

- **Per-tile score sync during stomp**: Would require pre-calculating per-tile scores in PlayExecutor and emitting events during StompAnimationExecutor. Significant refactor with limited additional payoff vs. post-stomp countup. Deferred.
- **HardBoss in early rotation (2nd slot)**: Would mean players encounter it at round 6. Chosen to keep it at 5th slot (round 15) for now; easy to change by reordering registration.
- **Particle per-play spawn vs. persistent node**: Persistent `CPUParticles2D` with `restart()` is simpler than spawning/queuing particles each play.
- **Quadratic target via config resource**: Could add a `target_score_exponent` field to `ProgressionConfig`. Chose to hard-code the quadratic formula in `ProgressionRules._calculate_target_score` using existing `base` and `increment` fields with new semantics -- simpler, fewer moving parts.
