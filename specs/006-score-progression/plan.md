# Implementation Plan: Score Progression and Scoring System Overhaul

**Branch**: `006-score-progression` | **Date**: 2026-04-11 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/006-score-progression/spec.md`

## Summary

Replace the unplayable 1,000,000-point target with a calibrated quadratic cumulative scoring model. Scores persist across rounds (growing total displayed to the player), while win conditions check whether the cumulative total reaches this round's threshold. A new ScorePanel UI at the top left shows the live target/score ratio with pulse animation and particle celebration. The top-right HUD loses its Score/Target labels. A new Hard Boss doubles the per-round scoring requirement. The game over screen already displays the final score but currently excludes the current (failed) round -- that bug is fixed here.

## Technical Context

**Language/Version**: GDScript 2.0 (Godot 4.6)
**Primary Dependencies**: Godot 4.6 engine only
**Storage**: N/A (no persistent storage; run data is in-memory)
**Testing**: Manual, in Godot editor (per constitution)
**Target Platform**: Desktop (Windows/Mac/Linux via Godot export)
**Project Type**: Desktop game
**Performance Goals**: 60 fps; animations complete in under 1s
**Constraints**: No Godot engine classes in `/scripts/domain`; no modal overlays
**Scale/Scope**: ~12 files modified, 3 files created

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Domain-Driven Design | PASS | HardBossHooks is pure GDScript in `/scripts/domain`. Score formula changes are in ProgressionRules (domain). |
| II. Decoupled via EventBus | PASS | ScorePanel listens to `score_updated` and `run_round_ready`. No direct reference to GameManager from ScorePanel. |
| III. Immutable Domain Objects | PASS | No domain value objects are mutated. GameManager state fields are mutable by design (autoload singleton, not domain VO). |
| IV. Thin Controllers | PASS | GameManager extended with one new field and one getter. Score animation logic lives in ScorePanel (UI layer). |
| V. Manual Testing First | PASS | All verification is done manually in the Godot editor per convention. |
| No Godot in Domain | PASS | `hard_boss.gd` extends `BossHooks` (RefCounted, no engine nodes). |
| No Modals | PASS | ScorePanel is a persistent CanvasLayer, not a modal overlay. |

## Project Structure

### Documentation (this feature)

```text
specs/006-score-progression/
├── plan.md              # This file
├── research.md          # Phase 0: scoring analysis, design decisions
├── data-model.md        # Phase 1: entity changes and state transitions
└── checklists/
    └── requirements.md
```

### Source Code (affected files)

```text
# New files
scripts/domain/bosses/hard_boss.gd
scenes/ui/score_panel/score_panel.gd
scenes/ui/score_panel/score_panel.tscn

# Modified files
data/progression/progression_config.gd      # target values
data/progression/progression_default.tres   # exported resource values
scripts/domain/progression_rules.gd         # formula + boss modifier fix
scripts/domain/bosses/boss_registry.gd      # register HardBoss
autoload/game_manager.gd                    # cumulative score support
autoload/run_manager.gd                     # pass previous_total + failure score fix
scenes/ui/main_hud/main_hud.gd              # remove score/target labels
scenes/ui/main_hud/main_hud.tscn            # remove ScoreLabel + TargetLabel nodes
scenes/ui/game_over_popup/game_over_popup.gd # no change needed (already correct)
scenes/main.gd                              # add ScorePanel, use cumulative in shop display
scenes/main.tscn                            # add ScorePanel child node
```

## Implementation Steps

### Step 1: Calibrate Target Score Formula

**File**: `data/progression/progression_config.gd`

Change defaults:
```gdscript
@export var base_target_score: int = 25    # was 1000000
@export var target_score_increment: int = 15  # was 50 (new: quadratic growth rate)
```

**File**: `data/progression/progression_default.tres`

Update the exported resource to match the new defaults. Open in editor or edit the text resource to set `base_target_score = 25` and `target_score_increment = 15`.

**File**: `scripts/domain/progression_rules.gd`

Replace `_calculate_target_score`:
```gdscript
func _calculate_target_score(round_number: int) -> int:
    # Cumulative target (quadratic growth)
    # Per-round requirement for round N = base + (N-1) * increment
    # Cumulative = base*N + increment * N*(N-1)/2
    return _config.base_target_score * round_number + \
           _config.target_score_increment * round_number * (round_number - 1) / 2
