# Board Component

## Overview
The Board component manages the game grid where tiles are placed to form words. It dynamically generates cells based on configurable rows and columns.

## Files
- `board.gd` - Board controller script
- `board_cell.gd` - Individual cell script
- `Board.tscn` - Board scene (GridContainer-based)
- `BoardCell.tscn` - Cell scene template

## Architecture

### Board (`board.gd`)
- **Class**: `Board extends Control`
- **Responsibility**: Grid generation, cell management, hover detection
- **Key Properties**:
  - `rows: int` - Number of rows (default: 8)
  - `columns: int` - Number of columns (default: 8)
  - `cell_size: int` - Cell size in pixels (default: 64)
  - `cell_spacing: int` - Gap between cells (default: 4)

### BoardCell (`board_cell.gd`)
- **Class**: `BoardCell extends Control`
- **Responsibility**: Individual cell state, tile placement, visual feedback
- **Key Properties**:
  - `tile: Tile` - Currently placed tile (or null)
  - `grid_position: Vector2i` - Cell coordinates
  - `cell_type: CellType` - Special cell type (for multipliers)

## Signals

### Board Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `board_initialized` | `rows, columns` | Grid generation complete |
| `cell_clicked` | `cell: BoardCell` | Cell was clicked |
| `cell_hovered` | `cell: BoardCell` | Mouse entered cell |
| `cell_unhovered` | `cell: BoardCell` | Mouse exited cell |

### BoardCell Signals
| Signal | Parameters | Description |
|--------|------------|-------------|
| `cell_clicked` | `cell: BoardCell` | Cell was clicked |
| `cell_hovered` | `cell: BoardCell` | Mouse entered |
| `cell_unhovered` | `cell: BoardCell` | Mouse exited |

## Key Methods

### Board
```gdscript
get_cell(row: int, col: int) -> BoardCell    # Get cell by coordinates
get_cell_at_position(pos: Vector2) -> BoardCell  # Get cell at world position
get_all_cells() -> Array[BoardCell]          # Get all cells
get_cell_coords(cell: BoardCell) -> Vector2i # Get cell coordinates
get_grid_state() -> Array[Array]             # Get 2D array of tiles
clear_board() -> void                        # Remove all tiles
resize_board(rows: int, cols: int) -> void   # Resize grid
add_row() -> void                            # Add row to bottom
add_column() -> void                         # Add column to right
```

### BoardCell
```gdscript
is_occupied() -> bool            # Has tile placed
can_place_tile() -> bool         # Can accept tile
place_tile(tile: Tile) -> bool   # Place tile
remove_tile() -> Tile            # Remove and return tile
clear_tile() -> void             # Just clear reference
show_valid_hover() -> void       # Green overlay
show_invalid_hover() -> void     # Red overlay
clear_hover() -> void            # Hide overlay
get_letter_multiplier() -> int   # Letter score multiplier
get_word_multiplier() -> int     # Word score multiplier
```

## Cell Types
```gdscript
enum CellType {
    NORMAL,        # No multiplier (1x)
    DOUBLE_LETTER, # 2x letter score
    TRIPLE_LETTER, # 3x letter score
    DOUBLE_WORD,   # 2x word score
    TRIPLE_WORD,   # 3x word score
    STAR           # Center cell (2x word)
}
```

## Visual Feedback

### Hover Colors
```gdscript
# Valid placement hover
COLOR_VALID = Color(0.0, 1.0, 0.0, 0.45)  # Green

# Invalid placement hover
COLOR_INVALID = Color(1.0, 0.0, 0.0, 0.65)  # Red

# Special cell highlight
COLOR_SPECIAL = Color(1.0, 0.84, 0.0, 0.3)  # Gold
```

### Multi-tile Hover
When multiple tiles are selected, Main requests sequential cell validation:
```gdscript
# In Main._on_cell_hovered()
var cells = _get_sequential_cells(cell, selected_count)
if cells.is_empty():
    cell.show_invalid_hover()
else:
    for c in cells:
        c.show_valid_hover()
```

## Tile Placement

### Single Tile
```gdscript
# In Main.place_tile_on_cell()
tile.get_parent().remove_child(tile)
cell.tile_anchor.add_child(tile)
tile.position = Vector2.ZERO
tile.current_cell = cell
tile.location = Tile.TileLocation.ON_BOARD
cell.tile = tile
```

### Multi-tile Placement
```gdscript
# In Main._handle_multi_tile_drop()
var cells = _get_sequential_cells(start_cell, tiles.size())
for i in tiles.size():
    _place_tile_on_cell_silent(tiles[i], cells[i])
SelectionManager.deselect_all()
```

### Sequential Cells
Multi-tile placement requires consecutive empty cells:
```gdscript
func _get_sequential_cells(start: BoardCell, count: int) -> Array[BoardCell]:
    var cells: Array[BoardCell] = []
    var pos = start.grid_position
    var direction = Vector2i.RIGHT  # Future: configurable

    for i in count:
        var cell = board.get_cell(pos.y, pos.x)
        if cell == null or cell.is_occupied():
            return []  # Invalid - return empty
        cells.append(cell)
        pos += direction
    return cells
```

## Usage Example
```gdscript
# Create board with custom size
var board = $Board
board.rows = 11
board.columns = 11

# Get cell at coordinates
var center_cell = board.get_cell(5, 5)

# Check placement validity
if center_cell.can_place_tile():
    place_tile_on_cell(my_tile, center_cell)

# Resize board dynamically
board.add_row()  # Add row for special game mode

# Clear the board
board.clear_board()
```

## Grid State Query
```gdscript
var state = board.get_grid_state()
# Returns 2D array where each element is tile or null
# state[row][col] = Tile or null
```

## Future Considerations
- Special cell placement patterns (Scrabble-style multiplier layout)
- Custom board shapes (non-rectangular)
- Board state serialization for save/load
- Animated cell effects
- Placement direction toggle (horizontal/vertical)
- Cross-word detection
