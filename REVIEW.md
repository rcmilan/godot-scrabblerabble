# Comprehensive Code Review: Fan Hand Layout + Unlimited Draw System

**Reviewed Branch:** `hand-rework`
**Commits Reviewed:** `dedded7` through `fda0534` (14 commits across 3 phases)
**Review Date:** 2026-02-28

---

## Executive Summary

**Overall Status:** NEEDS FIXES — Multiple integration bugs found

The implementation demonstrates excellent architecture for the fan hand layout system and proper separation of concerns, but **critical bugs in Phase 2 prevent the system from functioning correctly**. The Phase 3 unlimited draw feature is well-designed but cannot be tested due to Phase 2 issues.

**Critical Issues:** 2
**Important Issues:** 2
**Suggestions:** 3

---

## 1. Architecture Assessment

### 1.1 Design Quality - EXCELLENT

The three-phase decomposition is conceptually sound:

- **Phase 1 (Arc Layout):** Pure geometry computation separated from UI, with immutable value objects (TileArcTransform)
- **Phase 2 (Remove Hand Size):** Elimination of mutable hand_size field across domain + runtime layers
- **Phase 3 (Unlimited Draw):** Shift from finite replenishment to constant batch drawing

The pattern of **pure computation (ArcLayoutComputer)** decoupled from **UI application (HandFanLayout)** is excellent for testability and reusability.

### 1.2 Adherence to Codebase Patterns - GOOD

The implementation respects existing architectural patterns:

- **TileArcTransform**: Follows the immutable value object pattern (like RoundConfig, BagDistribution)
- **ArcLayoutComputer**: Pure refCounted math class (like WordValidator, ProgressionRules)
- **HandFanLayout**: Proper dependency injection via `setup(container)`, manual signal management (no magic)
- **Draw batch**: Proper delegation to HandManager public API

The code integrates well with existing handlers and signals.

### 1.3 Separation of Concerns - EXCELLENT

- **Geometry logic** isolated in ArcLayoutComputer
- **Layout application** isolated in HandFanLayout (tweening, hover effects)
- **Hand container** purely manages tiles (add/remove/queries)
- **UI state** updates only through proper signal channels

---

## 2. Critical Issues (MUST FIX)

### CRITICAL ISSUE #1: RunManager Passes Removed `hand_size` Parameter

**File:** `/c/Users/suporte/Documents/dev/.worktrees/fan-hand-layout/autoload/run_manager.gd:53`

**Problem:**
```gdscript
# Line 53 - BROKEN
run_state.start_run(run.plays_per_round, run.hand_size, run.bag_config)

# RunState.start_run signature changed in Phase 2:
# OLD: func start_run(config_plays, config_hand_size, config_bag)
# NEW: func start_run(config_plays, config_bag)
```

Phase 2 commit `c037014` removed `hand_size` from `Run` class and changed `RunState.start_run()` signature to accept only 2 parameters. However, RunManager was not updated to match.

**Impact:** Runtime TypeError when initializing a run from RunBuilder. The game cannot start with the unlimited draw system active.

**Fix Required:**
```gdscript
# Line 53 - CORRECT
run_state.start_run(run.plays_per_round, run.bag_config)
```

Also at **line 69**, the debug print references removed field:
```gdscript
# Line 69 - WRONG
print("[RunManager] Run initialized from builder - Plays/round: %d | Hand: %d | Qualities: %d" % [
    run_state.plays_per_round, run_state.hand_size, run.qualities.size()  # hand_size doesn't exist
])

# Should be:
print("[RunManager] Run initialized from builder - Plays/round: %d | Qualities: %d" % [
    run_state.plays_per_round, run.qualities.size()
])
```

**Severity:** CRITICAL — Breaks run initialization entirely

---

### CRITICAL ISSUE #2: HandFanLayout Signal Cleanup Race Condition

**File:** `/c/Users/suporte/Documents/dev/.worktrees/fan-hand-layout/scripts/animation/hand/hand_fan_layout.gd:177-199`

