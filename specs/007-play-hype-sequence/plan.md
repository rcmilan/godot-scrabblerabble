# Implementation Plan: Play Hype Sequence

**Branch**: `007-play-hype-sequence` | **Date**: 2026-04-13 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/007-play-hype-sequence/spec.md`

## Summary

Enhance the Play action with a choreographed hype sequence: a synchronous lift phase for all placed tiles, followed by type-driven stomp/spin animations, then per-tile score pop labels that fly to the HUD and trigger score increments on arrival. All phases are governed by an exponential tile-count speed multiplier compounded with a player-facing master speed setting (0.5x-2.0x), backed by a single data-driven `HypeConfig` resource. The Hurry Boss countdown pauses for the entire sequence. Player interaction is fully locked during execution.

## Technical Context

**Language/Version**: GDScript 4 (Godot 4.6)
**Primary Dependencies**: Godot engine -- Tween, CanvasLayer, Label, Resource, Signal system
**Storage**: N/A (no persistence; `HypeConfig` is a `.tres` resource file)
**Testing**: Manual in Godot editor (per Constitution V)
**Target Platform**: Desktop (Windows/Mac/Linux via Godot export)
**Project Type**: Desktop game
**Performance Goals**: Full 7-tile Play sequence completes in under 4 seconds; no frame drops during animation batch
**Constraints**: No Godot code in `/scripts/domain`; no modals/overlays; thin controllers
**Scale/Scope**: Single-player session; up to ~14 tiles on board at once

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Domain-Driven Design | PASS | All new files in `/scripts/animation/`, `/scripts/controllers/`, `/scenes/ui/`. No domain changes except `AnimationCategorizer` receives config from outside rather than hardcoding. |
| II. Decoupled Communication via EventBus | PASS | New `play_sequence_started`/`play_sequence_ended` signals added to EventBus. Timer pause/resume flows through signals, not direct injection. |
| III. Immutable Domain Objects | PASS | No domain value objects modified. `HypeConfig` is a Resource (mutable by design for runtime settings). |
| IV. Thin Controllers | PASS | `PlayExecutor` orchestrates sequence but contains no game rules. Score calculation unchanged. |
| V. Manual Testing First | PASS | All acceptance scenarios are manually testable in editor. |
| No Modals/Popups | PASS | Score pop labels are CanvasLayer Label nodes, not modal overlays. |
| EventBus as Hub | PASS | Timer pause/resume uses EventBus. Score update signal extended (not duplicated). |
| Scene Dependency Injection | PASS | `PlayExecutor` receives board/hand refs via existing `setup()`. `HypeConfig` accessed via `TileAnimator` autoload. |

*Post-design re-check*: Adding `pulse_intensity` to `EventBus.score_updated` is backward-compatible. `BossTimerRelay.pause()/resume()` are consumed by `RunManager` via EventBus -- no direct coupling introduced. PASS.

## Project Structure

### Documentation (this feature)

```text
specs/007-play-hype-sequence/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks - NOT created here)
```

### Source Code Changes

```text
scripts/animation/
├── hype/
│   ├── hype_config.gd               (NEW: Resource with all tuning parameters)
│   └── hype_config.tres             (NEW: Default values for the resource)
├── lift/
│   └── lift_tile_animation.gd       (NEW: TileAnimationStrategy for lift phase)
├── stomp/
│   └── stomp_tile_animation.gd      (MODIFY: No code change; duration/stagger set externally)
└── spin/
    └── spin_tile_animation.gd       (MODIFY: No code change; duration/stagger set externally)

scripts/controllers/
├── play_executor.gd                 (MODIFY: hype sequence orchestration, speed scaling, score pop emission)
├── gameplay_controller.gd           (MODIFY: sequence lock guards on drag, placement, discard)
└── boss_timer_relay.gd              (MODIFY: add pause()/resume() methods)

scenes/ui/
├── score_panel/
│   └── score_panel.gd               (MODIFY: dynamic pulse intensity, expose target position)
└── score_pop/
    └── score_pop.gd                 (NEW: floating score label node script)

