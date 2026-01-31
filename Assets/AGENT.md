# Assets Directory

## Overview
Visual assets used throughout the game: textures, images, and graphical resources.

## Structure
```
Assets/
└── Tiles/              # Letter tile graphics
    ├── letter.png      # Base tile template
    └── letter_A.png    # Individual letter graphics (A-Z)
        through
        letter_Z.png
```

---

## Tiles Subdirectory

### Purpose
Contains visual textures for all letter tiles displayed in the game.

### Files

| File | Description |
|------|-------------|
| `letter.png` | Base tile template (blank tile) |
| `letter_A.png` | Letter A tile graphic |
| `letter_B.png` | Letter B tile graphic |
| ... | ... |
| `letter_Z.png` | Letter Z tile graphic |

### Specifications
- **Format**: PNG with transparency
- **Size**: 64x64 pixels (standard tile size)
- **Color**: Consistent style across all letters

### Import Settings
Godot auto-imports images with default settings. Import metadata stored in `.import` files.

---

## Usage

### In TileData Resources
Each `LetterTileData` resource references a tile texture:
```gdscript
# tile_a.tres
texture = "res://Assets/Tiles/letter_A.png"
```

### In Tile Scene
The `Tile.tscn` uses a `TextureRect` to display the tile graphic:
```gdscript
# tile.gd
@onready var texture_rect: TextureRect = $TextureRect

func initialize(data: LetterTileData) -> void:
    if data.texture:
        texture_rect.texture = data.texture
```

---

## Asset Guidelines

### Creating New Tile Graphics
1. Use 64x64 pixel canvas
2. Match existing visual style
3. Center letter in tile area
4. Export as PNG with transparency
5. Name following pattern: `letter_X.png`

### Special Tiles (Future)
For special tile types:
- `wildcard.png` - Wild card tile (blank or *)
- `bonus_2x.png` - Double points tile
- `bonus_3x.png` - Triple points tile
- `locked.png` - Locked tile indicator

---

## Future Asset Directories
- `Assets/UI/` - UI elements and icons
- `Assets/Board/` - Board and cell graphics
- `Assets/Effects/` - Particle effects and animations
- `Assets/Audio/` - Sound effects and music
