# Feature Specification: Clean and Enhance Title Screen

**Feature Branch**: `001-clean-title-screen`  
**Created**: 2026-04-03  
**Status**: Draft  
**Input**: Clean up title screen UI, remove Options button, simplify Run Setup modal, and add keyboard navigation

## User Scenarios & Testing

### User Story 1 - Start New Game (Priority: P1)

Player launches the game and wants to start a new game run with customized settings.

**Why this priority**: Core entry point to gameplay; must be fully functional and responsive.

**Independent Test**: Player can click "New Game" button, access Run Setup modal, and navigate to start the run independently without any other features working.

**Acceptance Scenarios**:

1. **Given** the title screen is displayed, **When** player clicks the "New Game" button, **Then** the Run Setup modal appears showing Deck selection and Auto Win quality option
2. **Given** the Run Setup modal is open, **When** player adjusts settings and clicks "Start Run", **Then** the game transitions to the first round
3. **Given** the Run Setup modal is open, **When** player clicks "Back" or presses ESC, **Then** the modal closes and returns to title screen

---

### User Story 2 - Keyboard Navigation (Priority: P2)

Player can navigate and interact with the title screen using only the keyboard (arrow keys, Enter, ESC).

**Why this priority**: Improves accessibility and game feel; enables keyboard-first control scheme consistent with gameplay.

**Independent Test**: Can be tested independently by verifying all interactive elements (New Game button, Run Setup modal inputs, Back button) are reachable and functional via keyboard alone without mouse.

**Acceptance Scenarios**:

1. **Given** the title screen is displayed, **When** player presses Up/Down arrow keys, **Then** focus cycles between interactive elements
2. **Given** the "New Game" button has focus, **When** player presses Enter, **Then** the Run Setup modal opens
3. **Given** the Run Setup modal is open, **When** player presses arrow keys (Up/Down for options, Left/Right for toggles), **Then** selection/focus moves appropriately
4. **Given** any modal is open, **When** player presses ESC, **Then** the modal closes and focus returns to previous screen
5. **Given** the Run Setup modal is open, **When** player presses Enter on "Start Run", **Then** the game proceeds; **When** player presses Enter on "Back", **Then** modal closes

---

### User Story 3 - Simplify Quality Selection (Priority: P1)

Player sees only the "Auto Win" quality option in the Run Setup modal, reducing cognitive load and configuration complexity.

**Why this priority**: Simplifies on-boarding experience and reduces screen complexity; Auto Win mode is the primary quality focus.

**Independent Test**: Can be tested by verifying the Run Setup modal displays only the Auto Win quality option and no other quality entries are visible.

**Acceptance Scenarios**:

1. **Given** the Run Setup modal is displayed, **When** viewing the "Select Qualities" section, **Then** only "Auto Win" quality appears in the list
2. **Given** the Auto Win option is visible, **When** player clicks or presses space/Enter to toggle it, **Then** the option toggles on/off
3. **Given** the Run Setup modal is open, **When** player navigates with arrow keys, **Then** the Auto Win quality is a navigable element

---

### Edge Cases

- Player starts run with no quality selected: allowed; Start Run button is always enabled regardless of quality selection
- Player opens Run Setup and immediately presses ESC: modal closes, title screen resumes with New Game focused

## Requirements

### Functional Requirements

- **FR-001**: System MUST remove the "Options" button from the title screen
- **FR-002**: System MUST permanently remove all code, event handlers, and assets associated with the Options button (options_popup.gd, options_popup.gd.uid, options_popup.tscn); display settings and key rebinding features are not relocated
- **FR-003**: System MUST display the Run Setup modal when player clicks "New Game" button
- **FR-004**: System MUST display only the "Auto Win" quality option in the Run Setup modal (hide: Big Hand, Time Attack, Time + Increment, Sprint, Random Modifiers)
- **FR-005**: System MUST support keyboard navigation on title screen using Up/Down arrows to cycle through interactive elements
- **FR-006**: System MUST support Enter key to activate focused button/option in title screen and modals
- **FR-007**: System MUST support ESC key to close open modals and return to title screen
- **FR-008**: System MUST support arrow keys (Up/Down/Left/Right) to navigate and toggle options within Run Setup modal
- **FR-009**: System MUST provide visual feedback (highlight/focus indicator) for keyboard-navigated elements
- **FR-010**: System MUST preserve existing Run Setup functionality: Deck selection and Start Run/Back buttons; when the modal opens, keyboard focus MUST land on the Start Run button

### Key Entities

- **Title Screen**: Main menu scene containing buttons and navigation
- **Run Setup Modal**: Configuration dialog for deck selection and qualities
- **Quality Option**: Toggle-able game modifier (currently only Auto Win will be visible)
- **Keyboard Focus**: UI element state indicating which interactive element is keyboard-active

## Success Criteria

### Measurable Outcomes

- **SC-001**: Options button removed; zero references to options button remain in code
- **SC-002**: Run Setup modal displays correctly with only Auto Win quality visible; all other qualities are hidden
- **SC-003**: Player can navigate all title screen elements using arrow keys, Enter, and ESC; no mouse required
- **SC-004**: Keyboard focus state is visually distinct from unfocused elements
- **SC-005**: Modal open/close transitions occur without visible errors, stuck states, or missing keyboard focus on return to title screen
- **SC-006**: Game successfully transitions from title screen → Run Setup → gameplay on keyboard interaction alone

## Assumptions

- "Auto Win" quality is an existing modifier (confirmed: auto_win_quality.gd exists in scripts/domain/qualities/)
- The "New Game" button already has existing functionality to open Run Setup modal; current implementation may need keyboard support addition
- Title screen and Run Setup modal are separate scenes (title_screen.tscn and run_setup_popup.tscn based on file inventory)
- Keyboard input mapping will use existing input actions from project.godot
- Visual focus indicator can be implemented via existing UI focus mechanics in Godot
- All interactive elements (buttons, toggles) should have consistent keyboard navigation pattern
- Display settings (fullscreen, vsync, volume) and key rebinding functionality are permanently removed along with the Options button; no alternative access point is provided

## Clarifications

### Session 2026-04-03

- Q: What happens to the Options popup features (display settings, key rebinding) when the Options button is removed? → A: Permanently removed - these settings are gone for now
- Q: Which element receives keyboard focus when the Run Setup modal opens? → A: Start Run button (current behavior preserved)
- Q: Can the player start a run with no quality selected (Auto Win unchecked)? → A: Yes - Start Run is always enabled; zero-quality runs are valid
