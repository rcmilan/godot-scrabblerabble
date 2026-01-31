# Tile Component

## Overview
The Tile component represents a letter tile that can be placed on the board or held in the player's hand. It supports click-to-select and drag-and-drop interactions.

## Files
- `tile.gd` - Tile controller script
- `Tile.tscn` - Tile scene with visual elements

## Architecture

### Tile (`tile.gd`)
- **Class**: `Tile extends Control`
- **Responsibility**: Tile state, drag/drop behavior, visual feedback
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
var letter: String  # The letter (A-Z)
var base_points: int  # Base point value
var tile_data: LetterTileData  # Source resource

# Modifiers (for future features)
var point_modifier: int  # Bonus/penalty
var is_wild: bool  # Wild card tile
var is_locked: bool  # Cannot be moved

# Location State
var location: TileLocation
var current_cell: BoardCell  # Only when ON_BOARD

# Selection State
var is_selected: bool
var allow_hover_feedback: bool
```

## Key Methods
```gdscript
initialize(data: LetterTileData) -> void  # Set up tile from data
set_selected(value: bool) -> void  # Toggle selection state
get_points() -> int  # Get total points with modifiers
can_interact() -> bool  # Check if interactable
reset() -> void  # Reset to initial state
```

## Visual Feedback
- **Normal**: White modulate
- **Hover**: Slightly brighter (Color 1.1, 1.1, 1.1)
- **Dragging**: Bright overlay (Color 1.2, 1.2, 1.2)
- **Selected**: Green border visible

## Usage Example
```gdscript
# Initialize a tile
var tile = tile_scene.instantiate()
tile.initialize(letter_tile_data)

# Check tile state
if tile.location == Tile.TileLocation.IN_HAND:
    if tile.can_interact():
        tile.set_selected(true)

# Get score contribution
var points = tile.get_points()
```

## Future Considerations
- Wild card tiles (blank tiles that can be any letter)
- Locked tiles (permanent placements)
- Tile modifiers (special effects)
- Visual effects for special tiles
- Tile animations
