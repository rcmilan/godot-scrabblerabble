# Keyboard Controls Update Design

**Date:** 2026-03-07
**Branch:** keyboard-orientation
**Status:** Approved

## Overview

Update keyboard hint bar to display only active controls and change the Play action from P to Enter.

## Current State

The hint bar currently displays 6 actions, but analysis revealed:
- **DRAW_TILES (L)** — defined as constant but never handled in gameplay; drawing is automatic after plays
- **PLAY_HAND (P)** — should be changed to Enter for better UX

Active controls during typing/board sessions:
- PLAY_HAND — submit plays
- DISCARD_TILES — discard tiles
- TOGGLE_MULTI — toggle multi-select mode
- SWITCH_ZONE — toggle orientation (repurposed via TAB in focus_cursor)
- PAUSE_GAME — pause gameplay

## Design

### 1. Update Input Bindings

**File:** `project.godot`

Change PLAY_HAND action:
- **Remove:** P (keycode 80)
- **Add:** Enter (keycode 4194309)

Rationale: Enter is a more intuitive "submit" key and aligns with standard UI conventions.

### 2. Update Keyboard Hint Bar

**File:** `scenes/ui/keyboard_hint_bar/keyboard_hint_bar.gd`

Remove DRAW_TILES from HINTS array. Reorder to show 5 active controls:

```gdscript
var HINTS: Array[Dictionary] = [
    { action = KeyAction.PLAY_HAND,     label = "Play"    },
    { action = KeyAction.DISCARD_TILES, label = "Discard" },
    { action = KeyAction.TOGGLE_MULTI,  label = "Multi"   },
    { action = KeyAction.SWITCH_ZONE,   label = "Orient"  },
    { action = KeyAction.PAUSE_GAME,    label = "Pause"   },
]
```

Result: `[Enter] Play  ·  [Z] Discard  ·  [Q] Multi  ·  [Tab] Orient  ·  [Esc] Pause`

## Impact

- **UI Clarity:** Hint bar shows only actionable controls (5 instead of 6)
- **UX Improvement:** Enter is more discoverable than P for submitting plays
- **No Gameplay Changes:** Only keybinding and display changes; no logic modifications

## Testing

- [x] Verify DRAW_TILES is not referenced in gameplay flow
- [ ] Test Play action with Enter key during gameplay
- [ ] Verify hint bar displays correct controls
- [ ] Test on keyboard and joypad input modes

