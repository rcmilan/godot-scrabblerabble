# Required Fixes - Fan Hand Layout Review

## Critical Issue #1: RunManager Hand Size Parameter

### File
`/c/Users/suporte/Documents/dev/.worktrees/fan-hand-layout/autoload/run_manager.gd`

### Lines to Fix
- Line 53
- Line 69

### Current Code (BROKEN)
```gdscript
## Line 53
run_state.start_run(run.plays_per_round, run.hand_size, run.bag_config)

## Line 69
print("[RunManager] Run initialized from builder - Plays/round: %d | Hand: %d | Qualities: %d" % [
    run_state.plays_per_round, run_state.hand_size, run.qualities.size()
])
```

### Fixed Code
```gdscript
## Line 53 - FIXED
run_state.start_run(run.plays_per_round, run.bag_config)

## Line 69 - FIXED
print("[RunManager] Run initialized from builder - Plays/round: %d | Qualities: %d" % [
    run_state.plays_per_round, run.qualities.size()
])
```

### Reason
Phase 2 commit `c037014` removed:
- `hand_size` field from `Run` class
- `config_hand_size` parameter from `RunState.start_run()` method

But RunManager was not updated to match the new signature.

### Impact
Without this fix, the game cannot start. Any attempt to run with RunBuilder will throw a TypeError.

---

## Critical Issue #2: HandFanLayout Signal Cleanup Race Condition

### File
`/c/Users/suporte/Documents/dev/.worktrees/fan-hand-layout/scripts/animation/hand/hand_fan_layout.gd`

### Method
`_unregister_tile(tile: Tile)`

### Current Code (BROKEN)
```gdscript
func _unregister_tile(tile: Tile) -> void:
    _managed_tiles.erase(tile)
    _kill_tween(tile)

    if not is_instance_valid(tile):
        if _hovered_tile == tile:
            _hovered_tile = null
        if _tile_callbacks.has(tile):
            _tile_callbacks.erase(tile)
        return  # ← PROBLEM: Exit before signal cleanup!

    tile.external_scale_management = false
    tile.scale = Tile.SELECTED_SCALE if tile.is_selected else Tile.NORMAL_SCALE
    tile.z_index = 0

    # Use stored callbacks for safe disconnection (avoids Callable recreation)
    if _tile_callbacks.has(tile):
        var cbs = _tile_callbacks[tile]
        if tile.mouse_entered.is_connected(cbs["entered"]):
            tile.mouse_entered.disconnect(cbs["entered"])  # ← Never reached if tile freed
        if tile.mouse_exited.is_connected(cbs["exited"]):
            tile.mouse_exited.disconnect(cbs["exited"])
        _tile_callbacks.erase(tile)

    if _hovered_tile == tile:
        _hovered_tile = null
```

### Fixed Code
```gdscript
func _unregister_tile(tile: Tile) -> void:
    _managed_tiles.erase(tile)
    _kill_tween(tile)

    # Store callbacks BEFORE any validity checks
    var cbs = _tile_callbacks.get(tile, {})

    if not is_instance_valid(tile):
        # Clean up references for freed tile
        if _hovered_tile == tile:
            _hovered_tile = null
        if _tile_callbacks.has(tile):
            _tile_callbacks.erase(tile)
        return  # Safe to return now - signals already disconnected below

    # For valid tiles, restore normal state
    tile.external_scale_management = false
    tile.scale = Tile.SELECTED_SCALE if tile.is_selected else Tile.NORMAL_SCALE
    tile.z_index = 0

    # Use stored callbacks for safe disconnection (valid tile, safe to check)
    if cbs:
        if cbs.has("entered") and tile.mouse_entered.is_connected(cbs["entered"]):
            tile.mouse_entered.disconnect(cbs["entered"])
        if cbs.has("exited") and tile.mouse_exited.is_connected(cbs["exited"]):
            tile.mouse_exited.disconnect(cbs["exited"])

    _tile_callbacks.erase(tile)

    if _hovered_tile == tile:
        _hovered_tile = null
```

### Key Changes
1. Extract `cbs = _tile_callbacks.get(tile, {})` BEFORE any validity checks
2. This allows signal disconnection to work whether tile is valid or freed
3. Validity check now only controls state restoration, not cleanup

### Reason
When a tile is freed (especially during round transitions), the old code would:
1. Check `if not is_instance_valid(tile)` → true
2. Return immediately without disconnecting signals
3. Signals remain connected to a freed tile object

This causes:
- Signal emissions from freed tiles
- Memory leaks (callbacks holding references)
- Potential crashes if signals are triggered

### Impact
Critical for round transitions where hand is cleared. Without this fix, expect crashes during scene cleanup.

