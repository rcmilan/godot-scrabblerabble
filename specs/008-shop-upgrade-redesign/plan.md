# Implementation Plan: Shop Upgrade Redesign

**Branch**: `008-shop-upgrade-redesign` | **Date**: 2026-04-19 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/008-shop-upgrade-redesign/spec.md`

## Summary

**Primary Requirement**: Transform the shop from a simple round summary screen into an interactive upgrade system. Players will preview modifier assignments to 10 randomly generated tiles via drag-and-drop, then commit changes for the next round. The shop animates in from the bottom (board slides up), and animates out to the top on commit (board slides back down).

**Technical Approach**: Implement ShopSession as an immutable domain object managing preview state. Extend TileAnimationStrategy for vertical slide animations (shop entrance/exit, board counterpart). Integrate with RunManager for tile/modifier sourcing and commit handling. Reuse existing ShakeTileAnimation for invalid drop feedback. Follow DDD pattern: domain logic in ShopSession, UI in ShopOverlay controller, communication via EventBus.

## Technical Context

**Language/Version**: GDScript (Godot 4.6 engine)  
**Primary Dependencies**: Godot 4.6 engine, existing TileAnimationStrategy system, EventBus autoload, RunManager  
**Storage**: N/A (shop session is ephemeral, committed tiles persisted via hand system)  
**Testing**: Manual testing in Godot editor (per constitution)  
**Target Platform**: Desktop (matches current project)  
**Project Type**: Desktop game (Godot-based word tile game)  
**Performance Goals**: 500ms animations (entrance/exit), 50ms ghost appear, 60fps smooth drag motion  
**Constraints**: Max 1 modifier per tile, 10 tiles, 2-3 modifiers per visit, full-screen Control (no modals)  
**Scale/Scope**: Single-player game screen (10 tiles, 3 modifiers, 2 buttons)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**I. Domain-Driven Design** ✓ PASS
- ShopSession will be pure domain logic (no Godot dependencies)
- No rule enforcement in ShopOverlay controller
- Domain returns new immutable tile copies on modifications

**II. Decoupled Communication** ✓ PASS
- Shop emits `continue_requested` signal → Main listens
- RunManager triggered via `run_shop_requested` event
- Internal tile updates may use EventBus or direct calls (tight coupling acceptable for shop state)

**III. Immutable Domain Objects** ✓ PASS
- ShopSession creates new TileState copies when modifiers applied
- Revert reconstructs original state, doesn't mutate in place

**IV. Thin Controllers** ✓ PASS
- ShopOverlay handles input routing and UI updates only
- Domain logic (tile modification, modifier validation) in ShopSession
- No business rules in ShopOverlay

**V. Manual Testing First** ✓ PASS
- Feature testable entirely in Godot editor
- No external dependencies or test harness required

**Architecture Constraints**:
- ✓ No Godot code in domain (ShopSession is pure GDScript)
- ✓ EventBus for inter-system communication
- ✓ No modals/popups (full-screen Control with visibility toggle)
- ✓ Autoload registry: uses existing RunManager, EventBus, TileAnimator
- ✓ Scene dependency injection: ShopOverlay receives Board, Hand refs in setup

**Status**: PASS - No violations

## Project Structure

### Documentation (this feature)

```text
specs/008-shop-upgrade-redesign/
├── spec.md              # Feature specification (input)
├── plan.md              # This file (Phase 0-1 planning)
├── research.md          # Phase 0 output (research findings)
├── data-model.md        # Phase 1 output (domain entities)
├── quickstart.md        # Phase 1 output (integration guide)
├── contracts/           # Phase 1 output (interface contracts)
│   └── shop_overlay_contract.md
├── checklists/
│   └── requirements.md
└── tasks.md             # Phase 2 output (implementation tasks - TBD)
```

### Source Code (Godot Game)

```text
# Existing project structure (Wordatro)
scripts/
├── domain/              # Pure business logic (NEW: ShopSession here)
│   ├── shop/
│   │   ├── shop_session.gd      # NEW: Domain state for shop
│   │   └── shop_modifier.gd     # NEW: Modifier assignment logic
│   ├── modifiers/
│   ├── deck/
│   └── [existing domain classes]
├── controllers/         # UI orchestration (MODIFY: ShopController here)
│   ├── shop_controller.gd       # NEW: Input routing, drag-drop handling
│   └── [existing controllers]
└── animation/           # Animation strategies (EXTEND: Shop animations)
    ├── shop/
    │   └── shop_slide_animation.gd  # NEW: Vertical slide strategy
    └── [existing animations]

