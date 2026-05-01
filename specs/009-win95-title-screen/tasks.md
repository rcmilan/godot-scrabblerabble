# Tasks: Win95 UI Overhaul - Title Screen

**Input**: Design documents from `/specs/009-win95-title-screen/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: Not requested. All verification is manual in the Godot Editor (Constitution Principle V).

**Organization**: Tasks grouped by user story. Each story is independently testable.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no shared state)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)

---

## Phase 1: Setup (Asset Acquisition)

**Purpose**: Copy Win95 design system assets from reference repo into the project. No Godot Editor required.

- [x] T001 [P] Download and copy the `theme/` directory from `https://github.com/rcmilan/godot-design-95` into the project root, preserving full subdirectory structure (`theme/button/`, `theme/checkbox/`, `theme/fonts/`, `theme/lineedit/`, `theme/menubar/`, `theme/panel/`, `theme/radiobutton/`, `theme/titlebar/`, `theme/window/`). Do NOT copy any `.import` files.
- [x] T002 [P] Download and copy `fonts/W95FA.otf` from `https://github.com/rcmilan/godot-design-95` into the project root `fonts/` directory (create `fonts/` if it does not exist).

---

## Phase 2: Foundational (Godot Project Configuration)

**Purpose**: Wire the Win95 theme into the Godot project settings. MUST be complete before any scene work.

**WARNING**: All three edits below target `project.godot`. Apply them sequentially in one editing session to avoid conflicts.

- [x] T003 Add `textures/canvas_textures/default_texture_filter=0` under the `[rendering]` section in `project.godot` to enable nearest-neighbor filtering globally.
- [x] T004 Add `config/custom_theme="res://theme/webcore_theme.tres"` under the `[application]` section in `project.godot` to register the Win95 theme as the project theme.
- [x] T005 Add `ThemeSetup="*res://theme/ThemeSetup.gd"` under the `[autoload]` section in `project.godot`, after the existing autoload entries.
- [ ] T006 Open the project in Godot Editor. Confirm zero import errors appear in the Output panel for files under `theme/` and `fonts/`. Then add a temporary `Button` node to any scene, verify it renders with Win95 raised-border style without any `theme_override_*` properties set, and delete the test node.

**Checkpoint**: Win95 theme is globally active. Any new Button, Panel, or Label renders in Win95 style automatically.

---

## Phase 3: User Story 1 - Win95 Theme on Main Menu (Priority: P1) MVP

**Goal**: Title screen renders with Win95 aesthetics - teal background, window panel, navy title bar, Win95 buttons. All existing keyboard navigation preserved.

**Independent Test**: Launch the game (F5). Verify Win95 window panel and title bar are visible, background is teal, "New Game" and "Exit" buttons have raised Win95 borders, W/S/Enter navigation works, and Exit quits the game.

- [x] T007 [P] [US1] In `autoload/background_manager.gd`, change the default/initial background color value to `Color("#008080")` (Win95 teal). Preserve all existing BackgroundManager animation logic.
- [x] T008 [US1] In `scenes/title_screen/title_screen.tscn`, wrap the existing MenuView content in a new `Panel` node. Set its `theme_type_variation` property to `"WindowPanel"`. Position and size it to be centered on screen with appropriate Win95 window dimensions.
- [x] T009 [US1] In `scenes/title_screen/title_screen.tscn`, add a `Panel` node as the first child of the WindowPanel with `theme_type_variation = "TitleBarActive"`. Inside it, add a `Label` with `theme_type_variation = "TitleBarLabel"` displaying the game name. The title bar must be decorative only (no close/minimize/maximize buttons).
- [x] T010 [US1] In `scenes/title_screen/title_screen.tscn`, remove all `theme_override_font_sizes/*` and `theme_override_colors/*` properties from every `Button` and `Label` node (NewGameButton, ExitButton, TitleLabel, ControlHint). Styling must come from the project theme only.
- [ ] T011 [US1] Manually verify in Godot Editor (F5): title screen shows Win95 window panel with navy title bar, teal background, Win95-styled buttons. Confirm W/S/Enter keyboard navigation works and Exit quits the game. Fix any visual regressions before proceeding.

**Checkpoint**: User Story 1 complete. Title screen is fully Win95-styled with zero regressions.

---

## Phase 4: User Story 2 - Win95 Theme on Run Builder (Priority: P2)

**Goal**: Run Builder dialog renders with Win95 styling - WindowPanel container, "RUN SETUP" title bar, Win95 form controls. All deck/quality selection and navigation preserved.

**Independent Test**: Press "New Game" to reach Run Builder. Verify Win95 window panel and "RUN SETUP" title bar visible. Confirm deck OptionButton, quality checkboxes, Back, and Start all function correctly.

- [x] T012 [US2] In `scenes/title_screen/run_setup_popup.tscn`, wrap the existing content in a new `Panel` node with `theme_type_variation = "WindowPanel"`. Ensure RunSetupView root node remains a `Control` (NOT a Window or Popup - Win95 appearance is cosmetic only).
- [x] T013 [US2] In `scenes/title_screen/run_setup_popup.tscn`, add a `Panel` node with `theme_type_variation = "TitleBarActive"` as the first child of the WindowPanel. Add a `Label` inside it with `theme_type_variation = "TitleBarLabel"` and text `"RUN SETUP"`. No window control buttons.
- [x] T014 [US2] In `scenes/title_screen/run_setup_popup.tscn`, remove all `theme_override_font_sizes/*` and `theme_override_colors/*` properties from every Button, Label, and OptionButton node (DeckLabel, DeckDescription, QualitiesLabel, DeckOption, BackButton, StartButton, ControlHint). Styling must come from the project theme only.
- [x] T015 [P] [US2] In `scenes/title_screen/run_setup_popup.gd`, find the code that creates `CheckBox` nodes dynamically for the quality list. After each `CheckBox.new()` instantiation, add `checkbox.theme_type_variation = "Win95Checkbox"` so dynamically-created checkboxes inherit Win95 styling.
- [ ] T016 [US2] Manually verify in Godot Editor (F5): press "New Game", confirm Run Builder shows Win95 WindowPanel and "RUN SETUP" title bar, all controls render in Win95 style. Confirm deck selection, quality toggle, Back (returns to menu), and Start (launches game) all function correctly.

