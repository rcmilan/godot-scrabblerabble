# Animation Executors

## Overview
Executor classes that implement the animation logic for the Strategy Pattern. Separated from TileAnimator facade to provide clean, composable animation implementations.

**Pattern**: Each animator strategy has a corresponding executor that handles the actual tween creation and state management.

---

## Architecture

### Executor Composition Model
```
TileAnimator (Facade)
    ↓
    ├─► BatchAnimationExecutor ─► DrawTileAnimation
    ├─► ReturnAnimationExecutor ─► GlideTileAnimation
    ├─► ShakeAnimationExecutor ─► ShakeTileAnimation
    └─► StompAnimationExecutor ─► StompTileAnimation

    (All use)
         ↓
    AnimationContext (Shared State)
```

### Design Benefits
1. **Separation of Concerns**: Strategy defines WHAT; Executor defines HOW
2. **Composability**: New executors don't require changes to TileAnimator
3. **Testability**: Each executor is independent and mockable
4. **Extensibility**: Add new animations without modifying existing code
5. **State Centralization**: AnimationContext tracks all active tweens

---

## AnimationContext

### Purpose
Shared state holder for animation execution. Tracks active tweens, emits completion signals, and provides utility methods.

### Class: `AnimationContext`

### Key Properties
```gdscript
var active_tweens: Dictionary = {}    # Tile -> Tween mapping
var is_animating: bool = false        # Overall animation state
```

### Public API
```gdscript
# Setup (called by TileAnimator._setup_context)
func setup(on_started: Callable, on_completed: Callable, on_single: Callable,
           create_tween: Callable, get_tree: Callable) -> void

# Signal emission
func emit_animation_started(tiles: Array[Tile]) -> void
func emit_animation_completed(tiles: Array[Tile]) -> void
func emit_single_tile_animated(tile: Tile) -> void

# Tween utilities
func create_tween() -> Tween
func get_tree() -> SceneTree
func is_instance_valid(obj: Object) -> bool

# State management
func cancel_tile_animation(tile: Tile) -> void
```

### Signal Coordination Flow
```
Animation Start
    ↓
emit_animation_started(tiles)
    ↓
For each tile:
    ↓
Tween completes
    ↓
emit_single_tile_animated(tile)
    ↓
All tiles done
    ↓
emit_animation_completed(tiles)
```

### Usage Example
```gdscript
# TileAnimator sets up context once
_context.setup(
    func(tiles): animation_started.emit(tiles),  # on_started callback
    func(tiles): animation_completed.emit(tiles), # on_completed callback
    func(tile): single_tile_animated.emit(tile),  # on_single callback
    create_tween,                                 # tween factory
    get_tree                                      # scene tree accessor
)

# Executors then use context for all animation work
```

---

## AnimationExecutor (Base Class)

### Purpose
Base class providing common functionality for all executors. Encapsulates tween registration, property application, and callback management.

### Class: `AnimationExecutor`

### Constructor
```gdscript
func _init(context: AnimationContext) -> void:
    _context = context
```

### Protected API (for subclasses)

#### Property & Tween Management
```gdscript
# Apply animation properties to tile
func _apply_properties(tile: Tile, properties: Dictionary) -> void

# Track tween for cancellation support
func _register_tween(tile: Tile, tween: Tween) -> void
func _unregister_tween(tile: Tile) -> void

# Create/manage tweens
func _create_tween() -> Tween
```

#### Callback Management
```gdscript
# Callbacks for single-tile completion
func _create_single_completion_callback(tile: Tile) -> Callable

# Callbacks for batch completion with shared counter
func _create_batch_completion_callback(tiles: Array[Tile], ref_count_array: Array) -> Callable
```

### Key Features
- **Active Tween Tracking**: Uses `_context.active_tweens` dictionary for cancellation
- **Instance Validation**: Checks `is_instance_valid()` before applying properties
- **Callback Coordination**: Reference counting for batch animations

