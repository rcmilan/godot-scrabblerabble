# Implementation Plan: Win95 UI Overhaul - Title Screen

**Branch**: `009-win95-title-screen` | **Date**: 2026-05-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/009-win95-title-screen/spec.md`

## Summary

Apply the Windows 95 design system from `godot-design-95` to the title screen and run builder. This means copying the Win95 theme assets into the project, wiring up the global theme and ThemeSetup autoload, and restructuring `title_screen.tscn` and `run_setup_popup.tscn` to use Win95 Panel/TitleBar/Button components - all without touching any GDScript logic files. The background default color changes to Win95 teal (#008080); the BackgroundManager animation is preserved.

## Technical Context

**Language/Version**: GDScript (Godot 4.6)
**Primary Dependencies**: godot-design-95 asset bundle (webcore_theme.tres, W95FA.otf, 9-slice PNGs, ThemeSetup.gd)
**Storage**: N/A
**Testing**: Manual in Godot Editor (Principle V)
**Target Platform**: Desktop (Windows/macOS/Linux)
**Project Type**: Desktop game - Godot scene/theme overhaul
**Performance Goals**: No perceptible load time increase (SC-006)
**Constraints**: No per-node theme overrides (FR-008); no modals/popups (Constitution Patch 1.0.2)
**Scale/Scope**: 2 scene files, 1 autoload, 1 project.godot entry

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle / Constraint | Status | Notes |
|---|---|---|
| I. Domain-Driven Design | PASS | No domain layer touched. Pure UI/scene work. |
| II. Decoupled Communication | PASS | EventBus signals in title_screen.gd unchanged. |
| III. Immutable Domain Objects | PASS | No domain objects modified. |
| IV. Thin Controllers | PASS | MenuController and run_setup_popup.gd scripts unchanged. |
| V. Manual Testing First | PASS | All verification via Godot editor play mode. |
| VI. Non-Representable Invalid States | PASS | Not applicable to UI theming. |
| No Godot Code in Domain | PASS | Theme files go in `theme/`, not `scripts/domain`. |
| Autoload Registry | PASS | ThemeSetup.gd registered in project.godot [autoload]. |
| Scene Dependency Injection | PASS | Existing setup() methods untouched. |
| **No Modals/Popups** | **CONDITIONAL PASS** | RunSetupView must remain a `Control` node with visibility toggling. The Win95 window appearance is cosmetic only (Panel with theme_type_variation). Must verify during implementation that no node type changes to `Window` or `Popup`. |
| **UI Design System Source of Truth (v1.1.0)** | **PASS** | This feature establishes compliance with this constraint. All assets sourced from `https://github.com/rcmilan/godot-design-95`; no custom visual styling introduced outside that system; per-node `theme_override_*` properties explicitly forbidden by FR-008. |

**Gate result: PROCEED** - no violations. Conditional constraint is design-time, not implementation-blocker.

## Project Structure

### Documentation (this feature)

```text
specs/009-win95-title-screen/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks - not yet created)
```

### Source Code (changes)

```text
theme/                              # NEW - copied from godot-design-95
├── ThemeSetup.gd
├── webcore_theme.tres
├── button/
│   ├── button_normal.png
│   ├── button_pressed.png
│   ├── button_normal_texture.tres
│   ├── button_pressed_texture.tres
│   ├── button_titlebar_normal_texture.tres
│   └── button_titlebar_pressed_texture.tres
├── checkbox/
│   ├── checkbox_checked.png
│   └── checkbox_unchecked.png
├── fonts/
│   ├── W95FA_section.tres
│   └── W95FA_spaced.tres
├── lineedit/
│   ├── lineedit_bg.png
│   └── lineedit_style.tres
├── menubar/
│   ├── menubar_bg.png
│   └── menubar_style.tres
├── panel/
│   ├── panel_bg.png
│   └── panel_style.tres
├── radiobutton/
│   ├── radio_checked.png
│   └── radio_unchecked.png
├── titlebar/
│   ├── titlebar_active.png
│   ├── titlebar_inactive.png
│   ├── titlebar_style_active.tres
│   └── titlebar_style_inactive.tres
└── window/
    ├── window_bg.png
    └── window_style.tres

fonts/                              # NEW - bitmap font
└── W95FA.otf

project.godot                       # MODIFIED
  # [application]: add config/custom_theme
  # [autoload]: add ThemeSetup
  # [rendering]: add default_texture_filter=0

autoload/background_manager.gd      # MODIFIED
  # Change default/initial background color to Color("#008080")

scenes/title_screen/
├── title_screen.tscn               # MODIFIED - add WindowPanel + TitleBar structure
├── title_screen.gd                 # UNCHANGED
├── run_setup_popup.tscn            # MODIFIED - add WindowPanel + TitleBar structure
└── run_setup_popup.gd              # MODIFIED - add theme_type_variation to dynamic CheckBox nodes
```

**Structure Decision**: Single Godot project, no new directories beyond `theme/` and `fonts/`. All changes are additive (new assets + project.godot edits) or scene restructuring. No new GDScript files beyond the copied ThemeSetup.gd.

## Implementation Phases

### Phase A: Asset Integration (no scene changes yet)

1. Copy all files from reference repo manifest (see research.md) into `theme/` and `fonts/`
2. Add `config/custom_theme="res://theme/webcore_theme.tres"` to `[application]` in project.godot
3. Add `ThemeSetup="*res://theme/ThemeSetup.gd"` to `[autoload]` in project.godot
4. Add `textures/canvas_textures/default_texture_filter=0` to `[rendering]` in project.godot
5. Open project in Godot Editor, let it reimport. Verify zero import errors.
6. Add a test Button to any scene; confirm Win95 styling applies automatically. Remove test node.

### Phase B: Background Color

1. Open `autoload/background_manager.gd`
2. Change initial/default background color value to `Color("#008080")`
3. Play the game, verify teal background on title screen, verify BackgroundManager animations still run

### Phase C: Title Screen Scene Restructuring

Target structure (from data-model.md):
- Wrap MenuView contents in `Panel` with `theme_type_variation = "WindowPanel"`
- Add `Panel` with `theme_type_variation = "TitleBarActive"` as first child, containing a `Label` with `theme_type_variation = "TitleBarLabel"` and the game name text
- Remove all `theme_override_font_sizes` and `theme_override_colors` from Button and Label nodes
- Verify keyboard navigation still works (MenuController is script-only, unaffected)

### Phase D: Run Builder Scene Restructuring

Same pattern as Phase C applied to `run_setup_popup.tscn`:
- Wrap content in `Panel (WindowPanel)` + `Panel (TitleBarActive)` with "RUN SETUP" label
- Remove inline theme overrides
- For dynamically-created CheckBox nodes in `run_setup_popup.gd`: after `CheckBox.new()`, set `theme_type_variation = "Win95Checkbox"` (this is the only script touch - one line per checkbox instantiation)
- Verify deck selection, quality toggles, Back, and Start all function correctly

### Phase E: Final Verification

Walk through the full quickstart.md checklist manually in the editor.

## Complexity Tracking

No Constitution violations requiring justification.
