# Research: Win95 UI Overhaul - Title Screen

**Branch**: `009-win95-title-screen` | **Date**: 2026-05-01

## Decision 1: Asset Destination Path

**Decision**: Copy all godot-design-95 assets to `theme/` at the project root (i.e., `res://theme/`).

**Rationale**: The `webcore_theme.tres` file internally references all textures and sub-resources using `res://theme/...` paths. Copying to any other location would require manually remapping every path in the .tres file. Keeping the same directory name eliminates all path surgery.

**Alternatives considered**: `assets/theme/win95/` (suggested in spec) - rejected because it requires rewriting all internal .tres resource paths.

---

## Decision 2: Nearest-Neighbor Texture Filtering

**Decision**: Add `rendering/textures/canvas_textures/default_texture_filter=0` to the `[rendering]` section of `project.godot`.

**Rationale**: Value `0` = Nearest in Godot 4. This is the global setting that applies nearest-neighbor filtering to all 2D canvas textures, which is what the 9-slice PNGs use. No per-viewport or per-node changes needed.

**Alternatives considered**: Per-node `texture_filter` overrides - rejected because it requires setting on every texture-bearing node and would need to be repeated for every new Win95 component added.

---

## Decision 3: Project Theme Registration

**Decision**: Set `gui/theme/custom="res://theme/webcore_theme.tres"` in the `[application]` section of `project.godot`, in addition to registering `ThemeSetup.gd` as an autoload.

**Rationale**: `ThemeSetup.gd` calls `ThemeDB.get_project_theme()` at `_ready()`. For this to return the Win95 theme, the theme must be set as the project custom theme in project settings. Without this setting, `get_project_theme()` returns null and the autoload is a no-op.

**Alternatives considered**: Assigning the theme at runtime via code - rejected because it requires modifying every scene root and is fragile.

---

## Decision 4: ThemeSetup Autoload Order

**Decision**: Register `ThemeSetup` as the last entry in `[autoload]` in `project.godot`.

**Rationale**: ThemeSetup reads the project theme and registers type variations. It only needs to run before scenes load their theme caches, which happens after all autoloads are initialized. Order relative to game-logic autoloads (EventBus, GameManager, etc.) does not matter.

**Alternatives considered**: First autoload position - unnecessary and could conflict with other autoloads that might reference UI nodes.

---

## Decision 5: Import Files for Copied PNGs

**Decision**: Do NOT copy `.import` files from the reference repo. Let Godot regenerate them on first project open after asset copy.

**Rationale**: Godot 4 `.import` files contain machine-specific UIDs and absolute paths. Copying them causes import errors. Godot will regenerate correct `.import` files automatically when the project is opened after assets are placed.

**Alternatives considered**: Copying .import files - rejected because they embed repo-specific UIDs that conflict with the target project.

---

## Decision 6: BackgroundManager Default Color

**Decision**: Change the default/initial background color in `autoload/background_manager.gd` from the current dark color (approximately `Color(0.15, 0.15, 0.2)`) to `Color("#008080")` (Win95 teal).

**Rationale**: Per clarification, all BackgroundManager animation behavior is preserved; only the starting color changes. The change is isolated to one property in the autoload script.

**Alternatives considered**: Changing color in title_screen.tscn Background ColorRect - rejected because BackgroundManager owns the background state; changing it at the source is correct.

---

## Decision 7: Win95 Components Used Per Screen

**Title Screen (title_screen.tscn)**:
- Root container: `Panel` with `theme_type_variation = "WindowPanel"` (gray raised border)
- Title bar: `Panel` with `theme_type_variation = "TitleBarActive"` + `Label` with `theme_type_variation = "TitleBarLabel"`
- Buttons: `Button` nodes (inherit Win95 button style from project theme automatically)
- Background: `ColorRect` with color `#008080` (managed by BackgroundManager)

**Run Builder (run_setup_popup.tscn)**:
- Same WindowPanel + TitleBarActive structure as title screen
- `CheckBox` nodes with `theme_type_variation = "Win95Checkbox"`
- `OptionButton` inherits Win95 button style (no dedicated OptionButton variation in reference repo; standard Button fallback per spec)
- Labels inherit default Win95 Label style; section headers can use `theme_type_variation = "SectionLabel"`

---

## Reference Repo File Manifest (files to copy)

From `godot-design-95`, copy these files preserving their directory structure under `theme/`:

```
theme/ThemeSetup.gd
theme/webcore_theme.tres
theme/button/button_normal.png
theme/button/button_pressed.png
theme/button/button_normal_texture.tres
theme/button/button_pressed_texture.tres
theme/button/button_titlebar_normal_texture.tres
theme/button/button_titlebar_pressed_texture.tres
theme/checkbox/checkbox_checked.png
theme/checkbox/checkbox_unchecked.png
theme/fonts/W95FA_section.tres
theme/fonts/W95FA_spaced.tres
theme/lineedit/lineedit_bg.png
theme/lineedit/lineedit_style.tres
theme/menubar/menubar_bg.png
theme/menubar/menubar_style.tres
theme/panel/panel_bg.png
theme/panel/panel_style.tres
theme/radiobutton/radio_checked.png
theme/radiobutton/radio_unchecked.png
theme/titlebar/titlebar_active.png
theme/titlebar/titlebar_inactive.png
theme/titlebar/titlebar_style_active.tres
theme/titlebar/titlebar_style_inactive.tres
theme/window/window_bg.png
theme/window/window_style.tres
```

Also copy the font to project root:
```
fonts/W95FA.otf
```
