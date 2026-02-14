# Glide Animation

Smooth position transitions for returning tiles to hand, cancelling drags, and discarding.

## Files

| File | Class | Extends |
|------|-------|---------|
| `glide_tile_animation.gd` | `GlideTileAnimation` | `TileAnimationStrategy` |
| `return_animation_executor.gd` | `ReturnAnimationExecutor` | `AnimationExecutor` |

## Visual Effect

Tiles glide smoothly between positions with a subtle overshoot bounce (`TRANS_BACK`). Z-index is raised during animation to float above other tiles.

## Strategy Properties

- `overshoot_scale`: Vector2(1.1, 1.1) -- bounce effect
- `start_alpha`: 1.0
- Uses `TRANS_BACK` easing for a natural bounce feel

## ReturnAnimationExecutor

Handles three distinct operations:

### `execute_single(tile, hand, cell, strategy)`
Returns a single tile from the board to the hand. Captures global position before reparenting to avoid flicker.

### `execute_cancel_batch(tiles, hand, strategy, restore_fn)`
Cancels a multi-tile drag. Captures all global positions, calls `restore_fn` (typically `DragManager.restore_tiles_to_parents`), awaits layout, then animates each tile back with stagger.

### `execute_discard_batch(tiles, target_pos, strategy, on_complete)`
Animates tiles flying to the discard pile. Tiles scale down to 0.3 and fade out to 0.0, then `on_complete` is called.

## Critical Pattern

Always captures global position BEFORE reparenting/removing tiles from their parent. This prevents a single-frame visual pop.
