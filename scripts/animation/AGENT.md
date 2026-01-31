# Animation System

## Overview
Flexible, object-oriented animation system for tile movements. Uses the Strategy pattern to allow different animation behaviors for various game actions.

## Structure
```
scripts/animation/
├── tile_animation_strategy.gd   # Base strategy class (Resource)
└── draw_tile_animation.gd       # Draw animation implementation
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
    return Vector2.ZERO  # Start at current position

func get_start_properties() -> Dictionary:
    return {
        "scale": Vector2.ONE,
        "modulate": Color.WHITE
    }

func get_end_properties() -> Dictionary:
    return {
        "scale": Vector2(0.5, 0.5),
        "modulate": Color(1.0, 1.0, 1.0, 0.0)
    }
```

### Step 2: Add Method to TileAnimator
```gdscript
# In tile_animator.gd
var _discard_animation: DiscardTileAnimation = null

func animate_discard_batch(tiles: Array[Tile]) -> void:
    if _discard_animation == null:
        _discard_animation = DiscardTileAnimation.new()
    _animate_batch(tiles, _discard_animation)
```

### Step 3: Call from Manager
```gdscript
# In hand_manager.gd or main.gd
TileAnimator.animate_discard_batch(tiles_to_discard)
```

---

## Future Animations
- `discard_tile_animation.gd` - Tiles shrink and fade out
- `place_tile_animation.gd` - Tiles snap onto board cells
- `return_tile_animation.gd` - Tiles return from board to hand
- `shuffle_animation.gd` - Tiles shuffle within hand
- `invalid_word_animation.gd` - Shake animation for invalid placements
