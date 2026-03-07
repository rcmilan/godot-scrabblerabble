# Animation Blocking Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prevent animation stacking on tiles by adding event-driven state tracking and guard checks in animation executors.

**Architecture:** Tiles listen to `TileAnimator.animation_started` and `animation_completed` signals to track animation state locally. Animation executors check this state before executing and silently reject blocked requests.

**Tech Stack:** GDScript, Godot signals, TileAnimator autoload

---

## Task 1: Add Animation State Tracking to Tile

**Files:**
- Modify: `scenes/tile/tile.gd` (add field, signal handlers, getter)

**Step 1: Read current Tile class structure**

Run:
```bash
grep -n "class_name Tile\|func _ready\|signal" scenes/tile/tile.gd | head -20
```

This shows the class structure and existing signals. We'll add our animation state tracking after these.

**Step 2: Add `_is_animating` field to Tile**

In `scenes/tile/tile.gd`, add after the class declaration (around line 30-40):

```gdscript
# Animation state tracking
var _is_animating: bool = false
```

**Step 3: Connect to TileAnimator signals in _ready()**

Find the `_ready()` function in Tile. Add these lines at the end of `_ready()`:

```gdscript
	# Connect to animation lifecycle signals
	TileAnimator.animation_started.connect(_on_tile_animator_animation_started)
	TileAnimator.animation_completed.connect(_on_tile_animator_animation_completed)
```

**Step 4: Add signal handler for animation_started**

Add this new function to Tile (at end of class):

```gdscript
func _on_tile_animator_animation_started(tiles: Array[Tile]) -> void:
	if self in tiles:
		_is_animating = true
```

**Step 5: Add signal handler for animation_completed**

Add this new function to Tile (after previous handler):

```gdscript
func _on_tile_animator_animation_completed(tiles: Array[Tile]) -> void:
	if self in tiles:
		_is_animating = false
```

**Step 6: Add public getter**

Add this public method to Tile:

```gdscript
func is_animating() -> bool:
	return _is_animating
```

**Step 7: Verify syntax**

Run:
```bash
grep -n "_is_animating\|_on_tile_animator\|is_animating" scenes/tile/tile.gd
```

Expected: Shows 6 matches (field, 2 connections, 2 handlers, getter)

**Step 8: Commit**

```bash
git add scenes/tile/tile.gd
git commit -m "feat: add animation state tracking to Tile using TileAnimator signals"
```

---

## Task 2: Add Guard Check to ShakeAnimationExecutor

**Files:**
- Modify: `scripts/animation/shake/shake_animation_executor.gd` (add guard at start of execute)

**Step 1: Read current ShakeAnimationExecutor.execute()**

Run:
```bash
sed -n '9,15p' scripts/animation/shake/shake_animation_executor.gd
```

Expected: Shows the execute function signature and first few lines

**Step 2: Add guard check after function signature**

In `scripts/animation/shake/shake_animation_executor.gd`, in the `execute()` method, add this RIGHT AFTER the function signature (before line 10):

```gdscript
	if tile.is_animating():
		print("[ShakeAnimationExecutor] Animation blocked: %s already animating" % tile.name)
		return
```

The function should now look like:
```gdscript
func execute(tile: Tile, strategy: ShakeTileAnimation) -> void:
	if tile.is_animating():
		print("[ShakeAnimationExecutor] Animation blocked: %s already animating" % tile.name)
		return

	# Cancel any existing animation on this tile
	_context.cancel_tile_animation(tile)
	...
```

**Step 3: Verify the change**

Run:
```bash
sed -n '9,15p' scripts/animation/shake/shake_animation_executor.gd
```

Expected: Shows the guard check at the start

**Step 4: Commit**

```bash
git add scripts/animation/shake/shake_animation_executor.gd
git commit -m "feat: add animation guard check to ShakeAnimationExecutor"
```

---

## Task 3: Add Guard Check to ReturnAnimationExecutor

**Files:**
- Modify: `scripts/animation/glide/return_animation_executor.gd` (add guard in execute_single)

**Step 1: Read current ReturnAnimationExecutor.execute_single()**