**Problem:**
```gdscript
func _unregister_tile(tile: Tile) -> void:
    _managed_tiles.erase(tile)
    _kill_tween(tile)

    if not is_instance_valid(tile):
        # Guard: tile is being freed
        if _hovered_tile == tile:
            _hovered_tile = null
        if _tile_callbacks.has(tile):
            _tile_callbacks.erase(tile)
        return  # ← EXIT HERE without disconnecting signals

    # This code is unreachable if tile is being freed
    tile.external_scale_management = false
    tile.scale = Tile.SELECTED_SCALE if tile.is_selected else Tile.NORMAL_SCALE
    tile.z_index = 0

    # Use stored callbacks for safe disconnection
    if _tile_callbacks.has(tile):
        var cbs = _tile_callbacks[tile]
        if tile.mouse_entered.is_connected(cbs["entered"]):
            tile.mouse_entered.disconnect(cbs["entered"])  # ← Never reached during tile free
```

**Analysis:**
The code attempts to guard against freed tiles but returns **before** disconnecting signals. When a tile is freed (tile removed from hand, hand cleared between rounds), the signals remain connected to an invalid object.

The pattern should be:
1. Store callbacks **before** any validity checks
2. Disconnect signals **after** validity checks (safe due to stored reference)
3. Then clean up state

**Impact:**
- Potential signal emission from freed tiles during hand updates
- Memory leaks if signal callbacks hold references
- undefined behavior if mouse enters a freed tile's area during scene transition

**Fix Required:**
```gdscript
func _unregister_tile(tile: Tile) -> void:
    _managed_tiles.erase(tile)
    _kill_tween(tile)

    # Store callbacks BEFORE validity check
    var cbs = _tile_callbacks.get(tile, {})

    if not is_instance_valid(tile):
        if _hovered_tile == tile:
            _hovered_tile = null
        if _tile_callbacks.has(tile):
            _tile_callbacks.erase(tile)
        return

    tile.external_scale_management = false
    tile.scale = Tile.SELECTED_SCALE if tile.is_selected else Tile.NORMAL_SCALE
    tile.z_index = 0

    # Disconnect using stored callbacks (safe, valid object)
    if cbs:
        if cbs.has("entered") and tile.mouse_entered.is_connected(cbs["entered"]):
            tile.mouse_entered.disconnect(cbs["entered"])
        if cbs.has("exited") and tile.mouse_exited.is_connected(cbs["exited"]):
            tile.mouse_exited.disconnect(cbs["exited"])

    _tile_callbacks.erase(tile)

    if _hovered_tile == tile:
        _hovered_tile = null
```

**Severity:** CRITICAL — Can cause crashes during round transitions

---

## 3. Important Issues (SHOULD FIX)

### IMPORTANT ISSUE #1: Draw Button Logic Doesn't Account for Full Hand

**File:** `/c/Users/suporte/Documents/dev/.worktrees/fan-hand-layout/scenes/ui/main_hud/main_hud.gd:233-237`

**Problem:**
```gdscript
func _update_draw_button(_hand_count: int) -> void:
    if _draw_button_blocked:
        draw_button.disabled = true
        return
    draw_button.disabled = TileBag.is_empty()  # ← Only checks bag, not hand
```

In Phase 3 (unlimited draw), drawing still respects hand capacity (Hand.is_full()). The draw button should be disabled when:
1. Bag is empty, **OR**
2. Hand is full

Current code only checks condition 1, allowing players to click draw when hand is at max capacity, which will silently fail in HandManager.draw_tiles():

```gdscript
# In HandManager.draw_tiles()
for i in count:
    if _hand_ui.is_full():
        print("[HandManager] Hand is full")
        break  # ← Silent break, returns 0
```

**Expected Behavior:**
The draw button should provide clear feedback that it's disabled when the hand is full, not silently fail.

**Fix Required:**
```gdscript
func _update_draw_button(_hand_count: int) -> void:
    if _draw_button_blocked:
        draw_button.disabled = true
        return
    # Disable if bag is empty OR hand is full
    draw_button.disabled = TileBag.is_empty() or HandManager.is_hand_full()
```

**Severity:** IMPORTANT — UX issue, not a crash

---

### IMPORTANT ISSUE #2: Hand.is_full() Called But Never Properly Initialized

**File:** `/c/Users/suporte/Documents/dev/.worktrees/fan-hand-layout/scenes/hand/hand.gd` (line missing)

