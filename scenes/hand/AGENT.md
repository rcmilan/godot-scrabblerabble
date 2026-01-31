# Hand Component

## Overview
The Hand component manages the player's collection of available tiles. It supports single and multi-select operations for tile placement and discarding.

## Files
- `hand.gd` - Hand controller script
- `Hand.tscn` - Hand scene with HBoxContainer layout

## Architecture

### Hand (`hand.gd`)
- **Class**: `Hand extends Control`
- **Responsibility**: Tile container, selection management, hand queries
- **Layout**: Horizontal box container (HBoxContainer)

## Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `tile_added` | `tile: Tile` | Tile added to hand |
| `tile_removed` | `tile: Tile` | Tile removed from hand |
| `selection_changed` | `selected: Array[Tile]` | Selection state changed |
| `hand_empty` | none | Hand became empty |

## Key Properties
```gdscript
@export var max_hand_size: int = 10  # Maximum tiles allowed
var _selected_tiles: Array[Tile]  # Currently selected tiles
```

## Key Methods

### Tile Management
```gdscript
add_tile(tile: Tile) -> bool  # Add tile to hand
remove_tile(tile: Tile) -> bool  # Remove specific tile
clear_hand() -> Array[Tile]  # Remove and return all tiles
```

### Selection (for multi-select feature)
```gdscript
select_tile(tile: Tile) -> void  # Select single tile
toggle_tile_selection(tile: Tile) -> void  # Toggle for multi-select
deselect_all() -> void  # Clear selection
select_all() -> void  # Select all tiles
get_selected_tiles() -> Array[Tile]  # Get selection
has_selection() -> bool  # Check if anything selected
```

### Queries
```gdscript
get_tile_count() -> int  # Number of tiles
get_tiles() -> Array[Tile]  # All tiles
is_empty() -> bool  # Hand empty check
is_full() -> bool  # At max capacity
get_available_space() -> int  # Remaining slots
get_tile_at(index: int) -> Tile  # Tile by index
find_tile_by_letter(letter: String) -> Tile  # First matching letter
find_tiles_by_letter(letter: String) -> Array[Tile]  # All matching
```

## Usage Example
```gdscript
# Add a tile
var success = hand.add_tile(new_tile)
if not success:
    print("Hand is full!")

# Multi-select for discarding
hand.toggle_tile_selection(tile1)
hand.toggle_tile_selection(tile2)
var to_discard = hand.get_selected_tiles()

# Query hand contents
var vowels = []
for tile in hand.get_tiles():
    if tile.letter in ["A", "E", "I", "O", "U"]:
        vowels.append(tile)
```

## Layout Notes
- Tiles are arranged horizontally
- HBoxContainer handles spacing automatically
- Hand is anchored to bottom-center of screen

## Future Considerations
- Multi-select UI (checkboxes, selection indicators)
- Hand sorting (alphabetical, by points)
- Hand capacity upgrades
- Special hand slots for power tiles
- Drag-to-reorder tiles
