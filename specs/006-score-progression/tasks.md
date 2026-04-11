# Tasks: Score Progression and Scoring System Overhaul

**Input**: Design documents from `/specs/006-score-progression/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to
- No test tasks (manual testing per constitution)

---

## Phase 1: Setup

**Purpose**: No new project scaffolding needed. One new directory must exist before implementation begins.

- [x] T001 Create directory `scenes/ui/score_panel/` (will hold ScorePanel scene and script)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Cumulative score model in GameManager + wiring through RunManager/Main. Every other user story depends on this being correct before they can be validated.

**Warning**: Do not begin any user story phase until ALL tasks here are complete and verified by logging in the Godot console.

- [x] T002 Add field `var _previous_rounds_total: int = 0` and getter `func get_cumulative_score() -> int: return _current_score + _previous_rounds_total` to `autoload/game_manager.gd`

- [x] T003 Update `GameManager.setup_round(config: RoundConfig)` to accept a second parameter `previous_total: int = 0`, store it in `_previous_rounds_total`, and reset `_current_score = 0` as before in `autoload/game_manager.gd`

- [x] T004 Update `GameManager.commit_play(score: int)` to compute `var cumulative: int = get_cumulative_score()` and emit `EventBus.score_updated.emit(cumulative, score)` (was: `_current_score`) and check win condition as `if cumulative >= _target_score` (was: `if _current_score >= _target_score`) in `autoload/game_manager.gd`

- [x] T005 Update `GameManager.start_round()` (the simpler overload on line ~132) to also accept `previous_total: int = 0` and store it in `_previous_rounds_total`, for safety in `autoload/game_manager.gd`

- [x] T006 Fix `RunManager._on_round_ended()` failure path: before calling `run_state.end_run()`, compute `var final_score: int = run_state.total_score + GameManager.get_current_score()` and emit `EventBus.run_ended.emit(false, final_score)` instead of `run_state.total_score` alone in `autoload/run_manager.gd`

- [x] T007 In `scenes/main.gd`, find the `_on_round_ready(config)` method that calls `GameManager.setup_round(config)` and update it to pass the previous total: read `RunManager.run_state.total_score` (guard for null) and call `GameManager.setup_round(config, previous_total)` in `scenes/main.gd`

**Checkpoint**: Open Godot, start a run, score points in round 1, win, advance to round 2. Console log from `[GameManager]` must show round 2 starting with previous round's total. Score display (still on top-right HUD at this point) will still show per-round values -- that is expected. What matters is the log.

---

## Phase 3: User Story 1 - Cumulative Score Persists Across Rounds (Priority: P1)

**Goal**: Cumulative score shown correctly on game over/victory screen; shop receives correct cumulative total.

**Independent Test**: Start run, score ~30 pts in round 1, win round (use debug auto-win if needed), enter shop. Verify shop shows ~30 pts. Then score ~20 pts in round 2, lose. Game over screen must show ~50 pts, not 20.

- [x] T008 [US1] Update the shop display call in `scenes/main.gd` (`_on_shop_requested`) to pass `GameManager.get_cumulative_score()` instead of `GameManager.get_current_score()` in `scenes/main.gd`

- [x] T009 [US1] Add log line in `GameManager.commit_play()` that includes cumulative and target: `print("[GameManager] Play committed: +%d pts | Round: %d | Cumulative: %d | Target: %d | Plays left: %d")` per FR-024 in `autoload/game_manager.gd`

- [x] T010 [US1] Add log line in `GameManager._complete_round(success)` when `success == true` and cumulative score beat the target: `print("[GameManager] Target beaten! Cumulative: %d | Target: %d | Excess: %d")` per FR-025 in `autoload/game_manager.gd`

- [x] T037 [US1] In `autoload/run_manager.gd`, at both run-end emit sites (victory and defeat), build a named log entry that captures the full run result fields: `print("[RunManager] Run ended | Victory: %s | TotalScore: %d | RoundReached: %d" % [str(victory), final_score, run_state.current_round])`. This named log is the leaderboard hook point per FR-005 -- no new class needed for this feature; the data is in `run_ended(victory, total_score)` signal plus `run_state.current_round` in `autoload/run_manager.gd`

**Checkpoint**: Game over screen shows the correct total including the failed round's points. Victory screen shows the correct total. Shop shows cumulative score. Console shows RunManager run-end log with all three fields.

---

## Phase 4: User Story 2 - Realistic Target Score Progression (Priority: P1)

**Goal**: Replace the 1,000,000 target with calibrated quadratic progression. Rounds 1 and 2 clearable with ordinary words.

**Independent Test**: Start a run and score two ordinary 4-letter words per play. Round 1 target (25) should be reachable in 1-2 plays. Round 2 target (65 cumulative) should require 3-4 plays total across both rounds.

- [x] T011 [P] [US2] Change `@export var base_target_score: int = 1000000` to `25` and `@export var target_score_increment: int = 50` to `15` in `data/progression/progression_config.gd`

- [x] T012 [P] [US2] Update `data/progression/progression_default.tres` to set `base_target_score = 25` and `target_score_increment = 15` to match the new defaults (the `.tres` resource overrides `.gd` defaults at runtime). This can be done via Godot editor inspector OR by editing the `.tres` file as plain text (find `base_target_score` and `target_score_increment` keys and change their values). If editing as text, save and reload in the editor to confirm no parse errors in `data/progression/progression_default.tres`

- [x] T013 [US2] Replace `_calculate_target_score(round_number)` with the quadratic formula: `return _config.base_target_score * round_number + _config.target_score_increment * round_number * (round_number - 1) / 2` in `scripts/domain/progression_rules.gd`. Expected: R1=25, R2=65, R3=120, R4=190, R5=275.

- [x] T014 [US2] Update `_apply_boss_target_modifiers(boss, base_target)` to accept a third parameter `round_num: int`, then apply the boss multiplier only to the per-round delta (not the full cumulative): compute `prev_cumulative = _calculate_target_score(round_num - 1) if round_num > 1 else 0`, then `return prev_cumulative + int((base_target - prev_cumulative) * multiplier)` in `scripts/domain/progression_rules.gd`

- [x] T015 [US2] Update both call sites of `_apply_boss_target_modifiers` in `get_round_config()` and `peek_round_config()` to pass the `round_num` argument in `scripts/domain/progression_rules.gd`

- [x] T016 [US2] Add log: `print("[ProgressionRules] Round %d cumulative target: %d" % [round_num, target])` after target calculation in both `get_round_config()` and `peek_round_config()` per FR-024 in `scripts/domain/progression_rules.gd`

**Checkpoint**: Start a run, check Godot console. Round 1 log must show target 25. Round 2 must show 65. Round 3 (Gravity boss) target must be 120 + boss adjustment applied only to the 55-pt per-round delta. Verify round 1 and 2 are clearable in normal play.

---

## Phase 5: User Story 3 - Score Panel at Top Left with Stagger-Matched Pulse (Priority: P2)

**Goal**: ScorePanel visible top-left showing "Y / X" (score / target). Score ticks once per tile slam during the stomp animation, not all at once after.

**Independent Test**: Submit a play with 3 tiles on the board. Watch the score panel: the number must change exactly 3 times, once per tile slam, at ~0.06s intervals. Panel must pulse on each change.

This phase requires refactoring when scores are committed -- currently `main.gd._on_play_completed()` commits scores after all animation. The stagger-matched approach commits per-tile during animation.

- [x] T017 [US3] In `PlayExecutor._execute_play()`, before calling `_animate_play()`, pre-calculate the total play score and per-tile score distribution: call `_word_validator.calculate_placement_score()` for each word, sum the `breakdown[i].tile_score` entries into a `tile_score_map: Dictionary` keyed by tile. Also emit `EventBus.score_calculated` per word as before in `scripts/controllers/play_executor.gd`

- [x] T018 [US3] Add a new method `_commit_scores_staggered(scored_tiles: Array[Tile], tile_score_map: Dictionary)` to `PlayExecutor` that awaits the stomp slam onset (read `StompTileAnimation.RISE_DURATION + StompTileAnimation.SLAM_DURATION` -- do NOT hardcode) then commits each tile's score with a per-tile stagger interval (read `StompTileAnimation.STAGGER_INTERVAL` or equivalent constant -- do NOT hardcode) via `GameManager.commit_play(tile_score_map[tile])` in `scripts/controllers/play_executor.gd`

- [x] T019 [US3] In `PlayExecutor._execute_play()`, launch `_commit_scores_staggered()` without awaiting it (so it runs concurrently), then `await _animate_play(all_tiles)`. The score commits fire during the animation. After the animation completes, ensure `play_completed` still emits once as before in `scripts/controllers/play_executor.gd`

- [x] T036 [US3] Update `PlayExecutor._auto_end_round()` to use the same stagger-matched scoring path as `_execute_play()`: call `_commit_scores_staggered()` concurrently (without await) before `await _animate_play()`, instead of calling `GameManager.commit_play(total_score)` directly. This ensures auto-ended rounds produce the same per-tile score ticking as manually submitted plays in `scripts/controllers/play_executor.gd`

- [x] T020 [US3] Update `main.gd._on_play_completed()` to remove the score calculation and `GameManager.commit_play()` call (scores are now committed inside `PlayExecutor`). The method can remain for other purposes (logging the word list, etc.) but must not commit score a second time in `scenes/main.gd`

- [x] T021 [P] [US3] Create `scenes/ui/score_panel/score_panel.gd`: `extends CanvasLayer` with `@onready` refs to `ScoreLabel` and `Particles` child nodes. Connect to `EventBus.run_round_ready` (update `_target`) and `EventBus.score_updated` (update `_cumulative`, snap label, play pulse). Label format: `"%d / %d" % [_cumulative, _target]` (score first, target second) in `scenes/ui/score_panel/score_panel.gd`

- [x] T022 [P] [US3] Create `scenes/ui/score_panel/score_panel.tscn`: root is `CanvasLayer` (layer=1), child `HBoxContainer` anchored top-left (offset 10, 10), children: `ScoreLabel` (Label, bold font size 22, white) and `Particles` (CPUParticles2D, hidden initially) in `scenes/ui/score_panel/score_panel.tscn`

- [x] T023 [US3] Implement pulse animation in `score_panel.gd`: on each `score_updated` signal, tween `HBoxContainer.scale` from `Vector2.ONE` to `Vector2(1.15, 1.15)` over 0.1s (EASE_OUT, TRANS_BACK) then back to `Vector2.ONE` over 0.15s (EASE_IN, TRANS_QUAD). Kill previous pulse tween before starting a new one in `scenes/ui/score_panel/score_panel.gd`

- [x] T024 [US3] Add ScorePanel instance to `scenes/main.tscn` (instantiate `res://scenes/ui/score_panel/score_panel.tscn` as a child of the main scene root). Add `@onready var _score_panel: CanvasLayer = $ScorePanel` in `scenes/main.gd` in `scenes/main.tscn` and `scenes/main.gd`

