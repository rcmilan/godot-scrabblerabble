# Keyboard Controls Fix — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix three root causes that prevent keyboard input from working in gameplay tile selection and the run builder popup.

**Architecture:** Three isolated file changes — trim the ModalInputGuard default blocked list, add Enter to the `confirm_action` InputMap binding, and switch FocusCursor from `_unhandled_input` to `_input` while cleaning up the debug code.

**Tech Stack:** Godot 4.5, GDScript. No test framework — manual verification in the Godot editor.

**Design doc:** `docs/plans/2026-02-23-keyboard-controls-fix-design.md`

---

## Task 1: Fix ModalInputGuard default blocked list

**File:**
- Modify: `scripts/input/modal_input_guard.gd:13-20`

**Context:**
The guard's default `_blocked_actions` currently includes `KeyAction.CONFIRM`, `&"ui_up"`, `&"ui_down"`, `&"ui_left"`, `&"ui_right"`. These two categories are wrong:

- `ui_up/down/left/right`: RunSetupPopup translates WASD → synthetic `InputEventAction("ui_up/...")` then reinjects them. When the synthetic events re-enter `_input()`, the guard immediately blocks them — focus never moves.
- `confirm_action` (Space): prevents Space from reaching the focused Control as `ui_accept`, so Space can't press buttons or check checkboxes in any modal.

**Step 1: Edit the file**

Open `scripts/input/modal_input_guard.gd`. Replace lines 13–20:

```gdscript
# BEFORE
var _blocked_actions: Array[StringName] = [
	KeyAction.NAVIGATE_LEFT,
	KeyAction.NAVIGATE_RIGHT,
	KeyAction.NAVIGATE_UP,
	KeyAction.NAVIGATE_DOWN,
	KeyAction.CONFIRM,
	&"ui_up", &"ui_down", &"ui_left", &"ui_right",
]
```

```gdscript
# AFTER
var _blocked_actions: Array[StringName] = [
	KeyAction.NAVIGATE_LEFT,
	KeyAction.NAVIGATE_RIGHT,
	KeyAction.NAVIGATE_UP,
	KeyAction.NAVIGATE_DOWN,
]
```

**Step 2: Manual test — RunSetupPopup navigation**

Run the game. On the title screen, press New Game to open RunSetupPopup.

- Press W/S or Up/Down → focus should move between the Start button, Back button, deck selector, and quality checkboxes
- Press Space or Enter → focused control should activate (checkbox toggles, button triggers)
- Press Escape → popup closes

Expected: all three work. If WASD does nothing, check that `_start_button.grab_focus()` is being called in `show_popup()` (line 92 of `run_setup_popup.gd`) — focus needs a starting point.

**Step 3: Commit**

```bash
git add scripts/input/modal_input_guard.gd
git commit -m "fix: remove confirm_action and ui_* from ModalInputGuard default blocked list"
```

---

## Task 2: Add Enter key to `confirm_action` InputMap

**File:**
- Modify: `project.godot` (via Godot editor — do NOT hand-edit this file)

**Context:**
`confirm_action` currently binds Space and Joypad Button A. Enter is absent. From the logs, Enter events reach FocusCursor but are never matched. After Fix 1, both Enter and Space will trigger `_confirm()` in FocusCursor — but only once Enter is bound.

**Step 1: Open Project Settings**

In the Godot editor: Project → Project Settings → Input Map tab.

**Step 2: Find `confirm_action`**

Scroll to `confirm_action`. It should show two existing events: Space key and Joypad Button 0.

**Step 3: Add Enter**

Click the `+` button next to `confirm_action`. In the "Add Input" dialog:
- Select "Key"
- Press Enter on your keyboard
- Click OK

The action should now show three events: Space, Enter, and Joypad Button 0.

**Step 4: Save**

Click "Close". Godot auto-saves `project.godot`.

**Step 5: Manual test**

Run the game and start a round. With the cursor on a hand tile, press Enter. It should behave identically to Space (tile selected). This test only confirms Enter is bound — tile selection may still not work until Task 3 is complete.

**Step 6: Commit**

```bash
git add project.godot
git commit -m "fix: bind Enter key to confirm_action InputMap"
```

---

## Task 3: Fix FocusCursor — switch to `_input`, clean up debug code

**File:**
- Modify: `scenes/ui/focus_cursor/focus_cursor.gd`

**Context:**
FocusCursor uses `_unhandled_input`. Godot's built-in UI system (Buttons, CheckBoxes) consumes Space/Enter press events as `ui_accept` before they reach `_unhandled_input`. FocusCursor only sees release events. `is_action_pressed()` correctly returns `false` on release events — so confirm never fires.

Fix: use `_input` instead. FocusCursor runs before the UI system and can consume events via `set_input_as_handled()`.

