# Shake Animation

Feedback animation for illegal actions (hand full, invalid placement, illegal drag).

## Files

| File | Class | Extends |
|------|-------|---------|
| `shake_tile_animation.gd` | `ShakeTileAnimation` | `TileAnimationStrategy` |
| `shake_animation_executor.gd` | `ShakeAnimationExecutor` | `AnimationExecutor` |

## Visual Effect

Tile rapidly shakes left-right N times, then returns to its original position. Uses `TRANS_SINE` for smooth oscillation.

## Strategy Properties

- `shake_distance`: 8.0 -- pixels per direction
- `shake_count`: 3 -- number of left-right cycles
- Duration: 0.08s per direction change

## ShakeAnimationExecutor

Single-tile executor. Flow:
1. Cancels any existing animation on the tile
2. Stores original position
3. Chains sequential tweens: right, left, right, left, ... back to center
4. Emits completion when done