### Creating Custom Executors
```gdscript
class_name CustomAnimationExecutor extends AnimationExecutor

func execute(tile: Tile, strategy: TileAnimationStrategy) -> void:
    # Get animation properties from strategy
    var start_props = strategy.get_start_properties()
    var end_props = strategy.get_end_properties()

    # Apply start state
    _apply_properties(tile, start_props)

    # Create tween
    var tween = _create_tween()

    # Animate to end state
    tween.tween_property(tile, "modulate:a", end_props.alpha, 0.5)

    # Register for tracking
    _register_tween(tile, tween)

    # Handle completion
    tween.finished.connect(_create_single_completion_callback(tile))
```

---

## BatchAnimationExecutor

### Purpose
Handles staggered batch animations where multiple tiles animate in sequence with delays.

### Class: `BatchAnimationExecutor extends AnimationExecutor`

### Public API
```gdscript
func execute(tiles: Array[Tile], strategy: TileAnimationStrategy) -> void (async)
```

### Behavior
1. **Awaits Process Frame**: Allows layout calculations before capturing positions
2. **Staggered Timing**: Uses `strategy.stagger_delay` between tiles
3. **Parallel Tweens**: Position and property tweens run simultaneously per tile
4. **Signal Coordination**:
   - Emits `animation_started` at beginning
   - Emits `single_tile_animated` for each completed tile
   - Emits `animation_completed` when all done

### Implementation Details
- **Start Properties**: Retrieved from `strategy.get_start_properties()`
- **Start Position Offset**: Retrieved from `strategy.get_start_position_offset()`
- **Stagger Delay**: Taken from `strategy.stagger_delay` property
- **Completion Order**: Tiles complete in sequence (not parallel completion)

### Use Cases
- Draw animations (tiles rise from below)
- Any batch property animations

### Example Usage
```gdscript
# Hand drawn 5 tiles
var tiles = [tile1, tile2, tile3, tile4, tile5]
var strategy = DrawTileAnimation.new()
strategy.stagger_delay = 0.1  # 100ms between each

_batch_executor.execute(tiles, strategy)  # Tiles animate with staggered timing
```

---

## ReturnAnimationExecutor

### Purpose
Handles complex position-based animations where tiles move between different parts of the scene tree.

### Class: `ReturnAnimationExecutor extends AnimationExecutor`

### Public API
```gdscript
# Return single tile from board to hand
func execute_single(tile: Tile, hand: Node, cell: Node,
                   strategy: TileAnimationStrategy) -> void (async)

# Return multiple tiles to hand after cancelled drag
func execute_cancel_batch(tiles: Array[Tile], hand: Node,
                         strategy: TileAnimationStrategy) -> void (async)

# Glide tiles to discard pile with callback
func execute_discard_batch(tiles: Array[Tile], target_global_pos: Vector2,
                          strategy: TileAnimationStrategy, on_complete: Callable) -> void (async)
```

### Key Capabilities

#### Global Position Management
- Captures global position BEFORE reparenting
- Maintains visual continuity across parent changes
- Converts between global and local coordinates

#### Parent Reparenting
- Removes tile from current parent
- Adds to new parent (Hand.TileContainer)
- Preserves position during reparent via global_position

#### Discard Animation Special Handling
```gdscript
# During discard, tiles:
# 1. Glide to discard pile target position
# 2. Scale down from 1.0 → 0.8
# 3. Fade out (alpha: 1.0 → 0.7)
# 4. Call on_complete callback when done
```

#### Cancel Batch Restoration
- Calls `DragManager.restore_tiles_to_parents()` to restore original state
- Uses GlideTileAnimation for smooth return transition
- Maintains tile order and hierarchy

### Position Capture Timing
**Critical**: Captures global position BEFORE reparenting:
```gdscript
var global_pos = tile.global_position  # Capture FIRST
tile.get_parent().remove_child(tile)   # Then remove
new_parent.add_child(tile)             # Then add
tile.global_position = global_pos      # Restore position
```

