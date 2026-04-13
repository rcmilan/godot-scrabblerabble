# Tasks: Play Hype Sequence

**Feature**: Play Hype Sequence | **Branch**: `007-play-hype-sequence` | **Date**: 2026-04-13
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

---

## Phase 1: Setup & Infrastructure

Setup phase: Create foundational resources and extend existing systems. All tasks are prerequisites for user story implementation.

### Goals
- Create `HypeConfig` resource with all tuning parameters
- Extend EventBus with new signals
- Add pause/resume to `BossTimerRelay`
- Hook RunManager to listen for sequence events
- Extend TileAnimator with lift animation support
- Create LiftTileAnimation strategy
- Make AnimationCategorizer config-driven

### Implementation Tasks

- [ ] T001 Create `HypeConfig` resource at `scripts/animation/hype/hype_config.gd` extending Resource with all fields (master_speed_multiplier, speed scaling constants, animation mapping, debug flag, etc.)
- [ ] T002 Create `hype_config.tres` default resource instance at `scripts/animation/hype/hype_config.tres` with documented default values
- [ ] T003 Extend `autoload/event_bus.gd` with new signals: `play_sequence_started()`, `play_sequence_ended()`. **KEEP existing `signal score_updated(total_score: int, delta: int)` unchanged** -- no pulse_intensity parameter. ScorePanel computes intensity locally from delta and its known _target.
- [ ] T004 Add `pause()` and `resume()` methods to `scripts/controllers/boss_timer_relay.gd` with internal `_paused: bool` guard in `on_process()`
- [ ] T005 Modify `autoload/run_manager.gd` to subscribe to `EventBus.play_sequence_started/ended` and call `_boss_timer_relay.pause()/resume()` respectively
- [ ] T006 Modify `autoload/tile_animator.gd`: Add `var hype_config: HypeConfig` property, load in `_ready()`, prepare for `animate_lift_batch()` support
- [ ] T007 Create `LiftTileAnimation` at `scripts/animation/lift/lift_tile_animation.gd` extending TileAnimationStrategy with parameters from HypeConfig (lift_scale, lift_offset_y, lift_duration)
- [ ] T008 Register lift animation in `TileAnimator._ensure_lift_resources()` and add public `animate_lift_batch(tiles: Array[Tile])` method
- [ ] T009 Refactor `scripts/domain/services/animation_categorizer.gd` to accept mapping and default animation as parameters instead of hardcoding (keep domain pure)

---

## Phase 2: Foundational Hype Sequence Components

Foundational phase: Prepare core sequence orchestration, UI updates, and player locks. Blocks all user story implementations.

### Goals
- Add dynamic pulse intensity to ScorePanel
- Create ScorePopLabel UI element
- Prepare PlayExecutor for hype sequence orchestration
- Implement player interaction lock during sequence

### Independent Test Criteria
- All new components can be instantiated without errors
- EventBus signals are emitted/received correctly
- Player lock flag works independently

### Implementation Tasks

- [ ] T010 Modify `scenes/ui/score_panel/score_panel.gd`: In `_on_score_updated()`, compute intensity locally: `var intensity = 1.0 if _target <= 0 else clamp(1.0 + delta / float(_target), 1.0, hype_config.pulse_intensity_max)`. Update `_play_pulse()` to accept `intensity: float = 1.0` parameter, compute pulse scale as `base_scale * intensity`. Add `_play_shake()` for secondary effect at high intensity.
- [ ] T011 Add `get_score_label_target_position() -> Vector2` method to `ScorePanel` returning global position of score label for label travel targeting
- [ ] T012 Create `scenes/ui/score_pop/score_pop.gd` as Label node script with `launch(start_pos, end_pos, delta, travel_duration, on_arrive_callback)` method (entrance fade/scale, travel with easing, on-arrival callback, self-destruct)
- [ ] T013 Add `var _is_sequence_active: bool = false` to `scripts/controllers/play_executor.gd` with `is_sequence_active() -> bool` getter
- [ ] T014 [P] Add `var _hud: CanvasLayer = null` and `set_hud(hud: CanvasLayer)` to `PlayExecutor` for score pop label parent node
- [ ] T015 [P] Add `var _hype_params: Dictionary = {}` to `PlayExecutor` for storing computed speed multiplier and scaled timings per play

