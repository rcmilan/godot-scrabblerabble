# Local Managers

## Overview
Local manager nodes created at runtime and injected into consumers. Unlike autoloads (which persist globally), these managers are created per-scene instance and follow dependency injection patterns for testability and flexibility.

## Files
- `selection_manager.gd` - Tile selection state (created by Main)
- `drag_manager.gd` - Multi-tile drag coordination (created by GameplayController)

---

## SelectionManager (Local Node)

### Purpose
Central source of truth for tile selection state. Manages single-select and multi-select modes with ordered selection tracking. Created by Main and injected into consumers.

**Why Local?** Selection state is scene-specific. Each gameplay instance gets its own SelectionManager. This enables testing in isolation and supports UI components that need selection state without depending on a global autoload.

### Lifecycle
```gdscript
# In Main._ready():
_selection_manager = SelectionManager.new()
_selection_manager.name = "SelectionManager"
add_child(_selection_manager)

# Injected into consumers:
hand.set_selection_manager(_selection_manager)
discard_pile.set_selection_manager(_selection_manager)
multi_select_indicator.set_selection_manager(_selection_manager)
gameplay_controller.setup(..., _selection_manager)
```

### Signals (on SelectionManager instance)
| Signal | Parameters | Description |
|--------|------------|-------------|
| `mode_changed` | `is_multi: bool` | Single/multi mode toggled |
| `selection_changed` | `tiles: Array` | Selection state changed |

### Selection Modes
```gdscript
enum SelectionMode {
    SINGLE,  # Click deselects others, one tile at a time
    MULTI    # Click toggles, multiple tiles can be selected
}
```

### Key Methods
```gdscript
toggle_mode() -> void
set_mode(new_mode: SelectionMode)
is_multi_select_enabled() -> bool
select_tile(tile: Tile) -> void
deselect_tile(tile: Tile) -> void
deselect_all() -> void
get_selected_tiles() -> Array[Tile]
get_selection_count() -> int
has_selection() -> bool
```

### Behavior

**SINGLE Mode:**
- Clicking a tile deselects all others
- Only one tile selected at a time
- `select_tile()` automatically deselects previous selection

**MULTI Mode:**
- Each `select_tile()` toggles the tile's selection
- Multiple tiles can be selected simultaneously
- Selection order maintained in `get_selected_tiles()` array
- When mode switches back to SINGLE: All tiles auto-deselect

### Usage Pattern
```gdscript
# In consumers (injected via set_selection_manager):
func _on_tile_clicked(tile: Tile) -> void:
    SelectionManager.select_tile(tile)

# Query selected tiles:
var selected = SelectionManager.get_selected_tiles()

# Listen to changes:
func _ready() -> void:
    SelectionManager.mode_changed.connect(_on_mode_changed)
    SelectionManager.selection_changed.connect(_on_selection_changed)
```

---

## DragManager (Local Node)

### Purpose
Coordinates multi-tile drag operations. Handles visual positioning and state management of dragged tiles during mouse drag. Separates drag logic from individual tile drag state machines.

**Why Local?** DragManager is specific to a GameplayController instance. Each gameplay session manages its own drag state. This prevents conflicts if multiple gameplay scenes were running (desktop windowing, editor preview, etc).

### Lifecycle
Created and owned by GameplayController:
```gdscript
# In GameplayController.setup():
_drag_mgr = DragManager.new()
add_child(_drag_mgr)

# Injected into DropHandler:
_drop.setup(_placement, _hand, _selection, _drag_mgr)
```

### Core State
```gdscript
is_dragging: bool = false                      # Drag in progress
dragged_tiles: Array[Tile] = []                # All tiles being dragged
lead_tile: Tile = null                         # Tile directly under cursor

_original_parents: Dictionary = {}             # Tile → original parent node
_original_positions: Dictionary = {}           # Tile → original Vector2 position
_original_indices: Dictionary = {}             # Tile → original child index
_relative_offsets: Dictionary = {}             # Tile → offset from lead tile
_drag_container: Control = null                # Temporary parent during drag
```

### Configuration
- `DRAG_Z_INDEX: int = 100` - Z-index for dragged tiles (above everything)
- `TILE_SPACING: float = 68.0` - Spacing between tiles in drag preview

### Key Methods