### Use Cases
- Returning tiles from board to hand
- Cancelling drag operations with animation
- Discarding tiles to discard pile with feedback

### Example Usage
```gdscript
# Single tile return with animation
_return_executor.execute_single(tile, hand, cell, GlideTileAnimation.new())

# Discard batch with callback
_return_executor.execute_discard_batch(
    selected_tiles,
    discard_pile.global_position,
    GlideTileAnimation.new(),
    func(): HandManager.refill_hand()
)
```

---

## ShakeAnimationExecutor

### Purpose
Provides feedback animation for illegal actions (hand full, invalid placement, etc.).

### Class: `ShakeAnimationExecutor extends AnimationExecutor`

### Public API
```gdscript
func execute(tile: Tile, strategy: ShakeTileAnimation) -> void (async)
```

### Animation Sequence
1. **Right Shake**: Move right by `strategy.shake_distance`
2. **Left Shake**: Move left by `strategy.shake_distance` (opposite side)
3. **Center**: Return to original position
4. Repeat `strategy.shake_count` times

### Key Properties (from ShakeTileAnimation strategy)
- **shake_distance**: How far to shake (pixels)
- **shake_count**: Number of shake cycles
- **duration**: Total animation duration

### Implementation Details
- **Sequential Motion**: Each shake direction is sequential (not parallel)
- **Cancellation**: Automatically cancels any existing animation on tile
- **Position Restoration**: Returns tile to original position
- **No State Change**: Only visual feedback, doesn't change tile state

### Use Cases
- Hand is full when trying to return tile
- Placement validation failed
- Illegal drag operation attempted

### Example Usage
```gdscript
# Shake tile to indicate error
var strategy = ShakeTileAnimation.new()
strategy.shake_distance = 10
strategy.shake_count = 3

_shake_executor.execute(tile, strategy)
```

---

## StompAnimationExecutor

### Purpose
Provides placement confirmation animation with particle effects and multi-phase scale feedback.

### Class: `StompAnimationExecutor extends AnimationExecutor`

### Public API
```gdscript
func execute(tiles: Array[Tile], strategy: StompTileAnimation) -> void (async)
```

### Animation Phases

#### 1. Rise Phase
```
Scale: 1.0 → scale_up (default 1.15)
Y Position: move up by offset_up pixels
Easing: Out bounce
Duration: strategy.rise_duration
```

#### 2. Slam Phase
```
Scale: 1.0 → squish_scale (default 0.85)
Y Position: move down below original
Easing: In out
Duration: strategy.slam_duration
```

#### 3. Particle Burst
Spawned on slam impact at 5 positions:
- **Bottom Center**: Vertical spray
- **Bottom-Left**: Diagonal down-left
- **Bottom-Right**: Diagonal down-right
- **Left**: Horizontal left
- **Right**: Horizontal right

#### 4. Recovery Phase
```
Scale: squish_scale → 1.0
Easing: Out elastic
Duration: strategy.recovery_duration
```

### Particle System Details

#### Configuration (from StompTileAnimation strategy)
```gdscript
particle_count: int = 12              # Total particles across all emitters
particle_speed: float = 200.0         # Initial particle velocity
particle_lifetime: float = 0.8        # Seconds before particles fade
particle_size_max: float = 10.0       # Max particle size
particle_size_min: float = 6.0        # Min particle size
particle_gravity: float = 500.0       # Downward acceleration
```

#### Particle Emission
- **CPUParticles2D-based**: Used for performance
- **Distribution**: `particle_count` divided among 5 emitters
- **One-shot Burst**: Each emitter fires once on slam
- **Auto-cleanup**: Via `WeakRef` to prevent memory leaks

#### Visual Properties
- **Color**: White with alpha fade to transparent
- **Size Curve**: Shrinks from max to min over lifetime
- **Velocity Spread**: Directional variation per emitter
- **Gravity**: Affects downward motion curve

