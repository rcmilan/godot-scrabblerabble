# Tile Component

## Overview
The Tile component represents a letter tile that can be placed on the board or held in the player's hand. It supports click-to-select and drag-and-drop interactions with visual feedback.

## Files
- `tile.gd` - Tile controller script
- `Tile.tscn` - Tile scene with visual elements

## Architecture

### Tile (`tile.gd`)
- **Class**: `Tile extends Control`
- **Responsibility**: Tile state, drag/drop behavior, selection visuals
- **Size**: 64x64 pixels

## State Machines

### DragState
```gdscript
enum DragState {
    IDLE,      # No interaction
    PRESSED,   # Mouse down, waiting for drag threshold
    DRAGGING   # Actively being dragged
}
```

**Transitions**:
- `IDLE -> PRESSED`: Left mouse button pressed
- `PRESSED -> DRAGGING`: Mouse moved beyond threshold (8px)
- `PRESSED -> IDLE`: Mouse released (triggers `tile_selected`)
- `DRAGGING -> IDLE`: Mouse released (triggers `tile_drag_ended`)

### TileLocation
```gdscript
enum TileLocation {
    IN_BAG,      # Not yet drawn
    IN_HAND,     # Player's hand
    ON_BOARD,    # Placed on board
    IN_DISCARD   # Discarded
}
```

## Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `tile_selected` | `tile: Tile` | Tile was clicked (not dragged) |
| `tile_right_clicked` | `tile: Tile` | Right-click on tile |
| `tile_drag_started` | `tile: Tile` | Drag began |
| `tile_drag_ended` | `tile: Tile` | Drag completed |

## Key Properties
```gdscript
# Tile Data (from LetterTileData resource)
var letter: String              # The letter (A-Z)
var base_points: int            # Base point value
var tile_data: LetterTileData   # Source resource

# State Flags
var point_modifier: int         # Bonus/penalty
var is_wild: bool               # Wild card tile
var is_locked: bool             # Cannot be moved (synced from LOCKED modifier)

# Composable Modifiers
var modifiers: Dictionary = {}  # Keyed by ModifierTypes.Type → ModifierInstance

# Location State
var location: TileLocation
var current_cell: BoardCell     # Only when ON_BOARD

# Selection State
var is_selected: bool
var selection_order: int = -1   # Position in multi-select (-1 if not)
var allow_hover_feedback: bool
```

## Key Methods
```gdscript
initialize(data: LetterTileData) -> void  # Set up tile from data
set_selected(value: bool) -> void         # Toggle selection with animation
set_selection_order(order: int) -> void   # Set position in multi-select
set_locked(value: bool) -> void           # Add/remove LOCKED modifier (syncs is_locked)
get_points() -> int                       # Get total points with modifiers
can_interact() -> bool                    # Check if interactable (not locked)
reset() -> void                           # Reset to initial state
```

## Modifier Management
```gdscript
add_modifier(modifier: ModifierInstance) -> void   # Add modifier (one per type), syncs is_locked for LOCKED
remove_modifier(type: ModifierTypes.Type) -> void  # Remove by type
has_modifier(type: ModifierTypes.Type) -> bool     # Check presence
consume_modifiers() -> void                        # Remove CONSUMABLE modifiers only
clear_round_modifiers() -> void                    # Remove CONSUMABLE + PER_ROUND
clear_modifiers() -> void                          # Remove all modifiers
resolve_play_animation() -> ModifierTypes.PlayAnimation  # Query behaviors for animation type
```

### LOCKED Modifier Integration
`set_locked(true)` creates a LOCKED modifier (PER_ROUND lifetime) via the modifier system. `is_locked` is automatically synced in `add_modifier()`, `remove_modifier()`, `consume_modifiers()`, `clear_round_modifiers()`, and `clear_modifiers()`. This preserves backward compatibility — any code checking `is_locked` or calling `can_interact()` works unchanged.

## Placement State Management (DDD)

The Tile class manages the bidirectional relationship with BoardCell atomically to prevent state inconsistencies. All placement operations should use these methods instead of directly manipulating `current_cell`, `cell.tile`, or `location`.