scenes/
├── shop/                # MODIFY: Shop UI scene
│   ├── shop_overlay.tscn
│   ├── shop_overlay.gd          # MODIFY: Extend with new functionality
│   └── debug_round_config_popup.tscn (unchanged)
└── [existing scenes]

autoload/
├── event_bus.gd        # EXTEND: Add shop-specific signals if needed
├── run_manager.gd      # EXTEND: Add shop_tiles(), shop_modifiers() methods
└── [existing autoloads]
```

**Structure Decision**: Modular feature structure within existing Godot project. New shop logic in domain/shop/, controllers/shop_controller.gd, and animation/shop/. Minimal changes to existing systems (RunManager extension, event definitions).

## Complexity Tracking

No constitution violations. All checks pass (see Constitution Check section above).

---

## Phase 0: Research & Unknowns

### Research Tasks

1. **Godot 4 Drag-and-Drop Best Practices**
   - Input event handling for mouse drag (InputEvent.position tracking)
   - Drag preview/ghost node management
   - Drop zone validation (Area2D, overlap detection, or pure input logic)
   - Decision: Use InputEvent-based drag tracking + custom ghost Control node

2. **Vertical Animation Composition in Godot**
   - How to sync two simultaneous animations (shop slide up, board slide down)
   - Tween composition patterns
   - Reuse existing TileAnimationStrategy for consistency
   - Decision: Extend TileAnimationStrategy to define board's counterpart animation

3. **RunManager Integration Pattern**
   - Current shop invocation point (run_shop_requested signal)
   - How to add get_shop_tiles(count) and get_shop_modifiers(count) methods
   - Return types: Array[TileState], Array[ModifierType]
   - Decision: Add methods to RunManager that delegate to TileBag and modifier pool

4. **Immutable TileState Copies in Shop**
   - How to create independent copies of TileState objects
   - Deep copy strategy (clone method, or reconstruct from attributes)
   - Preserving pre-loaded modifier state across copies
   - Decision: Implement TileState.create_shop_copy() method

**Output**: Findings consolidated in research.md (to be generated during Phase 1)

---

## Phase 1: Design & Contracts

### 1.1 Data Model (data-model.md)

**Entities to define**:

1. **ShopSession** (domain/shop/shop_session.gd)
   - Fields: available_modifiers, available_tiles, pending_assignments, is_boss_round
   - Methods: apply_modifier(tile, modifier), revert_all(), get_session_state(), get_final_tiles()
   - Immutability: Returns new ShopSession on modifications

2. **TileState Modifications**
   - Add: pre_loaded_modifier (ModifierInstance | null)
   - Add: session_modifier (ModifierInstance | null)
   - Add: create_shop_copy() method
   - Methods: swap_modifier(old_mod, new_mod), revert_to_original()

3. **ModifierInstance** (existing, may need enhancement)
   - Fields: modifier_type, applied_tile (optional reference)
   - Ensure immutable, no circular references

4. **ShopAnimation** (animation/shop/shop_slide_animation.gd)
   - Extends TileAnimationStrategy
   - Implements: get_animation(tile) for shop entrance/exit
   - Board counterpart managed by orchestrator (Main or TileAnimator)

### 1.2 Contracts (contracts/)

**ShopOverlay Interface** (contracts/shop_overlay_contract.md):
- Public methods: show_shop(round_completed, round_score, next_config)
- Signals: continue_requested
- Input handling: keyboard (Enter, Tab), mouse (drag-drop)
- Acceptable call sites: Main.gd only

### 1.3 Integration Guide (quickstart.md)

Steps to integrate shop into existing game:
1. Add RunManager.get_shop_tiles() and get_shop_modifiers()
2. Extend ShopOverlay with drag-drop handling
3. Update Main._on_shop_continue() to handle committed tiles
4. Add ShopSession to RunManager state on commit
5. Register shop animations with TileAnimator
6. Manual test flow: Win round → shop appears → drag modifiers → commit → next round

### 1.4 Post-Design Constitution Re-Check

All Phase 1 outputs reviewed for compliance:
- ✓ ShopSession is pure domain (no Godot nodes)
- ✓ ShopOverlay is thin controller (routes input only)
- ✓ Immutability preserved (new objects on modifications)
- ✓ EventBus integration (continue_requested signal)
- ✓ Full-screen Control (no modals)

---

## Next Phase

Phase 2 will generate `tasks.md` with:
- Implementation step-by-step tasks
- File creation/modification checklist
- Manual test acceptance criteria
- Dependencies between tasks

Run `/speckit.tasks` when Phase 0-1 artifacts are ready.