### Z-index & Pivot Management
```gdscript
# During stomp:
tile.z_index = STOMP_Z_INDEX      # Lift above other tiles
tile.pivot_offset = tile.size / 2  # Center-based scaling (not corner)

# After stomp:
tile.z_index = normal_z           # Restore original
tile.pivot_offset = Vector2.ZERO  # Restore corner scaling
```

### Staggered Batch Behavior
When stomping multiple tiles:
- Each tile stomps sequentially
- Gap between start times: `strategy.stagger_delay`
- Particles for each tile spawn when that tile slams

### Use Cases
- Confirming tile placement
- Scoring animation feedback
- Visual impact on board interaction

### Configuration Example
```gdscript
var strategy = StompTileAnimation.new()
strategy.rise_duration = 0.2
strategy.slam_duration = 0.15
strategy.recovery_duration = 0.4
strategy.particle_count = 16  # More particles for bigger impact
strategy.particle_lifetime = 1.0  # Longer particle life

_stomp_executor.execute([tiles], strategy)
```

---

## Common Patterns & Best Practices

### Active Tween Tracking
All executors track tweens for cancellation support:
```gdscript
_register_tween(tile, tween)
# ... later
_context.cancel_tile_animation(tile)  # Cancels tween automatically
```

### Reference Counting for Batch Animations
Batch executors use shared counter for completion detection:
```gdscript
var ref_count = [tiles.size()]  # Shared mutable container
for tile in tiles:
    tween.finished.connect(_create_batch_completion_callback(tile, ref_count))
```

### WeakRef for Memory Safety
StompAnimationExecutor uses WeakRef for particle cleanup:
```gdscript
var weak_particles = weakref(particles)
# Later, even if parent is deleted, safe to check:
if weak_particles.get_ref() != null:
    particles.queue_free()
```

### Graceful Instance Validation
All property applications check validity:
```gdscript
if _context.is_instance_valid(tile):
    _apply_properties(tile, properties)
```

---

## Extending the Animation System

### Creating a Custom Executor

1. **Extend AnimationExecutor**:
```gdscript
class_name CustomExecutor extends AnimationExecutor

func execute(tile: Tile, strategy: TileAnimationStrategy) -> void:
    # Implementation here
```

2. **Use Protected API**:
```gdscript
_apply_properties(tile, properties)
var tween = _create_tween()
_register_tween(tile, tween)
```

3. **Handle Completion**:
```gdscript
tween.finished.connect(_create_single_completion_callback(tile))
```

4. **Register in TileAnimator**:
```gdscript
func _ensure_custom_resources() -> void:
    if _custom_executor == null:
        _custom_executor = CustomExecutor.new(_context)
```

### Creating a Custom Strategy
```gdscript
class_name CustomAnimation extends TileAnimationStrategy

func get_start_properties() -> Dictionary:
    return {"custom_property": initial_value}

func get_end_properties() -> Dictionary:
    return {"custom_property": final_value}
```

---

## Troubleshooting

### Animation Not Playing
- Check if tile is valid: `is_instance_valid(tile)`
- Verify tween was created: Look for tween in `_context.active_tweens`
- Check strategy duration: `strategy.duration` should be > 0

### Tile Flickers During Reparent
- Ensure global position is captured BEFORE removing from parent
- See ReturnAnimationExecutor for correct pattern

### Particles Not Visible
- Check particle z_index is set correctly
- Verify particle_count > 0
- Check particle_lifetime is sufficient
- Ensure particles are in correct scene layer

### Memory Leak from Tweens
- All tweens are tracked and cancellable
- Ensure `_unregister_tween()` is called on completion
- Base class handles this automatically

---

## Signal Lifecycle Reference

```gdscript
# When starting any animation:
EventBus.animation_started.emit(tiles)

# For each tile that completes individually:
EventBus.single_tile_animated.emit(tile)

# When ALL tiles are done:
EventBus.animation_completed.emit(tiles)
```