**Checkpoint**: Play a round. Watch the top-left panel. Score must tick up once per tile stomp, not in one jump. Panel must pulse each time. After all tiles stomp, the displayed value must exactly equal the new cumulative total. If a play scores 0 pts (no valid words), no change in panel is expected.

---

## Phase 6: User Story 4 - Particle Celebration When Target Is Beaten (Priority: P2)

**Goal**: After a play that causes cumulative score to exceed the round target, particles fire on the score panel. Intensity scales in 4 tiers based on how far above target the score is.

**Independent Test**: Force-score to just above target (5% over) -- no particles. Then score to 35% over target -- full particle burst visible on score panel.

- [x] T025 [US4] Implement `_setup_particles()` in `score_panel.gd`: configure the `CPUParticles2D` child with `one_shot=true`, `explosiveness=0.8`, `lifetime=0.8`, upward direction, color gradient gold->orange->transparent. Call from `_ready()` in `scenes/ui/score_panel/score_panel.gd`

- [x] T026 [US4] Implement `_play_particles()` in `score_panel.gd`: compute `ratio = float(_cumulative - _target) / float(_target)`, then map to 4 tiers -- ratio < 0.05: return (no particles); 0.05-0.15: amount=8, velocity=30-60; 0.15-0.30: amount=20, velocity=60-90; >= 0.30: amount=40, velocity=90-130. Set `_particles.amount` and velocity fields, then call `_particles.show()` followed by `_particles.restart()` (`restart()` requires the node to be visible). Log the tier and ratio per FR-025 in `scenes/ui/score_panel/score_panel.gd`

