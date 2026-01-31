# Hand Component

## Overview
The Hand component manages the player's collection of available tiles. Selection is delegated to SelectionManager while Hand handles tile container management.

## Files
- `hand.gd` - Hand controller script
- `Hand.tscn` - Hand scene with HBoxContainer layout

## Architecture

### Hand (`hand.gd`)
- **Class**: `Hand extends Control`
- **Responsibility**: Tile container, tile queries, signal relay
- **Layout**: Horizontal box container (HBoxContainer)

## Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `tile_added` | `tile: Tile` | Tile added to hand |
| `tile_removed` | `tile: Tile` | Tile removed from hand |
| `hand_empty` | none | Hand became empty |

**Note**: Selection signals are now handled by EventBus via SelectionManager.

## Key Properties
```gdscript
@export var max_hand_size: int = 10  # Maximum tiles allowed
@onready var tile_container: HBoxContainer = $TileContainer
```

## Key Methods

### Tile Management
```gdscript
add_tile(tile: Tile) -> bool        # Add tile to hand
remove_tile(tile: Tile) -> bool     # Remove specific tile
clear_hand() -> Array[Tile]         # Remove and return all tiles
```

### Selection (Delegates to SelectionManager)
```gdscript
select_tile(tile: Tile) -> void     # Delegates to SelectionManager
deselect_all() -> void              # Delegates to SelectionManager
get_selected_tiles() -> Array[Tile] # Filters SelectionManager result
has_selection() -> bool             # Checks SelectionManager
```

### Queries
```gdscript
get_tile_count() -> int             # Number of tiles
get_tiles() -> Array[Tile]          # All tiles in hand
is_empty() -> bool                  # Hand empty check
is_full() -> bool                   # At max capacity
get_available_space() -> int        # Remaining slots
get_tile_at(index: int) -> Tile     # Tile by index
find_tile_by_letter(letter: String) -> Tile       # First matching
find_tiles_by_letter(letter: String) -> Array[Tile]  # All matching
```

## Selection Architecture

### Delegation Pattern
Hand delegates selection logic to SelectionManager:
```gdscript
func select_tile(tile: Tile) -> void:
    if not _has_tile(tile):
        return
    SelectionManager.select_tile(tile)

func get_selected_tiles() -> Array[Tile]:
    # Filter to only tiles in this hand
    return SelectionManager.get_selected_tiles().filter(
        func(t): return _has_tile(t)
    )
```

### Why Delegation?
- **Single Source of Truth**: SelectionManager owns selection state
- **Multi-component Support**: Board tiles could also be selectable
- **Mode Management**: SelectionManager handles single/multi-select
- **Order Tracking**: SelectionManager maintains selection order

## Usage Example
```gdscript
# Add a tile
var success = hand.add_tile(new_tile)
if not success:
    print("Hand is full!")

# Selection via SelectionManager
SelectionManager.select_tile(tile1)
SelectionManager.select_tile(tile2)

# Query selected tiles in hand
var to_discard = hand.get_selected_tiles()

# Query hand contents
var vowels = []
for tile in hand.get_tiles():
    if tile.letter in ["A", "E", "I", "O", "U"]:
        vowels.append(tile)
```

## Tile Flow

### Adding Tiles
```
TileBag.draw_tile()
    │
    ▼
HandManager.draw_tiles()
    │
    ▼
hand.add_tile(tile)
    │
    ├─► Reparent tile to TileContainer
    ├─► Set tile.location = IN_HAND
    ├─► Connect tile signals to Main
    └─► Emit tile_added signal
```

### Removing Tiles
```
hand.remove_tile(tile)
    │
    ├─► Remove from TileContainer
    ├─► Emit tile_removed signal
    └─► Check if empty → emit hand_empty
```

## Layout Notes
- Tiles are arranged horizontally
- HBoxContainer handles spacing automatically
- Hand is anchored to bottom-center of screen
- Maximum 10 tiles (configurable)

## Integration with Discard

When discarding via Z key or drag-to-pile:
1. SelectionManager provides selected tiles
2. Main filters to hand tiles only
3. HandManager.discard_tile() removes from hand
4. HandManager.refill_hand() draws replacements

## Future Considerations
- Hand sorting (alphabetical, by points)
- Hand capacity upgrades
- Special hand slots for power tiles
- Drag-to-reorder tiles
- Fan layout (overlapping tiles)
- Selection order visual indicators
