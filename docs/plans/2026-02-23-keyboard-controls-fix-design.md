# Keyboard Controls Fix — Design

**Date:** 2026-02-23
**Branch:** keyboard
**Scope:** Bug fixes only — no structural changes

---

## Problem Summary

Five related issues with keyboard input:

1. Run builder (RunSetupPopup) does not respond to WASD or arrow keys
2. Space does not select tiles from hand during gameplay
3. Inconsistent keyboard behavior between game and UI
4. Enter and Space should behave identically
5. No centralized pattern (deferred — out of scope for this fix)

---

## Root Cause Analysis

### Bug A — FocusCursor receives only key-release events

`FocusCursor` uses `_unhandled_input`. Godot's UI system consumes Space press events as `ui_accept` (because some Control has focus during gameplay), so only the release event reaches `_unhandled_input`. `is_action_pressed()` correctly returns `false` on release events — appearing as if Space is unbound, when in fact it is correctly bound but never seen as a press.

**Evidence from log:**
```
event: Space (keycode=32, pressed=false)
Space pressed - is confirm_action: false
```

### Bug B — ModalInputGuard blocks synthetic `ui_*` events

`RunSetupPopup._input()` translates `navigate_*` (WASD) into synthetic `InputEventAction("ui_up/down/left/right")` and reinjects them via `Input.parse_input_event()`. These synthetic events re-enter `_input()` on all nodes, including `RunSetupPopup`. The `ModalInputGuard` default blocked list includes `ui_up`, `ui_down`, `ui_left`, `ui_right` — so the guard consumes them before Godot's focus system can move focus.

### Bug C — ModalInputGuard blocks `confirm_action` (Space) in modals

The guard's default blocked list also includes `confirm_action`. Since Space is bound to `confirm_action`, pressing Space in any modal is consumed by the guard before the focused Control receives it as `ui_accept`. This prevents Space from activating buttons and checkboxes in RunSetupPopup, OptionsPopup, and DiscardConfirmationDialog.

### Bug D — Enter not bound to `confirm_action`

The `confirm_action` InputMap entry only has Space and Joypad Button A. Enter is absent, so FocusCursor never treats Enter as a confirm.

### Secondary issue — broken `elif` chain in FocusCursor

A debug `if event is InputEventKey and event.keycode == KEY_SPACE:` block was inserted after the `CONFIRM` branch, accidentally detaching `CANCEL` and `SWITCH_ZONE` from the main `if/elif` chain. They ended up as `elif` branches of the debug check instead. Functionally harmless in practice (Space isn't mapped to cancel/switch) but structurally wrong and confusing.

---

## Design: Three Targeted Fixes

### Fix 1 — `focus_cursor.gd`: switch to `_input`

**Why:** `_input` fires before Godot's UI routing. FocusCursor sees press events first and can consume them before any Control receives `ui_accept`.

**Changes:**
- Rename `_unhandled_input` to `_input`
- Replace `set_process_unhandled_input(true/false)` with `set_process_input(true/false)` in `activate()` / `deactivate()`
- Remove all debug `print()` statements
- Restore `CANCEL` and `SWITCH_ZONE` branches into the main `if/elif` chain (remove the stray debug `if/elif` block)

### Fix 2 — `project.godot`: add Enter to `confirm_action`

**Why:** Space and Enter should be identical. Enter keycode = `KEY_ENTER` (4194309).

**Change:** Add `InputEventKey(keycode=KEY_ENTER)` to the `confirm_action` action in the InputMap.

### Fix 3 — `modal_input_guard.gd`: trim default blocked list

**Why:** `confirm_action` and `ui_*` should not be blocked by default.

- `confirm_action` must be allowed through so Space/Enter can activate focused Controls via `ui_accept`
- `ui_up/down/left/right` must be allowed through so Godot's focus traversal works (and so RunSetupPopup's synthetic events reach the focus system)

**New default blocked list:**
```gdscript
var _blocked_actions: Array[StringName] = [
    KeyAction.NAVIGATE_LEFT,
    KeyAction.NAVIGATE_RIGHT,
    KeyAction.NAVIGATE_UP,
    KeyAction.NAVIGATE_DOWN,
]
```

`navigate_*` stays: in RunSetupPopup, WASD is translated before the guard and consumed early, so `navigate_*` never reaches the guard there. In simpler modals (Options, DiscardConfirm) without WASD translation, blocking WASD/arrows is correct — those keys shouldn't do anything.

---

## Files Changed

| File | Change |
|------|--------|
| `scenes/ui/focus_cursor/focus_cursor.gd` | `_unhandled_input` → `_input`, fix elif chain, remove debug prints |
| `project.godot` | Add Enter to `confirm_action` InputMap |
| `scripts/input/modal_input_guard.gd` | Remove `confirm_action` + `ui_*` from default blocked list |

---

## Not In Scope

- Centralized input routing pattern
- Refactoring modal input handling architecture
- Gamepad navigation improvements beyond existing bindings
