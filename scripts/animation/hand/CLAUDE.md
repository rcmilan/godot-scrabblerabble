# Hand Fan Layout

Positions hand tiles in a fan arrangement that adapts to tile count, with interactive hover effects.

## Files

| File | Class | Extends |
|------|-------|---------|
| `hand_fan_layout.gd` | `HandFanLayout` | `RefCounted` |

## How It Works

### Spacing Algorithm

Tiles are arranged horizontally, centered in the container.

- **<= 5 tiles** (`FAN_THRESHOLD`): Full spacing (64px tile + 4px gap = 68px step). No overlap.
- **> 5 tiles**: Step size compresses to fit within `MAX_LAYOUT_WIDTH` (400px). Overlap increases gradually.
- **Many tiles**: Step never goes below `MIN_STEP` (20px), capping maximum overlap at 44px per tile.

```
step = min(ideal_step, (MAX_LAYOUT_WIDTH - TILE_WIDTH) / (count - 1))
step = max(step, MIN_STEP)
```

### Z-Index Management

Default z-index follows tile order (0, 1, 2, ...). Later tiles render on top of earlier ones. Hovered tile temporarily jumps to z_index 50.

### Hover Effect

When a tile is hovered:
1. **Scale**: Tweens to 1.1x from center pivot
2. **Lift**: Rises 12px above the hand
3. **Push**: Neighbors are pushed away by `HOVER_PUSH / distance` pixels (24px for adjacent, 12px for two away, etc.)
4. **Z-index**: Set to 50 to render above all others

On hover exit, everything smoothly returns to base positions.

### Integration

Created by `Hand._ready()`. Layout updates automatically via `child_order_changed` and `resized` signals on the tile container. Sets `external_scale_management = true` on managed tiles to prevent conflicts with tile selection scale tweens.
