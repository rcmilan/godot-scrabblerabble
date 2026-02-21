# Directory Overview

## Purpose
Contains PNG graphics for all 26 letter tiles (A-Z) used in the game, plus a base template tile.

## Key Files
- **letter.png**: Base tile template (64×64px)
- **letter_A.png through letter_Z.png**: Individual letter graphics (26 files total)
- **[letter].png.import**: Godot import configuration files (auto-generated)

## Public Interfaces
### Referenced By
- `Data/TileData/tiles/*.tres`: Each TileData resource references one texture file
- `scenes/tile/Tile.tscn`: Uses TextureRect to display tile graphics

### Access Pattern
```gdscript
# In TileData resources (e.g., tile_a.tres)
texture = preload("res://Assets/Tiles/letter_A.png")

# In Tile scene script
@onready var texture_rect: TextureRect = $TextureRect
texture_rect.texture = tile_data.texture
```

## Dependencies
None - standalone image assets.

## Architecture / Patterns
- **Naming Convention**: `letter_[UPPERCASE].png` for consistency
- **Resource Loading**: Files are preloaded via Godot's resource system
- **Import System**: Godot auto-generates `.import` files with texture import settings

### Asset Specifications
- **Format**: PNG with transparency support
- **Dimensions**: 64×64 pixels (standard tile size)
- **Style**: Consistent typography and visual style across all 26 letters
- **Color Depth**: Full RGBA for alpha channel support

## Conventions
### File Organization
- One PNG file per letter (A-Z)
- Alphabetical ordering in filesystem
- Import files co-located with source PNG files

### Visual Consistency
- Letters centered within 64×64 canvas
- Uniform stroke weight and style
- Consistent baseline and cap height
- Transparent background for compositing

## Build / Test
N/A - Static image assets imported by Godot automatically. No build process required.

### Asset Workflow
1. Create/edit PNG in external image editor (64×64px)
2. Save to `Assets/Tiles/` with naming convention `letter_X.png`
3. Godot auto-detects and imports on save
4. Reference in TileData resource via resource path `res://Assets/Tiles/letter_X.png`
