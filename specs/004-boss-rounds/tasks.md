# Tasks: Boss Rounds and Round Counter

**Input**: Design documents from `/specs/004-boss-rounds/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1-US4)
- No tests requested -- no test tasks generated

---

## Phase 1: Setup

No project setup required. All changes are in-place modifications to an existing Godot 4.6 codebase.

---

## Phase 2: Foundational (Domain Layer -- Blocking Prerequisites)

**Purpose**: Add the `is_boss_round` domain concept to `RoundConfig` and `ProgressionRules`. This is required before any UI story can read round type.

**CRITICAL**: US1, US2, and US3 cannot be implemented until this phase is complete.

- [ ] T001 Add `is_boss_round: bool = false` field to `RoundConfig` in `scripts/domain/round_config.gd`: add the field declaration, add `p_is_boss: bool = false` as the last parameter to `_init()`, assign `is_boss_round = p_is_boss` in the constructor body, and update `_to_string()` to append `" (Boss)"` when `is_boss_round` is true
- [ ] T002 Add boss round classification to `ProgressionRules` in `scripts/domain/progression_rules.gd`: add `func _is_boss_round(round_number: int) -> bool: return round_number % 3 == 0`, then in `get_round_config()` compute `var is_boss := _is_boss_round(round_num)` and pass it as the final argument to `RoundConfig.new()`

**Checkpoint**: Domain layer is ready. `EventBus.run_round_ready` now emits a `RoundConfig` with `is_boss_round` set correctly. UI stories can begin.

---

## Phase 3: User Story 1 -- Round Counter Display (Priority: P1) MVP

**Goal**: Remove the MULTI [Q] indicator from the gameplay screen and place a new standalone "Round X" / "Boss Round" label in its position (top-left).

**Independent Test**: Start a game. Top-left shows "Round 1". Reach Round 3 and top-left shows "Boss Round". No MULTI [Q] text appears anywhere.

- [ ] T003 [US1] Edit `scenes/main.tscn`: remove the `[ext_resource ... path="res://scenes/ui/multi_select_indicator/multi_select_indicator.tscn" id="6_multi"]` entry and the `[node name="MultiSelectIndicator" ...]` node entry; add a `[node name="RoundIndicator" type="Label" parent="."]` node with `anchors_preset = 1` (top-right of its own offset), `offset_left = 20.0`, `offset_top = 20.0`, `offset_right = 120.0`, `offset_bottom = 34.0`, and `theme_override_font_sizes/font_size = 11`, `text = "Round 1"`
- [ ] T004 [US1] Update `scenes/main.gd`: remove `@onready var multi_select_indicator: Control = $MultiSelectIndicator`; remove the `multi_select_indicator.set_selection_manager(_selection_manager)` call from `_setup_selection_manager()`; add `@onready var _round_indicator: Label = $RoundIndicator`; in `_on_round_ready(config: RoundConfig)` add `_round_indicator.text = "Boss Round" if config.is_boss_round else "Round %d" % config.round_number` (place this before or after the board resize call, but before `_show_gameplay_ui()`)

**Checkpoint**: US1 complete. Round label updates correctly on every round transition. MULTI [Q] indicator is gone. Multi-select mechanic (Q key) still functions.

---

## Phase 4: User Story 2 -- Boss Round Visual Signal (Priority: P2)

**Goal**: Change the gameplay background to white (Normal) or light red (Boss) when each Round begins.

**Independent Test**: Normal rounds have a white background. Round 3 has a light red background. Round 4 returns to white. New game always starts white.

**Note**: T005 edits `main.tscn` again. The Background ColorRect must be the FIRST child of Main in the file so it renders behind all other nodes.

- [ ] T005 [US2] Edit `scenes/main.tscn`: insert a `[node name="Background" type="ColorRect" parent="."]` entry as the FIRST node under Main (before the Board node), with `layout_mode = 3`, `anchors_preset = 15`, `anchor_right = 1.0`, `anchor_bottom = 1.0`, `grow_horizontal = 2`, `grow_vertical = 2`, `color = Color(1, 1, 1, 1)` (white default)
- [ ] T006 [US2] Update `scenes/main.gd`: add `@onready var _background: ColorRect = $Background`; add `var _bg_tween: Tween = null`; add a private method `_transition_background(target_color: Color) -> void` that kills any active `_bg_tween`, creates a new Tween, and tweens `_background.color` to `target_color` over 1.0 seconds using `TRANS_SINE / EASE_IN_OUT`; in `_on_round_ready(config: RoundConfig)` call `_transition_background(Color(1.0, 0.85, 0.85, 1.0) if config.is_boss_round else Color(1.0, 1.0, 1.0, 1.0))` (alongside the T004 round label line)

**Checkpoint**: US2 complete. Background fades smoothly (1.0s) to light red on Boss rounds and back to white on Normal rounds. Transition is eased with no flicker.

---

## Phase 5: User Story 3 -- Boss Round Domain Extensibility (Priority: P2)

**Goal**: Confirm that the visual changes added in US1 and US2 are driven by the `config.is_boss_round` domain property, not by a raw numeric check in the UI layer.

**Independent Test**: Inspect `scenes/main.gd._on_round_ready()` -- no `% 3` or `round_number` arithmetic should appear in the visual-update lines.

- [ ] T007 [US3] Review `scenes/main.gd._on_round_ready()` to verify: (a) the round label text is set from `config.is_boss_round`, not from `config.round_number % 3`; (b) the background color is set from `config.is_boss_round`, not from inline arithmetic; (c) if any modulo logic crept in, move it to `ProgressionRules._is_boss_round()` in `scripts/domain/progression_rules.gd` where it belongs

**Checkpoint**: US3 complete. Any future game system can query `config.is_boss_round` from the `run_round_ready` event to apply Boss Round rules without touching ProgressionRules.

---

## Phase 6: User Story 4 -- Autowin Modifier Language Update (Priority: P3)

**Goal**: Update the Auto Win modifier description to use canonical "Plays" and "Rounds" terminology.

**Independent Test**: In the run modifier selection screen, Auto Win description contains "Plays" and "Rounds" (capitalized) and no synonyms.

- [ ] T008 [P] [US4] Update `scripts/domain/qualities/auto_win_quality.gd`: in `get_description()` change the string from `"Exhaust your %d plays to win each round. Run ends after %d rounds."` to `"Exhaust your %d Plays to win each Round. Run ends after %d Rounds."` (capitalize Plays and Rounds throughout)

**Checkpoint**: US4 complete. Auto Win modifier text matches the canonical ubiquitous language.

---

## Phase 7: Polish & Verification

**Purpose**: End-to-end manual validation across all user stories.

- [ ] T009 Run all 6 test scenarios from `specs/004-boss-rounds/quickstart.md` manually in the Godot 4.6 editor: Tests 1-4 verify round label and background across Rounds 1-9, Test 5 confirms MULTI [Q] is gone, Test 6 confirms Auto Win modifier text. Use the Fast Path (Auto Win modifier) to reach Round 3 quickly.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Foundation (Phase 2)**: No dependencies -- start immediately. BLOCKS all UI stories.
- **US1 (Phase 3)**: Depends on Phase 2 (reads `config.is_boss_round`)
- **US2 (Phase 4)**: Depends on Phase 2. Depends on Phase 3 (both edit `main.tscn` and `main.gd`; sequential file edits)
- **US3 (Phase 5)**: Depends on Phase 3 and Phase 4 (reviews their output)
- **US4 (Phase 6)**: Independent of US1-US3. Can run any time after Phase 2.
- **Polish (Phase 7)**: Depends on all phases complete

### User Story Dependencies

- **US1 (P1)**: Starts after Foundation -- no story dependencies
- **US2 (P2)**: Starts after US1 (shares `main.tscn` and `main.gd`)
- **US3 (P2)**: Starts after US1 and US2 (verification only)
- **US4 (P3)**: [P] -- independent of US1/US2/US3, different file entirely

### Within Each Phase

- T001 before T002 (T002 uses the new `is_boss_round` param from T001)
- T003 before T004 (node must exist in scene before `@onready` can reference it)
- T005 before T006 (same reason)
- T007 after T004 and T006 (reviews their output)
- T008 any time after T001 (independent file, [P])
- T009 after all tasks complete

### Parallel Opportunities

- T008 [P] can run in parallel with T003-T007 (completely separate file)
- T001 and T002 are sequential (dependency)
- T003-T006 are sequential (shared files: main.tscn, main.gd)

---

## Parallel Example

```text
# Once Foundation (T001, T002) is complete:

Stream A (scene/controller changes):
  T003 -> T004 -> T005 -> T006 -> T007

Stream B (domain quality text, independent):
  T008  [can run any time -- different file]
```

---

## Implementation Strategy

### MVP First (US1 Only)

1. Complete Phase 2 (Foundation): T001, T002
2. Complete Phase 3 (US1): T003, T004
3. **STOP and VALIDATE**: MULTI [Q] is gone, round label shows correctly through Round 3+
4. Continue to Phase 4+ when ready

### Full Feature (Sequential)

1. T001 -> T002 (Foundation)
2. T003 -> T004 (US1: label)
3. T005 -> T006 (US2: background)
4. T007 (US3: verification)
5. T008 in parallel at any point (US4: text)
6. T009 (full end-to-end verification)

---

## Notes

- [P] tasks have no file conflicts with concurrently running tasks
- Scene file (main.tscn) is edited twice (T003 and T005); do each edit fully before moving to the next
- The Background ColorRect (T005) MUST be the first child node in main.tscn for correct rendering order
- The top-right stats panel (MainHUD labels) is NOT touched -- it is a debug panel scheduled for future removal
- Commit after Phase 2 checkpoint and after each story checkpoint for clean rollback points