There is also a broken `elif` chain from a debug block: `CANCEL` and `SWITCH_ZONE` are accidentally chained to a debug `if` rather than the main `if/elif`. Removing the debug block restores correct structure.

**Step 1: Replace `_ready()` line 50**

```gdscript
# BEFORE
set_process_unhandled_input(false)

# AFTER
set_process_input(false)
```

**Step 2: Replace `activate()` line 64**

```gdscript
# BEFORE
set_process_unhandled_input(true)
_update_hand_tile_highlight()
print("[FocusCursor] Activated - hand has %d tiles" % (_hand.get_tile_count() if _hand else 0))

# AFTER
set_process_input(true)
_update_hand_tile_highlight()
```

**Step 3: Replace `deactivate()` line 75**

```gdscript
# BEFORE
set_process_unhandled_input(false)
print("[FocusCursor] Deactivated")

# AFTER
set_process_input(false)
```

**Step 4: Replace entire `_unhandled_input` function (lines 185–224)**

Remove the function completely and replace with:

```gdscript
func _input(event: InputEvent) -> void:
	if not _is_active:
		return
	if event.is_action_pressed(KeyAction.NAVIGATE_LEFT):
		_navigate(Vector2i.LEFT)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(KeyAction.NAVIGATE_RIGHT):
		_navigate(Vector2i.RIGHT)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(KeyAction.NAVIGATE_UP):
		_navigate(Vector2i.UP)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(KeyAction.NAVIGATE_DOWN):
		_navigate(Vector2i.DOWN)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(KeyAction.CONFIRM):
		_confirm()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(KeyAction.CANCEL):
		_cancel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(KeyAction.SWITCH_ZONE):
		if _state.position.is_hand():
			_switch_to_board_zone()
		else:
			_switch_to_hand_zone()
		get_viewport().set_input_as_handled()
```

**Step 5: Clean up `_confirm()` (line 290–292)**

```gdscript
# BEFORE
func _confirm() -> void:
	print("[FocusCursor] Confirm at position: Hand=%s Index=%d" % [_state.position.is_hand(), _state.position.hand_index if _state.position.is_hand() else -1])
	cursor_confirmed.emit(_state.position)

# AFTER
func _confirm() -> void:
	cursor_confirmed.emit(_state.position)
```

**Step 6: Manual test — tile selection**

Run the game and start a round.

- Press D/A → cursor highlight should move right/left through hand tiles
- Press Space on a highlighted hand tile → tile should be selected (faded to 50% alpha, ghost label on board)
- Press W → cursor should switch to board zone (cursor rect appears on board)
- Press arrow keys → cursor rect should move through board cells
- Press Space on a board cell → selected tile should be placed there
- Press Escape → tile should return to hand, cursor returns to hand zone
- Press Enter at any point → should behave identically to Space

**Step 7: Commit**

```bash
git add scenes/ui/focus_cursor/focus_cursor.gd
git commit -m "fix: switch FocusCursor to _input, restore elif chain, remove debug prints"
```

---

## Task 4: Remove debug prints from GameplayController

**File:**
- Modify: `scripts/controllers/gameplay_controller.gd`

**Context:**
Two debug `print()` statements were added to `_on_cursor_confirmed()` as part of the same debug pass. Clean them up now that the fix is verified.

**Step 1: Find and remove the prints**

Open `scripts/controllers/gameplay_controller.gd`. Search for `[FocusCursor]` or `[GameplayController]` debug prints added in the cursor confirmation handlers. Remove any `print(...)` lines inside `_on_cursor_confirmed()` that were added for debugging.

**Step 2: Manual test**

Run the game. Confirm the full keyboard flow works end-to-end with no debug output in the Godot console:
- RunSetupPopup: WASD navigates, Space/Enter activates, Escape closes
- Gameplay: cursor moves through hand, Space selects tile, W switches to board, arrows navigate board, Space places tile, Escape returns tile

**Step 3: Commit**

```bash
git add scripts/controllers/gameplay_controller.gd
git commit -m "fix: remove cursor debug prints from gameplay_controller"
```

---

## Verification Checklist

After all four tasks:

- [ ] RunSetupPopup: W/S moves focus between controls
- [ ] RunSetupPopup: Space and Enter both activate focused control
- [ ] RunSetupPopup: Escape closes popup
- [ ] Gameplay: D/A moves cursor through hand tiles
- [ ] Gameplay: Space selects tile from hand
- [ ] Gameplay: W switches to board zone
- [ ] Gameplay: Arrow keys navigate board cells
- [ ] Gameplay: Space places selected tile on board cell
- [ ] Gameplay: Escape returns tile to hand
- [ ] Gameplay: Enter behaves identically to Space at every step
- [ ] No debug prints in Godot console during normal play
