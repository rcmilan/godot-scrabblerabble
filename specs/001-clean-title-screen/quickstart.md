# Quickstart: Manual Test Guide

**Feature**: Clean and Enhance Title Screen  
**Branch**: `001-clean-title-screen` | **Date**: 2026-04-03

## Prerequisites

- Godot 4.6 installed
- Project opened in Godot Editor
- Branch `001-clean-title-screen` checked out

## Verification Steps

### 1. Title Screen - Options Button Removed

1. Press **F5** to run the game
2. Observe the title screen
3. **Verify**: Only "New Game" and "Exit" buttons are visible; no "Options" button

### 2. New Game Opens Run Setup Modal

1. On the title screen, click **New Game**
2. **Verify**: Run Setup modal appears with Deck selector and "Select Qualities" section
3. **Verify**: Only "Auto Win (10 Plays)" appears in the qualities list; no other qualities visible

### 3. Keyboard Navigation - Title Screen

1. On the title screen, press **Down Arrow** or **S**
2. **Verify**: Focus moves to next button (visual highlight changes)
3. Press **Up Arrow** or **W**
4. **Verify**: Focus moves to previous button; wraps at top/bottom
5. With "New Game" focused, press **Enter** or **Space**
6. **Verify**: Run Setup modal opens

### 4. Keyboard Navigation - Run Setup Modal

1. With Run Setup modal open, press **Up/Down Arrow** or **W/S**
2. **Verify**: Focus moves between Deck selector, Auto Win checkbox, Start Run, and Back buttons
3. Navigate to the Auto Win checkbox and press **Enter** or **Space**
4. **Verify**: Checkbox toggles on/off
5. Navigate to **Back** button and press **Enter**
6. **Verify**: Modal closes, returns to title screen with New Game focused

### 5. ESC Closes Modal

1. Open Run Setup modal (click or keyboard)
2. Press **ESC**
3. **Verify**: Modal closes, returns to title screen

### 6. Full Keyboard Run

1. Press **F5** to run the game
2. Without touching the mouse:
   - Press **Down Arrow** to reach "New Game" or just press **Enter** (first item focused)
   - Press **Enter** to open Run Setup
   - Press **Down Arrow** to navigate to Auto Win checkbox
   - Press **Enter** to enable Auto Win
   - Press **Down Arrow** twice to reach "Start Run"
   - Press **Enter** to start the game
3. **Verify**: Game transitions to gameplay scene

### 7. No Orphaned References

1. In Godot Editor, open `scenes/title_screen/title_screen.tscn`
2. **Verify**: No `OptionsButton` or `OptionsPopup` nodes in the scene tree
3. Open `scripts/controllers/menu_controller.gd`
4. **Verify**: No `_options_button` variable or `options_requested` signal

## Pass Criteria

All 7 verification steps complete without errors or missing nodes in the Godot editor output.
