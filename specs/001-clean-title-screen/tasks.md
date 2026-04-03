---
description: "Task list for Clean and Enhance Title Screen"
---

# Tasks: Clean and Enhance Title Screen

**Input**: Design documents from `/specs/001-clean-title-screen/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: No test tasks - manual verification per quickstart.md (no automated test framework integrated).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US3, US2 -- ordered by priority: US1+US3 are P1, US2 is P2)
- Include exact file paths in descriptions

---

## Phase 1: Foundational (Blocking Prerequisite)

**Purpose**: Delete the options popup files before any code edits reference them.
Without this, the Godot scene importer may report missing resource errors while editing.

- [x] T001 Delete `scenes/title_screen/options_popup.gd`, `scenes/title_screen/options_popup.gd.uid`, and `scenes/title_screen/options_popup.tscn`

**Checkpoint**: Three files gone. No other changes yet - engine will error if the game is run now.

---

## Phase 2: User Story 1 - Remove Options Button (Priority: P1)

**Goal**: Options button and all related code removed; title screen shows only "New Game" and "Exit".

**Independent Test**: Run the game and confirm only two menu buttons appear. Navigate with arrow keys
to verify focus wraps between them. Confirm "New Game" opens the Run Setup modal.

### Implementation for User Story 1

- [x] T002 [US1] In `scripts/controllers/menu_controller.gd`: remove `options_requested` signal declaration; change `setup(new_game_btn, options_btn, exit_btn)` to `setup(new_game_btn, exit_btn)`; remove `_options_button` field; change `_menu_items` initialization to `[new_game_btn, exit_btn]`; remove `_on_options_pressed()` method and its `pressed.connect` call; remove `options_requested.emit()` call
- [x] T003 [P] [US1] In `scenes/title_screen/title_screen.gd`: remove `@onready var _options_button` and `@onready var _options_popup`; remove `options_requested.connect(...)` line; remove `_options_popup.closed.connect(...)` line; change `_menu_controller.setup(_new_game_button, _options_button, _exit_button)` to `_menu_controller.setup(_new_game_button, _exit_button)`; remove `_on_options_requested()` method; remove `_on_options_closed()` method and the `# OPTIONS POPUP` section comment block
- [x] T004 [P] [US1] In `scenes/title_screen/title_screen.tscn`: remove the `[ext_resource]` line referencing `options_popup.tscn`; remove the `[node name="OptionsButton" ...]` block entirely; remove the `[node name="OptionsPopup" ...]` line; change `NewGameButton.focus_neighbor_bottom` from `NodePath("../OptionsButton")` to `NodePath("../ExitButton")`; change `ExitButton.focus_neighbor_top` from `NodePath("../OptionsButton")` to `NodePath("../NewGameButton")`

**Checkpoint**: Open project in Godot Editor - no missing node errors. Run game and verify title
screen shows only "New Game" and "Exit". Arrow keys navigate between them. "New Game" opens Run
Setup (FR-003 -- confirm this still works after signal path changes). "Exit" closes the game.

---

## Phase 3: User Story 3 - Simplify Quality Selection (Priority: P1)

**Goal**: Run Setup modal shows only "Auto Win (10 Plays)" quality; all other qualities hidden.

**Independent Test**: Open Run Setup modal and confirm the "Select Qualities" section contains
only a single checkbox labeled "Auto Win (10 Plays)" with its description text.

### Implementation for User Story 3

- [x] T005 [US3] In `scenes/title_screen/run_setup_popup.gd`: add constant `const VISIBLE_QUALITIES: Array[StringName] = [&"auto_win"]` near the top of the class (after the existing constants section); in `_populate_quality_list()`, immediately after `var id := ids[i]`, add `if id not in VISIBLE_QUALITIES: continue`

**Checkpoint**: Run game, click "New Game", confirm only Auto Win quality is visible. Toggle it
on/off. Confirm "Start Run" with Auto Win enabled starts the game correctly.

---

## Phase 4: User Story 2 - Keyboard Navigation (Priority: P2)

**Goal**: Confirm all title screen elements are reachable via arrow keys, Enter, and ESC only.

**Independent Test**: Complete quickstart.md step 6 (Full Keyboard Run) without touching the mouse.

