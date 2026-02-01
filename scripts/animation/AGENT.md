# Animation System

## Overview
Flexible, object-oriented animation system for tile movements. Uses the Strategy pattern to allow different animation behaviors for various game actions.

## Structure
```
scripts/animation/
├── tile_animation_strategy.gd    # Base strategy class (Resource)
├── draw_tile_animation.gd        # Draw animation implementation
├── return_to_hand_animation.gd   # Return from board animation
├── shake_tile_animation.gd       # Illegal action feedback animation
├── stomp_tile_animation.gd       # Play confirmation animation
└── executors/
    ├── animation_context.gd      # Shared state for executors
    ├── animation_executor.gd     # Base executor class
    ├── batch_animation_executor.gd    # Staggered batch animations
    ├── return_animation_executor.gd   # Return/cancel animations
    ├── shake_animation_executor.gd    # Shake effect executor
    └── stomp_animation_executor.gd    # Stomp with particles executor
```

---

## TileAnimationStrategy

### Purpose
Base abstract Resource class defining the animation interface. Extend this to create new animation types.

### Class: `TileAnimationStrategy extends Resource`

### Properties
```gdscript
@export var duration: float = 0.3
@export var ease_type: Tween.EaseType = Tween.EASE_OUT
@export var trans_type: Tween.TransitionType = Tween.TRANS_CUBIC
@export var stagger_delay: float = 0.05
```

### Virtual Methods
```gdscript
# Where animation starts (offset from final position)
get_start_position_offset() -> Vector2

# Initial visual state
get_start_properties() -> Dictionary

# Final visual state
get_end_properties() -> Dictionary

# Lifecycle hooks
on_animation_start(tile: Tile) -> void
on_animation_complete(tile: Tile) -> void
```

### Property Dictionary Format
```gdscript
{
    "scale": Vector2,
    "modulate": Color,
    # Any other Tile property...
}
```

---

## DrawTileAnimation

### Purpose
Concrete animation strategy for drawing tiles into the hand. Tiles animate from below the screen, scaling and fading in.

### Class: `DrawTileAnimation extends TileAnimationStrategy`

### Configuration
```gdscript
@export var vertical_offset: float = 200.0
@export var start_scale: Vector2 = Vector2(0.8, 0.8)
@export var start_alpha: float = 0.0
```

### Default Values
| Property | Value |
|----------|-------|
| duration | 0.3s |
| ease_type | EASE_OUT |
| trans_type | TRANS_CUBIC |
| stagger_delay | 0.05s |
| vertical_offset | 200px |
| start_scale | 0.8 |
| start_alpha | 0.0 |

### Behavior
- Tiles start 200px below their final position
- Scale animates from 0.8 to 1.0
- Alpha animates from 0.0 to 1.0
- Mouse interaction disabled during animation
- Mouse interaction re-enabled on completion

---

## ReturnToHandAnimation

### Purpose
Animation strategy for returning tiles from the board back to the hand. Tiles smoothly glide from their board position to their hand position with a subtle bounce effect.

### Class: `ReturnToHandAnimation extends TileAnimationStrategy`

### Configuration
```gdscript
@export var overshoot_scale: Vector2 = Vector2(1.1, 1.1)
@export var start_alpha: float = 1.0
```

### Default Values
| Property | Value |
|----------|-------|
| duration | 0.35s |
| ease_type | EASE_OUT |
| trans_type | TRANS_BACK (bounce) |
| stagger_delay | 0.03s |

### Behavior
- Tiles start at their board position (global coordinates)
- Smoothly glide to their new hand position
- Uses TRANS_BACK for subtle overshoot/bounce effect
- Z-index raised during animation to appear above other tiles
- Mouse interaction disabled during animation

### Usage
```gdscript
# Called automatically by Main when right-clicking board tiles
# Or call directly:
TileAnimator.animate_return_to_hand(tile, hand, cell)
```

---

## ShakeTileAnimation

### Purpose
Animation strategy for indicating an illegal action. The tile shakes left-right quickly to provide visual feedback that the action cannot be performed.

### Class: `ShakeTileAnimation extends TileAnimationStrategy`

### Configuration
```gdscript
@export var shake_distance: float = 8.0
@export var shake_count: int = 3
```

### Default Values
| Property | Value |
|----------|-------|
| duration | 0.08s (per direction) |
| ease_type | EASE_IN_OUT |
| trans_type | TRANS_SINE |
| shake_distance | 8px |
| shake_count | 3 |

### Behavior
- Tile shakes left-right quickly (3 times by default)
- Returns to original position after shaking
- Mouse interaction disabled during animation
- Used when attempting illegal actions (e.g., returning tile when hand is full)

### Usage
```gdscript
# Called automatically when trying to return a tile with full hand
# Or call directly:
TileAnimator.animate_shake(tile)
```

---

## StompTileAnimation

### Purpose
Dramatic animation for confirming tile placement when "playing" a hand. Tiles rise up, slam down with a squish effect, and spawn impact particles to indicate they are now permanently placed.

### Class: `StompTileAnimation extends TileAnimationStrategy`