```

This yields: R1=25, R2=65, R3=120, R4=190, R5=275, R6=375.

Also update `_apply_boss_target_modifiers` to accept `round_num` and apply multiplier only to the per-round delta:
```gdscript
func _apply_boss_target_modifiers(boss: Boss, base_target: int, round_num: int) -> int:
    var override: int = boss.hooks.get_target_score_override()
    if override > 0:
        return override
    var multiplier: float = boss.hooks.get_target_score_multiplier()
    if multiplier == 1.0:
        return base_target
    var prev_cumulative: int = _calculate_target_score(round_num - 1) if round_num > 1 else 0
    var per_round_delta: int = base_target - prev_cumulative
    return prev_cumulative + int(per_round_delta * multiplier)
```

Update both call sites (`get_round_config` and `peek_round_config`) to pass `round_num`:
```gdscript
target = _apply_boss_target_modifiers(boss, target, round_num)
```

**Logs to add**:
```gdscript
print("[ProgressionRules] Round %d target: %d (cumulative)" % [round_num, target])
print("[ProgressionRules] Boss '%s' modifier: per-round delta %d x%.2f | final target: %d" % [boss.display_name, per_round_delta, multiplier, target])
```

Note: FR-026 (Hard Boss activation log) fires here in `get_round_config()` at config calculation time, not at the moment the round scene loads. This is correct -- the config is prepared before the round begins and the log captures the intended doubled target value accurately.

**Test**: Start a run, confirm round 1 target is 25. Complete round 1, confirm round 2 target is 65. Check logs for correct values.

---

### Step 2: Cumulative Score in GameManager

**File**: `autoload/game_manager.gd`

Add field:
```gdscript
var _previous_rounds_total: int = 0
```

Add getter:
```gdscript
func get_cumulative_score() -> int:
    return _current_score + _previous_rounds_total
```

Update `setup_round(config)` to accept and store the previous total:
```gdscript
func setup_round(config: RoundConfig, previous_total: int = 0) -> void:
    _previous_rounds_total = previous_total
    _current_round = config.round_number
    _target_score = config.target_score
    _plays_per_round = config.plays_per_round
    _plays_remaining = config.plays_per_round
    _current_score = 0
    # ... rest unchanged
```

Update `commit_play` to emit cumulative score and check cumulative win condition:
```gdscript
func commit_play(score: int) -> void:
    if _current_phase != GamePhase.PLAYING:
        return

    _current_score += score
    _plays_remaining -= 1

    var cumulative: int = get_cumulative_score()
    EventBus.score_updated.emit(cumulative, score)
    EventBus.play_completed.emit(_plays_remaining)

    print("[GameManager] Play committed: +%d pts | Round: %d | Cumulative: %d | Target: %d | Plays left: %d" % [
        score, _current_round, cumulative, _target_score, _plays_remaining
    ])

    if cumulative >= _target_score:
        print("[GameManager] Target reached! Cumulative %d >= %d (excess: %d)" % [
            cumulative, _target_score, cumulative - _target_score
        ])
        _complete_round(true)
    elif _plays_remaining <= 0:
        # ... unchanged
```

Update `end_game` log to show cumulative:
```gdscript
print("[GameManager] Victory! Cumulative score: %d" % get_cumulative_score())
print("[GameManager] Game Over. Cumulative score: %d" % get_cumulative_score())
```

Also update `start_round` (the simpler overload) to accept `previous_total`:
```gdscript
func start_round(round_num: int, target: int = DEFAULT_TARGET_SCORE, plays: int = DEFAULT_PLAYS_PER_ROUND, previous_total: int = 0) -> void:
    _previous_rounds_total = previous_total
    # ... rest unchanged