**Checkpoint**: User Stories 1 and 2 complete. Both screens are Win95-styled with zero regressions.

---

## Phase 5: User Story 3 - Reusable Theme Architecture (Priority: P3)

**Goal**: Confirm zero per-node style overrides remain across both scenes, and that the theme system is properly reusable (new nodes auto-style without manual configuration).

**Independent Test**: Inspect any node in title_screen.tscn or run_setup_popup.tscn in the editor and confirm no `theme_override_*` properties are set. Add a fresh Button to the title screen and confirm Win95 style applies without any manual property setting.

- [x] T017 [US3] Perform a final audit of `scenes/title_screen/title_screen.tscn` and `scenes/title_screen/run_setup_popup.tscn`: search both files for any remaining `theme_override` strings. Remove every occurrence found. The `.tscn` file text must contain zero `theme_override` entries on Button, Label, Panel, or CheckBox nodes. NOTE: 4 `theme_override_constants/separation` entries remain on VBoxContainer/HBoxContainer layout nodes - these are outside FR-008's scope and preserved intentionally for correct layout spacing.
- [ ] T018 [P] [US3] Verify theme reusability: in Godot Editor, add a new `Button` node to `scenes/title_screen/title_screen.tscn`. Confirm it displays Win95 raised-border style with no properties set manually. Delete the test node and save the scene.
- [ ] T019 [P] [US3] Verify no import errors: open Godot Editor Output panel and confirm no missing resource, broken path, or import failure messages for any file under `theme/` or `fonts/`.

**Checkpoint**: All three user stories complete. Theme system is globally active, reusable, and has zero per-node overrides.

---

## Phase 6: Polish & Final Verification

**Purpose**: End-to-end walkthrough of the full quickstart.md checklist.

- [ ] T020 Run the complete manual verification checklist from `specs/009-win95-title-screen/quickstart.md` in Godot Editor. All 9 checklist items must pass. Document any failures and fix before declaring done.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - start immediately. T001 and T002 are parallel.
- **Foundational (Phase 2)**: Depends on Phase 1 completion. T003 -> T004 -> T005 -> T006 sequential (same file).
- **User Stories (Phase 3-5)**: All depend on Foundational phase (T006 checkpoint).
  - US1 (Phase 3) and US2 (Phase 4) can proceed in parallel after Phase 2.
  - US3 (Phase 5) depends on US1 and US2 being complete.
- **Polish (Phase 6)**: Depends on all user story phases complete.

### User Story Dependencies

- **US1 (P1)**: Depends on Phase 2 only. No dependencies on US2 or US3.
- **US2 (P2)**: Depends on Phase 2 only. Integrates visually with US1 but is independently testable.
- **US3 (P3)**: Depends on US1 and US2 being complete (audits both scenes).

### Within Each User Story

- T007 (background_manager.gd) is parallel with T008-T010 (title_screen.tscn) - different files.
- T008, T009, T010 are sequential - all edit title_screen.tscn.
- T012, T013, T014 are sequential - all edit run_setup_popup.tscn.
- T015 is parallel with T012-T014 - edits run_setup_popup.gd (different file).
- T018 and T019 are parallel - independent verifications.

---

## Parallel Execution Examples

### Phase 1 (parallel start)
```
T001: Copy theme/ directory from godot-design-95
T002: Copy fonts/W95FA.otf from godot-design-95
```

### Phase 3 - US1 (T007 can run alongside T008)
```
T007: Change background color in autoload/background_manager.gd
T008: Wrap MenuView in WindowPanel in scenes/title_screen/title_screen.tscn
```

### Phase 4 - US2 (T015 parallel with tscn edits)
```
T012+T013+T014: Restructure run_setup_popup.tscn (sequential, same file)
T015: Add Win95Checkbox variation in run_setup_popup.gd (parallel - different file)
```

### Phase 5 - US3 (T018 and T019 parallel)
```
T018: Reusability test - add/check/remove test Button
T019: Import error check in Output panel
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Copy assets
2. Complete Phase 2: Configure project.godot + verify theme active
3. Complete Phase 3: Title screen Win95 overhaul
4. **STOP and VALIDATE**: Launch game, verify Win95 title screen with full navigation
5. Ship as MVP

### Incremental Delivery

1. Phase 1 + 2: Theme infrastructure ready
2. Phase 3 (US1): Win95 title screen -> validate -> shippable MVP
3. Phase 4 (US2): Win95 run builder -> validate -> full title flow
4. Phase 5 (US3): Architecture validation -> zero overrides confirmed
5. Phase 6: Final checklist sign-off

---

## Notes

- [P] tasks operate on different files - safe to run in parallel
- Never set `theme_override_*` on any node - all styling via project theme
- `RunSetupView` must stay as a `Control` node - Win95 window look is cosmetic (Panel + theme_type_variation)
- Do NOT copy `.import` files from reference repo - Godot regenerates them automatically
- Commit after each phase checkpoint
