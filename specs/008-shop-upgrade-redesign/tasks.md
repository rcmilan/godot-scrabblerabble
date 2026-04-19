# Implementation Tasks: Shop Upgrade Redesign

**Feature**: 008-shop-upgrade-redesign  
**Branch**: `008-shop-upgrade-redesign`  
**Created**: 2026-04-19  
**Status**: Ready for Implementation

**Total Tasks**: 84  
**MVP Scope**: US1–US5 (Core functionality, ~56 tasks)  
**Extended Scope**: US6–US7 (Accessibility & Polish, ~17 tasks)  
**Polish & Integration**: ~11 tasks

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
- **Foundational Phase**: T011–T026
- **US1 Phase**: T027–T036
- **US2 Phase**: T037–T047
- **US3 Phase**: T048–T051
- **US4 Phase**: T052–T054
- **US5 Phase**: T055–T057
- **US6 Phase**: T058–T066
- **US7 Phase**: T067–T074
- **Critical Fixes Phase**: T075–T077
- **Polish Phase**: T078–T088

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
- [ ] T024-B Extend RunManager: Add `finalize_shop_commit(tiles: Array[TileState])` method to create hand tiles and proceed to next round
- [ ] T025 Implement Principle VI enforcement in TileState: Restructure pre_loaded_modifier and session_modifier as mutually-exclusive (enum or union pattern) to ensure non-representable invalid states; validate that max 1 modifier active per tile
- [ ] T026 [P] Test TileState and ShopSession manually in Godot editor; create test tiles/mods; verify immutability, state transitions, and Principle VI enforcement

---

## Phase 3: User Story 1 - Enter Shop After Round Win (T027–T036)

**Goal**: Shop entrance animation, tile display, modifier options visibility.  
**Test**: Win a round → shop slides in from bottom → board slides up off-screen → 10 tiles displayed, 2-3 modifiers visible.  
**Independent Test**: Complete with T027–T037; all other user stories depend on this.

### Shop Animation Infrastructure

- [ ] T027 Implement ShopSlideAnimation (scripts/animation/shop/shop_slide_animation.gd) extending TileAnimationStrategy
- [ ] T028 Implement ShopSlideAnimation.get_entrance_animation(shop, board) method; returns Tween for simultaneous animations (500ms)
- [ ] T029 Implement ShopSlideAnimation.get_exit_animation(shop, board) method; returns Tween for exit animations (500ms)
- [ ] T029-B [P] **CRITICAL FIX**: Explicitly implement board animation counterpart in T028-T029; ensure shop and board animations start/end simultaneously. Document in quickstart.md how board animation is orchestrated in scenes/main.gd
- [ ] T030 [P] Verify existing TileAnimationStrategy base class exists; document inheritance pattern

### Shop Entrance Integration

- [ ] T031 Update scenes/main.gd: Modify `_on_shop_requested()` to create ShopSession and trigger entrance animation (T028 for shop, matching board animation)
- [ ] T032 Update ShopOverlay.show_shop() to accept ShopSession state (if needed); populate UI labels and tile display
- [ ] T033 Verify ShopOverlay scene has TitleLabel, Upgrades section (2-3 modifier cards), Tiles section, buttons
- [ ] T034 Update ShopOverlay._ready() to connect signals for animation orchestration
- [ ] T035 Update scenes/main.gd to call shop_overlay.show_shop() after entrance animation completes
- [ ] T036 [P] Manual test US1: Win round → verify entrance animation (500ms, simultaneous shop+board), 10 tiles displayed, 2-3 modifiers shown

---

## Phase 4: User Story 2 - Drag Modifier Onto Tile (T037–T047)

**Goal**: Core drag-drop interaction, ghost preview, badge display, invalid drop feedback.  
**Test**: Click modifier → drag to tile → ghost follows → drop on valid tile → badge appears; drop on occupied → red X + shake.  
**Independent Test**: Complete with T036–T046.

### Input & Drag-Drop Handler

- [ ] T037 Implement ShopController (scripts/controllers/shop_controller.gd): Track input state (selected modifier, dragging, ghost node)
- [ ] T038 Implement ShopController._input() for InputEventMouseButton: Detect modifier card clicks
- [ ] T039 Implement modifier selection logic: Visual highlight when modifier card clicked
- [ ] T040 Implement drag start logic: Create ghost node on mouse down, update ShopSession if needed
- [ ] T041 Implement drag tracking: Update ghost position on InputEventMouseMotion; track current drop target
- [ ] T042 Implement drop zone validation: Check if tile can accept modifier (no existing mod)
- [ ] T043 Implement drop completion: Apply modifier to tile, update ShopSession, show badge
- [ ] T044 Implement invalid drop feedback: Red X overlay + trigger ShakeTileAnimation (reuse existing)
- [ ] T045 [P] Implement ghost node creation & destruction: Full modifier card visual (matches Upgrades card design, 0.7 opacity), smooth 60fps cursor tracking