---

## Phase 3: User Story 1 - Staged Play Feedback With Lift Phase (P1)

User Story 1: Implement the lift phase that runs before all other animations, providing an anticipation beat. Includes player lock and timer pause integration.

### Independent Test Criteria
- Place tiles and press Play; all tiles lift simultaneously before stomp/spin animations
- Lift animation completes without gaps before tile-specific animations start
- Player cannot interact (place/drag/discard) while lift is running
- Hurry Boss timer pauses at Play and resumes after sequence (if boss round active)

### User Story Test Procedure
1. Start any round with placed tiles on board
2. Press Play button
3. Verify all tiles scale up and move upward uniformly
4. Verify lift phase completes, then tiles transition to stomp/spin
5. Attempt to place/drag/discard during animation -- verify blocked
6. If Hurry Boss round: start with countdown active, press Play, verify timer pauses, resumes after

### Implementation Tasks

- [ ] T016 [US1] Refactor `scripts/controllers/play_executor.gd._execute_play()`: Add sequence lock (`_is_sequence_active = true`), emit `EventBus.play_sequence_started` at start
- [ ] T017 [US1] Add lift phase execution in `PlayExecutor._execute_play()`: Scale lift strategy duration/stagger from `_hype_params`, call `TileAnimator.animate_lift_batch(all_tiles)`, await completion
- [ ] T018 [US1] Restore animation strategy durations after each animation batch in `PlayExecutor` (scale before batch, restore after)
- [ ] T019 [US1] Modify `scripts/controllers/gameplay_controller.gd`: Guard `_on_tile_drag_started`, `_on_cell_drop_attempted`, discard handler with `if _play.is_sequence_active(): return`
- [ ] T020 [US1] Add final sequence cleanup in `PlayExecutor._execute_play()`: Emit `EventBus.play_sequence_ended` at end, set `_is_sequence_active = false`
- [ ] T021 [US1] Manual test: Place 5 tiles, press Play, observe lift phase, verify no gaps, verify player lock works during lift

---

## Phase 4: User Story 2 - Adaptive Speed Scaling By Tile Count (P2)

User Story 2: Implement exponential speed multiplier that scales all animation durations based on tile count, compounded with master speed setting.

### Independent Test Criteria
- 1-tile play runs at minimum speed (near 1.0x)
- 7-tile play runs visibly faster than 3-tile play
- Speed is exponential (difference between 7 and 3 is dramatic vs linear)
- Speed is clamped to max; no animation falls below min readable threshold
- Master speed multiplier (0.5x-2.0x) scales all phases proportionally

### User Story Test Procedure
1. Play 1-tile word; note animation duration (slow, readable)
2. Play 3-tile word; note animation duration (noticeably faster)
3. Play 7-tile word; note animation duration (significantly faster than 3)
4. Change `TileAnimator.hype_config.master_speed_multiplier` to 0.5 (slow) and re-play 7-tile; verify all animations are proportionally slower
5. Change to 2.0 (fast) and re-play; verify all animations are proportionally faster

### Implementation Tasks

