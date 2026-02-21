# Spin Animation

## Purpose
Provides rotation and scale animation for tiles with special modifiers (EXTRA, MULTI, EXPO). Tiles spin 360 degrees while scaling up and back down.

## Key Files
- `spin_tile_animation.gd` - SpinTileAnimation strategy (defines WHAT happens)
- `spin_animation_executor.gd` - SpinAnimationExecutor (defines HOW it executes)

## Public Interfaces

### SpinTileAnimation (Strategy)
```gdscript
class_name SpinTileAnimation extends TileAnimationStrategy

# Configuration
@export var peak_scale: Vector2 = Vector2(1.25, 1.25)
@export var spin_up_duration: float = 0.15
@export var spin_down_duration: float = 0.20

# Overrides
func get_start_position_offset() -> Vector2
func get_start_properties() -> Dictionary
func get_end_properties() -> Dictionary
func on_animation_start(tile: Tile) -> void
func on_animation_complete(tile: Tile) -> void
```

### SpinAnimationExecutor (Executor)
```gdscript
class_name SpinAnimationExecutor extends AnimationExecutor

func execute(tiles: Array[Tile], strategy: SpinTileAnimation) -> void
```

## Dependencies

### Internal
- `TileAnimationStrategy` - Base strategy class
- `AnimationExecutor` - Base executor class
- `Tile` - Tile node being animated
- `AnimationContext` - Shared animation state

### External (Godot)
- `Tween` - Animation interpolation
- `Control` - Mouse filtering during animation

## Architecture / Patterns

**Strategy Pattern**: SpinTileAnimation defines animation parameters and lifecycle hooks; SpinAnimationExecutor implements the execution logic.

**Two-Phase Animation**:
1. **Spin Up (0.15s)**: Scale increases to 1.25x, rotation begins
2. **Spin Down (0.20s)**: Scale returns to 1.0x, rotation completes 360°

**Parallel Tweening**: Scale and rotation animate simultaneously during spin-up phase.

**Batch Support**: Executor supports staggered animation of multiple tiles with configurable delay.

## Conventions

### Animation Lifecycle
1. Disable mouse interaction (`MOUSE_FILTER_IGNORE`)
2. Elevate z-index to 50 (above other tiles)
3. Set pivot offset to tile center for rotation
4. Execute two-phase tween animation
5. Restore visual state (locked tint, modifier tint)
6. Reset z-index, pivot, rotation, mouse filter

### Tween Configuration
- **Ease Type**: `EASE_OUT`, `EASE_IN_OUT` (phase-dependent)
- **Trans Type**: `TRANS_BACK` (spin-up), `TRANS_CUBIC` (spin-down)
- **Stagger Delay**: 0.06s between tiles in batch

### Visual Restoration
After animation completes, calls `tile._update_visual()` to restore:
- Locked overlay (if tile is locked)
- Modifier tint (EXTRA=purple, MULTI=orange, EXPO=red)
- Selection state

## Build / Test
Run game (`F5`) and observe tiles with EXTRA/MULTI/EXPO modifiers spinning after placement or round start. Verify smooth rotation, scale pulse, and proper visual state restoration.