### UI Display Updates

- [ ] T046 Update ShopOverlay to display modifier badges on tiles (modifier applied visual indicator)
- [ ] T047 [P] Manual test US2: Click modifier → drag to clean tile → badge appears; drag to occupied → red X + shake; verify ghost responsive (≤50ms appear, 60fps)

---

## Phase 5: User Story 3 - Swap Modifier on Pre-Loaded Tile (T048–T051)

**Goal**: Allow swapping pre-loaded modifiers with new ones; ensure pre-load persists on revert.  
**Test**: Drag new modifier onto pre-loaded tile → old mod returns to pool → new mod on tile; Revert → old mod returns.  
**Dependency**: Requires US2 (drag-drop working).

### Modifier Swapping Logic

- [ ] T048 Implement ShopController.swap_modifier() logic: Detect pre-loaded mod; remove from current tile; apply new one
- [ ] T049 Implement pre-loaded modifier return to available pool: Update Upgrades section UI
- [ ] T050 Verify ShopSession enforces mutual exclusivity (pre-loaded XOR session mod) per T025 Principle VI implementation
- [ ] T051 [P] Manual test US3: Drag modifier onto pre-loaded tile → swap happens; Revert → pre-load restored

---

## Phase 6: User Story 4 - Revert Session Changes (T052–T055)

**Goal**: Clear all player-applied modifiers; preserve pre-loaded; keep shop open; reset modifier pool.  
**Test**: Apply mods → click Revert → all session mods gone, pre-loads remain, shop stays open.  
**Dependency**: Requires US2, US3 (modifiers applied).

### Revert Implementation

- [ ] T052 Implement Revert button handler: Call ShopSession.revert_all(), update UI to reflect reset state (target ≤100ms latency per SC-007)
- [ ] T053 Implement ShopOverlay refresh logic after revert: Clear all session badges, keep pre-loaded badges, restore modifier availability
- [ ] T054 **CRITICAL FIX**: Implement ESC key handler (FR-018): Close shop without commit, discard preview state, return to gameplay without applying changes
- [ ] T055 [P] Manual test US4: Apply modifiers → click Revert → all player changes gone, pre-loads stay, shop stays open (≤100ms latency); test ESC close

---

## Phase 7: User Story 5 - Commit Changes and Return to Hand (T056–T058)

**Goal**: Finalize assignments, add to hand, trigger exit animation, proceed to next round.  
**Test**: Click Commit → exit animation (500ms) → next round has modified tiles.  
**Dependency**: Requires US2, US3, US4 (full shop interaction working).

### Commit & Hand Integration

- [ ] T056 Implement Commit button handler: Call ShopSession.get_final_tiles(), emit signal to RunManager
- [ ] T057 Verify RunManager.finalize_shop_commit(tiles) method (T024-B) creates hand tiles and proceeds
- [ ] T058 [P] Update scenes/main.gd to orchestrate exit animation (500ms) and round progression after commit; manual test US5

---

## Phase 8: User Story 6 - Keyboard Navigation & Accessibility (T059–T067)

**Goal**: TAB cycling, arrow key navigation, Enter/Space activation; keyboard-only flow.  
**Test**: Use only keyboard (no mouse) to open shop, apply modifiers, revert, commit.  
**Dependency**: Requires US1–US5 (full shop functional).

### Keyboard Input Handling

- [ ] T059 Implement TAB focus cycling: Modifiers → Tiles → Buttons → loop
- [ ] T060 Implement arrow key navigation: Move focus left/right/up/down between tiles based on scattered layout
- [ ] T061 Implement Enter/Space on modifier: Select modifier (same as click)
- [ ] T062 Implement keyboard drag simulation: Arrow keys move focus to tile, Enter applies selected modifier
- [ ] T063 Implement Enter on Revert button: Trigger revert (keyboard)
- [ ] T064 Implement Enter on Commit button: Trigger commit (keyboard)
- [ ] T065 Implement Escape key: Close shop without commit (optional, if in scope)
- [ ] T066 Verify focus visual indicators are clear (highlight, border, color change)
- [ ] T067 [P] Manual test US6: Play through full shop interaction using only keyboard (TAB, arrows, Enter)

---

## Phase 9: User Story 7 - Scattered Tile Layout Without Overlaps (T068–T075)

**Goal**: Non-grid, naturalistic tile positioning; no overlaps; visual variation across visits.  
**Test**: Open shop multiple times → tiles scattered differently each time → no overlaps.  
**Dependency**: Requires US1 (tiles displayed).

### Scattered Layout Implementation

