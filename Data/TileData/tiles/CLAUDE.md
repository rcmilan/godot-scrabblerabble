# Directory Overview

## Purpose
Contains individual LetterTileData resource files (.tres) for all 26 letters of the alphabet, each defining letter-specific properties: letter character, point value, and visual texture reference.

## Key Files
26 resource files named `tile_[letter].tres` (where [letter] = a through z):
- `tile_a.tres`: Letter='A', Points=1, Texture=letter_A.png
- `tile_b.tres`: Letter='B', Points=3, Texture=letter_B.png
- ... (24 more files)
- `tile_z.tres`: Letter='Z', Points=10, Texture=letter_Z.png

## Public Interfaces
### Resource Type
All files extend **LetterTileData** (defined in `../tile_data.gd`):
```gdscript
class_name LetterTileData extends Resource

@export var letter: String        # Single uppercase letter
@export var base_points: int      # Scrabble-style point value
@export var texture: Texture2D    # Reference to Assets/Tiles/letter_X.png
```

### Access Pattern
Resources are loaded dynamically by TileBag during bag population:
```gdscript
# TileBag._load_tile_data()
const TILE_DATA_PATH = "res://Data/TileData/tiles/tile_%s.tres"
var path = TILE_DATA_PATH % letter.to_lower()  # e.g., "tile_a.tres"
var tile_data = load(path) as LetterTileData
```

## Dependencies
### Internal Dependencies
- **Parent Resource Class**: `Data/TileData/tile_data.gd` (LetterTileData)

### External Dependencies
- **Texture Assets**: Each resource references a texture from `Assets/Tiles/letter_X.png`

### Consumers
- **TileBag** (autoload): Loads tiles dynamically based on BagDistribution keys
- **Tile Scene**: Uses LetterTileData during initialization via `tile.initialize(data)`

## Architecture / Patterns
### Resource-Based Configuration
- **Godot Resources (.tres)**: Data-driven tile definitions, no code required
- **Dynamic Loading**: TileBag constructs file paths from distribution keys
- **Immutable Data**: Resources define base properties; runtime modifiers are applied on Tile instances

### Naming Contract
File naming must follow pattern: `tile_[lowercase_letter].tres`
- BagDistribution key "A" → loads `tile_a.tres`
- BagDistribution key "E" → loads `tile_e.tres`
- Missing files result in TileBag error and tile skipped

### Point Value Distribution (Scrabble-style)
| Points | Letters |
|--------|---------|
| 1 | A, E, I, L, N, O, R, S, T, U |
| 2 | D, G |
| 3 | B, C, M, P |
| 4 | F, H, V, W, Y |
| 5 | K |
| 8 | J, X |
| 10 | Q, Z |

## Conventions
### File Naming
- Format: `tile_[letter].tres` (lowercase letter in filename)
- Letter property: Uppercase (e.g., "A", "E")
- 26 files total (one per English alphabet letter)

### Resource Properties
- **letter**: Must be a single uppercase character
- **base_points**: Positive integer (1-10 for standard letters)
- **texture**: Preload path to 64×64px PNG in Assets/Tiles/

### Extensibility
Future custom tiles can be added following the same pattern:
- Create `tile_wild.tres` with letter="*", base_points=0
- Add "WILD": 2 to BagDistribution
- TileBag will load `tile_wild.tres` automatically

## Build / Test
N/A - Resources are data files loaded at runtime by Godot. No compilation or build process required.

### Verification
To verify all 26 tile resources exist and are valid:
1. Open Godot Editor
2. Navigate to `res://Data/TileData/tiles/`
3. Ensure all files `tile_a.tres` through `tile_z.tres` exist
4. Double-click any .tres file to inspect properties in Inspector panel
