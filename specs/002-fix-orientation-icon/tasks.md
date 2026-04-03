---
description: "Task list for fixing orientation icon position after board resize"
---

# Tasks: Fix Orientation Icon Position After Board Resize

**Input**: Design documents from `/specs/002-fix-orientation-icon/`
**Prerequisites**: plan.md, spec.md, data-model.md, research.md

**Tests**: Manual verification per quickstart.md (no automated test framework integrated).

**Organization**: Single user story (US1 P1) with setup and foundational prerequisites.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Verify EventBus has board resize signal or add it.

- [x] T001 Check if `autoload/EventBus.gd` already has `signal board_resized` defined; if not, add it with parameter `board_state: BoardState`

**Checkpoint**: EventBus has board_resized signal available for subscription. ✓

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Extend Board script with event emission and position accessors.

**⚠️ CRITICAL**: These tasks must complete before icon repositioning can work.

- [x] T002 [P] In `scenes/board/board.gd`: Add two getter methods:
  - `get_top_left_screen_position() -> Vector2` — returns board's visual top-left corner position on screen
  - `get_cell_size_pixels() -> Vector2` — returns pixel dimensions of a single rendered cell
- [x] T003 [P] In `scenes/board/board.gd`: Find the method where board dimensions are set (likely `setup_grid()` or `_ready()`); after grid initialization, emit `EventBus.board_resized.emit(board_state)` signal
- [x] T004 In `scenes/board/board.tscn`: Verify the scene has both Board script and OrientationIcon as a child node; if OrientationIcon is missing or in wrong hierarchy, adjust scene structure

**Checkpoint**: Board emits board_resized signal after grid setup, and icon can query board position/size.

---

## Phase 3: User Story 1 - Orientation Icon Repositioning (Priority: P1)

**Goal**: Icon anchors to board grid (0,0) and updates position whenever board resizes.

**Independent Test**: Complete one full round with known board size, transition to next round with different size, verify icon is at new top-left cell (0,0).

### Implementation for User Story 1

- [x] T005 [P] [US1] In `scenes/board/orientation_icon.gd`: Add method `position_at_cell(cell_0_0_position: Vector2, cell_size: Vector2)` that sets icon position using formula: `icon_position = cell_0_0_position + (cell_size * 0.5)`
- [x] T006 [P] [US1] In `scenes/board/orientation_icon.gd`: Add method `_on_board_resized(board_state: BoardState)` that:
  - Gets `board_offset = _board.get_top_left_screen_position()`
  - Gets `cell_size = _board.get_cell_size_pixels()`
  - Calls `position_at_cell(board_offset, cell_size)`
- [x] T007 [US1] In `scenes/board/orientation_icon.gd` `_ready()` method: Add `EventBus.board_resized.connect(_on_board_resized)` to subscribe to board resize events; also call `_on_board_resized()` once immediately to set initial position
- [x] T008 [US1] Verify Board reference: In OrientationIcon `_ready()`, set `_board = get_parent()` or appropriate parent reference to access board methods added in T002

**Checkpoint**: Icon repositions when board resizes. All 5 acceptance scenarios from spec pass visually. ✓

---

## Phase 4: Polish and Verification

**Purpose**: Manual testing and edge case validation.

**READY FOR MANUAL TESTING** - Implementation complete. Run these tests in Godot editor with F5:

- [ ] T009 Run quickstart.md **Test 1** (icon stays at top-left during round transition) and confirm PASS
- [ ] T010 [P] Run quickstart.md **Test 2** (7x7 → 6x9) and confirm PASS
- [ ] T011 [P] Run quickstart.md **Test 3** (6x9 → 8x8) and confirm PASS
- [ ] T012 [P] Run quickstart.md **Test 4** (1x1 board extreme case) and confirm PASS
- [ ] T013 [P] Run quickstart.md **Test 5** (screen offset shift) and confirm PASS
- [ ] T014 Verify no console errors or warnings related to board_resized signal or icon positioning in Godot Output panel

**Checkpoint**: All 5 manual tests pass. Icon correctly positioned on all board sizes. No visual flicker or repositioning delays.

---

## Dependencies and Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - EventBus signal is foundational
- **Foundational (Phase 2)**: Depends on Phase 1 (T001 must complete; T002 depends on having board_resized signal available)
- **User Story 1 (Phase 3)**: Depends on Phase 2 (T002, T003, T004 must complete; icon can't subscribe to signal without T002)
- **Polish (Phase 4)**: Depends on Phase 3 (icon implementation must be complete for testing)

### User Story Dependencies

- **US1 (Phase 3)**: T005-T008 can run in parallel after T002-T004 complete
  - T005, T006, T008 are method additions (parallel)
  - T007 depends on T005, T006 existing
  - Suggest order: T005 → T006 → T008 → T007 (or T005+T006+T008 parallel, then T007)

### Parallel Opportunities

Once Phase 2 (T002-T004) completes:
- T005 (position_at_cell method) and T006 (_on_board_resized method) can be written in parallel (independent methods)
- T008 (Board reference setup) can also run parallel with T005-T006
- After T005, T006, T008 complete, T007 can subscribe to event
- T010-T013 can run in parallel (independent tests)

```text
T001 (EventBus signal)
  |
  +-- T002 [P] (getters)
  |
  +-- T003 [P] (emit signal)
  |
  +-- T004 (scene structure)

T002+T003+T004 done
  |
  +-- T005 [P] (position method)
  |
  +-- T006 [P] (_on_board_resized method)
  |
  +-- T008 [P] (Board reference)

T005+T006+T008 done
  |
  +-- T007 (subscribe to event)

T007 done
  |
  +-- T009 (Test 1)
  |
  +-- T010, T011, T012, T013 [P] (Tests 2-5 parallel)
  |
  +-- T014 (console check)
```

---

## Implementation Strategy

### MVP (User Story 1 Only)

1. Complete Phase 1: Verify/add EventBus signal (T001)
2. Complete Phase 2: Add Board accessors and signal emission (T002, T003, T004)
3. **STOP and VALIDATE**: Confirm board emits signal in console
4. Complete Phase 3: Implement OrientationIcon logic (T005-T008)
5. **STOP and VALIDATE**: Run Test 1 from quickstart.md manually; verify icon at new top-left
6. Complete Phase 4: Run all 5 tests; confirm all pass

### Single Developer Execution

Sequential with parallelization opportunities:
1. T001 → T002/T003/T004 (parallel) → T005/T006/T008 (parallel) → T007 → T009 → T010/T011/T012/T013 (parallel) → T014

Expected time per task:
- T001-T004: 5-10 min total (setup/foundational)
- T005-T008: 10-15 min total (icon implementation)
- T009-T014: 15-20 min total (manual testing)

---

## Notes

- [P] = different files, can run in parallel
- No new files created; only modifications to existing board, icon, and EventBus scripts
- Manual testing is part of Phase 4 (Principle V - Manual Testing First from constitution)
- Board reference (T008) is critical; if icon is not a child of board, hierarchy must be fixed in T004
- Commit after T004 checkpoint and again after T008 checkpoint for clean git history