**Problem:**
HandFanLayout requires a container to be passed, and Hand properly does this. However, there's no getter for `max_hand_size` on Hand itself. The draw button check calls `HandManager.is_hand_full()` which checks:

```gdscript
# In HandManager
func is_hand_full() -> bool:
    if _hand_ui == null:
        return false
    return _hand_ui.is_full()

# But Hand doesn't have is_full(), it delegates to tile count vs max_hand_size
```

**Observation:** Looking at Hand.gd, there's no `is_full()` method defined. This will cause a runtime error when `is_hand_full()` is called. The Hand component stores `max_hand_size` but doesn't expose `is_full()`.

**Fix Required:**
Add to Hand.gd:
```gdscript
func is_full() -> bool:
    if not has_meta("max_hand_size"):
        return false
    var max_size = get_meta("max_hand_size") if has_meta("max_hand_size") else 999
    return get_tile_count() >= max_size
```

Or HandManager.set_references should store a reference and check directly:
```gdscript
func is_hand_full() -> bool:
    if _hand_ui == null:
        return false
    return _hand_ui.get_tile_count() >= STARTING_HAND_SIZE
```

**Severity:** IMPORTANT — Will crash when draw button is updated

---

## 4. Suggestions (NICE TO HAVE)

### SUGGESTION #1: Arc Layout Computer Lacks Multi-Tile Edge Case Testing

**File:** `/c/Users/suporte/Documents/dev/.worktrees/fan-hand-layout/scripts/animation/hand/arc_layout_computer.gd`

The `_calculate_step()` function handles single tile (count == 1) and normal cases, but the behavior for count > 100 tiles is untested:

```gdscript
func _calculate_step(count: int, container_w: float) -> float:
    var natural_total_width = (count - 1) * ideal_step_px + TILE_WIDTH

    if natural_total_width <= container_w:
        return ideal_step_px

    # Compress step to fit container
    var compressed_step = (container_w - TILE_WIDTH) / float(count - 1)

    # Clamp to minimum
    return maxf(compressed_step, min_step)  # ← min_step prevents division issues
```

With `min_step = 20.0` and count = 100:
- compressed_step = (1200 - 64) / 99 = ~11.4px
- returns max(11.4, 20) = 20px
- Total width = 99 * 20 + 64 = 2044px (exceeds container!)

**Recommendation:** Document the expected tile limits or add an assertion:
```gdscript
assert(count <= 50, "Hand contains more than 50 tiles; layout becomes unreliable beyond this point")
```

Or recalculate min_step based on container width to guarantee fit-to-container.

---

### SUGGESTION #2: HandFanLayout Hover Effect Scale Not Restored on Selection Change

**File:** `/c/Users/suporte/Documents/dev/.worktrees/fan-hand-layout/scripts/animation/hand/hand_fan_layout.gd:112-114`

```gdscript
# In update_layout()
# Apply select/normal scale (don't touch hovered tiles here)
if tile != _hovered_tile:
    tile.scale = Tile.SELECTED_SCALE if tile.is_selected else Tile.NORMAL_SCALE
```

**Issue:** When a tile's selection state changes (via SelectionManager), the layout should update its tweened scale. Currently, if a tile is hovered and then selected, the hover scale (1.1) is preserved even after the hover ends.

**Recommended:** Connect to SelectionManager's `selection_changed` signal in HandFanLayout and re-apply base scales.

---

### SUGGESTION #3: Phase 3 Draw Button State Management Could Be Cleaner

**File:** `/c/Users/suporte/Documents/dev/.worktrees/fan-hand-layout/scripts/controllers/gameplay_controller.gd:112-114`

```gdscript
if event.is_action_pressed(KeyAction.DRAW_TILES):
    _on_draw_requested()
    get_viewport().set_input_as_handled()
```

The draw button is disabled by MainHUD, but the keyboard action has no guard. Consider:
```gdscript
if event.is_action_pressed(KeyAction.DRAW_TILES):
    if not TileBag.is_empty() and not HandManager.is_hand_full():
        _on_draw_requested()
    get_viewport().set_input_as_handled()
```

---

## 5. Integration Assessment

### 5.1 Phase 1 → Phase 2 Integration: GOOD

