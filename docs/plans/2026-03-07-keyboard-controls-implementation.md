# Keyboard Controls Update Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Update keyboard bindings (P→Enter for Play) and remove unused Draw action from hint bar display.

**Architecture:** Modify two files: project.godot (input config) and keyboard_hint_bar.gd (UI display). Changes are isolated and don't affect game logic.

**Tech Stack:** Godot 4.x InputMap, GDScript

---

## Task 1: Update PLAY_HAND Input Action in project.godot

**Files:**
- Modify: `project.godot` (InputMap section)

**Step 1: Locate PLAY_HAND action in project.godot**

Run:
```bash
grep -n "play_hand=" project.godot
```

Expected: Shows line number where `play_hand={` begins

**Step 2: Remove P key binding**

In `project.godot`, find the PLAY_HAND section (looks like):
```
play_hand={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,...,"keycode":80,...)]
}
```

Replace the entire section with:
```
play_hand={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194309,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

**Key change:**
- `keycode":80` (P) → `keycode":4194309` (Enter)
- Remove any duplicate key bindings for P

**Step 3: Verify the change**

Run:
```bash
grep -A 3 "play_hand=" project.godot
```

Expected: Shows updated section with keycode 4194309 (Enter key)

**Step 4: Commit**

```bash
git add project.godot
git commit -m "feat: change Play action from P to Enter"
```

---

## Task 2: Update Keyboard Hint Bar - Remove DRAW_TILES

**Files:**
- Modify: `scenes/ui/keyboard_hint_bar/keyboard_hint_bar.gd:8-15`

**Step 1: Read current HINTS array**

File: `scenes/ui/keyboard_hint_bar/keyboard_hint_bar.gd`, lines 8-15

Current (to be replaced):
```gdscript
var HINTS: Array[Dictionary] = [
	{ action = KeyAction.PLAY_HAND,     label = "Play"     },
	{ action = KeyAction.DRAW_TILES,    label = "Draw"     },
	{ action = KeyAction.DISCARD_TILES, label = "Discard"  },
	{ action = KeyAction.TOGGLE_MULTI,  label = "Multi"    },
	{ action = KeyAction.SWITCH_ZONE,   label = "Orient" },
	{ action = KeyAction.PAUSE_GAME,    label = "Pause"    },
]
```

**Step 2: Update HINTS array to remove DRAW_TILES**

Replace with:
```gdscript
var HINTS: Array[Dictionary] = [
	{ action = KeyAction.PLAY_HAND,     label = "Play"    },
	{ action = KeyAction.DISCARD_TILES, label = "Discard" },
	{ action = KeyAction.TOGGLE_MULTI,  label = "Multi"   },
	{ action = KeyAction.SWITCH_ZONE,   label = "Orient"  },
	{ action = KeyAction.PAUSE_GAME,    label = "Pause"   },
]
```

**Changes:**
- Remove line: `{ action = KeyAction.DRAW_TILES, label = "Draw" },`
- Normalize spacing in remaining entries

**Step 3: Verify the file**

Run:
```bash
sed -n '8,15p' scenes/ui/keyboard_hint_bar/keyboard_hint_bar.gd
```

Expected: Shows 5 hint entries (no DRAW_TILES)

**Step 4: Commit**

```bash
git add scenes/ui/keyboard_hint_bar/keyboard_hint_bar.gd
git commit -m "fix: remove unused Draw action from hint bar"
```

---

## Task 3: Manual Testing (Keyboard Input)

**Prerequisites:** Tasks 1 & 2 complete

**Test Environment:** Run game in editor

**Step 1: Start the game**

- Open scene: `scenes/Main.tscn`
- Run in editor (F5 or play button)
- Wait for board and hand to load

**Step 2: Verify hint bar displays correctly**

Expected display:
```
[Enter] Play  ·  [Z] Discard  ·  [Q] Multi  ·  [Tab] Orient  ·  [Esc] Pause
```

Verify:
- [ ] No "Draw" action shown
- [ ] "Play" shows "[Enter]" (not "[P]")
- [ ] All 5 actions display
- [ ] Separators (·) between actions

**Step 3: Test Enter key triggers Play**

- Place some tiles on board
- Press Enter
- Verify: Word is validated and scored (or error shows if invalid)

Expected: Play executes (not P key anymore)

**Step 4: Test that P key does NOT trigger Play**

- Place some tiles on board
- Press P
- Verify: Nothing happens (P is no longer bound to Play)

Expected: No action (or console shows P is unhandled input)

**Step 5: Test other controls still work**

- [ ] Z key: Opens discard dialog
- [ ] Q key: Toggles Multi mode
- [ ] Tab key: Toggles orientation (H/V)
- [ ] Esc key: Pauses game

**Step 6: Notes**

If any test fails:
- Check project.godot for correct keycode (4194309 = Enter)
- Check hint bar HINTS array doesn't reference DRAW_TILES
- Check console for input warnings

---

## Task 4: Manual Testing (Joypad Input - Optional)

**Prerequisites:** Joypad connected, Tasks 1 & 2 complete

**Step 1: Connect joypad**

- Plug in controller/joypad
- Wait for "Joypad connected" message

**Step 2: Verify hint bar shows joypad buttons**

Expected: Hint bar updates to show joypad button names instead of keyboard keys
- e.g., `[A] Play  ·  [B] Discard` (depending on joypad mapping)

**Step 3: Test Play action on joypad**

- Note which button is shown for Play in hint bar
- Press that button
- Verify: Play executes

**Step 4: Disconnect joypad**

- Unplug controller
- Verify: Hint bar reverts to keyboard keys

---

## Task 5: Final Verification & Cleanup

**Step 1: Check git status**

Run:
```bash
git status
```

Expected: Only `project.godot` and `scenes/ui/keyboard_hint_bar/keyboard_hint_bar.gd` modified

**Step 2: View final commits**

Run:
```bash
git log --oneline -3
```

Expected: Last 2 commits are:
- `fix: remove unused Draw action from hint bar`
- `feat: change Play action from P to Enter`

**Step 3: Verify no broken references**

Run:
```bash
grep -r "DRAW_TILES" scenes/ui/keyboard_hint_bar/
```

Expected: No matches (DRAW_TILES removed from hint bar)

**Step 4: Verify no stray P bindings in play action**

Run:
```bash
grep -A 5 'play_hand=' project.godot | grep -i keycode
```

Expected: Shows only keycode 4194309 (no keycode 80 / P)

---

## Summary

| Task | Files | Time | Status |
|------|-------|------|--------|
| 1 | `project.godot` | 5m | Modify input binding |
| 2 | `keyboard_hint_bar.gd` | 3m | Remove DRAW_TILES |
| 3 | Manual test (keyboard) | 5m | Verify all controls |
| 4 | Manual test (joypad) | 5m | Optional, if available |
| 5 | Verification | 3m | Final checks |

**Total:** ~15-25 minutes (excluding optional joypad test)

**Success Criteria:**
- ✅ Enter key triggers Play action
- ✅ P key no longer triggers anything
- ✅ Hint bar shows 5 actions (no Draw)
- ✅ Hint bar displays "[Enter]" for Play
- ✅ All tests pass
- ✅ Commits created

