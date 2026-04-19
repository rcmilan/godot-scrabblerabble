# Implementation Tasks: Shop Upgrade Redesign

**Feature**: 008-shop-upgrade-redesign  
**Branch**: `008-shop-upgrade-redesign`  
**Created**: 2026-04-19  
**Status**: Ready for Implementation

**Total Tasks**: 58  
**MVP Scope**: US1–US5 (Core functionality, ~35 tasks)  
**Extended Scope**: US6–US7 (Accessibility & Polish, ~23 tasks)

---

## Overview

This document breaks down the Shop Upgrade Redesign feature into testable, independent implementation tasks organized by user story. Each task follows strict checklist format with file paths and dependencies clearly marked.

### User Story Summary

| Story | Priority | Focus | Dependencies |
|-------|----------|-------|--------------|
| US1 | P1 | Shop entrance animation & display | Setup, Foundational |
| US2 | P1 | Drag-drop core interaction | US1 |
| US3 | P1 | Modifier swapping | US2 |
| US4 | P1 | Revert functionality | US2 |
| US5 | P1 | Commit & hand integration | US2, US3, US4 |
| US6 | P2 | Keyboard navigation | US1–US5 |
| US7 | P2 | Scattered tile layout | US1 |

### Task ID Scheme

- **Setup Phase**: T001–T010
- **Foundational Phase**: T011–T025
- **US1 Phase**: T026–T035
- **US2 Phase**: T036–T046
- **US3 Phase**: T047–T050
- **US4 Phase**: T051–T053
- **US5 Phase**: T054–T056
- **US6 Phase**: T057–T065
- **US7 Phase**: T066–T073
- **Polish Phase**: T074–T084

---

## Phase 1: Setup & Infrastructure (T001–T010)

**Goal**: Initialize project structure and prepare for feature implementation.  
**Completion Criteria**: All domain and controller directories created; existing autoloads extended; basic plumbing in place.

### Tasks

- [ ] T001 Create domain/shop/ directory and ShopSession skeleton file `scripts/domain/shop/shop_session.gd`
- [ ] T002 Create domain/shop/shop_modifier_helpers.gd for modifier application utility functions
- [ ] T003 Create controllers/shop_controller.gd for input routing and drag-drop orchestration
- [ ] T004 Create scripts/animation/shop/ directory and ShopSlideAnimation skeleton `scripts/animation/shop/shop_slide_animation.gd`
- [ ] T005 Create scenes/shop/shop_ui_manager.gd (optional, for visual state management)
- [ ] T006 Verify scenes/shop/shop_overlay.tscn exists; document current structure and modifications needed
- [ ] T007 [P] Verify existing scenes/shop/debug_round_config_popup.tscn is unchanged
- [ ] T008 Review existing EventBus (autoload/event_bus.gd) for shop-related signals; confirm no changes needed
- [ ] T009 Verify project.godot autoload registry includes RunManager, EventBus, TileAnimator
- [ ] T010 Update CLAUDE.md with shop feature context (references to spec.md, quickstart.md, domain layer notes)

---

## Phase 2: Foundational Domain & Architecture (T011–T025)

**Goal**: Implement core domain objects and integrate with existing RunManager; establish immutable state pattern.  
**Completion Criteria**: ShopSession fully functional; TileState extended; RunManager hooks added; no runtime validation errors.

### Domain Implementation

- [ ] T011 Extend TileState (scripts/domain/tile/tile_state.gd): Add fields `pre_loaded_modifier`, `session_modifier`
- [ ] T012 Add method `create_shop_copy()` to TileState; returns independent copy with pre-load preserved, session null
- [ ] T013 Add method `with_session_modifier(mod)` to TileState; returns new TileState with session modifier applied
- [ ] T014 Add method `revert_session_modifier()` to TileState; returns new TileState with session=null, pre-load unchanged
- [ ] T015 Add method `get_active_modifier()` to TileState; returns pre-load if present, else session, else null
- [ ] T016 Add method `can_accept_modifier()` to TileState; returns true if no active modifier
- [ ] T017 [P] Implement ShopSession class (scripts/domain/shop/shop_session.gd) with fields: round_number, is_boss_round, available_modifiers, available_tiles, pending_assignments
- [ ] T018 [P] Implement ShopSession constructor with validation (tiles count = 10, mods = 2-3)
- [ ] T019 Implement ShopSession.apply_modifier(tile, modifier) method; validates max 1 mod per tile; returns new ShopSession
- [ ] T020 Implement ShopSession.revert_all() method; clears pending_assignments, returns fresh ShopSession
- [ ] T021 Implement ShopSession.get_final_tiles() method; returns tiles with all applied mods (for commit)
- [ ] T022 Implement ShopSession.get_unused_modifiers() method; returns modifiers not applied to any tile

