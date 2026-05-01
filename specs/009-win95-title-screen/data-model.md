# Data Model: Win95 UI Overhaul - Title Screen

**Branch**: `009-win95-title-screen` | **Date**: 2026-05-01

This feature introduces no new domain entities. It is a pure visual layer change. The entities below describe the theme system components and their relationships within the Godot project.

---

## Theme System Entities

### Win95 Theme Resource (`res://theme/webcore_theme.tres`)

The master Godot `Theme` resource. Defines styleboxes, fonts, colors, and icons for all Win95 UI components.

**Owns**:
- StyleBox resources for Button (normal, hover, pressed, focused, disabled)
- StyleBox resources for Panel variations (WindowPanel, TitleBarActive, TitleBarInactive, Win95MenuBar)
- Font resources (W95FA at various sizes via W95FA_section.tres, W95FA_spaced.tres)
- Texture resources for CheckBox (Win95Checkbox checked/unchecked) and RadioButton

**Relationships**:
- Referenced by `project.godot` as the global project theme
- Read by `ThemeSetup.gd` via `ThemeDB.get_project_theme()`
- Inherited by all Control nodes in all scenes at runtime

---

### ThemeSetup Autoload (`res://theme/ThemeSetup.gd`)

A Node autoload singleton. Runs at startup before any scene node resolves its theme cache.

**Responsibility**: Register custom `theme_type_variation` names so that Control nodes can use them.

**Type variations registered**:

| Variation Name    | Base Type | Used On                            |
|-------------------|-----------|------------------------------------|
| WindowPanel       | Panel     | Root container of each screen      |
| TitleBarActive    | Panel     | Active title bar strip             |
| TitleBarInactive  | Panel     | Inactive title bar (unused for now)|
| TitleBarLabel     | Label     | Text inside title bar              |
| TitleBarButton    | Button    | Window chrome buttons (unused)     |
| Win95MenuBar      | Panel     | Menu bar backgrounds               |
| SectionLabel      | Label     | Bold section headers in Run Builder|
| RadioButton       | CheckBox  | Radio button controls              |
| Win95Checkbox     | CheckBox  | Quality toggle checkboxes          |

**Lifecycle**: `_ready()` only. No state, no signals, no per-frame logic.

---

### Win95 Asset Bundle

Static image and font files. No runtime entity; imported by the Godot editor.

**Font**:
- `res://fonts/W95FA.otf` - bitmap font, pixel-perfect at integer scales

**9-Slice Textures** (PNGs, nearest-neighbor filtered):
- `res://theme/button/button_normal.png` + `button_pressed.png`
- `res://theme/titlebar/titlebar_active.png` + `titlebar_inactive.png`
- `res://theme/panel/panel_bg.png`
- `res://theme/window/window_bg.png`
- `res://theme/checkbox/checkbox_checked.png` + `checkbox_unchecked.png`
- `res://theme/lineedit/lineedit_bg.png`
- `res://theme/menubar/menubar_bg.png`
- `res://theme/radiobutton/radio_checked.png` + `radio_unchecked.png`

---

## Scene Structure After Overhaul

### title_screen.tscn (modified)

```
TitleScreen (Control)
  Background (ColorRect)            # color = #008080, managed by BackgroundManager
  MenuView (Control)
    Window (Panel)                  # theme_type_variation = "WindowPanel"
      TitleBar (Panel)              # theme_type_variation = "TitleBarActive"
        TitleBarLabel (Label)       # theme_type_variation = "TitleBarLabel", text = game name
      ContentArea (VBoxContainer)
        NewGameButton (Button)      # inherits Win95 Button style
        ExitButton (Button)         # inherits Win95 Button style
        ControlHint (Label)
  RunSetupView (instance)           # visibility-toggled sibling, unchanged behavior
```

### run_setup_popup.tscn (modified)

```
RunSetupView (Control)              # initially hidden, visibility-toggled
  Window (Panel)                    # theme_type_variation = "WindowPanel"
    TitleBar (Panel)                # theme_type_variation = "TitleBarActive"
      TitleBarLabel (Label)         # theme_type_variation = "TitleBarLabel", text = "RUN SETUP"
    ContentArea (VBoxContainer)
      DeckLabel (Label)             # theme_type_variation = "SectionLabel"
      DeckOption (OptionButton)     # inherits Win95 Button fallback style
      DeckDescription (Label)
      QualitiesLabel (Label)        # theme_type_variation = "SectionLabel"
      QualityList (VBoxContainer)   # dynamically populated Win95Checkbox nodes
      Spacer (Control)
      ButtonContainer (HBoxContainer)
        BackButton (Button)
        StartButton (Button)
      ControlHint (Label)
```

**Invariants**:
- `RunSetupView` remains a `Control` node (not `Window`, not `Popup`). The Win95 window appearance is purely cosmetic via Panel theme variations.
- No per-node `theme_override_*` properties on any node in either scene.
- All script files (`title_screen.gd`, `run_setup_popup.gd`) unchanged.