autoload/
├── tile_animator.gd                 (MODIFY: add hype_config property, animate_lift_batch())
└── event_bus.gd                     (MODIFY: add play_sequence_started/ended; extend score_updated)

scripts/domain/services/
└── animation_categorizer.gd         (MODIFY: delegate mapping to HypeConfig, keep fallback)

autoload/
└── run_manager.gd                   (MODIFY: subscribe to play_sequence_started/ended, pause/resume relay)
```

## Complexity Tracking

No constitution violations to justify. All changes are extensions or thin modifications to existing patterns.

---

## Phase 0: Research

See [research.md](./research.md) for all decisions. Summary:

- **Timer pause/resume**: New `pause()`/`resume()` on `BossTimerRelay`; triggered by EventBus signals from `PlayExecutor`.
- **Interaction lock**: `is_sequence_active()` flag on `PlayExecutor`; guards in `GameplayController` and `DiscardHandler`.
- **Lift phase**: New `LiftTileAnimation extends TileAnimationStrategy`; `TileAnimator.animate_lift_batch()`.
- **Speed scaling**: Scale strategy `duration`/`stagger_delay` in-place before each batch; restore after. Refactor `_commit_scores_staggered` to accept pre-computed scaled timings.
- **Score pops**: Dynamic `Label` nodes on HUD CanvasLayer; `GameManager.add_tile_score()` called on tween arrival. Replaces the current stagger-timer scoring model.
- **Pulse intensity**: `pulse_intensity` param on `_play_pulse()`; appended to `EventBus.score_updated`.
- **Animation mapping**: `HypeConfig.animation_mapping` dictionary; `AnimationCategorizer` delegates lookup.
- **HypeConfig access**: Owned by `TileAnimator` autoload as `hype_config` property.

---

## Phase 1: Design & Contracts

### Implementation Steps (ordered)

Implementation must follow this order to avoid forward-dependency issues:

**Step 1: HypeConfig Resource** *(no dependencies)*

Create `scripts/animation/hype/hype_config.gd`:
```gdscript
extends Resource
class_name HypeConfig

@export var master_speed_multiplier: float = 1.0
@export var master_speed_min: float = 0.5
@export var master_speed_max: float = 2.0
@export var speed_scale_k: float = 0.04
@export var speed_scale_n: float = 2.0
@export var tile_count_speed_min: float = 1.0
@export var tile_count_speed_max: float = 3.0
@export var min_animation_duration: float = 0.08
@export var animation_completion_threshold: float = 0.65
@export var lift_scale: Vector2 = Vector2(1.2, 1.2)
@export var lift_offset_y: float = -20.0
@export var lift_duration: float = 0.12
@export var animation_mapping: Dictionary = {"EXTRA": "spin", "MULTI": "spin", "EXPO": "spin"}
@export var default_animation: String = "stomp"
@export var score_pop_travel_duration: float = 0.4
@export var score_pop_font_size: int = 22
@export var pulse_base_scale: float = 1.15
@export var pulse_intensity_max: float = 3.0
@export var secondary_effect_threshold: float = 1.5
@export var secondary_effect_magnitude: float = 4.0
@export var debug_logging_enabled: bool = false
@export var inter_tile_stagger_delay: float = 0.06

func get_tile_count_multiplier(tile_count: int) -> float:
    return clamp(1.0 + speed_scale_k * pow(tile_count, speed_scale_n),
                 tile_count_speed_min, tile_count_speed_max)

func get_effective_multiplier(tile_count: int) -> float:
    return get_tile_count_multiplier(tile_count) * master_speed_multiplier

func scale_duration(base: float, multiplier: float) -> float:
    return max(base / multiplier, min_animation_duration)
