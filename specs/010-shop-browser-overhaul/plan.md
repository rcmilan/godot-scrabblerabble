# Implementation Plan: Shop Browser Overhaul

**Branch**: `010-shop-browser-overhaul` | **Date**: 2026-05-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/010-shop-browser-overhaul/spec.md`

## Summary

Replace the existing modifier-shop overlay with a Win95-style browser window containing a 3x3 grid of 9 placeholder shop cells. The browser uses the `godot-design-95` design system and supports full keyboard navigation (TAB forward, Shift+TAB reverse, ENTER to activate, ESC to close). All 9 cells display a "coming soon" visual state. Closing the browser (X button or ESC) dismisses the shop and starts the next round. No purchase logic is implemented.

## Technical Context

**Language/Version**: GDScript 4.x (Godot 4.6)
**Primary Dependencies**: Godot 4.6 engine; `godot-design-95` design system (webcore_theme.tres, browser scene, exe/dll/bat icons)
**Storage**: N/A
**Testing**: Manual in Godot editor (Constitution Principle V)
**Target Platform**: Desktop (Windows primary, cross-platform)
**Project Type**: Desktop game (single-player)
**Performance Goals**: Shop window visible within 1 second of round-end event
**Constraints**: No modal overlays (view-swapping only); all UI must use godot-design-95 theme; no per-node theme_override_* properties
**Scale/Scope**: 1 player, 9 shop cells, local session only

## Constitution Check

*GATE: Must pass before implementation begins.*

| Principle / Constraint | Status | Notes |
|------------------------|--------|-------|
| I. Domain-Driven Design | PASS | `ShopItem` value object in `/scripts/domain/shop/`. No business logic in scene or controller. |
| II. Decoupled Communication via EventBus | PASS | Shop listens to `EventBus.run_shop_requested` (wired in main.gd). Emits `continue_requested` signal consumed by main.gd. No new direct coupling introduced. |
| III. Immutable Domain Objects | PASS | `ShopItem` is constructed once and never mutated. |
| IV. Thin Controllers | PASS | `shop_overlay.gd` only routes input to close logic and wires focus. No game rules. |
| V. Manual Testing First | PASS | All acceptance criteria verified manually in editor. |
| VI. Non-Representable Invalid States | PASS | `ShopItem.Type` is an enum - only EXE/DLL/BAT can exist. Invalid type is unrepresentable. |
| No Modals/Popups/Dialogs | PASS | ShopOverlay is a sibling Control in main.tscn shown/hidden via `visible` toggle. Not a popup or modal. |
| UI Design System Source of Truth | PASS | Browser scene and icons sourced from godot-design-95. webcore_theme.tres applied. No per-node theme overrides. |
| EventBus as Communication Hub | PASS | No new direct scene-to-scene references introduced. |
| Scene Dependency Injection | PASS | No `get_tree()` lookups. Shop receives nothing via injection in this iteration (stateless display). |

**No violations. No Complexity Tracking entry required.**

## Project Structure

### Documentation (this feature)

```text
specs/010-shop-browser-overhaul/
├── plan.md              # This file
├── research.md          # Phase 0 decisions
├── data-model.md        # Phase 1 entities and signal contract
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code

```text
scenes/shop/
├── shop_overlay.tscn    # REPLACE: Win95 browser window scene
└── shop_overlay.gd      # REPLACE: browser shop controller

scripts/domain/shop/
└── shop_item.gd         # NEW: ShopItem value object (Type enum + index)

autoload/
└── event_bus.gd         # NO CHANGE: run_shop_requested signal already exists

scenes/
└── main.gd              # MODIFY: simplify _on_shop_requested and _on_shop_continue
```

**Removed call sites in main.gd** (the old shop logic to delete):
- `RunManager.get_shop_tiles(10)` call and result usage
- `RunManager.get_shop_modifiers(modifier_count)` call
- `ShopSession.new(...)` construction
- `ShopController` instantiation and `_shop_controller` variable
- `ShopSlideAnimation.get_entrance_animation(...)` and `get_exit_animation(...)`
- `RunManager.finalize_shop_commit(final_tiles)` call

Note: Do NOT delete ShopController/ShopSlideAnimation script files until confirming they are not referenced elsewhere. Remove only the call sites in main.gd for now; the scripts can be cleaned up in a follow-up.

**Structure Decision**: Single project (Godot game). UI in `scenes/`, domain in `scripts/domain/`, no backend or external service.

## Implementation Phases

### Phase A: Domain Layer

Create `scripts/domain/shop/shop_item.gd`:
- Define `Type` enum: `EXE = 0`, `DLL = 1`, `BAT = 2`
- Constructor: `static func create(type: Type, index: int) -> ShopItem`
- Properties: `type: Type` (readonly), `index: int` (readonly)
- No Godot node dependencies

### Phase B: Asset Import