### RunManager Integration

- [ ] T023 Extend RunManager (autoload/run_manager.gd): Add `get_shop_tiles(count: int) -> Array[TileState]` method
- [ ] T024 Extend RunManager: Add `get_shop_modifiers(count: int) -> Array[ModifierType]` method
- [ ] T025 [P] Test TileState and ShopSession manually in Godot editor; create test tiles/mods; verify immutability and state transitions

---

## Phase 3: User Story 1 - Enter Shop After Round Win (T026–T035)

**Goal**: Shop entrance animation, tile display, modifier options visibility.  
**Test**: Win a round → shop slides in from bottom → board slides up off-screen → 10 tiles displayed, 2-3 modifiers visible.  
**Independent Test**: Complete with T026–T035; all other user stories depend on this.

### Shop Animation Infrastructure

- [ ] T026 Implement ShopSlideAnimation (scripts/animation/shop/shop_slide_animation.gd) extending TileAnimationStrategy
- [ ] T027 Implement ShopSlideAnimation.get_entrance_animation(shop, board) method; returns Tween for simultaneous animations
- [ ] T028 Implement ShopSlideAnimation.get_exit_animation(shop, board) method; returns Tween for exit animations
- [ ] T029 [P] Verify existing TileAnimationStrategy base class exists; document inheritance pattern

### Shop Entrance Integration

- [ ] T030 Update scenes/main.gd: Modify `_on_shop_requested()` to create ShopSession and trigger entrance animation
- [ ] T031 Update ShopOverlay.show_shop() to accept ShopSession state (if needed); populate UI labels and tile display
- [ ] T032 Verify ShopOverlay scene has TitleLabel, Upgrades section (2-3 modifier cards), Tiles section, buttons
- [ ] T033 Update ShopOverlay._ready() to connect signals for animation orchestration
- [ ] T034 Update scenes/main.gd to call shop_overlay.show_shop() after entrance animation completes
- [ ] T035 [P] Manual test US1: Win round → verify entrance animation (500ms, simultaneous), 10 tiles displayed, 2-3 modifiers shown

---

## Phase 4: User Story 2 - Drag Modifier Onto Tile (T036–T046)

**Goal**: Core drag-drop interaction, ghost preview, badge display, invalid drop feedback.  
**Test**: Click modifier → drag to tile → ghost follows → drop on valid tile → badge appears; drop on occupied → red X + shake.  
**Independent Test**: Complete with T036–T046.

### Input & Drag-Drop Handler

- [ ] T036 Implement ShopController (scripts/controllers/shop_controller.gd): Track input state (selected modifier, dragging, ghost node)
- [ ] T037 Implement ShopController._input() for InputEventMouseButton: Detect modifier card clicks
- [ ] T038 Implement modifier selection logic: Visual highlight when modifier card clicked
- [ ] T039 Implement drag start logic: Create ghost node on mouse down, update ShopSession if needed
- [ ] T040 Implement drag tracking: Update ghost position on InputEventMouseMotion; track current drop target
- [ ] T041 Implement drop zone validation: Check if tile can accept modifier (no existing mod)
- [ ] T042 Implement drop completion: Apply modifier to tile, update ShopSession, show badge
- [ ] T043 Implement invalid drop feedback: Red X overlay + trigger ShakeTileAnimation (reuse existing)
- [ ] T044 [P] Implement ghost node creation & destruction: Full modifier card visual, smooth cursor tracking

### UI Display Updates

- [ ] T045 Update ShopOverlay to display modifier badges on tiles (modifier applied visual indicator)
- [ ] T046 [P] Manual test US2: Click modifier → drag to clean tile → badge appears; drag to occupied → red X + shake

---

## Phase 5: User Story 3 - Swap Modifier on Pre-Loaded Tile (T047–T050)

**Goal**: Allow swapping pre-loaded modifiers with new ones; ensure pre-load persists on revert.  
**Test**: Drag new modifier onto pre-loaded tile → old mod returns to pool → new mod on tile; Revert → old mod returns.  
**Dependency**: Requires US2 (drag-drop working).

### Modifier Swapping Logic

- [ ] T047 Implement ShopController.swap_modifier() logic: Detect pre-loaded mod; remove from current tile; apply new one
- [ ] T048 Implement pre-loaded modifier return to available pool: Update Upgrades section UI
- [ ] T049 Update ShopSession to track both pre-loaded and session mods; enforce mutual exclusivity (non-representable invalid states)
- [ ] T050 [P] Manual test US3: Drag modifier onto pre-loaded tile → swap happens; Revert → pre-load restored

---

## Phase 6: User Story 4 - Revert Session Changes (T051–T053)

