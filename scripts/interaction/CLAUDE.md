# Scripts/Interaction Directory

User input handling utilities for tile interaction and drag operations.

---

## Overview

The Interaction subsystem handles low-level tile input mechanics:
- Drag state detection for individual tiles
- Multi-tile drag coordination (via DragManager)
- Input discrimination (click vs drag)

---

## Files

### tile_drag_helper.gd

**Type:** Utility helper

**Purpose:** Per-tile drag state machine for distinguishing clicks from drags.

**State Machine:**
```
IDLE
  ├──→ (mouse button down) → PRESSED
       ├──→ (mouse moved > threshold) → DRAGGING
       │    └─ Tile follows cursor
       └──→ (mouse button up while in PRESSED) → IDLE
            └─ Emit tile_selected signal (click detected)

DRAGGING
  ├─ (mouse moved) → Update tile position to follow cursor
  └─ (mouse button up) → IDLE
      └─ Emit tile_drag_ended signal (drag complete)
```

**API:**
```gdscript
class_name TileDragHelper

# State tracking
var is_pressed: bool = false
var is_dragging: bool = false
var drag_threshold: float = 8.0

# Position tracking
var press_position: Vector2 = Vector2.ZERO
var current_drag_offset: Vector2 = Vector2.ZERO

# Public methods
func on_mouse_down(global_pos: Vector2) -> void:
    # Transition: IDLE → PRESSED
    
func on_mouse_move(global_pos: Vector2) -> void:
    # Check if movement exceeds threshold
    # Transition: PRESSED → DRAGGING if needed
    
func on_mouse_up() -> void:
    # Transition back to IDLE
    # Emit appropriate signal
```

**Signals:**
- `tile_selected()` - Click detected (short press + release)
- `tile_drag_started(offset: Vector2)` - Drag threshold crossed
- `tile_drag_updated(offset: Vector2)` - Tile position updated (mouse moved)
- `tile_drag_ended(offset: Vector2)` - Mouse released during drag

---

## Integration with Tile Input

```gdscript
# In Tile.gd
extends Control
class_name Tile

var _drag_helper: TileDragHelper

func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            _drag_helper.on_mouse_down(get_global_mouse_position())
        elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            _drag_helper.on_mouse_up()
    
    elif event is InputEventMouseMotion:
        _drag_helper.on_mouse_move(get_global_mouse_position())
```

---

## Multi-Tile Drag Coordination

For multi-tile drag operations:

1. **Single Tile Receives Input** → Emits `tile_drag_started`
2. **Main/GameplayController** → Starts DragManager:
   ```gdscript
   func _on_tile_drag_started(tile: Tile, offset: Vector2):
       if _selection.has_selection():
           var lead = tile
           var all_selected = _selection.get_selected_tiles()
           _drag_mgr.start_drag(lead, all_selected)
   ```

3. **DragManager** → Coordinates all tiles:
   - Reparents to temporary drag container
   - Updates positions based on lead tile movement
   - Handles release via input event (caught by DragManager._input())

4. **Drop Validation** → DropHandler validates placement
5. **Restore or Place** → Tiles moved to final location

---

## Design Rationale

### Why Separate Helper?
- Single responsibility: Detect drag vs click
- Reusable: Can be used for any draggable element
- Testable: State logic isolated from Tile scene logic
- Stateless: No side effects, pure state transitions

### Why Global DragManager?
- Coordinates multiple tiles from different parents
- Handles reparenting during drag (visual positioning)
- Catches global input events (important after reparenting)
- Detects drop zone validation during drag

---

## Common Tasks

### Adjusting Drag Threshold

```gdscript
# In TileDragHelper
var drag_threshold: float = 8.0  # pixels

# Set globally in Tile initialization:
_drag_helper.drag_threshold = 10.0
```

### Adding Hover Effects

```gdscript
# In Tile.mouse_entered/exited handlers
# TileDragHelper emits drag_started/ended signals
# Listen in GameplayController to apply visual effects

_drag_mgr.drag_started.connect(_on_drag_started)
```

### Implementing Snap-to-Grid

```gdscript
# In DragManager._update_drag_positions()
# Can snap lead tile to nearest grid cell

var snapped_pos = snap(lead_tile.position, Vector2(64, 64))
```

---

## Future Enhancements

- **Tap and hold** - Support mobile long-tap to initiate drag
- **Swipe gestures** - Multi-touch drag on mobile
- **Momentum scrolling** - For hand scrolling on small screens
- **Gesture shortcuts** - E.g., V swipe to discard