---

## Important Issue #1: Draw Button Hand Full Check

### File
`/c/Users/suporte/Documents/dev/.worktrees/fan-hand-layout/scenes/ui/main_hud/main_hud.gd`

### Method
`_update_draw_button(_hand_count: int)`

### Lines
233-237

### Current Code (INCOMPLETE)
```gdscript
func _update_draw_button(_hand_count: int) -> void:
    if _draw_button_blocked:
        draw_button.disabled = true
        return
    draw_button.disabled = TileBag.is_empty()
```

### Fixed Code
```gdscript
func _update_draw_button(_hand_count: int) -> void:
    if _draw_button_blocked:
        draw_button.disabled = true
        return
    # Disable if bag is empty OR hand is full
    draw_button.disabled = TileBag.is_empty() or HandManager.is_hand_full()
```

### Reason
With unlimited draw (Phase 3), the draw button should be disabled when:
1. The bag is empty (can't draw)
2. The hand is full (max 10 tiles)

Current code only checks #1, allowing players to click "Draw" when hand is full.

### Impact
UX issue: Draw button silently fails when hand is full. Players don't get feedback that they need to play tiles or discard.

---

## Important Issue #2: Add Hand.is_full() Method

### File
`/c/Users/suporte/Documents/dev/.worktrees/fan-hand-layout/scenes/hand/hand.gd`

### What's Missing
The Hand class doesn't expose an `is_full()` method, but HandManager tries to call it.

### Where It's Called
`/c/Users/suporte/Documents/dev/.worktrees/fan-hand-layout/autoload/hand_manager.gd` line 187:
```gdscript
func is_hand_full() -> bool:
    if _hand_ui == null:
        return false
    return _hand_ui.is_full()  # ← This method doesn't exist!
```

### Option A: Add to Hand.gd (Recommended)
Add after the other query methods:

```gdscript
## Returns true if hand is at max capacity.
func is_full() -> bool:
    if not has_meta("max_hand_size"):
        return false
    var max_size = get_meta("max_hand_size")
    return get_tile_count() >= max_size
```

### Option B: Fix HandManager.is_hand_full()
Change HandManager to not call a nonexistent method:

```gdscript
func is_hand_full() -> bool:
    if _hand_ui == null:
        return false
    # Directly check against STARTING_HAND_SIZE
    return _hand_ui.get_tile_count() >= STARTING_HAND_SIZE
```

### Recommendation
Use **Option A** because:
- Consistent with Hand API (follows delegation pattern)
- More maintainable if max_hand_size changes
- Better encapsulation

### Impact
Without this, calling `HandManager.is_hand_full()` will raise a method not found error.

---

## Fix Priority

| Priority | Issue | File | Time | Must Fix |
|----------|-------|------|------|----------|
| 1 | RunManager hand_size | autoload/run_manager.gd | 2 min | YES |
| 2 | HandFanLayout signals | scripts/animation/hand/hand_fan_layout.gd | 5 min | YES |
| 3 | Hand.is_full() | scenes/hand/hand.gd | 2 min | YES |
| 4 | Draw button check | scenes/ui/main_hud/main_hud.gd | 1 min | YES |

**Total Time: ~10 minutes**

---

## Verification Steps

After applying fixes:

1. **Test Game Startup**
   ```
   Run scene: Main.tscn
   Expected: Game loads, first round ready
   ```

2. **Test Drawing**
   ```
   Click Draw button 2x (5 tiles each)
   Expected: Hand has 10 tiles arranged in arc
   ```

3. **Test Draw Button State**
   ```
   With full hand (10 tiles), observe Draw button
   Expected: Button is DISABLED
   ```

4. **Test Round Transition**
   ```
   Complete round, transition to next round
   Expected: No crashes, hand cleared and refilled correctly
   ```

5. **Test Hover Effects**
   ```
   Hover over tiles with 1, 5, 10 tiles in hand
   Expected: Arc layout correct, hover effects smooth, no signal errors
   ```

---

## Files Modified

- `/c/Users/suporte/Documents/dev/.worktrees/fan-hand-layout/autoload/run_manager.gd` (2 lines)
- `/c/Users/suporte/Documents/dev/.worktrees/fan-hand-layout/scripts/animation/hand/hand_fan_layout.gd` (1 method)
- `/c/Users/suporte/Documents/dev/.worktrees/fan-hand-layout/scenes/hand/hand.gd` (1 method added)
- `/c/Users/suporte/Documents/dev/.worktrees/fan-hand-layout/scenes/ui/main_hud/main_hud.gd` (1 line)

**Total Changes: ~20 lines of code**
