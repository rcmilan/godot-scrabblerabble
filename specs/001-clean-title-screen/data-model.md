# Data Model: Clean and Enhance Title Screen

**Branch**: `001-clean-title-screen` | **Date**: 2026-04-03

## Overview

This feature has no new data entities. It removes an existing UI element (Options), filters an
existing collection (quality list), and refines an existing controller (MenuController).
The data model documents the changed relationships.

---

## Entity Changes

### MenuController (scripts/controllers/menu_controller.gd)

**Before**:
```
MenuController
  - _new_game_button: Button
  - _options_button: Button    <-- REMOVE
  - _exit_button: Button
  - _menu_items: [new_game, options, exit]  <-- update to [new_game, exit]
  signals: new_game_requested, options_requested, exit_requested
  setup(new_game_btn, options_btn, exit_btn)  <-- simplify to 2 params
```

**After**:
```
MenuController
  - _new_game_button: Button
  - _exit_button: Button
  - _menu_items: [new_game, exit]
  signals: new_game_requested, exit_requested
  setup(new_game_btn, exit_btn)
```

---

### TitleScreen (scenes/title_screen/title_screen.gd)

**Before**:
```
TitleScreen
  - _new_game_button: Button
  - _options_button: Button    <-- REMOVE
  - _exit_button: Button
  - _options_popup: OptionsPopup    <-- REMOVE
  - _run_setup_popup: RunSetupPopup
  - _title_label: Label
  - _menu_controller: MenuController
```

**After**:
```
TitleScreen
  - _new_game_button: Button
  - _exit_button: Button
  - _run_setup_popup: RunSetupPopup
  - _title_label: Label
  - _menu_controller: MenuController
```

---

### RunSetupPopup Quality List (scenes/title_screen/run_setup_popup.gd)

**Before**: `_populate_quality_list()` iterates all registered quality ids and creates a checkbox
for each (max_hand_size, time_attack, limited_time_with_increment, max_score_in_n_rounds,
random_modifiers, auto_win).

**After**: `_populate_quality_list()` only creates a checkbox for quality ids in `VISIBLE_QUALITIES`:
```gdscript
const VISIBLE_QUALITIES: Array[StringName] = [&"auto_win"]
```

All other quality ids are skipped silently. `_quality_checkboxes` dictionary will only contain
the `auto_win` entry. `_build_run()` is unchanged and reads from `_quality_checkboxes` correctly.

---

### Scene Tree Changes (title_screen.tscn)

**Nodes removed**:
- `MenuContainer/VBoxContainer/OptionsButton`
- `OptionsPopup` (instance of options_popup.tscn)

**Focus neighbor updates**:
- `NewGameButton.focus_neighbor_bottom` = `"../ExitButton"` (was `"../OptionsButton"`)
- `ExitButton.focus_neighbor_top` = `"../NewGameButton"` (was `"../OptionsButton"`)

**Files deleted**:
- `scenes/title_screen/options_popup.gd`
- `scenes/title_screen/options_popup.gd.uid`
- `scenes/title_screen/options_popup.tscn`
