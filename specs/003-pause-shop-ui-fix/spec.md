# Feature Specification: Pause Menu and Shop UI Redesign

**Feature Branch**: `003-pause-shop-ui-fix`
**Created**: 2026-04-04
**Status**: Draft
**Input**: User description: "lets fix the UI for the pause menu and for the shop. The UI for both the pause menu and the shop should be created the same way we do on the New Game/Run Setup. Modals/Dialogs/Popups are forbiden."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Pause Menu with Animated Scene Swap (Priority: P1)

When a player pauses the game mid-round, the gameplay board animates off-screen to the left while the pause menu simultaneously animates in from the right. This creates a seamless scene-swap effect similar to the title screen ↔ run setup navigation. Resuming reverses the animations, with the pause menu sliding left and the board returning from the right, creating a "rotation" visual illusion.

**Why this priority**: The pause menu is accessed frequently during play. A smooth animated transition improves perceived responsiveness and visual polish. The scene-swap architecture eliminates overlay complexity and input routing issues.

**Independent Test**: Pause the game during a round. Verify: (1) board slides left off-screen while pause menu slides in from right simultaneously, (2) both animations complete smoothly, (3) pause menu is fully interactive with proper focus handling, (4) pressing Resume reverses the animations symmetrically, (5) no CanvasLayer, overlays, or modal elements are present.

**Acceptance Scenarios**:

1. **Given** a player is in an active round, **When** they press Escape, **Then** the board animates left off-screen and the pause menu animates in from the right simultaneously, with both animations completing in under 500ms.
2. **Given** the pause menu is visible and focused, **When** the player presses arrow keys, **Then** focus navigates between Resume and Return to Title buttons.
3. **Given** the pause menu is visible, **When** the player selects "Resume", **Then** the pause menu animates left off-screen while the board animates in from the right, and gameplay resumes seamlessly.
4. **Given** the pause menu is visible, **When** the player selects "Return to Title", **Then** the pause menu is dismissed and the game transitions to the title screen (no reverse animation).
5. **Given** the pause menu is displayed, **Then** the scene tree shows full-screen Control siblings (Board and PauseMenu), not CanvasLayer or overlay elements.

---

### User Story 2 - Shop as Full-Screen View (Priority: P2)

After a round ends successfully, the shop is presented as a full-screen Control node -- not a floating panel overlaid on the game board. It follows the same structural layout pattern as the Run Setup screen.

**Why this priority**: The shop is a key between-round transition. Removing the modal pattern here ensures visual consistency across all non-gameplay screens.

**Independent Test**: Complete a round and verify the shop fills the screen as a dedicated full-screen view with no dark overlay, no centered Panel, and no CanvasLayer wrapper.

**Acceptance Scenarios**:

1. **Given** a round ends in success, **When** the shop screen appears, **Then** it fills the entire screen as a full-rect Control node and does not use a CanvasLayer or ColorRect overlay.
2. **Given** the shop is displayed, **Then** round summary information (round number, score, next round preview) is visible on the full-screen layout.
3. **Given** the shop is displayed, **When** the player selects "Continue", **Then** the shop view hides and the next round begins.
4. **Given** the shop is displayed, **Then** no floating Panel, no CanvasLayer, and no popup/dialog node is used as the structural root.

---

### Edge Cases

- If the player triggers pause while a round-end transition is in progress, the shop takes precedence: the shop is shown and the pause input is ignored (existing game logic behavior, unchanged by this refactor).
- If the player presses Resume while the pause menu animation is still playing, the action is queued or ignored until the animation completes (debounce input during animation).
- If tile animations are playing on the board when pause is pressed, they continue smoothly as the board slides off-screen (no cancellation or interruption).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The pause menu MUST be implemented as a full-screen Control node with full-rect anchors, matching the RunSetupView structural pattern.
- **FR-002**: The shop MUST be implemented as a full-screen Control node with full-rect anchors, matching the RunSetupView structural pattern.
- **FR-003**: Neither the pause menu nor the shop MUST use a CanvasLayer, ColorRect dimming overlay, floating Panel, AcceptDialog, ConfirmationDialog, Popup, or any modal/dialog node type as the root or primary container.
- **FR-004**: When the player presses Escape during gameplay, the game board MUST animate off-screen to the left while the pause menu simultaneously animates in from the right. Both animations MUST complete within 500ms.
- **FR-005**: When the player selects Resume from the pause menu, the pause menu MUST animate off-screen to the left while the game board animates back in from the right (reversing the pause animation). Both animations MUST complete within 500ms.
- **FR-006**: The pause menu animations MUST reuse or extend the existing tile animation infrastructure (`scripts/animation/draw/` and `scripts/animation/glide/`) to maintain consistency with the game's animation system.
- **FR-007**: The pause menu MUST preserve all existing actions: Resume and Return to Title. Button navigation using arrow keys and Enter MUST work without mouse input.
- **FR-008**: The shop MUST preserve all existing information and actions: round summary labels, Continue button, and the debug round config trigger.
- **FR-009**: Both screens MUST include a title label and keyboard hint label at consistent positions, following the Run Setup layout convention (title anchored near top-center, hint anchored near bottom-center). The pause menu hint text is "Press Escape to resume". The shop hint text is "Press Enter to continue".
- **FR-010**: Content in both screens MUST be centered on the full-screen layout using a VBoxContainer anchored to the screen center, consistent with the ContentContainer pattern in Run Setup.

### Key Entities

- **PauseMenu**: Full-screen Control replacing the current CanvasLayer-based PauseMenu (class name unchanged).
- **ShopOverlay**: Full-screen Control replacing the current CanvasLayer-based ShopOverlay (class name unchanged).
- **RunSetupView**: The reference layout pattern both screens must mirror structurally.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Pause animation completes in under 500ms: board slides left off-screen while pause menu slides in from right, both starting and ending simultaneously.
- **SC-002**: Resume animation mirrors the pause animation: pause menu slides left off-screen while board slides in from right, both completing in under 500ms.
- **SC-003**: Both the pause menu and shop screens fill 100% of the viewport with no floating panel, overlay rect, or CanvasLayer above the game scene. Visual inspection of the scene tree confirms root Control nodes with full-rect anchors and zero CanvasLayer or Panel nodes at the root level.
- **SC-004**: Pause menu button navigation via arrow keys and Enter works correctly (focus moves between Resume and Return to Title, Enter activates focused button).
- **SC-005**: All existing pause menu actions (Resume, Return to Title) and shop actions (Continue, debug config) remain functional after the redesign.
- **SC-006**: Tile animations running on the board continue smoothly as the board slides off-screen (animations are not interrupted or cancelled by the pause transition).

## Assumptions

- The Run Setup view (`scenes/title_screen/run_setup_popup.tscn`) is the canonical reference pattern: full-rect Control, title label near top-center, centered VBoxContainer for content, keyboard hint near bottom-center.
- The current pause menu (`scenes/ui/pause_menu/pause_menu.tscn`) and shop overlay (`scenes/shop/shop_overlay.tscn`) are the only two screens requiring this change; other dialogs (e.g., discard confirmation, game over popup) are out of scope for this feature.
- The `DebugRoundConfigPopup` referenced in the shop overlay is a developer-only debug tool (not player-facing) and is explicitly exempt from the no-modal constitution rule. Only the shop's own root container structure must change; the popup remains as-is and stays a direct child of the Control root.
- Keyboard navigation behavior is expected to remain unchanged after the structural refactor.
