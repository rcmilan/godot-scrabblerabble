# Implementation Plan: Fix Orientation Icon Position After Board Resize

**Branch**: `002-fix-orientation-icon` | **Date**: 2026-04-03 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/002-fix-orientation-icon/spec.md`

## Summary

Bug: Orientation icon remains at old board coordinates when board dimensions change between rounds. Fix: Anchor icon to grid coordinate (0,0) and recalculate position whenever board is resized. Approach: Add dynamic position calculation based on board dimensions and offset; emit EventBus signal on board resize; subscribe icon to signal for automatic repositioning.

## Technical Context

**Language/Version**: GDScript (Godot 4.6)  
**Primary Dependencies**: Godot 4.6 UI system, EventBus (existing autoload), Board scene system  
**Storage**: N/A (in-memory game state)  
**Testing**: Manual in Godot editor (per Principle V - Manual Testing First)  
**Target Platform**: Desktop Windows/macOS/Linux via Godot export  
**Project Type**: Desktop game (Wordatro - Scrabble-like word tile game)  
**Performance Goals**: 60 fps gameplay (standard game performance); icon positioning <1ms  
**Constraints**: Position calculation must occur before board render to avoid visual flicker; icon must update synchronously with board resize  
**Scale/Scope**: Single feature affecting one UI element; board dimensions vary per round (6x9, 7x7, 8x8, etc.)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Domain-Driven Design | PASS | Fix is UI layer (scene positioning), not domain logic. No domain changes needed. |
| II. Decoupled Communication | PASS | Uses EventBus signal for board resize notification; icon subscribes to signal. Maintains decoupling. |
| III. Immutable Domain Objects | PASS | No domain objects modified; purely scene/controller layer. |
| IV. Thin Controllers | PASS | Icon positioning is visual concern (scene script), not logic routing. |
| V. Manual Testing First | PASS | Manual test suite provided in quickstart.md. No automated test framework required. |
| No Modals/Popups | PASS | Not applicable (pure positioning fix, no UI state changes). |

**Result**: No violations. All principles satisfied. No Complexity Tracking needed.

## Project Structure

### Documentation (this feature)

```text
specs/002-fix-orientation-icon/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 findings (completed)
├── data-model.md        # Phase 1 entities and relationships
├── quickstart.md        # Phase 1 manual test guide
├── checklists/
│   └── requirements.md  # Spec quality validation
└── tasks.md             # Phase 2 task breakdown (/speckit.tasks command)
```

### Source Code (affected paths)

```text
scenes/board/
├── board.gd              # MODIFY: Add board_resized event emission
├── board.tscn            
└── orientation_icon.gd   # MODIFY: Add position update on board resize event

autoload/
└── EventBus.gd           # VERIFY/MODIFY: Add board_resized signal if not present
```

**Structure Decision**: Single project, Godot game. Fix is isolated to board-related scene scripts. No new files created; modifications only to existing board and icon scripts. EventBus extended if needed to include board_resized signal.

## Complexity Tracking

No Constitution Check violations. No complexity justifications needed.
