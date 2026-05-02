# Feature Specification: Win95 UI Overhaul - Title Screen

**Feature Branch**: `009-win95-title-screen`
**Created**: 2026-05-01
**Status**: Draft
**Input**: User description: "Win95 UI overhaul applied to title screen and run builder using godot-design-95 as reference"

## Clarifications

### Session 2026-05-01

- Q: Should the Win95 theme be applied globally (all scenes) or scoped only to the title screen? -> A: Global from day one - Win95 theme applies to all scenes immediately; other screens receive Win95 styling automatically as they are redesigned.
- Q: Should the Win95 title bar include close/minimize/maximize buttons? -> A: Decorative only - title text only, no window control buttons.
- Q: How should the animated background be handled with the Win95 redesign? -> A: Replace default background color with Win95 teal (#008080); all other BackgroundManager behavior (animated color transitions) is preserved unchanged.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Win95 Theme Applied to Main Menu (Priority: P1)

The player launches the game and sees a title screen styled after Windows 95: a gray raised-panel window with a navy title bar, the game title displayed in the Win95 bitmap font, and two buttons ("New Game" and "Exit") rendered as authentic Win95-style buttons with raised 3D borders. The overall aesthetic is immediately recognizable as Win95.

**Why this priority**: The main menu is the first thing every player sees. Delivering the Win95 look on this screen alone constitutes a shippable MVP of the overhaul.

**Independent Test**: Launch the game and verify the title screen renders with Win95 aesthetics without touching the Run Builder. All existing navigation (W/S/Enter/Exit) must still work.

**Acceptance Scenarios**:

1. **Given** the game starts, **When** the title screen loads, **Then** the background, panel, title bar, font, and buttons all use the Win95 design system assets and theme.
2. **Given** the title screen is displayed, **When** the player navigates with W/S/Enter keys, **Then** keyboard navigation behaves identically to the current implementation (no regression).
3. **Given** the title screen is displayed, **When** the player clicks "Exit", **Then** the game quits as before.

---

### User Story 2 - Win95 Theme Applied to Run Builder (Priority: P2)

After pressing "New Game", the Run Builder view appears as a Win95-style dialog: a window panel with a title bar reading "RUN SETUP", form elements (OptionButton for deck, checkboxes for qualities) styled as Win95 controls, and "Back" / "Start" buttons with authentic raised borders.

**Why this priority**: Depends on P1 theme infrastructure. The Run Builder is the second user-facing screen and must be visually consistent with the main menu.

**Independent Test**: Reach the Run Builder, verify all controls render with Win95 style, confirm deck selection and quality toggles still function correctly, and confirm a run can be started.

**Acceptance Scenarios**:

1. **Given** the player presses "New Game", **When** the Run Builder appears, **Then** all controls (panel, title bar, OptionButton, checkboxes, buttons) use Win95-themed components.
2. **Given** the Run Builder is open, **When** the player changes deck or toggles qualities, **Then** the behavior is unchanged from the pre-overhaul implementation.
3. **Given** the Run Builder is open, **When** the player presses "Back", **Then** the main menu returns with Win95 styling intact.
4. **Given** the Run Builder is open, **When** the player presses "Start", **Then** the run launches into gameplay normally.

---

### User Story 3 - Reusable Win95 Theme Components (Priority: P3)

The Win95 design system is integrated as a proper Godot theme resource (`webcore_theme.tres`) and registered via an autoload (`ThemeSetup.gd`). All UI nodes on the title screen and run builder inherit styles from this theme rather than using per-node style overrides, making the system reusable for future screens.

**Why this priority**: Architectural quality. Without this, the visual changes would be brittle one-offs. This story enables future screens to adopt Win95 styling at near-zero cost.

**Independent Test**: Inspect any Button or Label node on the title screen in the editor and verify it has no per-node style overrides; all styling is inherited from the theme resource.

**Acceptance Scenarios**:

1. **Given** the project opens in the editor, **When** any title screen Button or Label is inspected, **Then** no per-node style override properties are set; styling comes from the theme.
2. **Given** the Win95 theme is active, **When** a new Button node is added to any scene, **Then** it automatically renders in Win95 style without manual configuration.
3. **Given** the assets from `godot-design-95` are copied into the project, **When** the project loads, **Then** no import errors appear for fonts, textures, or theme resources.

---

### Edge Cases

- What happens if the Win95 bitmap font fails to load? The game must still be playable with a fallback font, not a crash.
- How does keyboard focus render on Win95-styled buttons? Focused state must be visually distinct (Win95 dotted focus rectangle or equivalent highlight).
- How does the OptionButton (deck selector) render with the Win95 theme? If no dedicated OptionButton style exists in the reference repo, the standard Win95 button style is applied as a fallback.
- The background behind the window panel starts as Win95 teal (#008080) and transitions via `BackgroundManager` animations; the window panel must remain legible over any tween state.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The project MUST include all asset files from `godot-design-95` (font `W95FA.otf`, theme `webcore_theme.tres`, all 9-slice textures for button, panel, window, titlebar, lineedit, checkbox, radiobutton, menubar) copied to `theme/` at the project root and `fonts/W95FA.otf` at the project root `fonts/` directory. These paths match the internal `res://theme/...` resource references hardcoded in `webcore_theme.tres` and must not be changed.
- **FR-002**: The project MUST register `ThemeSetup.gd` as an autoload singleton so the Win95 theme is applied globally at runtime. This is intentional: all scenes will receive Win95 styling as they are progressively redesigned; scenes not yet redesigned are considered acceptable temporary collateral.
- **FR-003**: Texture filtering MUST be set to nearest-neighbor (either globally or per-viewport) to preserve the pixel-accurate appearance of all 9-slice textures.
- **FR-004**: The title screen MUST use a Win95 window panel as its root container, with a navy title bar displaying the game title. The title bar is decorative only (no close/minimize/maximize buttons). It MUST match the `WindowPanel` and `TitleBar` components from `godot-design-95`.
- **FR-005**: The "New Game" and "Exit" buttons on the main menu MUST use the Win95 Button style (raised 3D border, gray background, bitmap font label).
- **FR-006**: The Run Builder MUST be styled as a Win95 dialog: `WindowPanel` container, `TitleBar` with "RUN SETUP" label (decorative only, no window control buttons), and all form controls (OptionButton, CheckBox, Buttons) using Win95-themed variants.
- **FR-007**: All text on the title screen and run builder MUST render using the `W95FA.otf` bitmap font at sizes that preserve pixel-correct rendering.
- **FR-008**: No per-node style override properties MUST be set on any Button, Label, Panel, or CheckBox node in the title screen or run builder scenes; all styling MUST be inherited from the project theme resource.
- **FR-009**: All existing functionality (keyboard navigation, deck selection, quality toggles, run start, exit) MUST continue to work without regression after the visual overhaul.
- **FR-010**: The `title_screen.tscn` and `run_setup_popup.tscn` scenes MUST be restructured to use Win95 reusable components wired to the Win95 theme, not bare Control nodes with manual inline styling.
- **FR-011**: The default background color of the title screen MUST be changed to Win95 teal (#008080). The `BackgroundManager` animated color-transition behavior MUST be preserved unchanged.

### Key Entities

- **Win95 Theme Resource** (`webcore_theme.tres`): Master Godot Theme resource defining all styleboxes, fonts, and colors for Win95 components. Copied from reference repo; referenced by ThemeSetup autoload.
- **ThemeSetup Autoload**: GDScript singleton that registers the Win95 theme at startup. Copied from reference repo and registered in `project.godot`.
- **Win95 Asset Bundle**: Font (`W95FA.otf`) stored under `fonts/` at project root; 9-slice texture PNGs and theme resources stored under `theme/` at project root. These paths are required by `webcore_theme.tres` internal resource references (`res://theme/...`).
- **TitleScreen Scene** (`title_screen.tscn`): Main menu scene restructured to use Win95 window/panel/button components.
- **RunSetupPopup Scene** (`run_setup_popup.tscn`): Run configuration dialog restructured to use Win95 dialog/form components.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A player with no context can identify the title screen as "Windows 95 style" on first impression (visually matches the reference repo screenshots).
- **SC-002**: Zero per-node style override properties exist on any UI node in the title screen or run builder after the overhaul (verifiable by scene file inspection).
- **SC-003**: All 5 existing user flows complete without error on the overhauled screens: navigate menu, start new game, select deck, toggle quality, exit.
- **SC-004**: No texture import errors or missing-font warnings appear in the editor output when the project loads.
- **SC-005**: Adding a new Button node to the title screen scene renders in Win95 style without any manual property configuration.
- **SC-006**: The title screen loads with no perceptible startup delay compared to before the overhaul.

## Assumptions

- The reference repository (`https://github.com/rcmilan/godot-design-95`) is publicly accessible and its assets are freely usable in this project.
- The Win95 design system targets Godot 4.x, which is compatible with Wordatro running on Godot 4.6.
- Only `title_screen.tscn` and `run_setup_popup.tscn` are in scope for this iteration; the Win95 theme is registered globally so gameplay, shop, and HUD scenes will also receive Win95 styling automatically (acceptable side-effect, addressed in future iterations).
- The existing keyboard navigation logic in `MenuController` and `run_setup_popup.gd` is preserved as-is; only the visual layer changes.
- Mobile and touch support are out of scope; the Win95 aesthetic is inherently desktop-oriented.
- The `BackgroundManager` is preserved as-is. Only the default/starting background color changes to Win95 teal (#008080); all animated color transition behavior remains unchanged.
- The `OptionButton` for deck selection will use the closest available Win95 component from the design system; if no dedicated dropdown style exists, the standard Win95 button style is applied as a fallback.