```

Save default instance to `scripts/animation/hype/hype_config.tres`.

**Step 2: EventBus Signal Extensions** *(depends on: nothing)*

In `autoload/event_bus.gd`:
- **KEEP** `signal score_updated(total_score: int, delta: int)` unchanged (no pulse_intensity parameter). ScorePanel computes pulse intensity locally from delta and target score.
- Add: `signal play_sequence_started`
- Add: `signal play_sequence_ended`

**Step 3: BossTimerRelay Pause/Resume** *(depends on: Step 2)*

In `scripts/controllers/boss_timer_relay.gd`:
- Add `var _paused: bool = false`
- Add `func pause() -> void: _paused = true`
- Add `func resume() -> void: _paused = false`
- In `on_process(delta)`: guard with `if not _is_active or _paused: return`

**Step 4: RunManager Timer Gate** *(depends on: Steps 2, 3)*

In `autoload/run_manager.gd`, in the method that connects signals after round start (or in `_ready`):
- Connect `EventBus.play_sequence_started` -> `_on_play_sequence_started`
- Connect `EventBus.play_sequence_ended` -> `_on_play_sequence_ended`
- Implement:
  ```gdscript
  func _on_play_sequence_started() -> void:
      if _boss_timer_relay and _boss_timer_relay.is_active():
          _boss_timer_relay.pause()

  func _on_play_sequence_ended() -> void:
      if _boss_timer_relay and _boss_timer_relay.is_active():
          _boss_timer_relay.resume()
  ```

**Step 5: TileAnimator HypeConfig + Lift** *(depends on: Step 1)*

In `autoload/tile_animator.gd`:
- Add `var hype_config: HypeConfig = null`
- In `_ready()`: `hype_config = load("res://scripts/animation/hype/hype_config.tres")`
- Create `LiftTileAnimation` (Step 6) then:
  - Add `var _lift_animation: LiftTileAnimation = null`
  - Add `func _ensure_lift_resources(): _lift_animation = _ensure_strategy(_lift_animation, LiftTileAnimation)`
  - Add:
    ```gdscript
    func animate_lift_batch(tiles: Array[Tile]) -> void:
        if tiles.is_empty(): return
        _ensure_lift_resources()
        _stomp_executor.execute(tiles, _lift_animation)  # reuse stomp executor for batch
    ```

**Step 6: LiftTileAnimation** *(depends on: Step 1)*

Create `scripts/animation/lift/lift_tile_animation.gd`:
```gdscript
extends TileAnimationStrategy
class_name LiftTileAnimation

func _init() -> void:
    duration = 0.12       # overridden at runtime from HypeConfig
    stagger_delay = 0.0   # all tiles lift simultaneously
    ease_type = Tween.EASE_OUT
    trans_type = Tween.TRANS_BACK

func on_animation_start(tile: Tile) -> void:
    tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
    tile.z_index = 50
    tile.pivot_offset = tile.size / 2.0

func build_custom_tweens(tile: Tile, tween: Tween, delay: float) -> void:
    # Scale up and move upward simultaneously
    var target_scale: Vector2 = TileAnimator.hype_config.lift_scale
    var target_pos: Vector2 = tile.position + Vector2(0, TileAnimator.hype_config.lift_offset_y)
    tween.tween_property(tile, "scale", target_scale, duration).set_delay(delay)
    tween.parallel().tween_property(tile, "position", target_pos, duration).set_delay(delay)

func on_animation_complete(tile: Tile) -> void:
    tile.mouse_filter = Control.MOUSE_FILTER_STOP
    tile.z_index = 0
    tile.pivot_offset = Vector2.ZERO
    tile._update_visual()