Run:
```bash
grep -n "func execute_single" scripts/animation/glide/return_animation_executor.gd
```

Expected: Shows line number of execute_single function

**Step 2: Add guard check to execute_single**

In `scripts/animation/glide/return_animation_executor.gd`, in the `execute_single()` method, add guard check right after the function signature:

```gdscript
	if tile.is_animating():
		print("[ReturnAnimationExecutor] Animation blocked: %s already animating" % tile.name)
		return
```

**Step 3: Verify the change**

Run:
```bash
grep -A 5 "func execute_single" scripts/animation/glide/return_animation_executor.gd | head -7
```

Expected: Shows guard check at start

**Step 4: Commit**

```bash
git add scripts/animation/glide/return_animation_executor.gd
git commit -m "feat: add animation guard check to ReturnAnimationExecutor"
```

---

## Task 4: Add Guard Check to StompAnimationExecutor

**Files:**
- Modify: `scripts/animation/stomp/stomp_animation_executor.gd` (add guard in execute)

**Step 1: Read current StompAnimationExecutor.execute()**

Run:
```bash
grep -n "func execute" scripts/animation/stomp/stomp_animation_executor.gd
```

**Step 2: Add guard check for each tile**

In `scripts/animation/stomp/stomp_animation_executor.gd`, in the `execute()` method, add this at the start (after function signature, before any other logic):

```gdscript
	# Block if any tile is already animating
	for tile in tiles:
		if tile.is_animating():
			print("[StompAnimationExecutor] Animation blocked: %s already animating" % tile.name)
			return
```

**Step 3: Verify the change**

Run:
```bash
grep -A 6 "func execute" scripts/animation/stomp/stomp_animation_executor.gd | head -8
```

Expected: Shows guard loop at start

**Step 4: Commit**

```bash
git add scripts/animation/stomp/stomp_animation_executor.gd
git commit -m "feat: add animation guard check to StompAnimationExecutor"
```

---

## Task 5: Add Guard Check to SpinAnimationExecutor

**Files:**
- Modify: `scripts/animation/spin/spin_animation_executor.gd` (add guard in execute)

**Step 1: Locate execute method**

Run:
```bash
grep -n "func execute" scripts/animation/spin/spin_animation_executor.gd
```

**Step 2: Add guard check**

In `scripts/animation/spin/spin_animation_executor.gd`, add guard at start of `execute()` method:

```gdscript
	# Block if any tile is already animating
	for tile in tiles:
		if tile.is_animating():
			print("[SpinAnimationExecutor] Animation blocked: %s already animating" % tile.name)
			return
```

**Step 3: Verify**

Run:
```bash
grep -A 6 "func execute" scripts/animation/spin/spin_animation_executor.gd | head -8
```

**Step 4: Commit**

```bash
git add scripts/animation/spin/spin_animation_executor.gd
git commit -m "feat: add animation guard check to SpinAnimationExecutor"
```

---

## Task 6: Add Guard Check to BatchAnimationExecutor

**Files:**
- Modify: `scripts/animation/draw/batch_animation_executor.gd` (add guard in execute)

**Step 1: Locate execute method**

Run:
```bash
grep -n "func execute" scripts/animation/draw/batch_animation_executor.gd
```

**Step 2: Add guard check**

In `scripts/animation/draw/batch_animation_executor.gd`, add guard at start of `execute()` method:

```gdscript
	# Block if any tile is already animating
	for tile in tiles:
		if tile.is_animating():
			print("[BatchAnimationExecutor] Animation blocked: %s already animating" % tile.name)
			return
```

**Step 3: Verify**

Run:
```bash
grep -A 6 "func execute" scripts/animation/draw/batch_animation_executor.gd | head -8
```

**Step 4: Commit**

```bash
git add scripts/animation/draw/batch_animation_executor.gd
git commit -m "feat: add animation guard check to BatchAnimationExecutor"
```

---

## Task 7: Manual Testing - Verify Animation Blocking Works

**Prerequisites:** All tasks 1-6 complete

**Test Environment:** Godot editor with game running

**Step 1: Start the game**