- [x] T027 [US4] Call `_play_particles()` from `_on_score_updated()` whenever `_cumulative > _target` (re-evaluates every time, handles FR-016: already-beaten target still fires particles on subsequent plays) in `scenes/ui/score_panel/score_panel.gd`

**Checkpoint**: Win a round by exactly 5% -- no particles. Win by 20% -- moderate burst. Win by 40% -- full burst. After winning and continuing to score, each new play still triggers particles at the correct intensity.

---

## Phase 7: User Story 5 - Hard Boss (Priority: P2)

**Goal**: Hard Boss entity in rotation. When active, doubles the per-round score requirement and shows metallic gray background.

**Independent Test**: Trigger a Hard Boss round (advance to round 15 or swap boss order temporarily). Confirm target is higher than a normal round at the same position. Confirm metallic gray background. Win or lose, confirm next round uses normal targets.

- [x] T028 [P] [US5] Create `scripts/domain/bosses/hard_boss.gd`: `class_name HardBossHooks extends BossHooks`, override only `func get_target_score_multiplier() -> float: return 2.0`. No other overrides. No Godot engine imports in `scripts/domain/bosses/hard_boss.gd`

- [x] T029 [US5] Register Hard Boss in `BossRegistry._init()` after the Diagonal boss: `Boss.new(&"hard", "Hard", Color(0.6, 0.6, 0.65), HardBossHooks.new())`, append to `_bosses`, log registration in `scripts/domain/bosses/boss_registry.gd`