**Goal**: Clear all player-applied modifiers; preserve pre-loaded; keep shop open; reset modifier pool.  
**Test**: Apply mods → click Revert → all session mods gone, pre-loads remain, shop stays open.  
**Dependency**: Requires US2, US3 (modifiers applied).

### Revert Implementation

- [ ] T051 Implement Revert button handler: Call ShopSession.revert_all(), update UI to reflect reset state
- [ ] T052 Implement ShopOverlay refresh logic after revert: Clear all session badges, keep pre-loaded badges, restore modifier availability
- [ ] T053 [P] Manual test US4: Apply modifiers → click Revert → all player changes gone, pre-loads stay, shop stays open

---

## Phase 7: User Story 5 - Commit Changes and Return to Hand (T054–T056)

**Goal**: Finalize assignments, add to hand, trigger exit animation, proceed to next round.  
**Test**: Click Commit → exit animation (500ms) → next round has modified tiles.  
**Dependency**: Requires US2, US3, US4 (full shop interaction working).

### Commit & Hand Integration

- [ ] T054 Implement Commit button handler: Call ShopSession.get_final_tiles(), emit signal to RunManager
- [ ] T055 Extend RunManager to receive committed tiles: Add method `finalize_shop_commit(tiles)` to create hand tiles
- [ ] T056 [P] Update scenes/main.gd to orchestrate exit animation and round progression after commit; manual test US5

---

## Phase 8: User Story 6 - Keyboard Navigation & Accessibility (T057–T065)

**Goal**: TAB cycling, arrow key navigation, Enter/Space activation; keyboard-only flow.  
**Test**: Use only keyboard (no mouse) to open shop, apply modifiers, revert, commit.  
**Dependency**: Requires US1–US5 (full shop functional).

### Keyboard Input Handling

- [ ] T057 Implement TAB focus cycling: Modifiers → Tiles → Buttons → loop
- [ ] T058 Implement arrow key navigation: Move focus left/right/up/down between tiles based on scattered layout
- [ ] T059 Implement Enter/Space on modifier: Select modifier (same as click)
- [ ] T060 Implement keyboard drag simulation: Arrow keys move focus to tile, Enter applies selected modifier
- [ ] T061 Implement Enter on Revert button: Trigger revert (keyboard)
- [ ] T062 Implement Enter on Commit button: Trigger commit (keyboard)
- [ ] T063 Implement Escape key: Close shop without commit (optional, if in scope)
- [ ] T064 Verify focus visual indicators are clear (highlight, border, color change)
- [ ] T065 [P] Manual test US6: Play through full shop interaction using only keyboard (TAB, arrows, Enter)

---

## Phase 9: User Story 7 - Scattered Tile Layout Without Overlaps (T066–T073)

**Goal**: Non-grid, naturalistic tile positioning; no overlaps; visual variation across visits.  
**Test**: Open shop multiple times → tiles scattered differently each time → no overlaps.  
**Dependency**: Requires US1 (tiles displayed).

### Scattered Layout Implementation

- [ ] T066 Implement scatter algorithm in ShopOverlay: Grid-with-jitter (2 rows × 5 cols, ±15px random offset)
- [ ] T067 Generate tile positions for 10 tiles; validate no overlaps using Rect2.intersects() checks
- [ ] T068 Apply random jitter to grid positions; ensure variation between shop visits (use randf_range)
- [ ] T069 Clamp positions to viewport bounds; verify all tiles fit within Tiles section
- [ ] T070 Test with multiple random seeds; verify tile positions vary
- [ ] T071 Update ShopOverlay scene to position tiles based on generated positions (dynamic, not hardcoded)
- [ ] T072 Verify scattered layout is visually distinct from orderly board grid
- [ ] T073 [P] Manual test US7: Open shop multiple times; tiles scattered differently each time; no overlaps

---

## Phase 10: Polish, Integration & Final Testing (T074–T084)

**Goal**: Cross-cutting concerns, animation polish, integration validation, manual end-to-end test.

### Animation & Visual Polish

- [ ] T074 Polish entrance/exit animations: Fine-tune timing, easing; verify 500ms target and sync
- [ ] T075 Polish ghost drag preview: Ensure smooth 60fps tracking, no lag
- [ ] T076 Polish red X invalid drop feedback: Ensure visibility, timing, clear rejection signal
- [ ] T077 Polish modifier badge visuals: Clear, readable, visually distinct from pre-loaded vs session
- [ ] T078 [P] Verify no visual glitches during drag-drop (ghost clipping, badges misaligned, etc.)

### Integration & Edge Cases

- [ ] T079 Verify shop properly integrates with RunManager.proceed_from_shop()
- [ ] T080 Verify committed tiles persist in hand across round transitions
- [ ] T081 Test edge case: Multiple pre-loaded tiles (5+) in same shop
- [ ] T082 Test edge case: All 2-3 modifiers applied to tiles (Upgrades section empty)
- [ ] T083 Test edge case: Boss round (3 modifiers) vs normal (2 modifiers)
- [ ] T084 [P] Full end-to-end manual test: Title → Run Setup → Play → Win → Shop → All interactions → Commit → Next round → Verify tiles

