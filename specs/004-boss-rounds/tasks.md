# Tasks: Boss Rounds and Round Counter

**Input**: Design documents from `/specs/004-boss-rounds/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1-US5)
- No tests requested -- no test tasks generated

---

## Phase 1: Setup

No project setup required. All changes are in-place modifications to an existing Godot 4.6 codebase.

---

## Phase 2: Foundational (Domain Layer -- Blocking Prerequisites)

**Purpose**: Add the `is_boss_round` domain concept to `RoundConfig` and `ProgressionRules`. This is required before any UI story can read round type.

**CRITICAL**: US1, US2, US3, and US5 cannot be implemented until this phase is complete.

- [x] T001 Add `is_boss_round: bool = false` field to `RoundConfig` in `scripts/domain/round_config.gd`: add the field declaration, add `p_is_boss: bool = false` as the last parameter to `_init()`, assign `is_boss_round = p_is_boss` in the constructor body, and update `_to_string()` to append `" (Boss)"` when `is_boss_round` is true
- [x] T002 Add boss round classification to `ProgressionRules` in `scripts/domain/progression_rules.gd`: add `func _is_boss_round(round_number: int) -> bool: return round_number % 3 == 0`, then in `get_round_config()` compute `var is_boss := _is_boss_round(round_num)` and pass it as the final argument to `RoundConfig.new()`

**Checkpoint**: Domain layer is ready. `EventBus.run_round_ready` now emits a `RoundConfig` with `is_boss_round` set correctly. UI stories can begin.

---

## Phase 2b: Foundational (Global Background Infrastructure)

**Purpose**: Create BackgroundManager autoload for persistent, global background color management across all scenes.

**CRITICAL**: US2 and US5 depend on BackgroundManager.

- [ ] T010 Create `autoload/background_manager.gd`: new autoload script with `var _current_color: Color` (default blue-gray 0.85, 0.88, 0.92), signal `color_changed(new_color: Color)`, method `set_color(color: Color)` that kills any active tween and tweens to the new color over 1.0s, method `reset_to_default()` that sets color back to blue-gray. No Godot nodes, pure state management.
- [ ] T011 Register BackgroundManager in `project.godot` under `[autoload]` section as `BackgroundManager = "res://autoload/background_manager.gd"`.
- [ ] T012 Update `autoload/run_manager.gd` in `initialize_run_from_builder()` to call `BackgroundManager.reset_to_default()` when a new run starts.

**Checkpoint**: BackgroundManager is ready. All scenes can now access the global background color and react to changes.

---

## Phase 3: User Story 1 -- Round Counter Display (Priority: P1) MVP

**Goal**: Remove the MULTI [Q] indicator from the gameplay screen and place a new standalone "Round X" / "Boss Round" label in its position (top-left).

**Independent Test**: Start a game. Top-left shows "Round 1". Reach Round 3 and top-left shows "Boss Round". No MULTI [Q] text appears anywhere.

- [x] T003 [US1] Edit `scenes/main.tscn`: remove the `[ext_resource ... path="res://scenes/ui/multi_select_indicator/multi_select_indicator.tscn" id="6_multi"]` entry and the `[node name="MultiSelectIndicator" ...]` node entry; add a `[node name="RoundIndicator" type="Label" parent="."]` node with `anchors_preset = 0`, `offset_left = 20.0`, `offset_top = 20.0`, `offset_right = 120.0`, `offset_bottom = 34.0`, `theme_override_font_sizes/font_size = 11`, `text = "Round 1"`
- [x] T004 [US1] Update `scenes/main.gd`: remove `@onready var multi_select_indicator: Control = $MultiSelectIndicator`; remove the `multi_select_indicator.set_selection_manager(_selection_manager)` call from `_setup_selection_manager()`; add `@onready var _round_indicator: Label = $RoundIndicator`; in `_on_round_ready(config: RoundConfig)` add `_round_indicator.text = "Boss Round" if config.is_boss_round else "Round %d" % config.round_number` (place alongside the background update)

**Checkpoint**: US1 complete. Round label updates correctly on every round transition. MULTI [Q] indicator is gone. Multi-select mechanic (Q key) still functions.

---

## Phase 4: User Story 2 -- Boss Round Visual Signal (Priority: P2)

**Goal**: Change the gameplay background to blue-gray (Normal) or light red (Boss) when each Round begins, with smooth 1.0s transitions. Background persists across scene changes.

**Independent Test**: Normal rounds show blue-gray bg. Round 3 shows light red. Background persists on game over/shop screens until new game starts.

- [x] T005 [US2] Edit `scenes/main.tscn`: insert a `[node name="Background" type="ColorRect" parent="."]` entry as the FIRST node under Main (before the Board node), with `layout_mode = 3`, `anchors_preset = 15`, `anchor_right = 1.0`, `anchor_bottom = 1.0`, `grow_horizontal = 2`, `grow_vertical = 2`, `color = Color(0.85, 0.88, 0.92, 1)` (blue-gray default)
- [x] T006 [US2] Update `scenes/main.gd`: add `@onready var _background: ColorRect = $Background`; add `var _bg_tween: Tween = null`; add private method `_transition_background(target_color: Color) -> void` that kills any active `_bg_tween`, creates a new Tween, and tweens `_background.color` to `target_color` over 1.0s using `TRANS_SINE / EASE_IN_OUT`; in `_on_round_ready(config: RoundConfig)` call `_transition_background(Color(1.0, 0.85, 0.85, 1.0) if config.is_boss_round else Color(0.85, 0.88, 0.92, 1.0))`; also call `BackgroundManager.set_color(...)` with the same color to persist across scenes
- [ ] T013 [P] [US2] Update `scenes/title_screen/title_screen.gd`: add signal connection to `BackgroundManager.color_changed` that updates a Background ColorRect (add as child of root node if not present) in real-time, respecting the persisted color from previous runs.
- [ ] T014 [P] [US2] Verify `scenes/shop/shop_overlay.gd` exists. If it does, add a `@onready var _background: ColorRect` reference and connect `BackgroundManager.color_changed.connect(_on_background_color_changed)` where `_on_background_color_changed(color: Color)` updates `_background.color = color`. If file does not exist, create it with the above code as a new controller script for the shop overlay.
- [ ] T015 [P] [US2] Update `scenes/ui/game_over_popup/game_over_popup.gd`: add Background ColorRect child and connect to `BackgroundManager.color_changed` signal.

**Checkpoint**: US2 complete. Background is blue-gray on Normal rounds, light red on Boss rounds, persists across all scenes, transitions smoothly over 1.0s, resets to blue-gray only on new game.

---

## Phase 5: User Story 3 -- Boss Round Domain Extensibility (Priority: P2)

**Goal**: Confirm that visual changes are driven by the `config.is_boss_round` domain property, not raw numeric checks.

**Independent Test**: Inspect `scenes/main.gd._on_round_ready()` -- no `% 3` or `round_number` arithmetic in visual-update code.

- [x] T007 [US3] Review `scenes/main.gd._on_round_ready()` to verify: (a) round label text set from `config.is_boss_round`, not from arithmetic; (b) background color set from `config.is_boss_round`, not from inline arithmetic; (c) all logic flows through domain layer.

**Checkpoint**: US3 complete. Future systems can query `config.is_boss_round` to apply Boss Round rules.

---

## Phase 6: User Story 4 -- Autowin Modifier Language Update (Priority: P3)

**Goal**: Update Auto Win modifier description to use canonical "Plays" and "Rounds" terminology.

**Independent Test**: Auto Win description contains "Plays" and "Rounds" (capitalized), no synonyms.

- [x] T008 [P] [US4] Update `scripts/domain/qualities/auto_win_quality.gd`: in `get_description()` change string from `"Exhaust your %d plays to win each round. Run ends after %d rounds."` to `"Exhaust your %d Plays to win each Round. Run ends after %d Rounds."`

**Checkpoint**: US4 complete. Auto Win text matches canonical language.

---

## Phase 7: User Story 5 -- Global Persistent Background (Priority: P2)

**Goal**: Background color persists across all scenes during a run and resets only on new game start.

**Independent Test**: Play to Round 3 (red bg). Lose/complete round. Verify red bg persists on game over → title. Start new game. Verify bg resets to blue-gray.

- [ ] T016 [US5] Read `autoload/background_manager.gd` and verify: (a) `_current_color` defaults to blue-gray; (b) `reset_to_default()` method exists and sets color back to blue-gray; (c) `set_color()` method tweens over 1.0s; (d) `color_changed` signal is emitted on color change.
- [ ] T017 [US5] Verify all UI scenes have Background ColorRects and active connections to `BackgroundManager.color_changed`: inspect title_screen.gd, shop_overlay.gd, game_over_popup.gd for the signal connection. Each must update its local Background ColorRect on signal emit.
- [ ] T018 [US5] Manual test: Play to Boss Round, end round, verify color persists on shop/game-over screens, return to title, verify color still persists, start new game, verify color resets to blue-gray.

**Checkpoint**: US5 complete. Global background system fully integrated and persistent.

---

## Phase 8: Polish & Verification

**Purpose**: End-to-end manual validation across all user stories.

- [ ] T009 Run all 6 test scenarios from `specs/004-boss-rounds/quickstart.md` manually in Godot 4.6 editor: Tests 1-4 verify round label and background across Rounds 1-9, Test 5 confirms MULTI [Q] is gone, Test 6 confirms Auto Win modifier text. Use Auto Win modifier fast path to reach Round 3 quickly.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Foundation (Phase 2)**: No dependencies -- start immediately. BLOCKS all UI stories.
- **Foundation 2b (Phase 2b)**: Depends on Phase 2 (reads `config.is_boss_round`). BLOCKS US2 and US5.
- **US1 (Phase 3)**: Depends on Phase 2
- **US2 (Phase 4)**: Depends on Phase 2 and Phase 2b. Sequential edits to main.tscn/gd (T005-T006); parallel updates to all other scenes (T013-T015)
- **US3 (Phase 5)**: Depends on Phase 3 and Phase 4 (verification only)
- **US4 (Phase 6)**: Independent of US1-US3. Can run any time after Phase 2.
- **US5 (Phase 7)**: Depends on Phase 2b and Phase 4 (integration verification)
- **Polish (Phase 8)**: Depends on all phases complete

### Sequential Within Phases

- T001 before T002 (T002 uses new param from T001)
- T010 before T011 (autoload script before registration)
- T011 before T012 (autoload must exist before RunManager calls it)
- T003 before T004 (node must exist before @onready references it)
- T005 before T006 (scene structure before code references it)
- T013, T014, T015 can run in parallel [P]
- T012 before T016 (BackgroundManager integration verification)

### Parallel Opportunities

- T013, T014, T015 [P] (separate scene files, no dependencies)
- T008 [P] (independent quality file)
- T001 and T002 are sequential but T010-T012 can run in parallel with them

---

## Parallel Example

```text
# Phase 2 + 2b can overlap:
Stream A (Domain):
  T001 -> T002 -> done

