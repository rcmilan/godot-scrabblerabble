# Draw Animation

Animates tiles being drawn from the bag into the player's hand.

## Files

| File | Class | Extends |
|------|-------|---------|
| `draw_tile_animation.gd` | `DrawTileAnimation` | `TileAnimationStrategy` |
| `batch_animation_executor.gd` | `BatchAnimationExecutor` | `AnimationExecutor` |

## Visual Effect

Tiles rise from 200px below their target position, scale up from 0.8 to 1.0, and fade in from transparent to opaque. Each tile is staggered by `stagger_delay`.

## Strategy Properties

- `vertical_offset`: 200.0 -- pixels below final position
- `start_scale`: Vector2(0.8, 0.8)
- `start_alpha`: 0.0

## Lifecycle Hooks

- `on_animation_start`: Sets `mouse_filter = IGNORE` so tiles can't be clicked mid-animation
- `on_animation_complete`: Restores `mouse_filter = STOP`

## BatchAnimationExecutor

General-purpose executor for staggered batch animations. Flow:
1. Emits `animation_started`
2. Awaits one frame for layout to settle
3. Captures each tile's final position
4. Applies start offset/properties, then tweens to final state
5. Emits `single_tile_animated` per tile, `animation_completed` when all done