- [x] T030 [US5] Add FR-026 logging: in `ProgressionRules.get_round_config()`, after `_apply_boss_target_modifiers()` and only if boss is the Hard boss (`boss.id == &"hard"`), log: `print("[ProgressionRules] Hard Boss active | Per-round delta doubled | Final target: %d" % target)` in `scripts/domain/progression_rules.gd`

**Checkpoint**: Run the game and reach a boss round with Hard Boss active (check log for "[BossRegistry] Registered boss: Hard"). Background is metallic gray. Target is higher. After boss round ends, next round target is not doubled.

---

## Phase 8: User Story 6 - Target Score and Points Removed from Debug Panel (Priority: P3)

**Goal**: Top-right HUD no longer shows Score or Target. All other labels (Round, Plays, Deck, Hand, Discard, Timer) remain.

**Independent Test**: Open gameplay. Top-right panel shows Round, Plays, Deck, Hand, Discard -- no Score or Target rows.

- [x] T031 [US6] Open `scenes/ui/main_hud/main_hud.tscn` in Godot editor and delete the `ScoreLabel` and `TargetLabel` nodes from the scene tree in `scenes/ui/main_hud/main_hud.tscn`

- [x] T032 [US6] Remove from `scenes/ui/main_hud/main_hud.gd`: `@onready var score_label`, `@onready var target_label`, the `_update_score()` method, the `_update_target()` method, the `_on_score_updated()` handler, the `EventBus.score_updated.connect(_on_score_updated)` line, and all calls to `_update_score()` / `_update_target()` in `_initialize_display()`, `_on_round_started()`, and `_on_run_round_ready()` in `scenes/ui/main_hud/main_hud.gd`

**Checkpoint**: No "Score:" or "Target:" text visible anywhere in the top-right panel during gameplay. ScorePanel at top-left still shows both values correctly.

---

## Phase 9: Polish & Cross-Cutting Concerns

- [x] T033 Manually verify all 16 checklist items from `specs/006-score-progression/plan.md` in Godot editor, checking off each item as confirmed

- [x] T034 [P] Update `specs/006-score-progression/research.md` "Score Countup Animation" section to reflect the stagger-matched approach chosen in clarification (replace the post-stomp countup description) in `specs/006-score-progression/research.md`