- [ ] T022 [US2] Compute tile-count multiplier in `PlayExecutor._execute_play()`: `tileCount = unplayed_tiles.size()`, `tileCountMultiplier = hype_config.get_tile_count_multiplier(tileCount)`, `effectiveMultiplier = tileCountMultiplier * hype_config.master_speed_multiplier`
- [ ] T023 [US2] Store computed timings in `_hype_params`: `stomp_slam_time_scaled`, `stomp_stagger_scaled`, `spin_up_time_scaled`, `spin_stagger_scaled`, `score_travel_duration_scaled`
- [ ] T024 [US2] Implement duration scaling in animation batches: Before `TileAnimator.animate_stomp_batch()`, set `stomp_animation.duration = base / effectiveMultiplier`, restore after
- [ ] T025 [US2] Implement stagger scaling: Set `strategy.stagger_delay = base_stagger / effectiveMultiplier` before batch, restore after
- [ ] T026 [US2] Apply min_animation_duration clamp: Use `hype_config.scale_duration(base, multiplier)` which returns `max(base / multiplier, min_threshold)`
- [ ] T027 [US2] Add debug logging if enabled: Log `[Play] tileCount=N speedMultiplier=X.XX` to console at start of sequence
- [ ] T028 [US2] Manual test: Play 1, 3, 7 tile words at master speed 1.0, 0.5, 2.0; verify speed scaling is exponential and compounded

---

## Phase 5: User Story 3 - Per-Tile Score Pop With Score Transfer (P3)

User Story 3: Implement floating score labels that appear above tiles after animation, travel to HUD, and trigger score increments on arrival. Replaces concurrent stagger-based scoring.

### Independent Test Criteria
- Score pop label appears above each tile with non-zero contribution after tile animation reaches completion threshold
- Label entrance animation is smooth (fade + scale)
- Label travels from tile position to score panel position
- Score counter increments only when label arrives at HUD (not before)
- Multiple labels in flight move independently (no merging)
- Label travel speed respects the effective multiplier (faster plays = faster travel)