```

**Test**: Score some points in round 1. Advance to round 2. Verify the score display (log) shows round 1 total as starting point.

---

### Step 3: Pass Previous Total from RunManager

**File**: `autoload/run_manager.gd`

In `_advance_to_next_round()`, after `EventBus.run_round_ready.emit(current_round_config)`, update the GameManager call. The `start_run()` -> `_advance_to_next_round()` path currently sets up via the `run_round_ready` event which triggers `GameplayController` -> `Main._on_round_ready` -> `GameManager.setup_round(config)`.

Trace the setup call: in `scenes/main.gd`, `_on_round_ready(config)` calls `GameManager.setup_round(config)`. Update that call:

**File**: `scenes/main.gd`

Find `GameManager.setup_round(config)` call in `_on_round_ready`:
```gdscript
func _on_round_ready(config: RoundConfig) -> void:
    # ... existing setup ...
    var previous_total: int = 0
    if RunManager.run_state:
        previous_total = RunManager.run_state.total_score
    GameManager.setup_round(config, previous_total)
    # ... rest unchanged
```

**Fix failure score in RunManager**:
```gdscript
if not success:
    var final_score: int = run_state.total_score + GameManager.get_current_score()
    run_state.end_run()
    EventBus.run_ended.emit(false, final_score)
    print("[RunManager] Round %d lost - run ended | Final cumulative score: %d" % [round_number, final_score])
    return
```

**Fix shop display** (also in `scenes/main.gd`):
```gdscript
shop_overlay.show_shop(round_number, GameManager.get_cumulative_score(), next_config)
```

**Test**: Lose a round. Verify the game over screen shows the full total (including points scored in the lost round). Advance to shop and verify correct score is shown.

---

### Step 4: Create Hard Boss

**File**: `scripts/domain/bosses/hard_boss.gd` (new)

```gdscript
## HardBossHooks: Doubles the per-round score requirement.
## Target score multiplier of 2.0 is applied to the per-round delta only
## (see ProgressionRules._apply_boss_target_modifiers).
##
## Pure logic -- no Godot node references.
class_name HardBossHooks
extends BossHooks


func get_target_score_multiplier() -> float:
    return 2.0
```

**File**: `scripts/domain/bosses/boss_registry.gd`

Add after the Diagonal boss registration:
```gdscript
# Register Hard boss
var hard_boss = Boss.new(
    &"hard",
    "Hard",
    Color(0.6, 0.6, 0.65),
    HardBossHooks.new()
)
_bosses.append(hard_boss)
print("[BossRegistry] Registered boss: %s | Total bosses: %d" % [hard_boss.display_name, _bosses.size()])
```

**Test**: Advance to round 15 (or test with debug override to force a boss round). Verify the background turns metallic gray. Verify the target shown in ScorePanel is higher than it would be for a normal round. Verify the next round (16) uses the normal target formula.

---

### Step 5: Create ScorePanel Scene and Script

**File**: `scenes/ui/score_panel/score_panel.gd` (new)

```gdscript
extends CanvasLayer

## ScorePanel: Displays cumulative score (Y) vs round target (X) at top left.
## Pulses on score update. Plays particles when Y exceeds X.

@onready var _score_label: Label = $HBoxContainer/ScoreLabel
@onready var _particles: CPUParticles2D = $HBoxContainer/Particles

var _target: int = 0
var _cumulative: int = 0
var _pulse_tween: Tween = null


func _ready() -> void:
    EventBus.run_round_ready.connect(_on_round_ready)
    EventBus.score_updated.connect(_on_score_updated)
    _setup_particles()
    _update_label()
    print("[ScorePanel] Ready")