- ✅ Arc layout persists correctly through phase 2 changes
- ✅ HandFanLayout created in Hand._ready() as expected
- ✅ No hand size dependencies in layout computation
- ⚠️ Layout updates happen correctly even with dynamic hand size management removed

### 5.2 Phase 2 → Phase 3 Integration: BROKEN

Due to Critical Issue #1, the integration is **blocked at initialization**. Once that's fixed:
- ✅ Draw button changes are correct (checks bag only)
- ✅ draw_batch() API properly limits to DRAW_BATCH_SIZE (5 tiles)
- ✅ refill_hand() removed from draw path, proper unlimited flow
- ✅ HandManager constants replace mutable hand_size correctly

### 5.3 Signal Flow: GOOD (with caveat)

The signal path is correct:
```
MainHUD.draw_requested
  → GameplayController._on_draw_requested()
    → HandManager.draw_batch()
      → Hand.add_tile() (emits tile_added)
      → HandManager.tile_ready
        → Main.register_tile()
          → Tile signals connected
      → HandFanLayout.update_layout()
        → Tiles positioned, tweened, hovered
      → TileAnimator.animate_draw_batch()
```

**Caveat:** HandFanLayout signal cleanup has the race condition noted above.

---

## 6. Edge Cases Analysis

### 6.1 Single Tile in Hand
- ✅ ArcLayoutComputer handles count=1 with elevation but no rotation
- ✅ HandFanLayout hover effect works (scales, no neighbors to push)
- ✅ Z-index stays at 0

