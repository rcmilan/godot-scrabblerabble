# Research: Play Hype Sequence

## Decision 1: HurryBoss Timer Pause/Resume

**Decision**: Add `pause()` / `resume()` methods to `BossTimerRelay`.

**Rationale**: `BossTimerRelay` (`scripts/controllers/boss_timer_relay.gd`) drives the countdown via `on_process(delta)` called by `RunManager._process()`. It currently has `start()`, `stop()`, and `is_active()` but no pause primitive. Adding `_paused: bool` with a guard in `on_process` is the minimal, non-breaking change. `PlayExecutor` calls `relay.pause()` at sequence start and `relay.resume()` at sequence end. `RunManager` already holds a reference to the relay, so `PlayExecutor` needs it injected or accessed via a new EventBus signal pair (`sequence_started` / `sequence_ended`).

**Preferred approach**: Emit `EventBus.play_sequence_started` and `EventBus.play_sequence_ended` signals; `RunManager` subscribes and calls `pause()`/`resume()` on the relay. This avoids injecting the relay into `PlayExecutor` and keeps the pattern consistent with how other cross-system communication works.

**Alternatives considered**:
- Directly inject `BossTimerRelay` into `PlayExecutor` -- rejected: violates thin-controller principle (relay is RunManager's concern).
- Use `GameManager.is_playing()` gate already present in RunManager -- rejected: too coarse; it pauses the whole game phase, not just the timer.

---

## Decision 2: Player Interaction Lock During Sequence

**Decision**: Add `is_sequence_active() -> bool` to `PlayExecutor`; guard all interaction entry points in `GameplayController` and `DiscardHandler`.

**Rationale**: The existing `TileAnimator.is_animating()` guard in `GameplayController._on_play_requested()` (line 735) blocks double-play but does NOT block tile placement, drag-and-drop, or discard during an active sequence. A dedicated boolean flag on `PlayExecutor` set to `true` at the start of `_execute_play` and `false` on completion is the simplest correct guard. `GameplayController` already receives `PlayExecutor` via dependency injection, so reading `is_sequence_active()` requires no new wiring.

**Specific entry points to guard**:
- `GameplayController._on_tile_drag_started` (block dragging from board during sequence)
- `GameplayController._on_cell_drop_attempted` (block placement)
- `DiscardHandler` discard trigger
- `GameplayController._on_play_requested` (already partially guarded)

**Alternatives considered**:
- Modal input guard pattern (`ModalInputGuard`) -- rejected: designed for overlay-style dialogs, not game sequence gates.
- `TileAnimator.is_animating()` extension -- rejected: TileAnimator doesn't know about score transfer phase (which happens after animations).

---

## Decision 3: Lift Phase Animation

**Decision**: Create `LiftTileAnimation extends TileAnimationStrategy` in `scripts/animation/lift/lift_tile_animation.gd`.

**Rationale**: The lift phase is logically identical to existing stomp/spin strategies -- it's a batch tile animation applied to all placed tiles simultaneously. Creating a new strategy and adding `animate_lift_batch(tiles)` to `TileAnimator` follows the existing pattern exactly. The lift uses `stagger_delay = 0.0` (all tiles move together, synchronously). Duration, scale, and offset are parameters in `HypeConfig`.

**Integration**: In `PlayExecutor._execute_play()`, `animate_lift_batch` is called and awaited BEFORE `_animate_play_from_cats`. After lift completes, existing stomp/spin animations run as before.

**Alternatives considered**:
- Reuse `StompTileAnimation` with modified parameters -- rejected: stomp has 3 phases (rise/slam/recover) and particle effects; lift is a single rise with no slam.
- Inline tween in `PlayExecutor` -- rejected: bypasses the strategy pattern and duplicates tween creation logic.

---

## Decision 4: Speed Multiplier Application

**Decision**: Apply `effectiveMultiplier = tileCountMultiplier * masterSpeed` by scaling strategy `duration` and `stagger_delay` properties in-place before each animation batch, restoring originals after.

**Rationale**: Animation strategies store durations as simple float properties. Scaling them before execution and restoring after is the lowest-complexity approach -- no new abstractions, no parameter threading through all executor layers. The pattern is:
```
var orig_duration = strategy.duration
var orig_stagger = strategy.stagger_delay
strategy.duration = orig_duration / effective_multiplier
strategy.stagger_delay = orig_stagger / effective_multiplier
TileAnimator.animate_stomp_batch(tiles)
await TileAnimator.animation_completed
strategy.duration = orig_duration
strategy.stagger_delay = orig_stagger
```
`_commit_scores_staggered` must read the scaled values, so it is refactored to accept `stomp_slam_time`, `stomp_stagger`, `spin_up_time`, `spin_stagger` as parameters rather than creating fresh strategy instances internally.

**Speed formula**: `tileCountMultiplier = clamp(1.0 + k * pow(tileCount, n), minSpeed, maxSpeed)` where default values are `k=0.04`, `n=2.0`, `minSpeed=1.0`, `maxSpeed=3.0`. These make 1-tile plays run at 1.04x (near normal) and 7-tile plays at ~2.96x (near max). Combined with masterSpeed=1.0 default, the baseline is unchanged from current behavior.

**Min duration clamp**: After scaling, each duration is floor-clamped to `HypeConfig.min_animation_duration` (default 0.08s) to prevent sub-perceptual flashes.

**Alternatives considered**:
- Threading multiplier through executor constructors -- rejected: requires changes to all executors.
- A wrapper `ScaledAnimationExecutor` -- rejected: over-engineering; the scale-restore pattern is simpler and fully reversible.

---

## Decision 5: Score Pop Labels

**Decision**: Create score pop labels as `Label` nodes added to the main HUD `CanvasLayer` at runtime, using `global_position` targeting.

**Rationale**: Score labels must fly from a tile's screen position to the score panel's screen position, crossing scene boundaries. Adding labels to the top-level HUD `CanvasLayer` (same layer as the score panel) ensures correct coordinate space. Labels are instantiated as children of the HUD, animated via `Tween`, and freed on completion. `ScorePanel` exposes `get_score_label_target_position() -> Vector2` returning the global position of the score label node.

**Triggering**: Score pop emission is handled by a new `ScorePopEmitter` class (or inline in `PlayExecutor`) that fires after each tile reaches the animation completion threshold. The completion threshold is `animationCompletionThreshold` in `HypeConfig` (default 0.65, normalized over the stomp sequence = after slam, before recover).

**Label travel**: Tween from tile's `global_position + Vector2(0, -40)` to score panel target. Travel duration scales with `effectiveMultiplier` (faster play = faster travel).

**Score update trigger**: The label's `tween.finished` callback calls `GameManager.add_tile_score(delta)` instead of the stagger timer approach currently in `_commit_scores_staggered`. This replaces the concurrent stagger approach with the sequential label-arrival approach described in the spec.

**Important**: This changes the scoring timing from the current "during animation" model to "after label arrives at HUD". This is a behavioral change that must be clearly noted.

**Alternatives considered**:
- Keeping `_commit_scores_staggered` and adding labels as purely cosmetic -- rejected: the spec (FR-014) requires score to update only on label arrival, not before.
- Particle system for score pops -- rejected: over-engineering; a Label with tween is sufficient.

---

## Decision 6: Dynamic Pulse Intensity

**Decision**: Modify `ScorePanel._play_pulse()` to accept `intensity: float = 1.0` as a parameter. Extend `EventBus.score_updated` signal to include `pulse_intensity: float`.

**Rationale**: The existing pulse is at `score_panel.gd` lines 71-79, hardcoded to scale 1.15x. Adding an `intensity` parameter and computing `pulse_scale = 1.15 * intensity` makes the existing pulse variable. The EventBus signal change is minimal and backward-compatible (existing subscribers that only read `total_score, delta` continue to work; the new parameter is appended).

**Formula**: `pulse_intensity = clamp(1.0 + delta / float(target_score), 1.0, HypeConfig.pulse_intensity_max)`. Default `pulse_intensity_max = 3.0` (caps at 3x base scale = 3.45x actual).

**Secondary effect threshold**: At `intensity >= HypeConfig.secondary_effect_threshold` (default 1.5), the score panel also plays a brief shake via `TileAnimator.animate_shake()` or an inline tween (since score panel is a CanvasLayer node, not a Tile).

**Alternatives considered**:
- Separate signal for pulse intensity -- rejected: redundant with score_updated; single signal with extra parameter is cleaner.
- CSS-style cascade (shake + glow as always-on with scaled opacity) -- rejected: beyond scope; shake at threshold is sufficient.

---

## Decision 7: Data-Driven Animation Mapping

**Decision**: Replace `AnimationCategorizer.categorize()` logic with a lookup against `HypeConfig.animation_mapping: Dictionary`.

**Rationale**: `AnimationCategorizer` (`scripts/domain/services/animation_categorizer.gd`) currently hardcodes modifier-to-animation rules. Moving the mapping to `HypeConfig` (a Resource) makes it editor-editable without code changes. `AnimationCategorizer` becomes a thin wrapper: if a tile has a modifier listed in `animation_mapping`, use that; else fall back to `HypeConfig.default_animation` (default: "stomp").

**Note on DDD**: `AnimationCategorizer` is in the domain layer but its logic is about animation presentation, not game rules. The mapping data belongs in `HypeConfig` (controller/animation layer). The categorizer is already a borderline case; moving its data to config is consistent with the existing pattern.

**Alternatives considered**:
- Keep `AnimationCategorizer` as-is and add a separate mapping lookup in `PlayExecutor` -- rejected: duplicates categorization logic.
- Resource-per-tile-type with animation preset field -- rejected: over-engineering for the current number of tile types.

---

## Decision 8: HypeConfig Storage and Access

**Decision**: `HypeConfig` is a `Resource` subclass stored as a `.tres` file at `scripts/animation/hype/hype_config.tres`. `TileAnimator` autoload owns the singleton instance, loaded at `_ready()`. `PlayExecutor` accesses it via `TileAnimator.hype_config`. The `master_speed_multiplier` property is settable at runtime directly on the `TileAnimator.hype_config` instance.

**Rationale**: `TileAnimator` is already the animation system's autoload facade. Attaching `HypeConfig` to it keeps all animation configuration in one place. No new autoload is needed.

**Alternatives considered**:
- New `HypeManager` autoload -- rejected: unnecessary singleton for a config resource.
- `GameManager` owns the config -- rejected: GameManager manages game phase/score, not animation configuration.