### Configuration
```gdscript
# Rise phase
@export var rise_scale: Vector2 = Vector2(1.35, 1.35)
@export var rise_offset: float = -15.0  # Pixels up
@export var rise_duration: float = 0.15

# Slam phase
@export var slam_duration: float = 0.08
@export var squish_scale: Vector2 = Vector2(1.1, 0.9)

# Recovery phase
@export var recover_duration: float = 0.12

# Particles
@export var particle_count: int = 8
@export var particle_speed: float = 120.0
@export var particle_lifetime: float = 0.4
@export var particle_color: Color = Color(1.0, 0.9, 0.7, 0.9)
```

### Default Values
| Property | Value |
|----------|-------|
| duration | 0.35s (total) |
| rise_scale | 1.35x |
| rise_offset | -15px (upward) |
| squish_scale | 1.1x wide, 0.9x tall |
| stagger_delay | 0.06s |
| particle_count | 8 |

### Animation Phases
1. **Rise**: Tile scales up to 1.35x from center and moves up 15px
2. **Slam**: Tile quickly scales down and moves back, squishing on impact (1.1x0.9)
3. **Particles**: Impact particles spawn around tile edges (5 emitters), burst outward
4. **Recover**: Tile bounces back to normal scale with elastic easing

### Behavior
- **Center pivot**: Tile scales from its center (pivot_offset set automatically)
- **Z-index raised** during animation so tiles appear above others
- **Edge particles**: 5 CPUParticles2D emitters at bottom, corners, and sides
- Particles burst outward from each edge with directional spread
- Particles shrink and fade over lifetime, auto-cleanup
- Mouse interaction disabled during animation
- Staggered timing for cascading visual effect

### Usage
```gdscript
# Called automatically when Play button is pressed
# Or call directly:
TileAnimator.animate_stomp_batch(tiles)
```

---

## Animation Executors

### Purpose
Executors encapsulate animation execution logic, keeping TileAnimator as a thin facade. Each executor handles one type of animation, sharing state via AnimationContext.

### AnimationContext
Shared state container passed to all executors:
```gdscript
class_name AnimationContext

var active_tweens: Dictionary = {}  # Tile -> Tween
var is_animating: bool = false

# Signal callbacks (set by TileAnimator)
func emit_animation_started(tiles: Array[Tile]) -> void
func emit_animation_completed(tiles: Array[Tile]) -> void
func emit_single_tile_animated(tile: Tile) -> void

# Utilities
func create_tween() -> Tween
func get_tree() -> SceneTree
func cancel_tile_animation(tile: Tile) -> void
```

### AnimationExecutor (Base Class)
Common helpers for all executors:
```gdscript
class_name AnimationExecutor

var _context: AnimationContext

func _apply_properties(tile: Tile, properties: Dictionary) -> void
func _register_tween(tile: Tile, tween: Tween) -> void
func _unregister_tween(tile: Tile) -> void
func _create_batch_completion_callback(...) -> Callable
func _create_single_completion_callback(...) -> Callable
```

### Executor Classes
| Executor | Strategy | Purpose |
|----------|----------|---------|
| BatchAnimationExecutor | TileAnimationStrategy | Staggered batch property tweens |
| ReturnAnimationExecutor | TileAnimationStrategy | Return-to-hand and cancel animations |
| ShakeAnimationExecutor | ShakeTileAnimation | Shake effect for illegal actions |
| StompAnimationExecutor | StompTileAnimation | Stomp with particle spawning |

---

## Creating New Animations

### Step 1: Create Strategy Class
```gdscript
extends TileAnimationStrategy
class_name DiscardTileAnimation

func _init() -> void:
    duration = 0.25
    ease_type = Tween.EASE_IN
    trans_type = Tween.TRANS_QUAD

func get_start_position_offset() -> Vector2:
    return Vector2.ZERO

func get_start_properties() -> Dictionary:
    return {"scale": Vector2.ONE, "modulate": Color.WHITE}

func get_end_properties() -> Dictionary:
    return {"scale": Vector2(0.5, 0.5), "modulate": Color(1, 1, 1, 0)}
```

### Step 2: Create Executor (if needed)
For simple animations, use BatchAnimationExecutor. For complex animations:
```gdscript
extends AnimationExecutor
class_name DiscardAnimationExecutor

func execute(tiles: Array[Tile], strategy: DiscardTileAnimation) -> void:
    _context.is_animating = true
    _context.emit_animation_started(tiles)

    # Custom animation logic...

    for tile in tiles:
        var tween: Tween = _context.create_tween()
        # ... configure tween ...
        _register_tween(tile, tween)
        tween.finished.connect(_create_single_completion_callback(tile, strategy))
```

### Step 3: Add to TileAnimator
```gdscript
# In tile_animator.gd
var _discard_animation: DiscardTileAnimation = null
var _discard_executor: DiscardAnimationExecutor = null

func animate_discard(tiles: Array[Tile]) -> void:
    if tiles.is_empty():
        return
    _ensure_discard_resources()
    _discard_executor.execute(tiles, _discard_animation)

func _ensure_discard_resources() -> void:
    if _discard_animation == null:
        _discard_animation = DiscardTileAnimation.new()
    if _discard_executor == null:
        _discard_executor = DiscardAnimationExecutor.new(_context)
```

### Step 4: Call from Manager
```gdscript
TileAnimator.animate_discard(tiles_to_discard)
```

---

## Future Animations
- `discard_tile_animation.gd` - Tiles shrink and fade out
- `place_tile_animation.gd` - Tiles snap onto board cells
- `shuffle_animation.gd` - Tiles shuffle within hand
