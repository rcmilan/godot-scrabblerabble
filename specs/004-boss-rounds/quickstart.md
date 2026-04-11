# Quickstart: Testing Boss Rounds

**Branch**: `004-boss-rounds` | **Date**: 2026-04-06

## How to Manually Test This Feature

Open the project in Godot 4.6 Editor and press F5 to run.

### Test 1: Round Label and Background on Normal Round

1. Start a new game (any deck/difficulty).
2. Observe the **top-left** of the gameplay screen: label should read **"Round 1"**.
3. Observe the gameplay background: should be **white** (or near-white).
4. Complete Round 1 (exhaust Plays or meet target score).
5. Proceed through the Shop.
6. Observe: label reads **"Round 2"**, background is still **white**.

### Test 2: Boss Round Visual on Round 3

1. Continue from Test 1 through Round 2.
2. Proceed through the Shop after Round 2.
3. Round 3 begins.
4. Observe: HUD label reads **"Boss Round"** (not "Round 3").
5. Observe: gameplay background changes to **light red**.

### Test 3: Return to Normal After Boss Round

1. Continue from Test 2 through Round 3.
2. Proceed through the Shop after Round 3.
3. Round 4 begins.
4. Observe: HUD label reads **"Round 4"**.
5. Observe: background returns to **white**.

### Test 4: New Game Resets Round Counter

1. Finish or abandon a run that reached Round 3 or later.
2. Return to the Title Screen.
3. Start a new game.
4. Observe: HUD label reads **"Round 1"**.
5. Observe: background is **white**.

### Test 5: MULTI [Q] Indicator Removed

1. Start any game.
2. Confirm: no "MULTI [Q]" or "Multi [Q]" text appears anywhere on the gameplay screen.
3. Press Q to toggle multi-select mode.
4. Confirm: multi-select still works (tiles are selectable in multi mode) even though the indicator is gone.

### Test 6: AutoWin Modifier Text

1. From the Title Screen, select the **Auto Win** run modifier.
2. Read its description.
3. Confirm: the description uses **"Plays"** and **"Rounds"** (capital P, capital R).
4. Confirm: no legacy terms ("turn", "move", "multi") appear in the text.

## Fast Path (AutoWin to Boss Round)

Select the **Auto Win** modifier at the Title Screen. It gives 10 Plays per Round. Complete all 10 Plays quickly to win Round 1, proceed through Shop, win Round 2, and you will reach Round 3 (Boss Round) within a few minutes.