### 6.2 Many Tiles (>50)
- ⚠️ Layout compression works but exceeds container width (see Suggestion #1)
- ✅ Step clamp prevents division by zero
- ✅ Tiles remain clickable even if overlapped

### 6.3 Rapid Updates
- ⚠️ Reflow tweens can conflict if update_layout() called while tweens running
- ✅ Code kills old tweens before creating new ones (_kill_reflow_tween)
- ✅ Hover tweens properly guarded

### 6.4 Round Transition (tile freed)
- 🔴 **CRITICAL**: Signal cleanup race condition (Critical Issue #2)
- After fix: Signals properly disconnected before tile is freed

### 6.5 Hand Empty to Full
- ✅ Draw button state updates correctly (once Important Issue #1 fixed)
- ✅ HandManager properly stops drawing when full
- ✅ No animation conflicts

### 6.6 Draw Button Spam
- ✅ Button disabled when bag empty
- ⚠️ Not disabled when hand full (Important Issue #1)
- ✅ No double-draw protection needed (state-based disable)

---

## 7. Code Quality Standards

### 7.1 Documentation: EXCELLENT

- ✅ All new classes have clear header comments explaining purpose
- ✅ Constants properly documented with physics/design reasoning
- ✅ Complex algorithms (arc computation) have step-by-step comments
- ✅ Signals documented with parameters and emission points
- ✅ Public API clearly separated from private helpers

### 7.2 Naming Conventions: EXCELLENT

- ✅ Classes follow `PascalCase` (HandFanLayout, TileArcTransform)
- ✅ Constants follow `UPPER_SNAKE_CASE` (TILE_WIDTH, HOVER_SCALE)
- ✅ Private fields follow `_lower_snake_case` (_base_transforms, _hovered_tile)
- ✅ Public methods follow `lower_snake_case` (setup, update_layout, apply_hover_effect)
- ✅ Consistent with codebase standards (aligns with memory notes)

### 7.3 Type Safety: EXCELLENT

- ✅ All parameters fully typed (Vector2, float, Tile, etc.)
- ✅ Array returns typed as `Array[TileArcTransform]`, `Array[Tile]`
- ✅ No implicit conversions or unsafe casts
- ✅ Uses proper null coalescing and validation guards

### 7.4 Error Handling: GOOD

- ✅ Asserts in pure computation layer (ArcLayoutComputer)
- ✅ Null checks before accessing optional references (_container, _hovered_tile)
- ✅ Graceful degradation when tileset is invalid
- ⚠️ Missing some guard clauses in signal handlers (handled safely by return guards)

### 7.5 Memory Management: GOOD

- ✅ Tween cleanup with `_kill_tween()`, `_kill_reflow_tween()` methods
- ✅ Signal disconnection attempted in `_unregister_tile()` (though buggy)
- ✅ RefCounted classes properly scope their lifetimes
- ⚠️ Callback dictionary stores references indefinitely (minor: cleared in cleanup)

---

## 8. Regression Risk Assessment

### High Risk Areas
- **None identified** — Changes are isolated to hand layout and draw system
- Existing tile placement, scoring, board logic unaffected

### Medium Risk Areas
- **RunManager integration**: Critical Issue #1 breaks initialization path
- **Hand signal cleanup**: Critical Issue #2 affects round transitions
- Once fixed, regression risk is LOW

### Low Risk Areas
- ✅ Phase 1 arc layout has no regressions with hand system removed
- ✅ Unlimited draw doesn't break refill_hand() (it still works for shop resets)
- ✅ Selection system unaffected by layout changes

---

## 9. Backward Compatibility

### Preserved
- ✅ Hand UI public API unchanged (add_tile, remove_tile, get_tiles, etc.)
- ✅ HandManager public API mostly compatible (draw_batch replaces refill_hand at one call site)
- ✅ GameplayController interface stable
- ✅ Tile object unchanged

### Breaking Changes (Acceptable)
- ❌ Run.hand_size removed (RunBuilder calls removed from old code)
- ❌ RunState.start_run() signature changed (only internal, OK for domain refactor)
- ❌ HandManager.set_hand_size() removed (replaced by STARTING_HAND_SIZE constant)
- ❌ MaxHandSizeQuality removed from system (no longer needed)

**Assessment:** Breaking changes are intentional and documented. No public API regressions.

---

## Summary Table

| Category | Status | Issues |
|----------|--------|--------|
| **Architecture** | EXCELLENT | 0 |
| **Integration** | BROKEN | 2 CRITICAL |
| **Code Quality** | EXCELLENT | 0 |
| **Documentation** | EXCELLENT | 0 |
| **Edge Cases** | GOOD | 2 important |
| **Regressions** | LOW (after fixes) | 0 after fixes |

---

## Recommendations

### Immediate (CRITICAL)
1. **Fix RunManager.initialize_run_from_builder()**: Remove hand_size parameter from run_state.start_run() call (line 53)
2. **Fix debug print in RunManager** (line 69): Remove run_state.hand_size reference
3. **Fix HandFanLayout._unregister_tile()**: Properly disconnect signals before validity check (Critical Issue #2)

### High Priority (IMPORTANT)
4. **Fix MainHUD._update_draw_button()**: Check both bag empty AND hand full
5. **Add Hand.is_full()**: Properly expose hand capacity check

### Before Merge
6. **Add runtime assertions** for > 50 tiles in ArcLayoutComputer
7. **Test round transitions**: Verify tile cleanup with new signal handling
8. **Integration test**: Start game → draw tiles → full hand → can't draw → correct

### Nice to Have
9. Connect SelectionManager to HandFanLayout for selection-aware scale restoration
10. Add keyboard guard in GameplayController draw action

---

## Test Checklist (After Fixes)

- [ ] Game starts from title screen
- [ ] RunBuilder creates Run without hand_size parameter
- [ ] First round displays with parabolic arc layout
- [ ] Drawing 5 tiles expands hand
- [ ] Drawing when hand is full disables button
- [ ] Hand at 10 tiles: all positioned in arc, no overlaps
- [ ] Hand at 1 tile: centered, elevated, no rotation
- [ ] Hover single tile: scales to 1.1x, lifts 10px
- [ ] Hover tile in group: neighbors pushed away
- [ ] Round transition: hand cleared, layout recomputed
- [ ] Multiple rounds: hand layout persists correctly
- [ ] Selection state: hovered tiles not affected by selection scale

---

## Conclusion

The implementation demonstrates **excellent architectural design** and **adherence to codebase patterns**. The three-phase decomposition properly separates concerns and enables the unlimited draw feature. However, **two critical integration bugs** prevent the system from functioning. Once these are fixed, the code quality is high and regression risk is minimal.

**Status Before Fixes:** ❌ NEEDS FIXES
**Status After Fixes:** ✅ APPROVED (pending test checklist)

The codebase will benefit significantly from this refactor once the integration issues are resolved. The arc layout system is reusable, testable, and maintainable.
