# Directory Overview

## Purpose
Implements the Spin animation effect for tiles with EXTRA, MULTI, or EXPO modifiers during play confirmation. Tiles scale up and rotate 360° with a pulsing effect.

## Key Files
- **spin_tile_animation.gd**: Strategy class defining spin animation properties (scale, timing, rotation)
- **spin_animation_executor.gd**: Executor that sequences the spin animation using Godot Tweens

## Public Interfaces
### SpinTileAnimation (Strategy)
```gdscript
extends TileAnimationStrategy
class_name SpinTileAnimation

@export var peak_scale: Vector2 = Vector2(1.25, 1.25)
@export var spin_up_duration: float = 0.15
@export var spin_down_duration: float = 0.20

# Inherited from base
duration: float = 0.35
stagger_delay: float = 0.06
ease_type: Tween.EASE_OUT
trans_type: Tween.TRANS_BACK
```

### SpinAnimationExecutor (Executor)
```gdscript
extends AnimationExecutor
class_name SpinAnimationExecutor

func execute(tiles: Array[Tile], strategy: SpinTileAnimation) -> void
```

### Called By
- **TileAnimator.animate_spin_batch(tiles: Array[Tile])**: Facade method that lazy-loads and uses SpinTileAnimation + SpinAnimationExecutor

### Usage
```gdscript
# In PlayHandler after word validation
var modified_tiles = _get_tiles_with_modifiers(placed_tiles, [
    ModifierTypes.Type.EXTRA, 
    ModifierTypes.Type.MULTI, 
    ModifierTypes.Type.EXPO
])
if modified_tiles.size() > 0:
    TileAnimator.animate_spin_batch(modified_tiles)
```

## Dependencies
### Internal Dependencies
- **scripts/animation/base/tile_animation_strategy.gd**: Base class for SpinTileAnimation
- **scripts/animation/base/animation_executor.gd**: Base class for SpinAnimationExecutor
- **scripts/animation/base/animation_context.gd**: Shared context for tween creation and tracking

### External Dependencies
- **scenes/tile/tile.gd**: Tile component being animated
- **Godot Tween**: Built-in animation system
- **autoload/tile_animator.gd**: Facade that invokes this strategy/executor pair

### Consumers
- **TileAnimator**: Lazy-loads and calls this strategy/executor
- **scripts/controllers/play_handler.gd**: Requests spin animation via TileAnimator

## Architecture / Patterns
### Strategy Pattern
- **SpinTileAnimation** (Strategy): Defines WHAT to animate (properties, timing, easing)
- **SpinAnimationExecutor** (Executor): Defines HOW to execute (tween sequencing, parallel/serial operations)
- **Separation of Concerns**: Animation configuration separate from execution logic

### Animation Phases
1. **Delay Phase**: Staggered start based on tile index (0.06s intervals)
2. **Spin-Up Phase (0.15s)**: 
   - Scale from Vector2.ONE to peak_scale (1.25x)
   - Start 360° rotation (runs parallel with spin-up + spin-down)
3. **Spin-Down Phase (0.20s)**:
   - Scale back to Vector2.ONE
   - Rotation completes full circle (TAU radians)

### Parallel Tweening
Spin-up and rotation start simultaneously (parallel), while spin-down happens after spin-up completes (serial).

```gdscript
tween.set_parallel(true)  # Enable parallel mode
tween.tween_property(tile, "scale", peak_scale, spin_up_duration)
tween.tween_property(tile, "rotation", TAU, spin_up_duration + spin_down_duration)
tween.set_parallel(false)  # Back to serial mode
tween.tween_property(tile, "scale", Vector2.ONE, spin_down_duration)
```

### Tile State Management
- **on_animation_start()**: Disables mouse input, sets z_index to 50, centers pivot_offset
- **on_animation_complete()**: Restores mouse input, resets z_index, clears rotation, calls `tile._update_visual()` to restore modifier tints

## Conventions
### Animation Parameters
- **peak_scale**: 1.25x (125% of original size)
- **spin_up_duration**: 0.15s
- **spin_down_duration**: 0.20s
- **stagger_delay**: 0.06s between tiles
- **total_duration**: 0.35s (spin_up + spin_down)

### Easing Functions
- Scale up: EASE_OUT + TRANS_BACK (slight overshoot)
- Rotation: EASE_IN_OUT + TRANS_CUBIC (smooth acceleration/deceleration)
- Scale down: EASE_OUT + TRANS_CUBIC

### Modifier Filter
Only tiles with these modifiers trigger spin animation:
- ModifierTypes.Type.EXTRA
- ModifierTypes.Type.MULTI
- ModifierTypes.Type.EXPO

Tiles with RESET or LOCKED modifiers use stomp animation instead.

## Build / Test
N/A - GDScript files loaded at runtime by Godot. No compilation required.

### Testing
1. Start a new game with RandomModifiersQuality enabled
2. Place tiles with EXTRA/MULTI/EXPO modifiers on board
3. Form a valid word and click Play
4. Observe spin animation on modified tiles
5. Verify rotation completes 360° and scale pulses to 1.25x and back