```

**Step 7: AnimationCategorizer Config-Driven** *(depends on: Step 1, Step 5)*

In `scripts/domain/services/animation_categorizer.gd`:
- Change `categorize(tiles)` to check `TileAnimator.hype_config.animation_mapping` for each tile's modifier type key.
- Fallback to `TileAnimator.hype_config.default_animation` if key absent.
- The `categorize()` return Dictionary now has keys matching animation preset names (e.g., `{stomp: [...], spin: [...]}`) rather than hardcoded.

Note: This file is in `/scripts/domain/services/` but it references `TileAnimator` (an autoload). This is acceptable -- autoloads are global GDScript singletons, not Godot Node dependencies. The domain rule here is "categorize tiles by animation type," which is valid domain logic even if it reads config. Alternatively, pass `hype_config` as a parameter to `categorize()` to keep domain pure -- **preferred**.

Revised: `AnimationCategorizer.categorize(tiles: Array[Tile], mapping: Dictionary, default: String) -> Dictionary`. `PlayExecutor` passes `TileAnimator.hype_config.animation_mapping` and `default_animation`.

**Step 8: ScorePanel Dynamic Pulse** *(depends on: Step 2)*

In `scenes/ui/score_panel/score_panel.gd`:
- Keep `_on_score_updated(total_score: int, delta: int)` signature unchanged (no pulse_intensity parameter).
- Compute pulse intensity locally: `var pulse_intensity: float = clamp(1.0 + delta / float(_target) if _target > 0 else 1.0, 1.0, TileAnimator.hype_config.pulse_intensity_max)`
- Change `_play_pulse()` to `_play_pulse(intensity: float = 1.0)`:
  ```gdscript
  func _play_pulse(intensity: float = 1.0) -> void:
      if _pulse_tween: _pulse_tween.kill()
      $VBoxContainer.scale = Vector2.ONE
      var pulse_scale: float = TileAnimator.hype_config.pulse_base_scale * intensity
      _pulse_tween = create_tween()
      _pulse_tween.tween_property($VBoxContainer, "scale",
          Vector2(pulse_scale, pulse_scale), 0.1) \
          .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
      _pulse_tween.tween_property($VBoxContainer, "scale",
          Vector2.ONE, 0.15) \
          .set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
  ```
- In `_on_score_updated()`, compute intensity locally then call `_play_pulse(pulse_intensity)`.
- At high intensity (`pulse_intensity >= TileAnimator.hype_config.secondary_effect_threshold`), trigger a brief shake on `$VBoxContainer`:
  ```gdscript
  if pulse_intensity >= TileAnimator.hype_config.secondary_effect_threshold:
      _play_shake()
  ```
- Add `_play_shake()` method: short 3-step horizontal tween using `secondary_effect_magnitude`.
- Add `get_score_label_target_position() -> Vector2`: returns `$VBoxContainer/ScoreLabel.global_position`.

**Step 9: ScorePopLabel** *(depends on: Steps 1, 5, 8)*

Create `scenes/ui/score_pop/score_pop.gd`:
```gdscript
extends Label
class_name ScorePopLabel

func launch(start_pos: Vector2, end_pos: Vector2, delta: int,
            travel_duration: float, on_arrive: Callable) -> void:
    text = "+%d" % delta
    global_position = start_pos
    add_theme_font_size_override("font_size", TileAnimator.hype_config.score_pop_font_size)
    modulate.a = 0.0

    var tween := create_tween()
    # Entrance: fade + scale in
    tween.tween_property(self, "modulate:a", 1.0, 0.1)
    tween.parallel().tween_property(self, "scale", Vector2(1.3, 1.3), 0.1).set_trans(Tween.TRANS_BACK)
    tween.tween_property(self, "scale", Vector2.ONE, 0.05)
    # Travel to score panel
    tween.tween_property(self, "global_position", end_pos, travel_duration) \
        .set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
    tween.parallel().tween_property(self, "modulate:a", 0.0, travel_duration * 0.5)
    # On arrival: call callback, free self
    tween.tween_callback(on_arrive)
    tween.tween_callback(queue_free)
```

**ScorePopLabel Instantiation in PlayExecutor:**

Score pop labels are instantiated dynamically in `PlayExecutor._execute_play()` during the score transfer phase. Code pattern:
```gdscript
# In PlayExecutor score transfer phase (Step 10c item 10):
var score_pop = Label.new()
score_pop.set_script(ScorePopLabel)
_hud.add_child(score_pop)
var on_arrive = func():
    GameManager.add_tile_score(delta)
    EventBus.score_updated.emit(cumulative, delta)