Stream B (BackgroundManager):
  T010 -> T011 -> T012 -> done

# Phase 4 (once Phase 2b done):
Stream C (main.tscn/gd):
  T005 -> T006 -> done

Stream D (other scenes, parallel):
  T013, T014, T015 [P]

# Phase 6 (independent):
Stream E (quality text):
  T008 [P] can run any time after T001
```

---

## Implementation Strategy

### MVP First (US1 Only)

1. Complete Phase 2 (Foundation): T001, T002
2. Complete Phase 3 (US1): T003, T004
3. **STOP and VALIDATE**: Round label correct, MULTI [Q] gone
4. Continue to Phase 2b+ when ready for full feature

### Full Feature (Sequential with Parallelization)

1. T001 -> T002 (Foundation - domain layer)
2. T010 -> T011 -> T012 (Foundation 2b - BackgroundManager)
3. T003 -> T004 (US1: label)
4. T005 -> T006 + (T013, T014, T015 parallel) (US2: backgrounds)
5. T007 (US3: verification)
6. T008 (US4: text, can run anytime after T001)
7. T016, T017, T018 (US5: persistence verification)
8. T009 (full end-to-end verification)

---

## Notes

- [P] tasks have no file conflicts with concurrent tasks
- BackgroundManager is stateless domain-like component (no Godot scene nodes)
- All scenes must have a Background ColorRect child node
- Color transitions are standardized (1.0s SINE easing) across all scenes
- Manual testing required for persistence validation (T018)
- Commit at each phase checkpoint for clean rollback points