### Methods
```gdscript
# Atomic operations - always use these for tile-cell bindings
attach_to_cell(cell: BoardCell) -> void  # Place tile on cell (sets both references)
detach_from_cell() -> void               # Remove from cell (clears both references)

# Drag operations - temporary suspension of binding
suspend_cell_binding() -> void           # Clear cell.tile but keep current_cell
restore_cell_binding() -> void           # Restore cell.tile from current_cell

# Location changes
move_to_hand() -> void                   # Detach from cell, set location to IN_HAND
move_to_discard() -> void                # Detach from cell, set location to IN_DISCARD

# Queries
has_active_cell_binding() -> bool        # True if tile has valid, unsuspended binding
```

### State Consistency Pattern
```gdscript
# BAD - can cause state inconsistency
tile.current_cell = cell
cell.tile = tile
tile.location = Tile.TileLocation.ON_BOARD

# GOOD - atomic operation ensures consistency
tile.attach_to_cell(cell)

# BAD - drag cleanup can miss cell restoration
cell.tile = null  # during drag
# ... later forget to restore cell.tile

# GOOD - suspend/restore pattern for drags
tile.suspend_cell_binding()  # clears cell.tile, keeps current_cell
# ... drag operation ...
tile.restore_cell_binding()  # restores cell.tile from current_cell
```

## Visual Feedback

### Colors & Modifiers
- **Normal**: White modulate
- **Hover**: Slightly brighter (Color 1.1, 1.1, 1.1), uses modifier tint as base
- **Dragging**: Bright overlay (Color 1.2, 1.2, 1.2), uses modifier tint as base
- **Selected**: Green border visible
- **Locked**: Black 2px border (LockedBorder panel), hidden during play animations
- **Modifier Tint**: Determined by `ModifierVisualPipeline` (EXTRA/MULTI/EXPO have tier-based tints)
- **Invert Shader**: Applied to RESET tiles (via lazy-loaded ShaderMaterial)
- **Badges**: Displayed in BadgeContainer (HBoxContainer) — `+` for EXTRA, `x` for MULTI, `^` for EXPO
- **Spark Effect**: Particle sparks on EXPO tiles (TileSparkEffect child node)

### Scale Animation
```gdscript
const SELECTED_SCALE: Vector2 = Vector2(1.05, 1.05)  # 5% larger when selected
const NORMAL_SCALE: Vector2 = Vector2(1.0, 1.0)
const SCALE_TWEEN_DURATION: float = 0.1

func _animate_selection_scale() -> void:
    var target_scale = SELECTED_SCALE if is_selected else NORMAL_SCALE
    var tween = create_tween()
    tween.tween_property(self, "scale", target_scale, SCALE_TWEEN_DURATION)
        .set_ease(Tween.EASE_OUT)
```

### Z-Index During Drag
```gdscript
const DRAG_Z_INDEX: int = 100  # Ensures dragged tile is on top
```

## Drag Behavior

### Drag Threshold
Movement must exceed 8 pixels before drag begins. This allows click-to-select without triggering drag.

### Drag Flow
1. Mouse pressed → Enter PRESSED state
2. Mouse moved beyond threshold → Enter DRAGGING state
3. Tile follows cursor (updated in `_process`)
4. Mouse released → Emit `tile_drag_ended`, return to IDLE

## Selection Integration

The tile works with SelectionManager for selection state:
```gdscript
# In Main._on_tile_selected()
SelectionManager.select_tile(tile)

# SelectionManager calls tile methods:
tile.set_selected(true)
tile.set_selection_order(index)
```

## Usage Example
```gdscript
# Initialize a tile
var tile = tile_scene.instantiate()
tile.initialize(letter_tile_data)

# Check tile state
if tile.location == Tile.TileLocation.IN_HAND:
    if tile.can_interact():
        SelectionManager.select_tile(tile)

# Get score contribution
var points = tile.get_points()

# Check selection order
var order = tile.selection_order  # -1 if not selected
```

### Scene Structure (Tile.tscn)
```
Tile (Control, 64x64)
├── TextureRect         # Letter texture
├── BadgeContainer      # HBoxContainer for modifier badges (+, x, ^)
├── Border              # Green selection border (visible when selected)
└── LockedBorder        # Black 2px border (visible when is_locked)
```

## Future Considerations
- Wild card tiles (blank tiles that can be any letter)
- Selection order number display
- Additional modifier types and visual effects
