# Feature Specification: Fix Orientation Icon Position After Board Resize

**Feature Branch**: `002-fix-orientation-icon`  
**Created**: 2026-04-03  
**Status**: Draft  
**Input**: Bug report: Orientation icon displays at incorrect position when board changes size between rounds

## User Scenarios & Testing *(mandatory)*

<!--
  IMPORTANT: User stories should be PRIORITIZED as user journeys ordered by importance.
  Each user story/journey must be INDEPENDENTLY TESTABLE - meaning if you implement just ONE of them,
  you should still have a viable MVP (Minimum Viable Product) that delivers value.
  
  Assign priorities (P1, P2, P3, etc.) to each story, where P1 is the most critical.
  Think of each story as a standalone slice of functionality that can be:
  - Developed independently
  - Tested independently
  - Deployed independently
  - Demonstrated to users independently
-->

### User Story 1 - Orientation Icon Anchors to Board Top-Left Cell (Priority: P1)

Player completes a round and transitions to the next round where the board has a different size. The orientation icon, which indicates directional reference, should be repositioned to the new board's top-left cell (0,0) instead of staying at the old position.

**Why this priority**: The orientation icon is critical visual feedback for navigation and spatial understanding of the board. Incorrect positioning breaks the player's mental model and gameplay experience.

**Independent Test**: Complete one full round with a known board size, transition to next round with different board dimensions, verify orientation icon is at the new top-left cell (0,0).

**Acceptance Scenarios**:

1. **Given** a game board is 7x7 with orientation icon at top-left cell, **When** player completes round and transitions to next round with 6x9 board, **Then** orientation icon appears at new top-left cell
2. **Given** the orientation icon is on a 6x9 board at top-left, **When** player completes round and board size changes to 8x8, **Then** icon repositions to new top-left cell
3. **Given** the board is displayed with a new size and screen position, **When** the scene renders, **Then** orientation icon is visually aligned with the new top-left cell before player sees the board

### Edge Cases

- What happens if board size changes to 1x1? Orientation icon should still appear on the single cell at (0,0)
- What if the board's screen offset changes (due to screen resolution or layout shift)? Icon must track with board position, not stay at fixed screen coordinates
- What if orientation icon was previously at a different board position and board resizes? Icon should snap back to (0,0) immediately on resize
- What if multiple board resizes happen in rapid succession? Each resize should recalculate icon position correctly

## Requirements *(mandatory)*

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right functional requirements.
-->

### Functional Requirements

- **FR-001**: System MUST anchor orientation icon to board grid coordinate (0,0) at all times
- **FR-002**: When board dimensions change, system MUST recalculate and reposition orientation icon to new (0,0) location
- **FR-003**: Orientation icon position MUST account for the board's visual offset/screen position
- **FR-004**: Icon MUST remain visually centered on the top-left cell regardless of cell size or board offset changes
- **FR-005**: Orientation icon repositioning MUST occur before board is rendered to player (no visible flickering or mid-render misalignment)
- **FR-006**: System MUST handle board size changes from any dimensions to any other dimensions correctly

### Key Entities

- **Orientation Icon**: Visual directional marker indicating board's top-left reference point; positioned relative to grid coordinate (0,0)
- **Board Grid**: 2D container with variable dimensions (width × height in cells); dimensions can change between rounds
- **Cell (0,0)**: Grid coordinate at top-left of board; designated anchor point for orientation icon
- **Board Offset**: Screen-space position where the board's top-left corner is rendered (changes when board resizes or screen layout shifts)

## Success Criteria *(mandatory)*

<!--
  ACTION REQUIRED: Define measurable success criteria.
  These must be technology-agnostic and measurable.
-->

### Measurable Outcomes

- **SC-001**: Orientation icon is positioned at board grid (0,0) on 100% of board size transitions
- **SC-002**: Icon positioning is correct within first frame of new board render (no repositioning delays or flickering)
- **SC-003**: Icon remains aligned with top-left cell when board offset changes (screen position shifts)
- **SC-004**: Visual alignment is pixel-perfect (icon center aligned with cell center) across all board sizes (minimum 1x1, maximum tested bounds)

## Assumptions

- Board dimensions vary between rounds (part of game progression system per shop/difficulty selections)
- Orientation icon position is currently calculated relative to screen space or cached board state, not dynamically relative to grid (0,0)
- Board resizing is triggered at a clear transition point: when transitioning from Shop view → Next Round gameplay
- Board always has a visible top-left cell at grid coordinate (0,0)
- Icon should be anchored to grid coordinates, not absolute screen positions
- Board's visual position on screen and cell render sizes may change; icon must adapt proportionally
- "Top-left cell" refers to the cell at grid coordinate (0,0), visually rendered at the board's top-left corner
