# Implementation Plan: Pause and Shop UI Redesign

**Branch**: `003-pause-shop-ui-fix` | **Date**: 2026-04-04 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/003-pause-shop-ui-fix/spec.md`

## Summary

Convert `PauseMenu` and `ShopOverlay` from `CanvasLayer`-based modal overlays to full-screen `Control` nodes matching `RunSetupView` structure. Implement the pause menu as an **animated scene-swap**: when paused, the board slides left off-screen while the pause menu slides in from the right (mirroring the title screen ↔ run setup navigation pattern). Resume reverses the animations, creating a "rotation" illusion. The shop remains a simple visibility-toggled view (no animation). This architecture eliminates overlay complexity, modal anti-patterns, and resolves input routing issues. Changes include new animations, modified pause menu script with animation orchestration, and updates to `main.gd` to trigger animated transitions.

## Technical Context

**Language/Version**: GDScript / Godot 4.6
**Primary Dependencies**: Godot 4.6 engine, EventBus autoload, ModalInputGuard
**Storage**: N/A
**Testing**: Manual in Godot editor
**Target Platform**: Desktop
**Project Type**: Desktop game (Wordatro)
**Performance Goals**: 60 fps (unchanged)
**Constraints**: No modals/popups/dialogs (constitution); view-swapping via visibility toggling required
**Scale/Scope**: 2 scene files modified (pause_menu.tscn, shop_overlay.tscn); 4 script files modified (pause_menu.gd, shop_overlay.gd, tile_animator.gd, main.gd); 2 new animation files created (slide_left_animation.gd, slide_in_from_right_animation.gd)

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
scripts/animation/slide/
+-- slide_left_animation.gd          # NEW: Board slide-left animation strategy
+-- slide_in_from_right_animation.gd # NEW: Pause menu slide-in animation strategy

scenes/ui/pause_menu/
+-- pause_menu.tscn      # Rewrite: remove CanvasLayer/ColorRect/Panel; add full-rect Control
+-- pause_menu.gd        # Edit: extends Control, add animation methods, input debouncing, update paths

scenes/shop/
+-- shop_overlay.tscn    # Rewrite: same structural change (no animations)
+-- shop_overlay.gd      # Edit: extends Control, update @onready paths

scripts/animation/
+-- tile_animator.gd     # Edit: Register new slide animations (AnimationType.SLIDE_LEFT, SLIDE_IN_FROM_RIGHT)
```

**Files PARTIALLY CHANGING**:
- `main.gd`: Update pause menu show/hide calls to use animated methods (`show_pause_menu_animated()`, `close_pause_menu_animated()`).

**Files NOT changing**: `main.tscn`, `modal_input_guard.gd`, any other scene or script.

**Structure Decision**: Single-project Godot game. New animation strategies in `scripts/animation/slide/`. Scene changes in `scenes/`. Updates to `main.gd` for animation orchestration.

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

### Animation Strategies (New)

**SlideLeftAnimation** (`scripts/animation/slide/slide_left_animation.gd`):
- Extends `TileAnimationStrategy` (reuses framework)
- Animates node position from current x to off-screen left (x = -screen_width)
- Duration: 400ms
- Tween-based, non-blocking (allows parallel animations)

**SlideInFromRightAnimation** (`scripts/animation/slide/slide_in_from_right_animation.gd`):
- Extends `TileAnimationStrategy`
- Animates node position from off-screen right (x = screen_width) to x=0
- Duration: 400ms
- Mirrors SlideLeftAnimation for symmetry

**Registration**:
- Both registered in `TileAnimator` under new category `slide` with enum `AnimationType.SLIDE_LEFT` and `AnimationType.SLIDE_IN_FROM_RIGHT`

### Script Changes

**pause_menu.gd**:
- `extends CanvasLayer` -> `extends Control`
- Remove `@onready var _overlay: ColorRect` (no overlay needed; animations handle visibility)
- `@onready` paths: `$Panel/MarginContainer/VBoxContainer/X` -> `$ContentContainer/X`
- Replace `show()` and `hide()` with animation methods:
  - `show_pause_menu_animated()`: Triggers TileAnimator to animate board slide-left + pause menu slide-in-from-right simultaneously
  - `close_pause_menu_animated()`: Triggers TileAnimator to animate pause menu slide-left + board slide-in-from-right, then emits `resume_requested`
- Add `_animating: bool` flag to debounce input during animations (block button presses while slide animation is running)
- ModalInputGuard still used for Escape key; Escape calls `close_pause_menu_animated()`
- Signal emission unchanged (`resume_requested`, `return_to_title_requested`)

**shop_overlay.gd**:
- `extends CanvasLayer` -> `extends Control`
- Remove `@onready var _overlay: ColorRect`
- All `@onready` paths: `$Panel/MarginContainer/VBoxContainer/X` -> `$ContentContainer/X`
- `@onready var _debug_popup: DebugRoundConfigPopup = $DebugRoundConfigPopup` unchanged
- All other logic unchanged (no animations for shop; standard visibility toggling)

### Architecture: Scene Swap with Animations

The pause menu and board operate as sibling full-screen Control nodes. When paused:
1. Board animates off-screen left (position x → -screen_width) via SlideLeftAnimation
2. PauseMenu animates in from right (position x: screen_width → 0) via SlideInFromRightAnimation
3. Both animations run **simultaneously** for 400ms
4. After animations complete, PauseMenu is visible and interactive; Board is off-screen

When resuming:
1. PauseMenu animates left off-screen via SlideLeftAnimation
2. Board animates in from right via SlideInFromRightAnimation
3. Both animations run **simultaneously** for 400ms
4. After animations complete, Board is visible; PauseMenu is off-screen

This creates a "carousel" or "rotation" visual effect, improving perceived responsiveness and eliminating overlay/modal complexity.

### Rendering Order

Both nodes are direct children of Main (Control root). In Godot 4, later siblings in tree order render on top. PauseMenu and Board are never visible simultaneously (mutual exclusion via animation states). No z-index manipulation needed.

## Complexity Tracking

No constitution violations. No complexity justification required.