- [x] T035 [P] Update `specs/006-score-progression/plan.md` Step 5 ScorePanel script to remove the `_countup_tween` variable and `_start_countup()` / `_set_displayed_score()` methods, since per-tile snap is now used instead in `specs/006-score-progression/plan.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies -- start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 -- BLOCKS all user story phases
- **US1 (Phase 3)**: Depends on Foundational
- **US2 (Phase 4)**: Depends on Foundational; can run in parallel with US1
- **US3 (Phase 5)**: Depends on Foundational + US1 (cumulative values must be correct before ScorePanel wires up)
- **US4 (Phase 6)**: Depends on US3 (particles live in ScorePanel)
- **US5 (Phase 7)**: Depends on US2 (boss modifier fix in ProgressionRules)
- **US6 (Phase 8)**: Independent after Foundational; can run any time after T002-T007
- **Polish (Phase 9)**: After all desired stories complete

### User Story Dependencies

```
Phase 2 (Foundational)
  |
  +-- Phase 3 (US1)  ─────────────────────┐
  |                                        |
  +-- Phase 4 (US2)  ──── Phase 7 (US5)   |
  |                                        |
  +-- Phase 8 (US6) (independent)         |
                                           |
  Phase 3 (US1) complete                  |
       |                                  |
       +-- Phase 5 (US3) ─── Phase 6 (US4)|
```

### Parallel Opportunities Within Phases

- **Phase 4**: T011 and T012 can run in parallel (different files)
- **Phase 5**: T021 and T022 (ScorePanel scene + script creation) can run in parallel; T017-T020 (PlayExecutor refactor) must be sequential
- **Phase 7**: T028 (hard_boss.gd creation) can run in parallel with other work

---

## Parallel Execution Example: Phase 5 (US3)

```
Parallel group A (run together):
  T021: Create score_panel.gd
  T022: Create score_panel.tscn

Sequential after A:
  T017: Pre-calculate per-tile scores in PlayExecutor
  T018: Add _commit_scores_staggered() method
  T019: Wire concurrent execution + fix play_completed
  T020: Remove score calculation from main.gd._on_play_completed()
  T023: Implement pulse animation in score_panel.gd
  T024: Add ScorePanel to main.tscn
```

---

## Implementation Strategy

### MVP Scope (Minimum Playable)

Complete Phases 1-4 (Foundational + US1 + US2) to get a fully playable game with correct scoring and realistic targets. The score still shows in the top-right HUD at this point -- that is acceptable for MVP.

1. Phase 1: Setup (T001)
2. Phase 2: Foundational (T002-T007)
3. Phase 3: US1 (T008-T010)
4. Phase 4: US2 (T011-T016)
5. **STOP and VALIDATE**: Play several rounds. Confirm cumulative scoring works. Confirm round 1 and 2 are clearable. Confirm game over shows correct total.

### Full Delivery

Continue with Phases 5-9 after MVP is validated:

5. Phase 5: US3 (score panel + stagger-matched scoring)
6. Phase 6: US4 (particles)
7. Phase 7: US5 (Hard Boss)
8. Phase 8: US6 (cleanup)
9. Phase 9: Polish

---

## Notes

- The most complex implementation is the stagger-matched scoring in Phase 5 (T017-T020). The key insight: `_commit_scores_staggered()` must run concurrently with `_animate_play()` (not awaited first), so GDScript's coroutine model handles both. Launch the score commits, then `await` the animation.
- `GameManager.commit_play()` will be called N times per play (once per tile) after Phase 5. The win condition check inside `commit_play()` fires after each tile -- this is intentional: the round can end mid-stomp if the target is hit on the 3rd of 5 tiles, which is dramatically satisfying.
- `play_completed` must still fire ONCE after all tiles have committed their scores. Do not emit it inside the stomp callbacks.
- `progression_default.tres` is a Godot resource that overrides `.gd` defaults at runtime. T012 MUST be done in the editor or the config change in T011 will have no effect in-game.
- [P] tasks = different files, no blocking dependency on each other within the same phase.