#### Drag Control
- `start_drag(lead: Tile, tiles: Array[Tile]) -> void` - Begin multi-tile drag
  - lead: The tile being directly dragged (must be in tiles array)
  - tiles: All tiles to drag (including lead)
  - Stores original state (parents, positions, indices)
  - Calculates relative offsets from lead tile
  - Reparents all tiles to _drag_container
  - Sets is_dragging = true
  - Emits `drag_started(dragged_tiles)`
  - Emits `EventBus.multi_drag_started(dragged_tiles)`

- `end_drag(success: bool) -> void` - Complete drag operation
  - Emits `drag_ended(dragged_tiles, success)`
  - Emits `EventBus.multi_drag_ended(dragged_tiles, success)`
  - Sets is_dragging = false
  - Cleanup delegated to caller

- `cancel_drag() -> void` - Cancel drag and restore tiles
  - Restores tiles to original parents and positions
  - Emits `drag_cancelled(dragged_tiles)`
  - Restores cell bindings (atomic state)

- `restore_tiles_to_parents() -> void` - Return tiles to original parents
  - Sorts tiles by original index to maintain order
  - Removes from _drag_container
  - Re-adds to original parents in original order
  - Restores cell bindings for board tiles

#### Queries
- `get_drag_position() -> Vector2` - Lead tile's global position
- `get_dragged_tiles() -> Array[Tile]` - Copy of dragged_tiles
- `get_original_parent(tile: Tile) -> Node` - Original parent of tile
- `get_original_position(tile: Tile) -> Vector2` - Original position of tile

### Signals (on DragManager instance)
- `drag_started(tiles: Array[Tile])` - Drag initiated
- `drag_ended(tiles: Array[Tile], success: bool)` - Drag completed
- `drag_cancelled(tiles: Array[Tile])` - Drag cancelled/failed
- `drag_release_requested(lead_tile: Tile)` - Mouse released during drag

### EventBus Integration
- Emits `EventBus.multi_drag_started(tiles)` when drag begins
- Emits `EventBus.multi_drag_ended(tiles, success)` when drag ends
- Used by DiscardPile to receive drag enter/exit notifications

### Atomic State Management
- Before drag: Clears cell.tile binding via `tile.suspend_cell_binding()`
- After successful placement: Maintains new binding via `tile.attach_to_cell(new_cell)`
- On cancelled drag: Restores original binding via `tile.restore_cell_binding()`
- Never leaves partial state where tile.current_cell and cell.tile are desynchronized

### Usage Pattern
```gdscript
# In GameplayController.setup():
_drag_mgr = DragManager.new()
add_child(_drag_mgr)

# In DropHandler:
_drag_mgr.start_drag(lead_tile, selected_tiles)

# On drop success:
_drag_mgr.end_drag(true)
_drag_mgr.restore_tiles_to_parents()
# ... place tiles on cells ...

# On drop failure:
_drag_mgr.cancel_drag()  # Auto-restores tiles
```

---

## Design Principles

### Local vs Global
| Aspect | Autoload | Local Manager |
|--------|----------|---------------|
| Lifetime | Game session | Scene instance |
| Instances | Single global | Per-scene |
| Persistence | Survives scene changes | Destroyed with scene |
| Dependency | Accessed via name | Injected via setup() |
| Testing | Harder (exists globally) | Easier (can instantiate alone) |

### Dependency Injection
Both managers use dependency injection pattern:
- Created by a parent scene/controller
- Injected into consumers via `set_selection_manager()` or `setup()`
- Consumers receive references, never access as autoloads
- Benefits:
  - Testable: Inject mock managers for unit tests
  - Flexible: Easy to swap implementations
  - Clear: Dependencies visible in method signatures
  - Composable: Build complex interactions from simple pieces

---

## Integration with Global Systems

### EventBus Bridging
Local managers emit to EventBus for cross-system communication:
- `SelectionManager` → (no EventBus signals, local only)
- `DragManager` → EventBus.multi_drag_started, EventBus.multi_drag_ended

### Main Scene Responsibilities
Main coordinates all manager creation and injection:
```gdscript
# In Main._ready():
_selection_manager = SelectionManager.new()
add_child(_selection_manager)

# Distribute to consumers
hand.set_selection_manager(_selection_manager)
discard_pile.set_selection_manager(_selection_manager)
multi_select_indicator.set_selection_manager(_selection_manager)

# Pass to controller for further distribution
_gameplay_controller.setup(..., _selection_manager)
```

This avoids tight coupling and keeps Main as the composition root.
