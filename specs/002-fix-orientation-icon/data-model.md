# Data Model: Fix Orientation Icon Position After Board Resize

**Branch**: `002-fix-orientation-icon` | **Date**: 2026-04-03

## Entities

### OrientationIcon (Scene Script or Node)

**Responsibility**: Render directional marker at board grid coordinate (0,0).

**Properties**:
- `_position: Vector2` — global screen position (calculated dynamically)
- `_board: Board` — reference to board for accessing dimensions and offset
- `_icon_node: Control/Node2D` — visual representation (H marker or arrow)

**Methods**:
- `_ready()` — initialize position on scene load
- `position_at_cell(cell_0_0_position: Vector2, cell_size_pixels: Vector2)` — set icon position based on (0,0) cell location and size
- `_on_board_resized(board_state: BoardState)` — listen to EventBus board resize signal and recalculate position

**State Transitions**:
- On scene load → initial position calculation
- On board resize event → recalculate position using new board dimensions
- On board offset change → recalculate position (screen coordinates shift)

---

### Board (Existing - Modified)

**Responsibility**: Grid container; now must emit resize event when dimensions change.

**New Requirements**:
- Emit `EventBus.board_resized` signal when board dimensions are set (during setup or round transition)
- Provide accessor for: board offset (screen-space top-left position), cell size in pixels, board dimensions
- Ensure icon can query these values at any time

**Methods to add/modify**:
- `_on_board_initialized()` or `setup_grid(width, height, ...)` → emit board_resized signal after grid is ready
- Getter: `get_top_left_screen_position() -> Vector2` — offset of board's visual top-left
- Getter: `get_cell_size_pixels() -> Vector2` — pixel dimensions of one cell

---

### EventBus Signal (Existing - Extended)

**Name**: `board_resized` (or similar)

**Parameters**:
- `board_state: BoardState` — current board state with dimensions

**Fired by**: Board script when dimensions are initialized or changed

**Subscribed by**: OrientationIcon script (and any other UI elements that depend on board layout)

---

## Relationships

```
OrientationIcon
  └── listens to: EventBus.board_resized
  └── references: Board (for position/size queries)
  
Board
  └── emits: EventBus.board_resized
  
EventBus
  └── connects: OrientationIcon, Board, (other systems)
```

---

## Positioning Formula

```
icon_global_position = board_top_left_offset + (cell_size × 0.5)

Where:
- board_top_left_offset: Vector2 from Board.get_top_left_screen_position()
- cell_size: Vector2 from Board.get_cell_size_pixels()
- 0.5 offset: centers icon within the (0,0) cell
```

## State Changes Requiring Icon Update

1. **Round transition (Shop → Next Round)**
   - Board is reinitialized with potentially new dimensions
   - Board emits `board_resized` event
   - Icon recalculates position

2. **Board offset shift** (if screen layout changes mid-round)
   - Board offset changes due to screen resize or layout adjustment
   - Board emits `board_offset_changed` event (or equivalent)
   - Icon recalculates position

3. **Icon moved by player** (if applicable)
   - Player moves icon away from (0,0)
   - On next board event, icon snaps back to (0,0)

