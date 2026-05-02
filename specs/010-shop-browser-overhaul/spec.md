# Feature Specification: Shop Browser Overhaul

**Feature Branch**: `010-shop-browser-overhaul`
**Created**: 2026-05-02
**Status**: Draft
**Input**: User description: "let's completely overhaul our shop feature. the current shop can be completely discarded. the shop will look like a web browser on screen (Win95 style browser scene from design system). browser has read-only url 'shop.com', refresh button, and a content table with 9 cells each containing a file icon (.exe, .dll, or .bat). keyboard-only navigation via TAB and ENTER. close button concludes shop and starts next round."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Open and Navigate the Shop Browser (Priority: P1)

After completing a round, the shop opens automatically as a Win95-style browser window overlaying the game desktop. The player sees a browser interface with a title bar, a toolbar containing a read-only URL showing "shop.com" and a refresh button, and a content area showing a 3x3 grid of 9 file icons. The player can navigate all interactive elements using only the keyboard.

**Why this priority**: This is the core shell of the new shop. Without it nothing else can function. Every other story depends on the browser window existing and being keyboard-navigable.

**Independent Test**: Launch the game, complete a round, verify the Win95 browser window appears over the desktop with the correct layout and that TAB cycles through all focusable elements.

**Acceptance Scenarios**:

1. **Given** a round has just ended in success, **When** the shop phase begins, **Then** the Win95 browser window appears over the game desktop.
2. **Given** the browser window is open, **When** the player presses TAB repeatedly, **Then** focus cycles forward through all interactive elements: refresh button, each of the 9 grid cells, and the close button, then wraps back around.
3. **Given** the browser window is open, **When** the player presses Shift+TAB, **Then** focus moves in reverse order through the same element sequence.
4. **Given** the browser window is open, **When** the player presses TAB to reach any focusable element, **Then** that element shows a visible focus indicator.
5. **Given** the browser window is open, **When** the player inspects the URL bar, **Then** it displays "shop.com" and cannot be edited.

---

### User Story 2 - Close the Shop and Proceed to Next Round (Priority: P2)

The player decides they are done with the shop and wants to move on. They activate the close button (the "X" in the title bar) via keyboard or mouse to dismiss the shop and trigger the next round.

**Why this priority**: The shop must be closeable to keep the game loop progressing. Without this, the run is stuck at the shop phase indefinitely.

**Independent Test**: Open the shop, press TAB until the X button is focused, press ENTER, and verify the shop dismisses and the next round begins.

**Acceptance Scenarios**:

1. **Given** the browser window is open and focus is on the close button, **When** the player presses ENTER, **Then** the shop window is dismissed and the next round starts.
2. **Given** the browser window is open, **When** the player clicks the close button with the mouse, **Then** the shop window is dismissed and the next round starts.
3. **Given** the shop window has been dismissed, **When** the next round begins, **Then** the game desktop returns to the normal gameplay state with a fresh round ready to play.

---

### User Story 3 - Inspect Grid Items (Priority: P3)

The player navigates the 9-cell content grid and views each item. Each cell displays one of three file type icons (.exe, .dll, .bat) representing future purchasable modifications. Selecting a cell produces no gameplay effect yet but the interaction is wired and ready for future implementation.

**Why this priority**: The grid is the future marketplace surface. Visual and focus behavior must be correct now so it can be extended without rework when purchasing is implemented.

**Independent Test**: Tab to each grid cell and press ENTER on each; verify each cell is focusable and ENTER registers without crashing or breaking navigation flow.

**Acceptance Scenarios**:

1. **Given** the browser is open, **When** the player focuses any of the 9 grid cells, **Then** the cell shows a visible focused state distinct from unfocused cells.
2. **Given** a grid cell is focused, **When** the player presses ENTER, **Then** no purchase occurs and the cell's disabled/coming-soon state is visible to the player.
3. **Given** the browser content area is visible, **When** the player views the grid, **Then** all 9 cells are simultaneously visible, each displaying one of the three file type icons (.exe, .dll, or .bat).

---

### Edge Cases

