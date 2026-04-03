# Implementation Plan: Clean and Enhance Title Screen

**Branch**: `001-clean-title-screen` | **Date**: 2026-04-03 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-clean-title-screen/spec.md`

## Summary

Remove the Options button and all associated code from the title screen, hide all run qualities
except Auto Win in the Run Setup modal, and verify that existing keyboard navigation covers the
required arrow key + Enter + ESC interactions. The change touches 3 script files, 1 scene file,
and deletes 3 files. No new autoloads, domain logic, or animations are required.

## Technical Context

**Language/Version**: GDScript (Godot 4.6)
**Primary Dependencies**: Godot 4.6 UI system, QualityRegistry (existing), ModalInputGuard (existing)
**Storage**: N/A
**Testing**: Manual in Godot editor (see quickstart.md)
**Target Platform**: Desktop (Windows/macOS/Linux via Godot export)
**Project Type**: Desktop game - title screen / UI
**Performance Goals**: 60 fps (standard Godot UI; no new computation)
**Constraints**: No new autoloads; follow DDD and thin-controller patterns; no domain layer changes
**Scale/Scope**: 3 script files modified, 1 scene file modified, 3 files deleted

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Domain-Driven Design | PASS | All changes in controllers/scenes; QualityRegistry untouched |
| II. Decoupled Communication | PASS | MenuController and RunSetupPopup use signals throughout |
| III. Immutable Domain Objects | PASS | No domain value objects modified |
| IV. Thin Controllers | PASS | MenuController stays input-routing only; removing a button reduces complexity |
| V. Manual Testing First | PASS | quickstart.md provides full manual test suite |

No violations. No Complexity Tracking entries required.

## Project Structure

### Documentation (this feature)

```text
specs/001-clean-title-screen/
+-- plan.md              # This file
+-- spec.md              # Feature specification
+-- research.md          # Phase 0 output
+-- data-model.md        # Phase 1 output
+-- quickstart.md        # Phase 1 manual test guide
+-- checklists/
|   +-- requirements.md  # Spec quality checklist
+-- tasks.md             # Phase 2 output (/speckit.tasks - NOT created by /speckit.plan)
```

### Source Code (affected files)

```text
scripts/controllers/
+-- menu_controller.gd           # MODIFY: remove options_btn param + signal

scenes/title_screen/
+-- title_screen.gd              # MODIFY: remove _options_button, _options_popup, 2 methods
+-- title_screen.tscn            # MODIFY: remove OptionsButton node, OptionsPopup instance, fix focus
+-- run_setup_popup.gd           # MODIFY: add VISIBLE_QUALITIES filter in _populate_quality_list()
+-- options_popup.gd             # DELETE
+-- options_popup.gd.uid         # DELETE
+-- options_popup.tscn           # DELETE
```

**Structure Decision**: Single project (default). All changes are within the existing Godot project
tree with no new directories needed.

## Phase 0: Research (Complete)

See [research.md](research.md) for all findings. Summary of resolved decisions:

1. **Options removal scope**: 4 artifacts (node, scene, 2 script files) - all must be removed
2. **Quality filtering**: Whitelist constant in `_populate_quality_list()` - domain stays untouched
3. **Keyboard gap analysis**: Current implementation covers requirements; no new input logic needed
4. **Focus neighbor repair**: NewGameButton <-> ExitButton must be linked after OptionsButton removal

## Phase 1: Design (Complete)

See [data-model.md](data-model.md) for entity change details. See [quickstart.md](quickstart.md)
for manual test instructions.

### No External Contracts

This feature has no external interfaces (no APIs, no CLI commands, no inter-service communication).
The `/contracts/` directory is intentionally omitted.

### Key Implementation Notes

**menu_controller.gd**:
- Change `setup(new_game_btn, options_btn, exit_btn)` to `setup(new_game_btn, exit_btn)`
- Remove `options_requested` signal declaration
- Remove `_options_button` field
- Change `_menu_items = [new_game_btn, options_btn, exit_btn]` to `_menu_items = [new_game_btn, exit_btn]`
- Remove `_on_options_pressed()` callback and its connection
- Remove `options_requested.emit()` call

**title_screen.gd**:
- Remove `@onready var _options_button` and `@onready var _options_popup`
- Change `_menu_controller.setup(_new_game_button, _options_button, _exit_button)` to `_menu_controller.setup(_new_game_button, _exit_button)`
- Remove `_menu_controller.options_requested.connect(...)` line
- Remove `_options_popup.closed.connect(...)` line
- Remove `_on_options_requested()` method
- Remove `_on_options_closed()` method and its OPTIONS POPUP section comment block

**run_setup_popup.gd**:
- Add constant: `const VISIBLE_QUALITIES: Array[StringName] = [&"auto_win"]`
- In `_populate_quality_list()`, after `var id := ids[i]`, add: `if id not in VISIBLE_QUALITIES: continue`

**title_screen.tscn** (text edits):
- Remove `[ext_resource ... options_popup.tscn ...]` line
- Remove `[node name="OptionsButton" ...]` block
- Remove `[node name="OptionsPopup" ...]` line
- Change NewGameButton `focus_neighbor_bottom = NodePath("../OptionsButton")` to `NodePath("../ExitButton")`
- Change ExitButton `focus_neighbor_top = NodePath("../OptionsButton")` to `NodePath("../NewGameButton")`

**Files to delete**:
- `scenes/title_screen/options_popup.gd`
- `scenes/title_screen/options_popup.gd.uid`
- `scenes/title_screen/options_popup.tscn`
