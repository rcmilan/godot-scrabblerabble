# Tasks: Pause Menu and Shop UI Redesign (Animated Scene Swap)

**Input**: Specification from `spec.md`
**Prerequisites**: plan.md, research.md

**Tests**: No automated tests. Verification is manual in the Godot editor per constitution (Manual Testing First).

**Organization**: Tasks are grouped by user story and technical phase. US1 (pause menu with animations) and US2 (shop) are independent -- pause has no dependencies on shop.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2)

---

## Phase 1: Animation Infrastructure - Slide Animations (Priority: P0) Foundational

**Goal**: Create reusable slide-in and slide-out animations that mimic the existing tile animation system. These animations will drive both the board slide-left and pause-menu slide-in behaviors.

**Independent Test** (Manual, post-T003): In Godot editor, verify that slide animations work by manually instantiating a test node and triggering slide_left and slide_in_from_right animations. Animations should complete smoothly within 500ms.

### Implementation

- [X] T001 Create `scripts/animation/slide/slide_left_animation.gd`: Extends `TileAnimationStrategy`. Animates a node's position from its current x to off-screen left (negative screen width). **Duration: 400ms** (required to complete within 500ms threshold per FR-005 and SC-002). Reuses Tween infrastructure from existing animations.
- [X] T002 Create `scripts/animation/slide/slide_in_from_right_animation.gd`: Extends `TileAnimationStrategy`. Animates a node's position from off-screen right (screen width) to x=0. **Duration: 400ms** (required to complete within 500ms threshold per FR-004 and SC-001). Mirrors SlideLeftAnimation for symmetry.
- [X] T003 [P] Register both animations in `scripts/animation/tile_animator.gd` under new category `slide` (e.g., `AnimationType.SLIDE_LEFT`, `AnimationType.SLIDE_IN_FROM_RIGHT`). Verify registration does not break existing animations.

**Checkpoint**: Slide animations ready to use. TileAnimator can animate arbitrary nodes, not just tiles.

---

## Phase 2: User Story 1 - Pause Menu with Animated Scene Swap (Priority: P1) MVP

**Goal**: Convert `PauseMenu` to a full-screen Control that animates in/out alongside the board. Scene-swap architecture mirrors title screen ↔ run setup pattern.

**Independent Test**: Open Godot editor, run game, pause mid-round. Verify: (1) board slides left off-screen while pause menu slides in from right simultaneously, (2) both animations complete smoothly in under 500ms, (3) pause menu is fully visible and interactive, (4) arrow keys navigate buttons, (5) Resume button reverses animations symmetrically, (6) Return to Title exits to title screen.

### Implementation

- [X] T004 [US1] Rewrite scene tree in `scenes/ui/pause_menu/pause_menu.tscn`: Root is Control (`anchors_preset = 15`, `visible = false`). Add TitleLabel (Label, anchored top-center, text "PAUSED", font size 32). Add ContentContainer (VBoxContainer, anchored center, separation 20) containing ResumeButton and ReturnToTitleButton with explicit `focus_neighbor_top`/`focus_neighbor_bottom` for keyboard navigation. Add ControlHint (Label, anchored bottom-center, text "Press Escape to resume"). NO ColorRect overlay (animations handle visibility, not overlays). NO CanvasLayer.
- [X] T005 [US1] Edit `scenes/ui/pause_menu/pause_menu.gd`: Change `extends CanvasLayer` to `extends Control`. Remove all `_overlay` references. Update `@onready` paths to `$ContentContainer/ResumeButton` and `$ContentContainer/ReturnToTitleButton`. Replace `show()`/`hide()` calls with animation-based show/hide methods:
  - `show_pause_menu_animated()`: Calls TileAnimator to animate board slide-left and pause menu slide-in-from-right simultaneously.
  - `close_pause_menu_animated()`: Calls TileAnimator to animate pause menu slide-left and board slide-in-from-right simultaneously, then emits `resume_requested`.
  - Keep ModalInputGuard for Escape key handling: In `_ready()`, wire ModalInputGuard's `close_requested` signal to call `close_pause_menu_animated()` (replace the old simple `hide()` with the animation method).
  - Add input debouncing: prevent button presses during animation (set flag `_animating = true` during animation, check before processing input).
- [X] T006 [US1] Edit `scenes/main.gd`: Update pause menu show/hide calls:
  - Replace `pause_menu.show_pause_menu()` with `pause_menu.show_pause_menu_animated()`.
  - Replace `pause_menu.hide()` with `pause_menu.close_pause_menu_animated()` (where resume is requested).
  - **Verify Board is a direct child of Main**: Check `scenes/main.tscn` to confirm Board is a direct child (sibling of PauseMenu). If Board is nested deeper in the tree, flag as a blocking issue and halt—do not restructure the scene tree without explicit requirement. Animations require Board and PauseMenu to be siblings.
- [ ] T007 [US1] Manual verification in Godot editor: Run game, pause mid-round. Verify: (1) board slides left off-screen while pause menu slides in from right, both synchronously, (2) animations complete in under 500ms, (3) pause menu is fully visible and focused on Resume button, (4) **hint label text is exactly "Press Escape to resume"**, (5) arrow down key moves focus to Return to Title, arrow up moves back, (6) Enter activates focused button, (7) Resume reverses animations, (8) Return to Title exits to title screen. Inspect scene tree to confirm Control root (not CanvasLayer).

**Checkpoint**: Pause menu fully functional with smooth animated transitions. US1 complete.

---

## Phase 3: User Story 2 - Shop as Full-Screen View (Priority: P2)