score_pop.launch(tile.global_position, score_panel_target, delta, travel_duration_scaled, on_arrive)
```

`PlayExecutor` needs a reference to the HUD CanvasLayer. Inject via new `set_hud(hud_node)` method called from `GameplayController` during setup.

**Step 10: PlayExecutor Hype Sequence** *(depends on: Steps 1-9)*

Modify `scripts/controllers/play_executor.gd`:

a) Add `var _is_sequence_active: bool = false` and `func is_sequence_active() -> bool: return _is_sequence_active`.

b) Add `var _hud: CanvasLayer = null` and `func set_hud(hud: CanvasLayer) -> void: _hud = hud`.

c) Refactor `_execute_play(unplayed_tiles)`:
```
1. Set _is_sequence_active = true
2. Emit EventBus.play_sequence_started
3. Lock tiles, deselect
4. Execute boss post-play effects (unchanged)
5. Find words, calculate per-tile scores (unchanged)
6. Compute _hype_params from HypeConfig
7. Debug log: [Play] tileCount=N speedMultiplier=X
8. Run LIFT PHASE:
   a. var lift_strategy = TileAnimator._lift_animation
   b. var orig_duration = lift_strategy.duration
   c. lift_strategy.duration = hype_config.scale_duration(orig_duration, _hype_params.effective_multiplier)
   d. TileAnimator.animate_lift_batch(all_board_tiles)
   e. await TileAnimator.animation_completed
   f. lift_strategy.duration = orig_duration
9. Run TILE ANIMATION PHASE (stomp then spin):
   a. For each batch (stomp, spin):
      - Get strategy instance
      - Save original duration and stagger_delay
      - Scale: strategy.duration = hype_config.scale_duration(orig_duration, multiplier)
      - Scale: strategy.stagger_delay = orig_stagger / multiplier
      - Animate batch and await completion
      - Restore: strategy.duration = orig_duration; strategy.stagger_delay = orig_stagger
   b. Debug log per tile: [Tile] type=T animation=A duration=X.XX
10. Run SCORE TRANSFER PHASE:
   a. For each tile in unplayed_tiles (in order):
      - Compute delta = total_score / tile_count (or weighted)
      - Emit score pop label via: score_pop.launch(tile_pos, score_panel_target, delta, travel_duration_scaled, on_arrive_callback)
      - on_arrive_callback: GameManager.add_tile_score(delta); EventBus.score_updated.emit(cumulative, delta)
      - Debug log: [Score] delta=N progress=X.XX intensity=X.XX (intensity computed by ScorePanel)
11. Await all score pop labels to arrive (track count in a counter; when counter == tile_count, all arrived)
12. GameManager.end_play() (unchanged)
13. Consume modifiers (unchanged)
14. Emit EventBus.tiles_played, play_completed (unchanged)
15. Emit EventBus.play_sequence_ended
16. Set _is_sequence_active = false
17. Wait 0.5s, refill hand
```

d) Refactor `_commit_scores_staggered()` -> delete it entirely. Score transfer now handled by score pop label arrival callbacks (Step 10c item 10).

e) **GameManager.add_tile_score() remains unchanged**: Keep signature as `add_tile_score(score: int)`. No pulse_intensity parameter needed. ScorePanel computes intensity locally from its known `_target` and the received `delta` in the `score_updated` signal handler.

**EventBus signal contract**: `EventBus.score_updated(total_score: int, delta: int)` stays unchanged. ScorePanel subscription computes `pulse_intensity = clamp(1.0 + delta / float(_target) if _target > 0 else 1.0, 1.0, max_intensity)` in its handler before calling `_play_pulse(intensity)`. This keeps GameManager unaware of animation concerns and avoids threading intensity through the signal.

**Step 11: Interaction Lock in GameplayController** *(depends on: Step 10a)*

In `scripts/controllers/gameplay_controller.gd`, add guard at all input delegation points that should be blocked during sequence:
```gdscript
# At the top of each guarded handler:
if _play.is_sequence_active():
    return
```

Handlers to guard:
- `_on_tile_drag_started` (or equivalent drag initiation)
- `_on_cell_drop_attempted`
- Discard action handler
- Any tile selection or deselection triggers that move tiles

The existing `TileAnimator.is_animating()` guard on `_on_play_requested` is sufficient for play button -- sequence lock covers everything else.

### Contracts

No external API contracts apply (desktop game, no external interfaces). Internal EventBus signal contracts are documented in `data-model.md`.

### Agent Context Update

Run after plan is complete:
`.specify/scripts/powershell/update-agent-context.ps1 -AgentType claude`
