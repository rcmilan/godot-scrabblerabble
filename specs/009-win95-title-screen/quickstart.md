# Quickstart: Win95 UI Overhaul - Title Screen

**Branch**: `009-win95-title-screen` | **Date**: 2026-05-01

## Prerequisites

- Godot 4.6 installed
- Project open in Godot Editor on branch `009-win95-title-screen`
- Internet access to download assets from https://github.com/rcmilan/godot-design-95

## Step 1: Download Win95 Assets

Download or clone the reference repository. Copy the following directories into the Wordatro project root (preserving structure):

```
godot-design-95/theme/   ->  <project_root>/theme/
godot-design-95/fonts/   ->  <project_root>/fonts/
```

Do NOT copy `.import` files. Godot will regenerate them automatically.

## Step 2: Configure project.godot

Add/modify these settings:

**Under `[application]`**:
```ini
config/custom_theme="res://theme/webcore_theme.tres"
```

**Under `[autoload]`** (add after existing autoloads):
```ini
ThemeSetup="*res://theme/ThemeSetup.gd"
```

**Under `[rendering]`** (add if not present):
```ini
textures/canvas_textures/default_texture_filter=0
```

## Step 3: Reimport Assets

Open the Godot Editor. The editor will detect new files and reimport them. Check the Output panel for any import errors before proceeding.

## Step 4: Verify Theme is Active

1. Open any scene (e.g., `scenes/title_screen/title_screen.tscn`)
2. Add a temporary `Button` node
3. Confirm it renders with Win95 raised-border style without any manual overrides
4. Delete the test button

## Step 5: Redesign title_screen.tscn

See `data-model.md` for the target scene structure. Key changes:
- Replace the current flat `VBoxContainer` layout with a `Panel (WindowPanel)` + `Panel (TitleBarActive)` + content area
- Remove all `theme_override_*` properties from Button and Label nodes
- Set Background `ColorRect` color to `#008080` (BackgroundManager will animate from this base)

## Step 6: Redesign run_setup_popup.tscn

Same WindowPanel structure as title screen. Key changes:
- Wrap existing content inside `Panel (WindowPanel)`
- Add `Panel (TitleBarActive)` with label "RUN SETUP"
- Replace dynamically-created `CheckBox` nodes in script with `Win95Checkbox` variation (set `theme_type_variation` after instantiation)
- Remove all inline theme overrides

## Step 7: Manual Verification

Launch the game (F5) and verify:
- [ ] Title screen background is teal (#008080) on load
- [ ] Win95 window panel and title bar visible on menu
- [ ] "New Game" and "Exit" buttons have Win95 raised-border style
- [ ] W/S/Enter keyboard navigation works
- [ ] "New Game" reveals Run Builder with Win95 styling
- [ ] Deck selection and quality toggles function correctly
- [ ] "Start" launches gameplay without errors
- [ ] "Exit" quits the game
- [ ] No import errors in Output panel