Import from `godot-design-95` into the project:
- `exe_icon.png`, `dll_icon.png`, `bat_icon.png` -> `scenes/shop/icons/` (or existing asset dir)
- Confirm `webcore_theme.tres` is already present (from branch 009); import if missing
- Confirm `ThemeSetup.gd` autoload is registered in project.godot

### Phase C: Scene Construction

Build `scenes/shop/shop_overlay.tscn`:

```
ShopOverlay (Control, full-rect, z_index = 10)
└── BrowserWindow (Panel, theme: WindowPanel, centered, ~640x480)
    ├── VBox (VBoxContainer, full fill)
    │   ├── TitleBar (Panel, theme: TitleBarActive, min_height: 20)
    │   │   └── HBox (HBoxContainer)
    │   │       ├── Title (Label, theme: TitleBarLabel, text: "shop.com - Internet Explorer")
    │   │       └── CloseButton (Button, theme: TitleBarButton, text: "X")
    │   ├── Toolbar (Panel, theme: Win95MenuBar, min_height: 26)
    │   │   └── HBox (HBoxContainer)
    │   │       ├── RefreshButton (Button, text: "Refresh")
    │   │       └── UrlBar (LineEdit, text: "shop.com", editable: false)
    │   └── ContentArea (Panel, size_flags: expand+fill)
    │       └── ItemGrid (GridContainer, columns: 3, centered)
    │           └── ShopItemCell x9 (Button, FOCUS_ALL, min_size: 80x80)
    │               ├── Icon (TextureRect, 32x32)
    │               ├── DimOverlay (ColorRect, semi-transparent, full-rect)
    │               └── SoonLabel (Label, text: "?", centered)
```

Focus chain (set via `focus_next` / `focus_previous` on each node):
`RefreshButton -> Cell0 -> Cell1 -> ... -> Cell8 -> CloseButton -> RefreshButton`

### Phase D: Controller Script

Write `scenes/shop/shop_overlay.gd`:

```gdscript
extends Control
class_name ShopOverlay

signal continue_requested

const ICON_MAP = {
    ShopItem.Type.EXE: preload("res://scenes/shop/icons/exe_icon.png"),
    ShopItem.Type.DLL: preload("res://scenes/shop/icons/dll_icon.png"),
    ShopItem.Type.BAT: preload("res://scenes/shop/icons/bat_icon.png"),
}
const ITEM_TYPES = [
    ShopItem.Type.EXE, ShopItem.Type.DLL, ShopItem.Type.EXE,
    ShopItem.Type.DLL, ShopItem.Type.BAT, ShopItem.Type.EXE,
    ShopItem.Type.BAT, ShopItem.Type.DLL, ShopItem.Type.BAT,
]

# Node refs: @onready for CloseButton, RefreshButton, ItemGrid cells

func _ready() -> void:
    # Wire CloseButton.pressed -> _close_shop
    # Wire RefreshButton.pressed -> no-op (placeholder)
    # Wire each cell.pressed -> no-op (placeholder)
    # Set focus chain via focus_next/focus_previous
    hide()
    # Note: icon assignment happens in show_shop(), not _ready(),
    # to support future dynamic item lists per shop session.

func show_shop(_round_number: int) -> void:
    show()
    RefreshButton.grab_focus()

func _input(event: InputEvent) -> void:
    if not visible:
        return
    if event.is_action_pressed("ui_cancel"):
        _close_shop()
        get_viewport().set_input_as_handled()

func _close_shop() -> void:
    hide()
    continue_requested.emit()
```

### Phase E: main.gd Simplification

Simplify `_on_shop_requested()`:
- Remove: ShopController setup, ShopSlideAnimation entrance, tile/modifier sampling, ShopSession construction
- Keep: `_deactivate_gameplay()`, `_hide_gameplay_ui()`, brief timer pause, `shop_overlay.show_shop(round_number)`

Simplify `_on_shop_continue()`:
- Remove: ShopController finalize, ShopSlideAnimation exit, `RunManager.finalize_shop_commit()`
- Keep: `shop_overlay.hide()`, `RunManager.proceed_from_shop()`

### Phase F: Manual Verification

Test checklist (editor play mode):
- [ ] Complete a round -> shop browser window appears over desktop
- [ ] URL bar shows "shop.com" and cannot be typed in
- [ ] TAB cycles: RefreshButton -> Cell0..8 -> CloseButton -> RefreshButton (wraps)
- [ ] Shift+TAB cycles in reverse; wraps from RefreshButton back to CloseButton
- [ ] Each element shows visible focus ring when focused
- [ ] ENTER on CloseButton: shop hides, next round starts
- [ ] Click X button with mouse: shop hides, next round starts
- [ ] ESC while shop open: shop hides, next round starts
- [ ] ENTER on RefreshButton: no crash, no effect
- [ ] ENTER on any cell: no crash, no effect; coming-soon overlay visible
- [ ] All 9 cells visible simultaneously at 1920x1080
- [ ] Each cell shows correct icon (.exe/.dll/.bat)
- [ ] No input leaks to gameplay when shop is visible

## Complexity Tracking

*No violations. No entries required.*
