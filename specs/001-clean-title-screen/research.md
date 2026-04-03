# Research: Clean and Enhance Title Screen

**Branch**: `001-clean-title-screen` | **Phase**: 0 | **Date**: 2026-04-03

## Findings Summary

All unknowns resolved through codebase inspection. No external dependencies required.

---

### Decision 1: Options Button Removal Scope

**Decision**: Remove `OptionsButton` node from `title_screen.tscn`, delete `options_popup.gd` and
`options_popup.tscn`, and update `title_screen.gd` + `menu_controller.gd` to remove all references.

**Rationale**: The Options button has full ownership in 4 artifacts (node, scene, two script files).
All four must be removed or the scene tree will error on missing node references at runtime.

**Files affected**:
- `scenes/title_screen/title_screen.tscn` - remove OptionsButton node, OptionsPopup instance, fix focus_neighbor_bottom on NewGameButton (line 73), fix focus_neighbor_top on ExitButton (line 86)
- `scenes/title_screen/title_screen.gd` - remove `_options_button`, `_options_popup` onready vars; remove `_on_options_requested`, `_on_options_closed` methods; remove `options_popup.closed.connect(...)` call; update `_menu_controller.setup()` call
- `scripts/controllers/menu_controller.gd` - remove `_options_button` dependency, `options_requested` signal, update `setup()` signature to 2 buttons, update `_menu_items` array
- DELETE: `scenes/title_screen/options_popup.gd`, `options_popup.gd.uid`, `options_popup.tscn`

**Alternatives considered**: Hiding the button instead of deleting it. Rejected: leaves dead code and
misses the explicit "remove all code related to it" requirement.

---

### Decision 2: Quality Filtering Approach

**Decision**: Filter in `_populate_quality_list()` inside `run_setup_popup.gd`. Add a constant
`VISIBLE_QUALITIES` whitelist containing only `&"auto_win"` and skip any quality id not in it.

**Rationale**: `_populate_quality_list()` iterates `QualityRegistry.get_all_quality_ids()` and
creates a checkbox per quality. The simplest, least invasive change is a one-line filter on `id`.
No domain changes needed; the registry stays intact for future use.

**Qualities currently registered** (from quality_registry.gd):
- `max_hand_size` (Big Hand) - hide
- `time_attack` (Time Attack) - hide
- `limited_time_with_increment` (Time + Increment) - hide
- `max_score_in_n_rounds` (Sprint 3 Rounds) - hide
- `random_modifiers` (Random Modifiers) - hide
- `auto_win` (Auto Win 10 Plays) - keep visible

**Auto Win confirmed**: `auto_win_quality.gd` exists, registered as `&"auto_win"`, displays as
"Auto Win (10 Plays)" with description "Exhaust your 10 plays to win each round. Run ends after 10 rounds."

**Alternatives considered**: Removing hidden qualities from the registry. Rejected: violates
Domain-Driven Design principle - the registry is a domain service and must not be controlled by UI.
Hiding at the domain layer (adding a `is_visible_in_setup()` method on RunQuality) is also a valid
future path, but out of scope for this cleanup task.

---

### Decision 3: Keyboard Navigation Gap Analysis

**Decision**: The existing implementation already covers most of the required keyboard support.
The gap is that RunSetupPopup does not have visual focus feedback for the OptionButton (deck selector).
The menu controller already handles arrow keys (via `ui_up`/`ui_down` which Godot maps to arrow keys).

**Current keyboard support inventory**:

| Feature | Handler | Status |
|---------|---------|--------|
| Title screen Up/Down arrows | MenuController._input (ui_up/ui_down) | Works |
| Title screen Enter/Space | MenuController._input (ui_accept) | Works |
| Title screen A=First/D=Last | MenuController._input | Works |
| Run Setup WASD -> ui navigation | RunSetupPopup._input (nav_map forward) | Works |
| Run Setup Enter to toggle checkbox | RunSetupPopup._input (ui_accept + CheckBox) | Works |
| Run Setup ESC to close | ModalInputGuard (KeyAction.CANCEL / ui_cancel) | Works |
| Title screen ESC | Not required - no modal open | N/A |

**Gap**: After removing Options button, MenuController has only [New Game, Exit]. Navigation wraps
correctly via modulo (already in `_move_selection`). No logic changes needed for navigation itself.

**Rationale**: Arrow keys work because `is_action_pressed("ui_up")` is checked before the raw
keycode check for W. Godot's default input map binds Up arrow to `ui_up`. This means existing
keyboard navigation covers the specification's requirements.

---

### Decision 4: Scene Focus Neighbor Cleanup

**Decision**: After removing OptionsButton, the focus_neighbor links in title_screen.tscn must be
updated so NewGameButton and ExitButton are neighbors of each other directly.

**Current links (from tscn grep)**:
- NewGameButton.focus_neighbor_bottom = `"../OptionsButton"` - must change to `"../ExitButton"`
- ExitButton.focus_neighbor_top = `"../OptionsButton"` - must change to `"../NewGameButton"`

This ensures arrow-key navigation wraps correctly in the scene tree focus system as well.