func _on_round_ready(config: RoundConfig) -> void:
    _target = config.target_score
    _update_label()
    print("[ScorePanel] Round ready | Target: %d | Cumulative: %d" % [_target, _cumulative])


func _on_score_updated(total_score: int, delta: int) -> void:
    print("[ScorePanel] Score updated | Old: %d | New: %d | Delta: +%d | Target: %d" % [
        _cumulative, total_score, delta, _target
    ])
    _cumulative = total_score
    _displayed_score = float(_cumulative)
    _update_label()
    _play_pulse()
    if _cumulative > _target:
        _play_particles()


func _play_pulse() -> void:
    if _pulse_tween:
        _pulse_tween.kill()
    $HBoxContainer.scale = Vector2.ONE
    _pulse_tween = create_tween()
    _pulse_tween.tween_property($HBoxContainer, "scale", Vector2(1.15, 1.15), 0.1) \
        .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    _pulse_tween.tween_property($HBoxContainer, "scale", Vector2.ONE, 0.15) \
        .set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func _play_particles() -> void:
    if _target <= 0:
        return
    var ratio: float = float(_cumulative - _target) / float(_target)
    var particle_amount: int = 0
    var velocity_min: float = 0.0
    var velocity_max: float = 0.0
    if ratio >= 0.30:
        particle_amount = 40
        velocity_min = 90.0
        velocity_max = 130.0
    elif ratio >= 0.15:
        particle_amount = 20
        velocity_min = 60.0
        velocity_max = 90.0
    elif ratio >= 0.05:
        particle_amount = 8
        velocity_min = 30.0
        velocity_max = 60.0
    else:
        return  # below 5% threshold, no particles

    print("[ScorePanel] Particles | Ratio: %.2f | Amount: %d" % [ratio, particle_amount])
    _particles.amount = particle_amount
    _particles.initial_velocity_min = velocity_min
    _particles.initial_velocity_max = velocity_max
    _particles.show()    # restart() requires the node to be visible
    _particles.restart()


func _setup_particles() -> void:
    _particles.emitting = false
    _particles.one_shot = true
    _particles.explosiveness = 0.8
    _particles.lifetime = 0.8
    _particles.direction = Vector2(0, -1)
    _particles.spread = 60.0
    _particles.gravity = Vector2(0, 200)
    _particles.scale_amount_min = 1.5
    _particles.scale_amount_max = 3.0
    var gradient := Gradient.new()
    gradient.add_point(0.0, Color(1.0, 0.9, 0.2, 1.0))   # gold
    gradient.add_point(0.5, Color(1.0, 0.6, 0.1, 1.0))   # orange
    gradient.add_point(1.0, Color(1.0, 0.3, 0.0, 0.0))   # fade out
    _particles.color_ramp = gradient


func _update_label() -> void:
    _score_label.text = "%d / %d" % [int(_displayed_score), _target]  # score / target (e.g., "87 / 120")
```

**File**: `scenes/ui/score_panel/score_panel.tscn` (new)

Create via Godot editor:
```
ScorePanel [CanvasLayer] (layer=1)
└── HBoxContainer [HBoxContainer]
    ├── ScoreLabel [Label]
    └── Particles [CPUParticles2D]
```

Position `HBoxContainer` at top-left (anchor TOP_LEFT, offset ~10,10).
`ScoreLabel` theme: bold font, size 22, white color.

---

### Step 6: Add ScorePanel to Main Scene

**File**: `scenes/main.tscn`

Add `ScorePanel` as an instantiated child (via `res://scenes/ui/score_panel/score_panel.tscn`). Layer value 1 so it renders above game elements.

**File**: `scenes/main.gd`

Add onready reference:
```gdscript
@onready var _score_panel: CanvasLayer = $ScorePanel
```

No additional wiring needed -- ScorePanel connects to EventBus in its own `_ready()`.

---

### Step 7: Remove Score/Target from MainHUD

**File**: `scenes/ui/main_hud/main_hud.tscn`

Delete nodes: `ScoreLabel` and `TargetLabel`.