- [ ] T068 Implement scatter algorithm in ShopOverlay: Grid-with-jitter (2 rows × 5 cols, ±15px random offset)
- [ ] T069 Generate tile positions for 10 tiles; validate no overlaps using Rect2.intersects() checks (100% success per SC-004)
- [ ] T070 Apply random jitter to grid positions; ensure variation between shop visits (use randf_range)
- [ ] T071 Clamp positions to viewport bounds; verify all tiles fit within Tiles section
- [ ] T072 Test with multiple random seeds; verify tile positions vary
- [ ] T073 Update ShopOverlay scene to position tiles based on generated positions (dynamic, not hardcoded)
- [ ] T074 Verify scattered layout is visually distinct from orderly board grid
- [ ] T075 [P] Manual test US7: Open shop 5 times; tiles scattered differently each time; visually inspect no overlaps; verify SC-004

---

## Phase 10: Polish, Integration & Final Testing (T076–T090)

**Goal**: Cross-cutting concerns, animation polish, integration validation, manual end-to-end test.

### Performance Validation (Success Criteria)

- [ ] T076 Measure and validate entrance/exit animation timing: Verify 500ms target and sync (SC-001)
- [ ] T077 Measure and validate ghost appearance latency: Verify ≤50ms appear, 60fps tracking (SC-002)
- [ ] T078 Measure and validate full interaction timing: Verify player completes view+apply+commit in <30s (SC-003)
- [ ] T079 Measure and validate revert latency: Verify ≤100ms button response (SC-007)

### Animation & Visual Polish

- [ ] T080 Polish entrance/exit animations: Fine-tune easing; verify smooth sync
- [ ] T081 Polish ghost drag preview: Ensure smooth 60fps tracking per T077 measurement
- [ ] T082 Polish red X invalid drop feedback: Ensure visibility, timing, clear rejection signal
- [ ] T083 Polish modifier badge visuals: Clear, readable, visually distinct from pre-loaded vs session
- [ ] T084 [P] Verify no visual glitches during drag-drop (ghost clipping, badges misaligned, etc.)

### Integration & Edge Cases

- [ ] T085 Verify shop properly integrates with RunManager.finalize_shop_commit() (T024-B)
- [ ] T086 Verify committed tiles persist in hand across round transitions
- [ ] T087 Test edge case: Multiple pre-loaded tiles (5+) in same shop
- [ ] T088 Test edge case: All 2-3 modifiers applied to tiles (Upgrades section empty)
- [ ] T089 Test edge case: Boss round (3 modifiers) vs normal (2 modifiers)
- [ ] T090 [P] Full end-to-end manual test: Title → Run Setup → Play → Win → Shop → All interactions → Commit → Next round → Verify tiles active

---

## Dependency Graph

```
Setup (T001–T010)
├── Foundational (T011–T026)
│   └── US1 (T027–T036) — Shop entrance
│       └── US2 (T037–T047) — Drag-drop core
│           ├── US3 (T048–T051) — Swap modifiers
│           ├── US4 (T052–T055) — Revert
│           └── US5 (T056–T058) — Commit
│       ├── US6 (T059–T067) — Keyboard (parallel with US2–US5)
│       └── US7 (T068–T075) — Layout (parallel with US2)
└── Polish (T076–T090) — Final integration & testing
```

---

## Parallel Execution Opportunities

### MVP Implementation (US1–US5 Core Path)

**Serialized (blocking dependencies)**:
```
T001–T010 (Setup)
  ↓
T011–T026 (Foundational)
  ↓
T027–T036 (US1 — Required for all)
  ↓
T037–T047 (US2 — Core interaction)
  ↓
T048–T055 (US3 + US4 — Parallel safe)
  ↓
T056–T058 (US5 — Requires US2+US3+US4)
```

**Estimated Duration**: ~5–7 sprints (1 sprint = 2–3 story-related tasks)

### Extended Scope (Add US6–US7)

**Parallel opportunities after US1**:
```
US2–US5 (Main path)
  ├── US6 (T059–T067) — Keyboard [Parallel after US1, completes with US5]
  └── US7 (T068–T075) — Layout [Parallel after US1, independent]
```

**Parallel Example**:
- Team A: T037–T047 (US2 drag-drop)
- Team B: T059–T067 (US6 keyboard) — can start after T027–T036
- Team C: T068–T075 (US7 layout) — can start after T027–T036

---

## MVP Scope & Timeline

**Minimum Viable Product**: US1–US5  
**Task Count**: ~56 tasks (T001–T058 + polish subset)  
**Sprint Estimate**: 5–7 two-week sprints  
**Parallel Potential**: 30% task overlap (US6, US7, polish can run in parallel)

**Critical Path** (blocks everything else):
- T001–T010: Setup (1 sprint)
- T011–T026: Foundational (1 sprint)
- T027–T036: US1 (1 sprint)
- T037–T047: US2 (1–2 sprints)
- T048–T058: US3–US5 (1–2 sprints)

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
