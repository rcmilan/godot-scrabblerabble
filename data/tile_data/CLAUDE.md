# TileData Resources

## Overview
Letter tile data definitions. Each tile resource contains the letter, point value, and visual texture.

## Files
- `tile_data.gd` - LetterTileData resource class definition
- `tiles/` - Folder containing 26 letter resources (tile_a.tres through tile_z.tres)

---

## LetterTileData Resource

### Class Definition
```gdscript
class_name LetterTileData extends Resource

@export var letter: String        # Single uppercase letter (A-Z)
@export var base_points: int      # Base point value for scoring
@export var texture: Texture2D    # Visual texture for the tile
```

### Validation & Properties
- **letter**: Single character or symbol (A-Z, *, etc.). Converted to uppercase during Tile initialization
- **base_points**: Non-negative integer. Follows Scrabble-style scoring
- **texture**: Texture2D reference from `Assets/Tiles/` (typically 64×64 PNG images)

**Note**: Resources are immutable after creation. Point modifiers (bonuses, penalties) are applied on Tile instances, not in data.

---

## Tile Resources

### File Naming Convention
```
tile_<letter>.tres
```
Examples: `tile_a.tres`, `tile_e.tres`, `tile_z.tres`

### Standard Point Values

| Points | Letters |
|--------|---------|
| **1** | A, E, I, L, N, O, R, S, T, U |
| **2** | D, G |
| **3** | B, C, M, P |
| **4** | F, H, V, W, Y |
| **5** | K |
| **8** | J, X |
| **10** | Q, Z |

---

## Usage

### Loading Tile Data
```gdscript
# Direct load
var tile_a = load("res://Data/TileData/tiles/tile_a.tres") as LetterTileData

# Dynamic load by letter
func load_tile_data(letter: String) -> LetterTileData:
    var path = "res://Data/TileData/tiles/tile_%s.tres" % letter.to_lower()
    return load(path) as LetterTileData
```

### Initializing Tiles
```gdscript
# In TileBag or other tile factory
var tile_scene = preload("res://scenes/tile/Tile.tscn")
var tile_data = load("res://Data/TileData/tiles/tile_e.tres")

var tile = tile_scene.instantiate()
tile.initialize(tile_data)
```

### TileBag Integration Pattern
TileBag dynamically loads tile data using the **distribution key** as the filename:

```gdscript
const TILE_DATA_PATH = "res://Data/TileData/tiles/tile_%s.tres"

# For each letter in BagDistribution.distribution:
for letter in distribution.keys():
    var path = TILE_DATA_PATH % letter.to_lower()
    var tile_data = load(path)  # Loads tile_<letter>.tres
```

**Critical**: Distribution keys must match tile resource file names (case-insensitive):
- Distribution key `"A"` → loads `tile_a.tres`
- Distribution key `"WILD"` → loads `tile_wild.tres`
- Distribution key `"Special"` → loads `tile_special.tres`

If a key doesn't have a corresponding `.tres` file, TileBag logs an error and skips it.

---

## Texture References
Each tile resource references a texture from `Assets/Tiles/`:
```
texture = "res://Assets/Tiles/letter_A.png"
```

---

## Creating New Tile Types

### Custom Letter Tile
1. Create new `.tres` file: `tile_custom.tres`
2. Set script to `tile_data.gd`
3. Configure properties:
   - letter: "?" (or custom symbol)
   - base_points: desired value
   - texture: custom texture path

### Wild Card Tile (Future)
```gdscript
# Potential wild card resource
letter = "*"
base_points = 0
texture = "res://Assets/Tiles/wildcard.png"
```

---

## Notes
- Tile data is immutable at runtime
- Point modifiers are applied on the Tile instance, not the data
- Textures should be 64x64 pixels for standard display