**File**: `scenes/ui/main_hud/main_hud.gd`

Remove:
- `@onready var score_label: Label = $ScoreLabel`
- `@onready var target_label: Label = $TargetLabel`
- `_update_score()` method
- `_update_target()` method
- `_on_score_updated()` signal handler
- The `EventBus.score_updated.connect(_on_score_updated)` connection
- Calls to `_update_score()` and `_update_target()` in `_initialize_display()`, `_on_round_started()`, `_on_run_round_ready()`

**Test**: Open a round and verify the top-right panel shows Round, Plays, Deck, Hand, Discard, Timer -- but no Score or Target rows.

---

### Step 8: Verify Game Over Score

**File**: `scenes/ui/game_over_popup/game_over_popup.gd`

No changes needed here. The popup already calls `show_game_over(total_score)` and `show_victory(total_score)`. The fix is upstream in RunManager (Step 3) which now emits the correct cumulative total including the failed round.

**File**: `scenes/main.gd` -- `_on_run_ended(victory, total_score)` (verify wiring)

Confirm that `_on_run_ended` in main.gd passes `total_score` to the game over popup. If it already does, no change needed. The corrected emission from RunManager flows through automatically.

**Test**: Play round 1 scoring some points, then run out of plays. Verify the game over screen shows the correct total.

---

## Complexity Tracking

No constitution violations. No Complexity Tracking entries needed.

## Risk Notes

- `progression_default.tres` is a Godot resource file (`.tres`). Changing the exported defaults in the `.gd` file alone is not enough -- the `.tres` override must also be updated. Verify in the inspector after making changes to `.gd`.
- `GameManager.start_round()` (the simpler overload, separate from `setup_round()`) also sets `_current_score = 0` and must receive `previous_total` if ever called. Add the parameter with default=0 to be safe, even if it's not the primary call path in a full run.
- Stagger-matched scoring requires moving score calculation BEFORE the stomp animation in `PlayExecutor._execute_play()`. Currently scoring happens in `main.gd._on_play_completed()` AFTER animation. This order must be reversed: calculate score, then start stomp animation, emitting per-tile deltas during the tween callbacks.
- `GameManager.commit_play()` will be called N times (once per tile) instead of once per play. The win/lose condition check inside `commit_play()` fires after each tile -- this is correct behavior (round can end mid-stomp if target is hit on the 3rd of 5 tiles).
- The `play_completed` signal (used by RunManager quality callbacks and hand refill) must still fire ONCE after all tiles have emitted their score. Ensure `PlayExecutor` emits `play_completed` only after the final tile's stomp callback.
- `CPUParticles2D.restart()` requires the node to be visible. Ensure the particles node is not hidden when `_play_particles()` is called.

## Manual Test Checklist

After implementation, verify each item in Godot editor (F5):

- [ ] Round 1 target is 25, round 2 target is 65, round 3 target is 120
- [ ] Scoring points in round 1 and advancing to round 2 shows the round 2 score starting from round 1 total
- [ ] Winning round 1 and seeing round 2 target (65) is reachable in practice
- [ ] Score panel visible at top left on entering gameplay
- [ ] Score panel shows "Y / X" format correctly
- [ ] Score panel Y pulses and counts up after each play
- [ ] Score panel plays particles when Y > X (test at exactly 6% above target for small burst)
- [ ] Score panel plays intense particles when Y is 35%+ above target
- [ ] Hard boss round has metallic gray background
- [ ] Hard boss round target is higher than a normal round at same position
- [ ] After Hard boss round, next round uses normal formula (not doubled)
- [ ] Top-right HUD does NOT show Score or Target labels
- [ ] Top-right HUD still shows Round, Plays, Deck, Hand, Discard correctly
- [ ] Game over screen shows full cumulative score including the failed round's points
- [ ] Victory screen shows full cumulative score
- [ ] Logs emit for: each play committed (with cumulative), target beaten, Hard Boss activation