**Goal**: Convert `ShopOverlay` from CanvasLayer overlay to full-rect Control node matching the RunSetupView structural pattern. Shop remains a visibility-toggled screen (no animation; pause menu is the primary animated transition).

**Independent Test**: Complete a round in the game. Verify: (1) shop fills 100% of the viewport with no dark overlay, (2) round summary labels (round number, score, next round info) are visible, (3) Continue proceeds to the next round, (4) the debug config button still opens the debug popup. The scene tree for ShopOverlay must show a Control root with no CanvasLayer or Panel nodes.

### Implementation

- [X] T008 [US2] Rewrite the scene tree in `scenes/shop/shop_overlay.tscn`: Replace CanvasLayer root with Control (`anchors_preset = 15`, `visible = false`). Add TitleLabel (Label, anchored top-center, text "SHOP", font size 24). Add ContentContainer (VBoxContainer, anchored center, separation 15) containing RoundLabel, ScoreLabel, NextBoardLabel, HSeparator, ContinueButton, and DebugConfigButton with explicit `focus_neighbor_top`/`focus_neighbor_bottom`. Add ControlHint (Label, anchored bottom-center, text "Press Enter to continue"). Keep `DebugRoundConfigPopup` as a direct child of the Control root (unchanged). NO ColorRect overlay, NO CanvasLayer.
- [X] T009 [US2] Edit `scenes/shop/shop_overlay.gd`: Change `extends CanvasLayer` to `extends Control`. Remove `@onready var _overlay: ColorRect`. Update all `@onready` paths from `$Panel/MarginContainer/VBoxContainer/X` to `$ContentContainer/X` (RoundLabel, ScoreLabel, NextBoardLabel, ContinueButton, DebugConfigButton). Keep `@onready var _debug_popup: DebugRoundConfigPopup = $DebugRoundConfigPopup` unchanged. No other logic changes required.
- [ ] T010 [US2] Manual verification in Godot editor: Complete a round. Verify: (1) shop fills the screen with no dimming overlay, (2) all three summary labels (Round, Score, Next Board) display correct data, (3) **hint label text is exactly "Press Enter to continue"**, (4) Continue proceeds to the next round, (5) debug config button opens the debug round config popup, (6) arrow keys navigate buttons, (7) Enter activates focused button. Inspect scene tree to confirm root is Control (not CanvasLayer).

**Checkpoint**: Shop fully functional as full-screen Control. US2 complete.

---

## Phase 4: Polish & Cross-Cutting Concerns

**Purpose**: Final integration validation across both user stories.

- [X] T011 Open `scenes/main.tscn` in the Godot editor and confirm the scene loads with zero errors -- Board, PauseMenu, and ShopOverlay nodes are recognized and type annotations in `scenes/main.gd` still resolve correctly.
- [ ] T012 Run the full game flow end-to-end: title screen -> run setup -> round 1 -> pause -> resume -> play to round end -> shop -> continue -> round 2 -> pause -> resume -> play to round end. Verify all animations play smoothly, no animation stuttering, all button interactions work, no regressions in transitions.
- [ ] T013 Verify tile animations continue smoothly while board is animating off-screen during pause transition (no cancellation or interruption).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Animations)**: No dependencies -- start immediately. Must complete before Phase 2 (pause menu animations depend on slide animations being registered).
- **Phase 2 (US1 Pause)**: Depends on Phase 1 (slide animations). Can start after T003 completes.
- **Phase 3 (US2 Shop)**: No dependency on Phase 2 (different files, different systems). Can run in parallel with US1 or after.
- **Phase 4 (Polish)**: Depends on all user stories being complete.

### Task Dependencies Within Phases

- **Phase 1**: T001 → T002 → T003 (sequential: animations must be created before registration)
- **Phase 2**: T004 → T005 → T006 → T007 (sequential: scene structure defines node paths; script updates reference those paths; main.gd wiring must be complete before testing)
- **Phase 3**: T008 → T009 → T010 (sequential: same logic as Phase 2)

### Parallel Opportunities

- T001 and T008 can start in parallel (different animation files)
- T002 and T009 can start in parallel (different script files)

---

## Parallel Example: Independent Teams

```
Agent A (Animations + Pause Menu):
  Phase 1: T001 → T002 → T003 (animations ready)
  Phase 2: T004 → T005 → T006 → T007 (pause menu animated)

Agent B (Shop):
  Phase 3 (parallel with Phase 2): T008 → T009 → T010 (shop as full-screen Control)

Both done -> Phase 4: T011 → T012 → T013 (integration)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 (animations)
2. Complete Phase 2 (pause menu animated)
3. Complete T007 (manual verification of pause menu)
4. **STOP and VALIDATE**: Pause menu works with smooth slide animations
5. Proceed to US2 when ready

### Sequential Single-Developer

1. Phase 1: T001 → T002 → T003 (animations)
2. Phase 2: T004 → T005 → T006 → T007 (pause menu)
3. Phase 3: T008 → T009 → T010 (shop)
4. Phase 4: T011 → T012 → T013 (integration)

---

## Notes

- No new files created in `scenes/`. All modifications to existing scene files.
- Two new animation strategy files created in `scripts/animation/slide/`.
- `main.gd` requires updates to use new animated show/hide methods for pause menu.
- `main.tscn` requires zero structural changes if Board is already a direct child (it should be).
- Input debouncing in pause_menu.gd prevents accidental button presses during slide animations.
- ModalInputGuard remains unchanged; Escape key handling is preserved.
- Shop uses standard visibility toggling (no animation); only pause menu uses slide animations.