---

## Dependency Graph

```
Setup (T001–T010)
├── Foundational (T011–T025)
│   └── US1 (T026–T035) — Shop entrance
│       └── US2 (T036–T046) — Drag-drop core
│           ├── US3 (T047–T050) — Swap modifiers
│           ├── US4 (T051–T053) — Revert
│           └── US5 (T054–T056) — Commit
│       ├── US6 (T057–T065) — Keyboard (parallel with US2–US5)
│       └── US7 (T066–T073) — Layout (parallel with US2)
└── Polish (T074–T084) — Final integration & testing
```

---

## Parallel Execution Opportunities

### MVP Implementation (US1–US5 Core Path)

**Serialized (blocking dependencies)**:
```
T001–T010 (Setup)
  ↓
T011–T025 (Foundational)
  ↓
T026–T035 (US1 — Required for all)
  ↓
T036–T046 (US2 — Core interaction)
  ↓
T047–T053 (US3 + US4 — Parallel safe)
  ↓
T054–T056 (US5 — Requires US2+US3+US4)
```

**Estimated Duration**: ~5–7 sprints (1 sprint = 2–3 story-related tasks)

### Extended Scope (Add US6–US7)

**Parallel opportunities after US1**:
```
US2–US5 (Main path)
  ├── US6 (T057–T065) — Keyboard [Parallel after US1, completes with US5]
  └── US7 (T066–T073) — Layout [Parallel after US1, independent]
```

**Parallel Example**:
- Team A: T036–T046 (US2 drag-drop)
- Team B: T057–T065 (US6 keyboard) — can start after T026–T035
- Team C: T066–T073 (US7 layout) — can start after T026–T035

---

## MVP Scope & Timeline

**Minimum Viable Product**: US1–US5  
**Task Count**: ~35 tasks (T001–T056 + polish subset)  
**Sprint Estimate**: 5–7 two-week sprints  
**Parallel Potential**: 30% task overlap (US6, US7, polish can run in parallel)

**Critical Path** (blocks everything else):
- T001–T010: Setup (1 sprint)
- T011–T025: Foundational (1 sprint)
- T026–T035: US1 (1 sprint)
- T036–T046: US2 (1–2 sprints)
- T047–T056: US3–US5 (1–2 sprints)

---

## Manual Testing Checklist

### Per User Story

Each user story should be independently verified:

- [ ] **US1**: Shop appears after round win; entrance animation 500ms; 10 tiles displayed; 2-3 modifiers visible
- [ ] **US2**: Click modifier → drag → ghost follows → drop on tile → badge appears; invalid drop → red X
- [ ] **US3**: Pre-loaded tile → drag new modifier → swap occurs; Revert → original returns
- [ ] **US4**: Apply mods → Revert → all session cleared, pre-loads remain, shop stays open
- [ ] **US5**: Click Commit → exit animation 500ms → next round has modified tiles
- [ ] **US6**: Play through entire shop using only keyboard (TAB, arrows, Enter)
- [ ] **US7**: Open shop 5× → tiles scattered differently each visit; no overlaps

### Integration Test

- [ ] Full game flow: Title → Run Setup → Round 1 → Win → Shop (all features) → Commit → Round 2 → Modified tiles functional
- [ ] Boss round: 3 modifiers displayed (not 2)
- [ ] Multiple shop visits: Tiles re-randomize each visit; modifiers don't carry over

---

## Notes & Assumptions

1. **Existing Code**: Assumes TileBag, TileAnimationStrategy, EventBus, RunManager exist and are functional
2. **Immutability**: All domain objects follow immutability principle (return new instances, never mutate)
3. **Non-representable States**: TileState structured so max 1 modifier (pre-load or session) can exist at once
4. **Testing First**: Manual testing in Godot editor is the acceptance criterion (no automated test framework integrated)
5. **Animation Reuse**: ShakeTileAnimation existing and available for reuse in invalid drop feedback
6. **Keyboard Fallback**: Keyboard-only flow simulates drag-drop via focus + arrow keys + Enter (US6)

---

## Success Criteria

✓ All 7 user stories independently testable  
✓ MVP (US1–US5) complete and functional  
✓ Extended scope (US6–US7) adds accessibility and polish  
✓ No modal overlays; full-screen Control with visibility toggling  
✓ Domain logic isolated in `/scripts/domain/shop/`  
✓ EventBus used for cross-system communication  
✓ Manual tests pass (per checklist above)  
✓ Code follows Wordatro architecture (DDD, immutability, thin controllers)
