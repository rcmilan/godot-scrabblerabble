# Manual Testing Checklist: Boss Entities System (Phase 6)

**Date**: 2026-04-11  
**Feature**: Boss Entities System (005-boss-entities)  
**Tester**: [Your Name]  
**Session Duration**: [Fill in]

---

## Setup Instructions

1. Open the Wordatro project in Godot 4.6
2. Press **F5** to start the game
3. From the title screen, start a new run with default settings
4. Proceed through rounds until reaching **Round 3** (first boss round)

---

## T027: Multi-Column Drop Test

**Scenario**: Gravity boss, tiles placed in multiple columns simultaneously  
**Expected Outcome**: Each column drops independently; tiles land at correct positions

### Test Steps

- [ ] **Setup**: Reach Round 3 (Gravity boss should be active)
  - Verify background is purple (#330033)
  - Verify round indicator shows "Gravity"

- [ ] **Place tiles in multiple columns** (at least 3 different columns)
  - Example: Place tile in column A, row 2
  - Example: Place tile in column C, row 3  
  - Example: Place tile in column E, row 1
  - Tiles should NOT be at bottom row yet

- [ ] **Press Play**
  - Observe drop animation starts
  - Watch for staggered cascade effect (tiles drop with ~0.03s delay between them)

- [ ] **Verify drop results**
  - [ ] Tile in column A lands at row 8 (bottom)
  - [ ] Tile in column C lands at row 8 (bottom)
  - [ ] Tile in column E lands at row 8 (bottom)
  - [ ] No tiles overlap or occupy wrong cells
  - [ ] Animation is smooth and takes ~0.5s per tile

- [ ] **Verify scoring works on dropped positions**
  - Scoring should calculate based on final (dropped) positions, not original positions

**Result**: ✓ PASS / ✗ FAIL  
**Notes**: 

---

## T028: Stacking with Locked Tiles

**Scenario**: Gravity boss, column has locked tiles from previous play  
**Expected Outcome**: New tiles stack above locked tiles, no overlap

### Test Steps

- [ ] **Setup**: Still in Round 3 (Gravity boss active)

- [ ] **First play - place tile at bottom row of column B**
  - Place 1 tile at column B, row 8 (or leave it to drop there)
  - Press Play
  - Observe tile gets locked (darker appearance)
  - End round to advance to next round, return to Round 3 is not possible, so instead:
  - Actually, we need to stay in Round 3. Let me clarify: place tiles in column B at the bottom row and press Play once.
  - The tile becomes locked.

- [ ] **Second play - place new tile in same column B, but higher up**
  - Place a new tile at column B, row 4
  - Press Play
  - Observe drop animation begins

- [ ] **Verify stacking behavior**
  - [ ] New tile animates downward
  - [ ] New tile stops at row 7 (directly above locked tile at row 8)
  - [ ] No overlap or collision
  - [ ] Locked tile remains in place (does not move)

- [ ] **Verify both tiles are visible and distinct**
  - Can see the locked tile below
  - Can see the newly dropped tile above it

**Result**: ✓ PASS / ✗ FAIL  
**Notes**: 

---

## T029: Bottom Row Tiles (No Movement)

**Scenario**: Gravity boss, tiles already at bottom row  
**Expected Outcome**: No animation, no errors, tiles stay in place

### Test Steps

- [ ] **Setup**: Round 3 (Gravity boss active)

- [ ] **Place tile directly at bottom row**
  - Click a cell at row 8 (bottom row) in an empty column
  - Place a tile there
  - Tile should be at row 8 immediately

- [ ] **Press Play**
  - Tile is already at bottom row
  - Gravity has no movement needed
  - **Expected**: No drop animation occurs, or animation is instant
  - No errors in console output

- [ ] **Verify no visual artifacts**
  - [ ] Tile does not flicker or disappear
  - [ ] Tile does not move unexpectedly
  - [ ] Tile remains locked after play completes
  - [ ] Score is calculated correctly

- [ ] **Check console for errors**
  - Open Godot console (View → Toggle Bottom Panel → Output)
  - Should NOT see errors related to drop, animation, or cell binding

**Result**: ✓ PASS / ✗ FAIL  
**Notes**: 

---

## T030: Stability Test (5+ Consecutive Runs)

**Scenario**: Run multiple complete games back-to-back  
**Expected Outcome**: Boss pool resets each run; Gravity appears every Round 3; drops work consistently

### Test Steps

**Run 1**:
- [ ] Start new run from title screen
- [ ] Proceed to Round 3
  - [ ] Verify background is purple
  - [ ] Verify round indicator shows "Gravity"
- [ ] Place tiles, press Play
  - [ ] Drop animation executes
  - [ ] Tiles land correctly
  - [ ] No tiles are lost or disappeared
- [ ] Complete round (win or lose)
- [ ] Proceed to Round 6 if possible, or let run end
  - [ ] If Round 6 is reached, verify no boss appears (normal round)
  - [ ] If pool exhausted after Round 3, verify run ends with victory screen

**Run 2**:
- [ ] Start new run from title screen
- [ ] Repeat Round 3 verification (same steps as Run 1)
- [ ] Repeat drop animation and scoring verification

**Run 3, 4, 5+**:
- [ ] Repeat pattern for each additional run
- [ ] Keep notes on any inconsistencies

**After 5 runs**:
- [ ] **Verify consistency**:
  - [ ] Gravity appeared exactly once per run (Round 3)
  - [ ] Drop animation worked consistently across all runs
  - [ ] No animation glitches (jittering, skipping frames)
  - [ ] No tiles were lost or disappeared
  - [ ] No memory leaks (performance remained stable)
  - [ ] No console errors

**Result**: ✓ PASS / ✗ FAIL  
**Notes**: 

---

## T031: Play Button Blocking During Animation

**Scenario**: Rapidly click Play button during Gravity drop animation  
**Expected Outcome**: Button is disabled; no double-submit; no state corruption

### Test Steps

- [ ] **Setup**: Round 3 (Gravity boss active)

- [ ] **Place tiles and prepare for Play**
  - Place 3-4 tiles in different columns
  - Cursor hovering over Play button

- [ ] **Press Play, then immediately mash the Play button**
  - Press Play once to start animation
  - Rapidly click Play button 5-10 times while drop animation is in progress
  - Animation duration is ~0.5s per tile, so you have time to click

- [ ] **Verify button is disabled during animation**
  - [ ] Play button should appear greyed out / disabled
  - [ ] Button should not respond to clicks
  - [ ] No second play is submitted
  - [ ] No console errors about "play already in progress"

- [ ] **Verify state is consistent after animation**
  - [ ] Drop animation completes cleanly
  - [ ] Tiles are in correct final positions
  - [ ] Play button re-enables after animation
  - [ ] Can press Play again for next play

- [ ] **Check for state corruption**
  - [ ] Round still has expected plays remaining
  - [ ] Score is correct (only one play counted)
  - [ ] Hand count is correct
  - [ ] Board state is consistent

**Result**: ✓ PASS / ✗ FAIL  
**Notes**: 

---

## T032: End-to-End Quickstart Scenarios

**Scenario**: Run quickstart.md validation scenarios  
**Expected Outcome**: All documented flows work as described

### Prerequisite: Read quickstart.md

Review `/specs/005-boss-entities/quickstart.md` for the documented scenarios.

### Test Steps

**Scenario 1: Basic Boss Selection** (if quickstart.md describes it)
- [ ] Follow documented steps
- [ ] Verify expected outcome matches specification
- [ ] Note any deviations: ________________

**Scenario 2: Gravity Drop Animation** (if documented)
- [ ] Follow documented steps
- [ ] Verify expected outcome matches specification
- [ ] Note any deviations: ________________

**Scenario 3: Pool Exhaustion & Run End** (if documented)
- [ ] Follow documented steps
- [ ] Verify expected outcome matches specification
- [ ] Note any deviations: ________________

**Additional Scenarios** (as documented in quickstart.md):
- [ ] Scenario: ________________
- [ ] Scenario: ________________

**Verify all flows**:
- [ ] All documented scenarios executed successfully
- [ ] All expected outcomes match actual behavior
- [ ] No console errors encountered
- [ ] No visual glitches or artifacts

**Result**: ✓ PASS / ✗ FAIL  
**Notes**: 

---

## Summary Results

| Task | Result | Notes |
|------|--------|-------|
| T027 - Multi-Column Drop | ✓ / ✗ | |
| T028 - Stacking | ✓ / ✗ | |
| T029 - Bottom Row | ✓ / ✗ | |
| T030 - Stability (5 runs) | ✓ / ✗ | |
| T031 - Button Blocking | ✓ / ✗ | |
| T032 - Quickstart Scenarios | ✓ / ✗ | |

---

## Overall Assessment

**Phase 6 Status**: ✓ COMPLETE / ✗ INCOMPLETE

**Critical Issues Found**:
- [ ] None
- [ ] Issue 1: ________________
- [ ] Issue 2: ________________

**Minor Issues / Notes**:
1. ________________
2. ________________
3. ________________

**Tester Sign-Off**: ________________  
**Date**: ________________  
**Time Spent**: ________________

---

## How to Report Issues

If you find a failing test:
1. Note the exact steps to reproduce
2. Describe expected vs. actual behavior
3. Screenshot or video (if possible)
4. Check console for errors (View → Toggle Bottom Panel → Output)
5. File as issue on branch with tag `[T0XX]` (e.g., `[T027]`)

---

## Regression Testing Checklist

After fixing any issues, verify these didn't break:

- [ ] Title screen still loads
- [ ] Can start a new run
- [ ] Rounds progress normally (Round 1, 2, 3, ...)
- [ ] Normal rounds have correct background color (light blue)
- [ ] Boss rounds have boss-specific color
- [ ] Boss name appears in round indicator
- [ ] Non-boss tiles place normally (no unwanted drops)
- [ ] Discard pile still works
- [ ] Hand refill works
- [ ] Pause menu works
- [ ] Game over / victory screens appear

---
