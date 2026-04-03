# Research: Fix Orientation Icon Position After Board Resize

**Branch**: `002-fix-orientation-icon` | **Phase**: 0 | **Date**: 2026-04-03

## Overview

Bug: Orientation icon remains at old board coordinates when board dimensions change between rounds.

Root cause hypothesis: Icon position is calculated relative to screen space or a cached board state, not dynamically relative to grid coordinate (0,0).

## Findings

### Decision 1: Current Icon Positioning Mechanism

**Decision**: Orientation icon is positioned via a scene script (likely `board/board.gd` or `board/orientation_icon.gd`) that calculates screen-space coordinates on `_ready()` or during initial board setup, but does not update when board dimensions change.

**Rationale**: Standard Godot pattern for UI overlays. Icon is likely a Control node positioned absolutely at the board's (0,0) cell location. When board resizes, cell positions change but icon position is not recalculated.

**Investigation points**:
- Icon likely positioned in `_ready()` or `_init()` once, never updated
- No signal listening to board resize/dimension change events
- Icon position calculated from board cell size and board offset (screen position)

### Decision 2: Board Resize Event Pattern

**Decision**: Board resize is triggered at round transition (Shop → Next Round). This is a distinct event point where board scene is reinitialized with new dimensions. The icon needs to listen to this event or be repositioned as part of board initialization.

**Rationale**: Wordatro uses EventBus for decoupled communication (per Principle II). Board resize should emit an event (e.g., `EventBus.board_resized` or `board_dimensions_changed`) that other systems subscribe to.

**Integration approach**:
- Board resize happens during `RunManager` round transition
- Board's `_ready()` or `setup_grid()` method initializes dimensions
- After board is fully initialized, icon should be positioned via a method call or event subscription
- Icon position = board_offset + (cell_size * grid_position_offset_for_0_0)

### Decision 3: Icon Positioning Formula

**Decision**: Icon position must be calculated dynamically:
```
icon_global_position = board_top_left_screen_position + (cell_size_in_pixels × 0.5)
```
Where:
- `board_top_left_screen_position` = offset of board's visual top-left corner on screen
- `cell_size_in_pixels` = rendered pixel size of one grid cell (may change with board resize)
- Multiply by 0.5 to center icon within the (0,0) cell

**Rationale**: This ensures icon moves with board offset changes and scales with cell size changes. Grid coordinate (0,0) is fixed; screen position is dynamic.

**Assumptions**:
- Board offset is available from board script or calculated from board node's position
- Cell size is determined by board dimensions and available render space
- Icon should be centered in the cell (offset of 0.5 in cell dimensions)

---

## Implementation Approach

1. **Identify board resize trigger**: Find where board dimensions are set during round transitions
2. **Add board resize event**: Emit EventBus signal when board is initialized with new dimensions
3. **Create icon positioning method**: Extract icon positioning logic into reusable method
4. **Subscribe icon to resize event**: Icon listens for board resize and calls positioning method
5. **Test across board sizes**: Verify icon stays at (0,0) for 1x1, 7x7, 6x9, 8x8, and other sizes

---

## No External Dependencies

This is a pure positioning fix within the existing scene architecture. No new dependencies, frameworks, or external systems required. Uses existing Godot 4.6 features and EventBus pattern already in use.