**Note**: Research confirmed keyboard navigation is already fully wired (MenuController handles
ui_up/ui_down + ui_accept; RunSetupPopup forwards WASD to Godot focus and handles ui_accept +
ModalInputGuard for ESC). No code changes are expected in this phase - this is a verification phase.

### Implementation for User Story 2

- [x] T006 [US2] Verify keyboard focus starts on "New Game" button when title screen opens - check `menu_controller.gd` `activate()` calls `_focus_item(0)` and `_menu_items[0]` is `_new_game_button`; if initial focus is incorrect, fix `activate()` to grab focus on the correct first item
- [x] T007 [P] [US2] Verify `run_setup_popup.gd` `show_popup()` grabs focus on `_start_button` (Start Run button) per FR-010; verify the Start Run button is visually highlighted when focused (SC-004); confirm Auto Win checkbox is reachable from Start Run via Down arrow and that focused elements are visually distinct from unfocused ones

**Checkpoint**: Run quickstart.md steps 3, 4, and 5 using keyboard only. All pass without issues.

---

## Phase 5: Polish and Verification

**Purpose**: Final cleanup and end-to-end manual test confirmation.

- [x] T008 [P] Grep codebase for any remaining references to `options_popup`, `_options_button`, `options_requested`, or `OptionsButton` in files other than the deleted ones; remove any orphaned references found
- [ ] T009 Run quickstart.md full test suite (all 7 steps) and confirm all pass  <!-- MANUAL: run in Godot Editor -->
- [x] T010 [P] Verify Godot Editor shows no errors, warnings, or missing resource messages for `scenes/title_screen/title_screen.tscn`

---

## Dependencies and Execution Order

### Phase Dependencies

- **Foundational (Phase 1)**: No dependencies - start here (delete files first)
- **User Story 1 (Phase 2)**: Depends on Phase 1 (T001 must be complete; options files must be deleted before editing scene)
- **User Story 3 (Phase 3)**: Independent of Phase 2 - can start after Phase 1 completes (different file: run_setup_popup.gd)
- **User Story 2 (Phase 4)**: Depends on Phase 2 + Phase 3 (verification requires both complete)
- **Polish (Phase 5)**: Depends on all user stories complete

### User Story Dependencies

- **US1 (Phase 2)**: T002 must complete before T003 and T004 (MenuController signature change must land before TitleScreen call-site update)
- **US3 (Phase 3)**: T005 is independent of all US1 tasks (different file)
- **US2 (Phase 4)**: T006 and T007 are independent of each other [P]

### Parallel Opportunities

Once Phase 1 (T001) completes:
- T003 and T004 can run in parallel after T002 completes
- T005 can run in parallel with T002/T003/T004 (entirely different file)
- T006 and T007 can run in parallel with each other

```text
T001 (delete files)
  |
  +-- T002 (menu_controller.gd) --> T003 (title_screen.gd) [parallel]
  |                              \-> T004 (title_screen.tscn) [parallel]
  |
  +-- T005 (run_setup_popup.gd) [independent, parallel with T002-T004]

T003 + T004 + T005 done
  |
  +-- T006, T007 [parallel verification]
  |
  +-- T008, T009, T010
```

---

## Implementation Strategy

### MVP (All Stories are P1/P2 - complete in order)

1. Complete Phase 1: Delete options files (T001)
2. Complete Phase 2: Remove Options button code (T002 -> T003+T004)
3. Complete Phase 3: Filter quality list (T005)
4. **STOP and VALIDATE**: Run game, confirm title screen clean, Run Setup shows only Auto Win
5. Complete Phase 4: Verify keyboard navigation (T006, T007)
6. Complete Phase 5: Polish + full quickstart test

### Parallel Approach (Single Developer)

T001 -> T002 -> [T003 + T004 + T005 in parallel] -> [T006 + T007] -> [T008 + T010] -> T009

---

## Notes

- [P] = different files, no dependencies on incomplete sibling tasks
- US3 (T005) is a 2-line change - can be done any time after T001
- No new files are created; all tasks are modifications or deletions
- If Godot editor shows parse errors after T001, that is expected - will resolve after T002-T004
- Verify tests fail before implementing - N/A here (no automated tests; use quickstart.md)
- Commit after Phase 2 checkpoint and again after Phase 3 checkpoint for clean git history
