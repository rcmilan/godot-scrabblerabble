# Quickstart: Manual Test Guide

**Feature**: Fix Orientation Icon Position After Board Resize  
**Branch**: `002-fix-orientation-icon` | **Date**: 2026-04-03

## Prerequisites

- Godot 4.6 installed
- Project opened in Godot Editor
- Branch `002-fix-orientation-icon` checked out

## Manual Verification Steps

### Test 1: Icon Stays at Top-Left During Round Transition

1. Start a new game via title screen (F5)
2. **Observe and note**: Current board size (e.g., 7x7) and orientation icon position (H marker at top-left)
3. Play one complete round until Shop appears
4. In the Shop, select any modifiers (optional; just proceed to next round)
5. Observe: Next round loads with potentially different board size
6. **Verify**: Orientation icon is at the new board's top-left cell (0,0), not at the old position

### Test 2: Icon Position with Size Change 7x7 → 6x9

1. Start game and note board is 7x7
2. Complete round → transition to next round
3. **Verify**: If new board is 6x9, icon is at new top-left (cell count changes but icon is still at 0,0)
4. Visual check: Icon should be on the leftmost, topmost cell

### Test 3: Icon Position with Size Change 6x9 → 8x8

1. In round with 6x9 board, complete round
2. Observe next round with 8x8 board
3. **Verify**: Icon repositions to new top-left, not lingering at old offset

### Test 4: Extreme Case 1x1 Board

1. [If possible via difficulty settings] Trigger a 1x1 board
2. **Verify**: Orientation icon appears on the single cell (at 0,0)
3. Icon should be visible and centered within the cell

### Test 5: Screen Offset (if board position on screen shifts)

1. Play a round and note board position on screen
2. [If applicable] Trigger a layout change or screen resize
3. **Verify**: Icon remains aligned with board's top-left cell, not at fixed screen position

## Pass Criteria

All 5 tests must pass:
- ✓ Icon at new top-left after every round transition
- ✓ Icon positions correctly for 6x9, 8x8 boards (no lingering)
- ✓ Icon appears on 1x1 board at (0,0)
- ✓ Icon tracks with board offset if screen position changes
- ✓ No flickering or repositioning delay visible to player

## Failure Signs

- Icon appears offset from the top-left cell
- Icon doesn't update position when board size changes
- Icon flickers or repositions after board is already visible
- Icon stays at old position for multiple frames before snapping to new position

## Debug Information to Collect

If test fails:
- Note exact board dimensions (width × height)
- Note icon screen position before and after transition
- Note if icon flickers or snaps delayed
- Check console output for error messages related to board resize or icon positioning