### User Story Test Procedure
1. Play any word (3+ tiles)
2. Watch labels pop above tiles after their animations
3. Verify labels travel visibly to score panel
4. Count label arrival ticks against score counter updates (should match)
5. Observe multiple labels in flight simultaneously (don't merge)
6. Play again with master speed 2.0, verify labels travel faster proportionally

### Implementation Tasks

- [ ] T029 [US3] Refactor `PlayExecutor._commit_scores_staggered()`: Delete entire method (replaced by label-based scoring)
- [ ] T030 [US3] Add score transfer phase in `PlayExecutor._execute_play()`: After tile animations, iterate through unplayed tiles, emit score pop label for each with non-zero delta
- [ ] T031 [US3] Implement score pop emission in `PlayExecutor`: Create `ScorePopLabel` instance, call `launch(tile_global_pos, score_panel_target, delta, scaled_travel_duration, on_arrive_callback)`
- [ ] T032 [US3] Implement score callback in `PlayExecutor._execute_play()` score transfer phase: Create lambda `on_arrive_callback = func(): GameManager.add_tile_score(delta); EventBus.score_updated.emit(cumulative, delta)` and pass to `score_pop.launch()` as callback. GameManager.add_tile_score() updates cumulative score; EventBus signal triggers ScorePanel to compute intensity locally and pulse.
- [ ] T033 [US3] Add score pop to HUD: Modify `GameplayController` to pass HUD CanvasLayer to `PlayExecutor.set_hud(hud)` during setup
- [ ] T034 [US3] Track score transfer completion: Add counter or signal to know when all labels have arrived (await or busy-wait)
- [ ] T035 [US3] Add debug logging: Log `[Score] delta=N progress=X.XX` for each tile score contribution
- [ ] T036 [US3] Manual test: Play any word, observe labels pop, travel, and arrive; verify score increments only on arrival

---

## Phase 6: User Story 4 - Dynamic Pulse Intensity on Score Update (P4)

User Story 4: Compute and apply dynamic pulse intensity to score display based on score contribution relative to target. Add secondary visual effects at high intensity.

### Independent Test Criteria
- Tile contribution of 5% of target produces 1.05x pulse
- Tile contribution of 110% of target produces 2.10x pulse
- Pulse intensity clamped at max (3.0) to prevent visual distortion
- At intensity >= 1.5, secondary shake effect activates
- Score text remains readable at all intensity levels

### User Story Test Procedure
1. Set round target to 100 points
2. Play a tile worth 5 points; observe mild pulse (5% of target)
3. Play a tile worth 110 points; observe dramatic pulse (110% of target, clamped to intensity 3.0 = 3.45x)
4. Verify secondary shake triggers on the 110-point play
5. Verify score label remains readable throughout

### Implementation Tasks

- [ ] T037 [US4] Compute pulse intensity in `ScorePanel._on_score_updated()`: `var pulse_intensity: float = 1.0 if _target <= 0 else clamp(1.0 + delta / float(_target), 1.0, TileAnimator.hype_config.pulse_intensity_max)`. Guard against divide-by-zero when _target is zero or undefined.
- [ ] T038 [US4] Verify `ScorePanel._on_score_updated()` computes intensity correctly with zero-guard: `intensity = 1.0 if _target <= 0 else clamp(1.0 + delta / float(_target), 1.0, max_intensity)`. (Note: T010 already implements this; this task verifies it works end-to-end.)
- [ ] T039 [US4] Pass intensity to `_play_pulse(intensity)` method
- [ ] T040 [US4] Implement secondary effect in `ScorePanel._play_shake()`: Horizontal tween at magnitude from config
- [ ] T041 [US4] Add threshold check: Trigger shake only if `intensity >= hype_config.secondary_effect_threshold`
- [ ] T042 [US4] Add debug logging: Log `[Score] delta=N progress=X.XX intensity=X.XX` for each score
- [ ] T043 [US4] Manual test: Play tiles worth 5%, 50%, 110% of target; observe pulse intensity and secondary effects

---

## Phase 7: User Story 5 - Data-Driven Animation Mapping (P5)

User Story 5: Verify animation mapping is fully config-driven. Tiles without explicit mapping fall back to default. No code changes needed to add new animation types.

### Independent Test Criteria
- Animation mapping from `HypeConfig.animation_mapping` is consulted during play
- Tiles with mapped modifiers use assigned animation
- Unmapped modifiers fall back to default animation without errors
- Reassigning animation in config takes effect on next play

### User Story Test Procedure
1. Edit `hype_config.tres` in Godot Inspector: Modify a tile type's animation mapping (e.g., change EXTRA from "spin" to "stomp")
2. Play a word with an EXTRA tile
3. Verify the tile uses the new animation
4. Change back in config
5. Play again, verify original animation restored
6. Add a hypothetical new modifier to the mapping (e.g., "MYSTERY" -> "stomp")
7. Verify no errors on play (graceful fallback if animation not implemented)

### Implementation Tasks

- [ ] T044 [US5] Verify `AnimationCategorizer.categorize()` uses `hype_config.animation_mapping` correctly
- [ ] T045 [US5] Test mapping lookup in `PlayExecutor._animate_play_from_cats()`: Verify categories match mapped animations
- [ ] T046 [US5] Test fallback: Verify unmapped tile type uses `default_animation` from config
- [ ] T047 [US5] Manual test: Edit `hype_config.tres`, reassign an animation, play, verify change takes effect

---

## Phase 8: Polish & Edge Cases

Final phase: Test edge cases, verify timer pause/resume, confirm player lock, optimize performance, and validate all scenarios.

### Goals
- Verify all edge cases from spec work correctly
- Confirm timer pause/resume during sequence
- Verify player lock comprehensive
- Check performance (7-tile play < 4 seconds)
- Debug logging functional

### Implementation Tasks

- [ ] T048 Test edge case: Single tile play (lift and animation still run, speed at minimum)
- [ ] T049 Test edge case: Tile with zero score (no label emitted)
- [ ] T050 Test edge case: Target score zero or undefined (pulse intensity defaults to 1.0, no divide-by-zero)
- [ ] T051 Test edge case: Sequence interrupted (game paused mid-sequence) - verify lock remains until sequence resolves
- [ ] T052 Test edge case: Hurry Boss time-out mid-sequence - verify sequence completes, then round-end logic runs
- [ ] T053 Test edge case: Maximum tile count (full board) - verify speed clamped, no visual overload
- [ ] T054 Test edge case: Score labels overlap in flight - verify independent travel, no collision resolution needed
- [ ] T055 Test Hurry Boss timer pause: Start Hurry Boss round with active countdown, press Play, verify timer pauses, resumes after
- [ ] T056 Test player lock comprehensive: During sequence, attempt placement, drag, removal, discard; all should be blocked
- [ ] T057 Performance test: Play 7-tile word multiple times, measure sequence duration (should be < 4 seconds), check for frame drops
- [ ] T058 Enable debug logging, play sequence, verify all required fields logged: `[Play]`, `[Tile]`, `[Score]`
- [ ] T059 Final integrated manual test: Play full round with multiple plays, verify lift → animations → score pops → scoring → timer management all work together
- [ ] T060 Manual test all user story acceptance scenarios end-to-end

---

## Dependencies & Execution Order

```
Phase 1 (Setup/Infrastructure)
  ├── T001-T009: HypeConfig, EventBus, Timer, TileAnimator, LiftAnimation, AnimationCategorizer
  └── [GATE: All Phase 1 complete before proceeding to Phase 2]

Phase 2 (Foundational Components)
  ├── T010-T015: ScorePanel enhancements, ScorePopLabel, PlayExecutor preparation
  └── [GATE: All Phase 2 complete before user story phases]

Phase 3 (US1 - Lift Phase) [Blocks: US2, US3, US4, US5 cannot run without lift]
  ├── T016-T021: Implement lift in sequence, player lock, timer integration
  └── [INDEPENDENT TEST: Lift phase with no scoring]

Phase 4 (US2 - Speed Scaling) [Depends on: US1]
  ├── T022-T028: Speed multiplier calculation, duration scaling, debug logging
  └── [INDEPENDENT TEST: Speed scaling without score pops]

Phase 5 (US3 - Score Pops) [Depends on: US1, US2]
  ├── T029-T036: Replace stagger scoring with label-based scoring
  └── [INDEPENDENT TEST: Score labels without pulse intensity]

Phase 6 (US4 - Pulse Intensity) [Depends on: US3]
  ├── T037-T043: Compute and apply intensity, secondary effects
  └── [INDEPENDENT TEST: Pulse intensity on score updates]

Phase 7 (US5 - Animation Mapping) [Depends on: US1 (reuses categorization)]
  ├── T044-T047: Verify config-driven mapping
  └── [INDEPENDENT TEST: Reassign animation in config, play, verify]

Phase 8 (Polish & Edge Cases)
  ├── T048-T060: Edge case testing, performance validation, integrated tests
  └── [GATE: All edge cases pass, performance target met]
```

---

## Parallel Execution Opportunities

**Within Phase 1 (Setup)**:
- T001, T002 can run in parallel (HypeConfig creation + default resource)
- T003, T004, T005 can run in parallel (EventBus, BossTimerRelay, RunManager) after EventBus is extended

**Within Phase 3 (US1)**:
- T016, T017 sequential (both modify same method)
- T019, T020 sequential (both modify PlayExecutor)
- T018 can run in parallel after T017 if on different file

**Within Phase 5 (US3)**:
- T029, T031, T032 are sequential (same method refactor)
- T030 can start after T029 is deleted

**Within Phase 8 (Polish)**:
- T048-T057 can be grouped and run in any order (all are independent tests)

---

## MVP Scope (Recommended Starting Point)

**Minimum Viable Product**: Implement User Story 1 (Lift Phase) only.

**Why**: 
- Lift phase is the foundational sequence beat
- Provides immediate visual feedback on Play action
- All subsequent stories (speed, scoring, pulse) layer on top
- US1 is independently testable

**Phases to complete for MVP**:
1. Phase 1 (All setup)
2. Phase 2 (All foundational)
3. Phase 3 (US1 complete)
4. Subset of Phase 8 (Basic edge cases, verify timer pause/lock)

**Estimated tasks for MVP**: ~30 tasks (T001-T021 + T048-T060 subset)

**What's deferred to follow-up increments**:
- Phase 4 (US2 - Speed scaling)
- Phase 5 (US3 - Score pops)
- Phase 6 (US4 - Pulse intensity)
- Phase 7 (US5 - Animation mapping)
