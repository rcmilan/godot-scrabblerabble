# Feature Specification: Pause Menu and Shop UI Redesign

**Feature Branch**: `003-pause-shop-ui-fix`
**Created**: 2026-04-04
**Status**: Draft
**Input**: User description: "lets fix the UI for the pause menu and for the shop. The UI for both the pause menu and the shop should be created the same way we do on the New Game/Run Setup. Modals/Dialogs/Popups are forbiden."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Pause Menu as Full-Screen View (Priority: P1)

When a player pauses the game mid-round, the pause menu replaces the game view as a full-screen Control node -- not a floating panel or overlay dialog. It is shown and hidden by toggling visibility, matching the same structural pattern as the Run Setup screen.

**Why this priority**: The pause menu is accessed frequently during play. Getting its presentation pattern right is fundamental to the consistency requirement. It is also simpler than the shop, making it a good starting point.

**Independent Test**: Pause the game during a round and verify the pause menu fills the screen as a dedicated view with no dimmed overlay, no floating panel, and no CanvasLayer above the game.

**Acceptance Scenarios**:

1. **Given** a player is in an active round, **When** they trigger the pause action, **Then** the pause menu fills the entire screen as a Control node with anchors covering the full rect, and the game view is hidden behind it (not dimmed beneath it).
2. **Given** the pause menu is visible, **When** the player selects "Resume", **Then** the pause menu hides (visible = false) and the game view returns.
3. **Given** the pause menu is visible, **When** the player selects "Return to Title", **Then** the game transitions to the title screen.
4. **Given** the pause menu is displayed, **Then** no CanvasLayer, ColorRect overlay, Panel, or popup/dialog node is used as the root of the pause menu structure.

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
- When the pause menu or shop appears while the underlying game scene is animating tiles, the animations continue beneath the full-screen view. No freeze or cancellation is required; the view renders on top via sibling tree order.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The pause menu MUST be implemented as a full-screen Control node with full-rect anchors, shown and hidden via the `visible` property, consistent with how RunSetupView is structured.
- **FR-002**: The shop MUST be implemented as a full-screen Control node with full-rect anchors, shown and hidden via the `visible` property, consistent with how RunSetupView is structured.
- **FR-003**: Neither the pause menu nor the shop MUST use a CanvasLayer, ColorRect dimming overlay, floating Panel, AcceptDialog, ConfirmationDialog, Popup, or any modal/dialog node type as the root or primary container.
- **FR-004**: The pause menu MUST preserve all existing actions: Resume and Return to Title.
- **FR-005**: The shop MUST preserve all existing information and actions: round summary labels, Continue button, and the debug round config trigger.
- **FR-006**: Both screens MUST include a title label and keyboard hint label at consistent positions, following the Run Setup layout convention (title anchored near top-center, hint anchored near bottom-center). The pause menu hint text is "Press Escape to resume". The shop hint text is "Press Enter to continue".
- **FR-007**: Content in both screens MUST be centered on the full-screen layout using a VBoxContainer anchored to the screen center, consistent with the ContentContainer pattern in Run Setup.

### Key Entities

- **PauseMenu**: Full-screen Control replacing the current CanvasLayer-based PauseMenu (class name unchanged).
- **ShopOverlay**: Full-screen Control replacing the current CanvasLayer-based ShopOverlay (class name unchanged).
- **RunSetupView**: The reference layout pattern both screens must mirror structurally.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Both the pause menu and shop screens fill 100% of the viewport with no floating panel, overlay rect, or CanvasLayer above the game scene. Visual inspection of the scene tree confirms a root Control node with full-rect anchors and zero CanvasLayer or Panel nodes at the root level, matching the structure of RunSetupView.
- **SC-002**: All existing pause menu actions (Resume, Return to Title) and shop actions (Continue, debug config) remain accessible and functional after the redesign.
- **SC-003**: Players can navigate and activate all buttons on both screens without any regression in behavior compared to the previous implementation.

## Assumptions

- The Run Setup view (`scenes/title_screen/run_setup_popup.tscn`) is the canonical reference pattern: full-rect Control, title label near top-center, centered VBoxContainer for content, keyboard hint near bottom-center.
- The current pause menu (`scenes/ui/pause_menu/pause_menu.tscn`) and shop overlay (`scenes/shop/shop_overlay.tscn`) are the only two screens requiring this change; other dialogs (e.g., discard confirmation, game over popup) are out of scope for this feature.
- The `DebugRoundConfigPopup` referenced in the shop overlay is a developer-only debug tool (not player-facing) and is explicitly exempt from the no-modal constitution rule. Only the shop's own root container structure must change; the popup remains as-is and stays a direct child of the Control root.
- Keyboard navigation behavior is expected to remain unchanged after the structural refactor.
