# Animation Blocking Design

> **Event-Driven Approach to Prevent Animation Stacking on Tiles**

**Date:** 2026-03-07
**Status:** Approved

## Problem

When a player rapidly triggers the same animation on a tile (e.g., mashing the discard key while a shake animation is running), multiple animation requests can stack. The shake animation stores the tile's original position at the start of each animation. When multiple shakes execute, subsequent animations capture an incorrect "original position" (mid-animation), causing the tile to move off the board cell when returning to "original."

**Example:**
1. Player presses Discard → Shake animation starts, stores position (10, 10)
2. Player mashes Discard again → New shake request created
3. Second shake stores position (15, 10) — already offset by first shake
4. Animations execute in parallel → Both try to move tile, causing drift off-cell

## Solution: Event-Driven Animation Blocking

Block new animation requests at the **Tile level** using signal-based state tracking. Each Tile listens to `TileAnimator.animation_started` and `animation_completed` signals to track its own animation state locally. Animation executors check this state before executing and silently reject blocked requests.

## Architecture

### Signal Flow
```
TileAnimator.animation_started(tiles: Array[Tile])
  ↓
Tile._on_animation_started(tiles)
  → if this tile in tiles: _is_animating = true

[Animation executes...]

TileAnimator.animation_completed(tiles: Array[Tile])
  ↓
Tile._on_animation_completed(tiles)
  → if this tile in tiles: _is_animating = false
```

### Guard Pattern
```gdscript
# In any animation executor
func execute(tile: Tile, strategy: TileAnimationStrategy) -> void:
    if tile.is_animating():
        return  # Silent block, animation already running

    # Proceed with animation...
```

## Components

### 1. Tile (Modified)

**Add to Tile class:**
```gdscript
# Animation state tracking
var _is_animating: bool = false

func _ready() -> void:
    # ... existing code ...

    # Connect to animation signals
    TileAnimator.animation_started.connect(_on_tile_animator_animation_started)
    TileAnimator.animation_completed.connect(_on_tile_animator_animation_completed)

func _on_tile_animator_animation_started(tiles: Array[Tile]) -> void:
    if self in tiles:
        _is_animating = true

func _on_tile_animator_animation_completed(tiles: Array[Tile]) -> void:
    if self in tiles:
        _is_animating = false

# Public interface
func is_animating() -> bool:
    return _is_animating
```

### 2. Animation Executors (Modified)

Add guard check to `execute()` methods in:
- `ShakeAnimationExecutor.execute(tile, strategy)`
- `ReturnAnimationExecutor.execute_single(tile, ...)`
- `StompAnimationExecutor.execute(tiles, strategy)`
- `SpinAnimationExecutor.execute(tiles, strategy)`
- `BatchAnimationExecutor.execute(tiles, strategy)`

**Pattern:**
```gdscript
func execute(tile: Tile, strategy: TileAnimationStrategy) -> void:
    if tile.is_animating():
        print("[Executor] Blocked: tile already animating")
        return

    # ... rest of animation logic ...
```

### 3. TileAnimator (No Changes)

Already emits required signals:
- `signal animation_started(tiles: Array[Tile])`
- `signal animation_completed(tiles: Array[Tile])`

These signals fire at the right lifecycle points (before/after animation execution).

## Data Flow: Multi-Tap Scenario

**User mashes Discard key 3 times in rapid succession:**

```
T=0ms: Player presses Discard
  → TileAnimator.animate_shake(tile)
  → ShakeAnimationExecutor.execute()
    → tile.is_animating() = false ✓ allowed
    → Stores original position
    → Creates tween
    → TileAnimator emits animation_started([tile])
    → Tile._on_animation_started() sets _is_animating = true

T=20ms: Player presses Discard again (while animating)
  → TileAnimator.animate_shake(tile)
  → ShakeAnimationExecutor.execute()
    → tile.is_animating() = true ✗ blocked, return early

T=40ms: Player presses Discard a third time
  → TileAnimator.animate_shake(tile)
  → ShakeAnimationExecutor.execute()
    → tile.is_animating() = true ✗ blocked, return early

T=500ms: Animation completes
  → TileAnimator emits animation_completed([tile])
  → Tile._on_animation_completed() sets _is_animating = false
  → Tile returned to original position (no drift)
```

## Benefits

✅ **Immutability:** No mutable state on Tile during normal gameplay (flag only tracks animation state)
✅ **DDD:** Uses domain events (animation_started/completed) as communication mechanism
✅ **Decoupling:** Tile only knows about TileAnimator signals, not internal executor details
✅ **OOP:** Clear separation of concerns (Tile manages its animation state)
✅ **Low Complexity:** Simple signal handlers, guard pattern in executors
✅ **Alignment:** Mirrors existing signal-based architecture (SelectionManager, DragManager patterns)

## Testing

**Manual Testing:**
1. Open gameplay scene
2. Place tiles on board
3. Press Discard (or trigger any animation)
4. Rapidly mash Discard key while animation runs
5. Verify: Tile returns to original cell without drift
6. Verify: Only first animation plays, subsequent requests silently blocked

**Verification Criteria:**
- [ ] Tile doesn't move off-cell when animation is mashed
- [ ] Shake animation plays exactly once per request
- [ ] Other animations (draw, glide, stomp, spin) also respect blocking
- [ ] No console errors or warnings during rapid input
- [ ] Animation completion properly clears flag (tile can animate again after)

## Files Modified

- `scenes/tile/tile.gd` — Add state tracking and signal handlers
- `scripts/animation/shake/shake_animation_executor.gd` — Add guard check
- `scripts/animation/glide/return_animation_executor.gd` — Add guard check
- `scripts/animation/stomp/stomp_animation_executor.gd` — Add guard check
- `scripts/animation/spin/spin_animation_executor.gd` — Add guard check
- `scripts/animation/draw/batch_animation_executor.gd` — Add guard check

## Edge Cases Handled

1. **Animation canceled mid-execution:** If `cancel_tile_animation()` kills the tween, the `animation_completed` signal still fires → flag clears correctly
2. **Tile destroyed while animating:** Tile's signal handlers auto-disconnect when node frees
3. **Multiple animations on same tile:** Each executor's guard ensures only one animation type can run at once
4. **Rapid re-triggering:** Blocked until `animation_completed` fires, then immediately available for new animation

