# Research: Pause and Shop UI Redesign

**Branch**: `003-pause-shop-ui-fix`
**Date**: 2026-04-04
**Phase**: 0 - Research

## Decision 1: Reference Pattern (RunSetupView)

**Decision**: Use `RunSetupView` (`scenes/title_screen/run_setup_popup.tscn` + `.gd`) as the exact structural template.

**Rationale**: It is already constitution-compliant -- `extends Control`, `anchors_preset = 15`, full-rect layout, `visible = false` initially, `show()`/`hide()` toggling. The constitution explicitly mandates this pattern ("view-swapping with sibling Control visibility toggles").

**Alternatives considered**: Scene change via `change_scene_to_file()` -- rejected because pause and shop are transient overlays over the main scene, not independent scene roots. Switching the entire scene tree for pause would destroy game state.

---

## Decision 2: Rendering Order After CanvasLayer Removal

**Decision**: Keep `ShopOverlay` and `PauseMenu` as the last children before `GameOverPopup` in `main.tscn`. No reordering required.

**Rationale**: In Godot 4, sibling `Control` nodes render in tree order (later = on top). Both `ShopOverlay` and `PauseMenu` are mutually exclusive states -- they are never visible simultaneously. `GameOverPopup` is already last and also out of scope. Existing order is correct.

**Alternatives considered**: Moving them to the very end of the scene tree -- not necessary since they are already positioned after all gameplay nodes.

---

## Decision 3: ModalInputGuard Compatibility

**Decision**: `ModalInputGuard` requires no changes. It already supports both `CanvasLayer` and `Control` owners.

**Rationale**: `ModalInputGuard.setup(owner)` only requires `.visible` and `.get_viewport()` on the owner node -- both of which are available on `Control`. The class comment already documents this: "Owner must be a Node with .visible and .get_viewport() -- both CanvasLayer and Control satisfy this."

**Alternatives considered**: Replacing `ModalInputGuard` with inline `_input` logic -- rejected, no benefit and would diverge from the established pattern.

---

## Decision 4: main.gd Changes Required

**Decision**: `main.gd` requires zero changes.

**Rationale**: `main.gd` calls `show()`, `hide()`, `show_pause_menu()`, `show_shop()`, `visible` checks -- all of these work identically on `Control` and `CanvasLayer`. The `@onready` type annotations use the class names (`ShopOverlay`, `PauseMenu`), which remain unchanged.

**Alternatives considered**: Updating type annotations -- not needed since class names stay the same.

---

## Decision 5: Node Path Updates in Scripts

**Decision**: Both `.gd` scripts need `@onready` path updates to reflect the new flat scene hierarchy.

**Rationale**: Currently paths go through `$Panel/MarginContainer/VBoxContainer/...`. After restructuring to match RunSetupView, the content will be directly under `$ContentContainer/...`. All button and label references must be updated to the new paths.

**Specific path changes:**

### pause_menu.gd
- Remove: `@onready var _overlay: ColorRect = $Overlay`
- Change: `$Panel/MarginContainer/VBoxContainer/ResumeButton` -> `$ContentContainer/ResumeButton`
- Change: `$Panel/MarginContainer/VBoxContainer/ReturnToTitleButton` -> `$ContentContainer/ReturnToTitleButton`

### shop_overlay.gd
- Remove: `@onready var _overlay: ColorRect = $Overlay`
- Change: `$Panel/MarginContainer/VBoxContainer/RoundLabel` -> `$ContentContainer/RoundLabel`
- Change: `$Panel/MarginContainer/VBoxContainer/ScoreLabel` -> `$ContentContainer/ScoreLabel`
- Change: `$Panel/MarginContainer/VBoxContainer/NextBoardLabel` -> `$ContentContainer/NextBoardLabel`
- Change: `$Panel/MarginContainer/VBoxContainer/ContinueButton` -> `$ContentContainer/ContinueButton`
- Change: `$Panel/MarginContainer/VBoxContainer/DebugConfigButton` -> `$ContentContainer/DebugConfigButton`
- Keep: `$DebugRoundConfigPopup` (unchanged, still a direct child of root)

---

## Decision 6: Scene Structure for Both Screens

**Decision**: Mirror RunSetupView exactly -- `Control` (full-rect) root, `TitleLabel` anchored top-center, `ContentContainer` (VBoxContainer) anchored center, `ControlHint` label anchored bottom-center.

**Pause menu content nodes** (inside ContentContainer):
- `ResumeButton`
- `ReturnToTitleButton`

**Shop content nodes** (inside ContentContainer):
- `RoundLabel`
- `ScoreLabel`
- `NextBoardLabel`
- `HSeparator`
- `ContinueButton`
- `DebugConfigButton`

**Rationale**: Structural consistency with RunSetupView is the core requirement. Reusing the same anchor presets and node names makes future maintenance predictable.

---

## Summary: Files to Change

| File | Change Type | Description |
|------|-------------|-------------|
| `scenes/ui/pause_menu/pause_menu.tscn` | Rewrite scene tree | Remove CanvasLayer+ColorRect+Panel, add full-rect Control root with TitleLabel, ContentContainer, ControlHint |
| `scenes/ui/pause_menu/pause_menu.gd` | Edit | Change `extends CanvasLayer` to `extends Control`, remove `_overlay` onready, update button paths |
| `scenes/shop/shop_overlay.tscn` | Rewrite scene tree | Same structural change as pause menu |
| `scenes/shop/shop_overlay.gd` | Edit | Change `extends CanvasLayer` to `extends Control`, remove `_overlay` onready, update label/button paths |
| `main.gd` | No change | All call sites are compatible |
| `main.tscn` | No change | Node positions already correct |