- What happens if the player presses ESC while the shop is open? ESC closes the shop and starts the next round, identical to pressing the X close button.
- What happens when focus is on the last element and the player presses TAB? Expected: focus wraps to the first focusable element. When focus is on the first element and the player presses Shift+TAB, focus wraps to the last focusable element.
- What happens if the shop phase is triggered after the final round of a run? Expected: closing the shop still proceeds correctly to the run-end screen rather than a new round.
- What happens if the player presses ENTER on the refresh button? Expected: no crash, placeholder behavior (grid content remains unchanged until this feature is implemented).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The shop MUST be presented as a Win95-style browser window overlaying the game desktop when the shop phase begins.
- **FR-002**: The browser window MUST have a title bar containing a title label and a close ("X") button.
- **FR-003**: The browser window MUST have a toolbar containing a read-only URL field displaying "shop.com" and a refresh button.
- **FR-004**: The browser content area MUST display a grid of exactly 9 cells arranged in a 3x3 layout.
- **FR-005**: Each of the 9 grid cells MUST display one of the three file type icons: .exe, .dll, or .bat.
- **FR-006**: The player MUST be able to navigate all interactive elements (close button, refresh button, grid cells) using TAB (forward) and Shift+TAB (reverse) keys.
- **FR-007**: The player MUST be able to activate any focused element by pressing ENTER.
- **FR-008**: Each interactive element MUST display a visible focus indicator when focused via keyboard.
- **FR-009**: The URL field MUST be read-only and reject keyboard input.
- **FR-010**: Activating the close button OR pressing ESC MUST dismiss the shop window and trigger the start of the next round.
- **FR-011**: The shop window MUST appear above all other game elements while open.
- **FR-012**: The existing shop scene content MUST be entirely replaced; no existing shop behavior is retained.
- **FR-013**: The refresh button MUST be present and keyboard-focusable; reloading grid content is reserved for future implementation and may be a no-op now.
- **FR-014**: All grid cells MUST display a disabled or "coming soon" visual state. Activating a cell via ENTER or mouse click MUST produce no purchase action; the disabled indicator is the only response.

### Key Entities

- **ShopItem**: Represents one purchasable slot in the grid. Has a type (.exe, .dll, or .bat) and a corresponding display icon. Future attributes will include resource cost and modification effect.
- **ShopSession** *(deferred - not created in this iteration)*: Will represent one visit to the shop between rounds, owning a set of ShopItems and tracking open/closed state. Deferred until purchasing logic is implemented; see research.md Decision 6.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The shop browser window is fully visible and interactive within one second of the round-end event firing.
- **SC-002**: A player using only the keyboard can navigate from the first to the last focusable element within 11 TAB presses, and back to the first within 11 Shift+TAB presses.
- **SC-003**: Pressing ENTER on the close button dismisses the shop and starts the next round with no additional player input required.
- **SC-004**: All 9 grid cells are visible simultaneously without scrolling at 1920x1080 (the game's primary target display resolution).
- **SC-005**: Every focusable element shows a distinct visual focus state when keyboard-focused, distinguishable from the unfocused state without color as the sole differentiator.

## Clarifications

### Session 2026-05-02

- Q: Does ESC close the shop and start the next round, or do nothing? -> A: ESC closes the shop and starts the next round (same as pressing X).
- Q: What is the TAB focus order for the close button? -> A: Close is last - refresh button, grid cells 1-9, then close button (wraps back to refresh).
- Q: Should Shift+TAB navigate in reverse focus order? -> A: Yes - Shift+TAB moves focus in reverse through the same sequence; wraps from first to last element.
- Q: What visual feedback should grid cells show when activated via ENTER or click? -> A: All cells display a "coming soon" or disabled state indicator; no purchase action occurs.

## Assumptions

- The Win95 browser scene from the `godot-design-95` design system is used as the base for the shop window and will be imported into the project.
- The 9 grid cells are arranged in a 3x3 layout (3 columns, 3 rows).
- The user's mention of "9x9 table" was a misstatement; the intended count is 9 cells total as confirmed by "n = 9 for now".
- The distribution of icon types (.exe, .dll, .bat) across the 9 cells is not gameplay-critical at this stage and can follow any simple pattern (e.g., 3 of each type).
- TAB focus order follows visual left-to-right, top-to-bottom reading order: refresh button -> grid cells 1-9 -> close button.
- Mouse interaction (clicking buttons and cells) is supported in addition to keyboard navigation.
- The shop opens automatically when the shop phase begins; there is no separate "open shop" player action.
- Resource spending (the future purchase mechanic) is explicitly out of scope for this implementation.
- ESC key in the shop closes the shop and starts the next round, identical to pressing the X button.
- The current `scenes/shop/` files are to be completely replaced and none of their logic is preserved.
