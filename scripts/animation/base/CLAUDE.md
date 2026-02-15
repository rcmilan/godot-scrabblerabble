# Animation Base

Shared infrastructure for the tile animation system.

## Files

| File | Class | Extends | Purpose |
|------|-------|---------|---------|
| `tile_animation_strategy.gd` | `TileAnimationStrategy` | `Resource` | Abstract base for all animation strategies |
| `animation_context.gd` | `AnimationContext` | `RefCounted` | Shared state container for executors |
| `animation_executor.gd` | `AnimationExecutor` | `RefCounted` | Base class for all executors |

## TileAnimationStrategy

Defines the animation interface via the Strategy pattern. Subclasses declare WHAT happens (properties, offsets, timing); executors handle HOW it runs.

### Exported Properties
- `duration` (0.3s) -- total animation time
- `ease_type` (EASE_OUT) -- easing curve
- `trans_type` (TRANS_CUBIC) -- transition type
- `stagger_delay` (0.05s) -- delay between tiles in a batch

### Virtual Methods
- `get_start_position_offset() -> Vector2` -- where the tile starts relative to its target
- `get_start_properties() -> Dictionary` -- initial property values (scale, modulate, etc.)
- `get_end_properties() -> Dictionary` -- final property values
- `on_animation_start(tile)` / `on_animation_complete(tile)` -- lifecycle hooks

## AnimationContext

Shared state passed to every executor. Holds:
- `active_tweens: Dictionary` -- Tile-to-Tween mapping for cancellation
- `is_animating: bool` -- global animation lock
- Callback callables wired by TileAnimator: `_on_animation_started`, `_on_animation_completed`, `_on_single_tile_animated`, `_create_tween`, `_get_tree`

## AnimationExecutor

Base class providing common helpers:
- `_apply_properties(tile, props)` -- sets tile properties from a dictionary
- `_register_tween(tile, tween)` / `_unregister_tween(tile)` -- tween tracking
- `_create_batch_completion_callback()` -- reference-counted batch completion
- `_create_single_completion_callback()` -- single-tile completion