- Open `scenes/Main.tscn` in Godot
- Press F5 to run
- Wait for board and hand to load

**Step 2: Test Shake Animation Blocking**

- Place tiles on the board
- Press Z (discard) or trigger a discard action
- You should see: "Animation blocked" message in console (optional)
- While shake animation is running, press Z again
- Expected: Second request is blocked silently, tile doesn't move off-cell

**Step 3: Test Rapid Key Mashing**

- Place tiles on board again
- Rapidly mash Z key (hold it down or press repeatedly)
- Verify: Only one shake animation plays
- Verify: Tile returns to original cell position without drift
- No console errors or warnings

**Step 4: Test Animation Works After Blocking**

- Let first animation complete
- Tile should be back to normal state
- Press Z again
- Expected: New animation plays normally
- Verify: `_is_animating` flag properly resets after completion

**Step 5: Test Multiple Tiles**

- Place multiple tiles on board
- Discard some tiles (which returns them to hand)
- Verify: Each tile can be animated independently
- Mash keys on different tiles - they should animate without interfering

**Step 6: Verify Console Messages**

- If animation is blocked, you should see: `[AnimationExecutor] Animation blocked: Tile already animating`
- These are debug messages - they'll help verify blocking is working
- If messages don't appear, blocking might not be working

**Step 7: Notes**

- If any test fails, check:
  - Is `_is_animating` flag being set in Tile._ready()?
  - Are signal connections working? (Check Godot debugger for signal warnings)
  - Are guard checks in executors executing before animation starts?
  - Try adding a print() in the guard to see if it's being reached

---

## Task 8: Final Verification & Cleanup

**Step 1: Check git status**

Run:
```bash
git status
```

Expected: Clean working tree (all changes committed)

**Step 2: View implementation commits**

Run:
```bash
git log --oneline -10
```

Expected: Last 6 commits should be:
- `feat: add animation guard check to BatchAnimationExecutor`
- `feat: add animation guard check to SpinAnimationExecutor`
- `feat: add animation guard check to StompAnimationExecutor`
- `feat: add animation guard check to ReturnAnimationExecutor`
- `feat: add animation guard check to ShakeAnimationExecutor`
- `feat: add animation state tracking to Tile using TileAnimator signals`

**Step 3: Verify all files modified**

Run:
```bash
git diff HEAD~6...HEAD --name-only
```

Expected: Exactly 6 files:
- `scenes/tile/tile.gd`
- `scripts/animation/shake/shake_animation_executor.gd`
- `scripts/animation/glide/return_animation_executor.gd`
- `scripts/animation/stomp/stomp_animation_executor.gd`
- `scripts/animation/spin/spin_animation_executor.gd`
- `scripts/animation/draw/batch_animation_executor.gd`

**Step 4: Verify Tile has is_animating() method**

Run:
```bash
grep "func is_animating" scenes/tile/tile.gd
```

Expected: Shows the getter method

**Step 5: Verify all executors have guard checks**

Run:
```bash
grep -l "is_animating()" scripts/animation/*/\*.gd | wc -l
```

Expected: Shows 5 (five executors with guard checks)

---

## Summary

| Task | Files | Time | Status |
|------|-------|------|--------|
| 1 | `tile.gd` | 10m | Add state tracking + signal handlers |
| 2 | `shake_animation_executor.gd` | 3m | Add guard check |
| 3 | `return_animation_executor.gd` | 3m | Add guard check |
| 4 | `stomp_animation_executor.gd` | 3m | Add guard check |
| 5 | `spin_animation_executor.gd` | 3m | Add guard check |
| 6 | `batch_animation_executor.gd` | 3m | Add guard check |
| 7 | Manual testing | 10m | Verify blocking works |
| 8 | Final verification | 5m | Check commits and files |

**Total:** ~40 minutes

**Success Criteria:**
- ✅ Tile has `_is_animating` state and signal handlers
- ✅ All 5 executors have guard checks
- ✅ Guard checks prevent animation stacking
- ✅ Tile doesn't move off-cell during rapid input
- ✅ All changes committed with clear messages
- ✅ Manual testing confirms no regression

