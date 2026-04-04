# Tasks: Pause Menu and Shop UI Redesign

**Input**: Design documents from `/specs/003-pause-shop-ui-fix/`
**Prerequisites**: plan.md, spec.md, research.md

**Tests**: No automated tests. Verification is manual in the Godot editor per constitution (Manual Testing First).

**Organization**: Tasks are grouped by user story. US1 (pause menu) and US2 (shop) are independent -- files do not overlap.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2)

---

## Phase 1: User Story 1 - Pause Menu as Full-Screen View (Priority: P1) MVP

**Goal**: Convert `PauseMenu` from CanvasLayer+ColorRect+Panel overlay to a full-rect Control node matching the RunSetupView structural pattern.

**Independent Test**: Open the project in the Godot editor, run the game, pause mid-round. Confirm: (1) pause menu fills 100% of the viewport with no dark overlay beneath it, (2) Resume returns to gameplay, (3) Return to Title navigates to the title screen. The scene tree for PauseMenu must show a Control root with no CanvasLayer or Panel nodes.

### Implementation

- [ ] T001 [US1] Rewrite the scene tree in `scenes/ui/pause_menu/pause_menu.tscn`: replace the CanvasLayer root (and its ColorRect + Panel + MarginContainer + VBoxContainer children) with a Control root using `anchors_preset = 15` and `visible = false`. Add a TitleLabel (Label, anchored top-center, text "PAUSED", font size 32) matching RunSetupView's TitleLabel. Add a ContentContainer (VBoxContainer, anchored center, separation 20) containing ResumeButton and ReturnToTitleButton. Add a ControlHint Label anchored bottom-center with text "Press Escape to resume".
- [ ] T002 [US1] Edit `scenes/ui/pause_menu/pause_menu.gd`: change `extends CanvasLayer` to `extends Control`; remove `@onready var _overlay: ColorRect = $Overlay`; update `@onready var _resume_button: Button` path from `$Panel/MarginContainer/VBoxContainer/ResumeButton` to `$ContentContainer/ResumeButton`; update `@onready var _return_button: Button` path from `$Panel/MarginContainer/VBoxContainer/ReturnToTitleButton` to `$ContentContainer/ReturnToTitleButton`. No other logic changes.
- [ ] T003 [US1] Manual verification in Godot editor: run the game, pause mid-round (default key). Confirm pause menu fills the screen, no dimming overlay is visible, "PAUSED" title label is visible near the top, "Press Escape to resume" hint is visible near the bottom, Resume resumes gameplay, Return to Title goes to title screen. Inspect the remote scene tree to confirm root is Control (not CanvasLayer).

**Checkpoint**: Pause menu fully functional as full-screen Control. US1 complete.

---

## Phase 2: User Story 2 - Shop as Full-Screen View (Priority: P2)

**Goal**: Convert `ShopOverlay` from CanvasLayer+ColorRect+Panel overlay to a full-rect Control node matching the RunSetupView structural pattern.

**Independent Test**: Complete a round in the game. Confirm: (1) shop fills 100% of the viewport with no dark overlay, (2) round summary labels (round number, score, next round info) are visible, (3) Continue proceeds to the next round, (4) the debug config button still opens the debug popup. The scene tree for ShopOverlay must show a Control root with no CanvasLayer or Panel nodes.

### Implementation

- [ ] T004 [US2] Rewrite the scene tree in `scenes/shop/shop_overlay.tscn`: replace the CanvasLayer root (and its ColorRect + Panel + MarginContainer + VBoxContainer children) with a Control root using `anchors_preset = 15` and `visible = false`. Add a TitleLabel (Label, anchored top-center, text "SHOP", font size 24) matching RunSetupView's TitleLabel. Add a ContentContainer (VBoxContainer, anchored center, separation 15) containing RoundLabel, ScoreLabel, NextBoardLabel, HSeparator, ContinueButton, and DebugConfigButton. Add a ControlHint Label anchored bottom-center with text "Press Enter to continue". Keep `DebugRoundConfigPopup` as a direct child of the Control root (unchanged).
- [ ] T005 [US2] Edit `scenes/shop/shop_overlay.gd`: change `extends CanvasLayer` to `extends Control`; remove `@onready var _overlay: ColorRect = $Overlay`; update all six label/button onready paths from `$Panel/MarginContainer/VBoxContainer/X` to `$ContentContainer/X` (RoundLabel, ScoreLabel, NextBoardLabel, ContinueButton, DebugConfigButton). Keep `@onready var _debug_popup: DebugRoundConfigPopup = $DebugRoundConfigPopup` unchanged. No other logic changes.
- [ ] T006 [US2] Manual verification in Godot editor: complete a round. Confirm shop fills the screen, no dimming overlay is visible, "SHOP" title label is visible near the top, "Press Enter to continue" hint is visible near the bottom, all three summary labels display correct data, Continue proceeds to the next round, debug config button opens the debug round config popup. Inspect the remote scene tree to confirm root is Control (not CanvasLayer).

**Checkpoint**: Shop fully functional as full-screen Control. US2 complete.

---

## Phase 3: Polish & Cross-Cutting Concerns

**Purpose**: Final integration validation across both user stories.

- [ ] T007 Open `scenes/main.tscn` in the Godot editor and confirm the scene loads with zero errors -- both ShopOverlay and PauseMenu nodes are recognized and the type annotations in `scenes/main.gd` still resolve correctly.
- [ ] T008 Run the full game flow end-to-end: title screen -> run setup -> round 1 -> pause -> resume -> play to round end -> shop -> continue -> round 2. Confirm no regressions in any transition.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (US1)**: No dependencies -- start immediately
- **Phase 2 (US2)**: No dependency on US1 (different files) -- can start in parallel or after US1
- **Phase 3 (Polish)**: Depends on both US1 and US2 being complete

### User Story Dependencies

- **US1**: T001 must complete before T002 (scene structure defines the node paths the script references)
- **US2**: T004 must complete before T005 (same reason)
- US1 and US2 are fully independent -- different files, different nodes, no shared state

### Parallel Opportunities

- T001 and T004 can run in parallel (different scene files)
- T002 and T005 can run in parallel (different script files, after their respective scene tasks)

---

## Parallel Example: Both User Stories Together

```
# If working with two parallel agents or developers:

Agent A:
  T001 - Rewrite pause_menu.tscn
  T002 - Edit pause_menu.gd
  T003 - Verify pause menu

Agent B (simultaneously):
  T004 - Rewrite shop_overlay.tscn
  T005 - Edit shop_overlay.gd
  T006 - Verify shop

Both done -> T007, T008 (integration validation)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete T001, T002: Pause menu scene + script
2. Complete T003: Manual verification
3. **STOP and VALIDATE**: Pause menu works as full-screen Control
4. Proceed to US2 when ready

### Sequential Single-Developer

1. T001 -> T002 -> T003 (pause menu done)
2. T004 -> T005 -> T006 (shop done)
3. T007 -> T008 (integration validation done)

---

## Notes

- No new files are created. All tasks modify existing files only.
- `main.gd` and `main.tscn` require zero changes -- all call sites are compatible with Control.
- `ModalInputGuard` requires zero changes -- already supports Control nodes.
- After T002 and T005, the `class_name` declarations (`PauseMenu`, `ShopOverlay`) remain unchanged, so all external references continue to work.
