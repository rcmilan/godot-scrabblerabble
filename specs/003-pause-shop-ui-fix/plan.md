# Implementation Plan: Pause and Shop UI Redesign

**Branch**: `003-pause-shop-ui-fix` | **Date**: 2026-04-04 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/003-pause-shop-ui-fix/spec.md`

## Summary

Convert `PauseMenu` and `ShopOverlay` from `CanvasLayer`-based modal overlays to full-screen `Control` nodes, mirroring the structure of `RunSetupView`. This brings both screens into compliance with the constitution's "No Modals, Popups, or Dialogs" constraint. No game logic changes. No changes to `main.gd` or `main.tscn`.

## Technical Context

**Language/Version**: GDScript / Godot 4.6
**Primary Dependencies**: Godot 4.6 engine, EventBus autoload, ModalInputGuard
**Storage**: N/A
**Testing**: Manual in Godot editor
**Target Platform**: Desktop
**Project Type**: Desktop game (Wordatro)
**Performance Goals**: 60 fps (unchanged)
**Constraints**: No modals/popups/dialogs (constitution); view-swapping via visibility toggling required
**Scale/Scope**: 2 scene files + 2 script files modified

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Domain-Driven Design | PASS | No domain logic touched |
| II. Decoupled Communication via EventBus | PASS | No signal wiring changes |
| III. Immutable Domain Objects | PASS | Not applicable |
| IV. Thin Controllers | PASS | No controller logic changes |
| V. Manual Testing First | PASS | Verified manually in editor |
| No Modals, Popups, or Dialogs | **FIXING** | This feature resolves the existing violation |

**Post-design re-check**: All constraints satisfied. The refactor replaces CanvasLayer+ColorRect+Panel (modal pattern) with full-rect Control nodes (view-swap pattern). `ModalInputGuard` is already compatible with Control nodes and requires no changes.

## Project Structure

### Documentation (this feature)

```text
specs/003-pause-shop-ui-fix/
+-- plan.md              # This file
+-- research.md          # Phase 0 output
+-- tasks.md             # Phase 2 output (/speckit.tasks - NOT created here)
```

### Source Code (files to change)

```text
scenes/ui/pause_menu/
+-- pause_menu.tscn      # Rewrite: remove CanvasLayer/ColorRect/Panel; add full-rect Control
+-- pause_menu.gd        # Edit: extends Control, remove _overlay, update @onready paths

scenes/shop/
+-- shop_overlay.tscn    # Rewrite: same structural change
+-- shop_overlay.gd      # Edit: extends Control, remove _overlay, update @onready paths
```

**Files NOT changing**: `main.gd`, `main.tscn`, `modal_input_guard.gd`, any other scene or script.

**Structure Decision**: Single-project Godot game. All changes are in `scenes/` only (UI layer). No new files created.

## Design Details

### Target Scene Structure (both screens)

Mirrors `scenes/title_screen/run_setup_popup.tscn` exactly:

```text
[Control]                 # root, anchors_preset=15, visible=false, script=...
  [TitleLabel]            # Label, anchored top-center
  [ContentContainer]      # VBoxContainer, anchored center
    [... buttons/labels]  # screen-specific content
  [ControlHint]           # Label, anchored bottom-center
```

### PauseMenu Scene Content

```text
ContentContainer (VBoxContainer)
  ResumeButton
  ReturnToTitleButton
```

### ShopOverlay Scene Content

```text
ContentContainer (VBoxContainer)
  RoundLabel
  ScoreLabel
  NextBoardLabel
  HSeparator
  ContinueButton
  DebugConfigButton
DebugRoundConfigPopup   # direct child of root (unchanged)
```

### Script Changes

**pause_menu.gd**:
- `extends CanvasLayer` -> `extends Control`
- Remove `@onready var _overlay: ColorRect = $Overlay`
- `$Panel/MarginContainer/VBoxContainer/ResumeButton` -> `$ContentContainer/ResumeButton`
- `$Panel/MarginContainer/VBoxContainer/ReturnToTitleButton` -> `$ContentContainer/ReturnToTitleButton`
- All other logic (ModalInputGuard, signals, show/hide) unchanged

**shop_overlay.gd**:
- `extends CanvasLayer` -> `extends Control`
- Remove `@onready var _overlay: ColorRect = $Overlay`
- All `$Panel/MarginContainer/VBoxContainer/X` -> `$ContentContainer/X`
- `$DebugRoundConfigPopup` unchanged (still a direct child of root)
- All other logic unchanged

### Rendering Order

Both nodes are already positioned after all gameplay nodes in `main.tscn` (PauseMenu and ShopOverlay appear after Board, Hand, HUD etc.). In Godot 4, later siblings render on top. No reordering needed. They are mutually exclusive states and never visible simultaneously.

## Complexity Tracking

No constitution violations. No complexity justification required.
