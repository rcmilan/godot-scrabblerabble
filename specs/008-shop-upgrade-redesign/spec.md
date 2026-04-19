# Feature Specification: Shop Upgrade Redesign

**Feature Branch**: `008-shop-upgrade-redesign`  
**Created**: 2026-04-19  
**Status**: Draft  
**Input**: User description: "Shop upgrade screen with modifier-to-tile drag system, preview mode, and commit workflow"

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

### User Story 1 - Enter Shop After Round Win (Priority: P1)

After successfully completing a round, the player's board slides up off-screen while the shop screen slides in from the bottom, replacing the game view. The shop displays 10 randomly selected tiles from the deck and 2 (or 3 for boss rounds) modifier options available for application.

**Why this priority**: Shop entrance is the foundational interaction. Without it, no upgrades can be applied. This is the critical path for all shop functionality.

**Independent Test**: Complete a non-boss round successfully. Verify: (1) board animates upward off-screen, (2) shop slides in from bottom simultaneously, (3) shop displays exactly 10 tiles in a scattered layout with no overlaps, (4) shop displays 2 modifier cards at top, (5) Revert and Commit buttons are visible and interactive.

**Acceptance Scenarios**:

1. **Given** a player has just won a round, **When** the round ends with success, **Then** the board animates off-screen upward and the shop animates in from the bottom within 500ms, both animations completing simultaneously.
2. **Given** the shop is open, **When** the player looks at the screen, **Then** they see exactly 10 tiles scattered randomly across the display with no visual overlaps.
3. **Given** the shop is open in a normal (non-boss) round, **When** they view the Upgrades section, **Then** they see exactly 2 modifier options displayed.
4. **Given** the shop is open in a boss round, **When** they view the Upgrades section, **Then** they see exactly 3 modifier options displayed.
5. **Given** the shop is displaying tiles, **When** the player examines any tile, **Then** they can see whether it has a pre-loaded modifier (came from deck with mod) or is unmodified (clean tile).

---

### User Story 2 - Drag Modifier Onto Tile to Preview (Priority: P1)

The player clicks a modifier card to select it, then drags it onto any unmodified tile. A custom ghost preview follows the cursor during the drag. When dropped onto a valid target (unmodified tile), a modifier badge immediately appears on that tile, showing the modifier has been "applied" in preview mode.

**Why this priority**: This is the core interaction loop. Players must be able to preview modifier assignments before committing. Without this, there's no meaningful decision-making in the shop.

**Independent Test**: Open shop with clean tiles. Click on a modifier, drag it to an unmodified tile, and release. Verify: (1) custom ghost follows cursor during drag, (2) tile highlights or shows drop-target feedback, (3) modifier badge appears on tile immediately on drop, (4) modifier card remains selectable for dragging to another tile (if another unmodified tile exists).

**Acceptance Scenarios**:

1. **Given** the shop is open and a modifier is unassigned, **When** the player clicks the modifier card, **Then** the modifier is visually marked as "selected" and ready to drag.
2. **Given** a modifier is selected, **When** the player drags it toward the tiles section, **Then** a custom ghost appears and follows the cursor precisely.
3. **Given** the player is dragging a modifier over an unmodified tile, **When** they move the ghost over the tile, **Then** the tile shows visual feedback (highlight, glow, or drop-target indicator) indicating a valid drop zone.
4. **Given** the player is dragging a modifier over a tile that already has a modifier, **When** they move the ghost over that occupied tile, **Then** the tile shows "forbidden" visual feedback (red X, disabled state, or invalid indicator) and the drag cannot complete.
5. **Given** the player drops a valid modifier drag onto an unmodified tile, **When** the drop completes, **Then** a modifier badge appears on the tile immediately and the modifier is no longer available in the Upgrades section (can only be on one tile).

---

### User Story 3 - Swap Modifier on Pre-Loaded Tile (Priority: P1)

If a tile came from the deck with a pre-loaded modifier, the player can drag a different modifier onto that tile to replace it. The original pre-loaded modifier returns to the available pool in the Upgrades section, and the new modifier is locked to that tile until Revert is pressed (which will restore the original pre-loaded modifier, not remove it).

**Why this priority**: Pre-loaded tiles (tiles that came with modifiers already on them) must be manageable. Players need to be able to optimize their upgrades even if a tile arrived pre-modified.

**Independent Test**: Open a shop where at least one of the 10 tiles has a pre-loaded modifier. Drag a different modifier onto that pre-loaded tile. Verify: (1) the pre-loaded modifier returns to the available pool, (2) the new modifier badge appears on the tile, (3) if Revert is pressed, the new modifier is removed and the original pre-loaded modifier reappears (tile reverts to original state).

**Acceptance Scenarios**:

1. **Given** a tile has a pre-loaded modifier and the player drags a different modifier onto it, **When** the drop completes, **Then** the pre-loaded modifier returns to the Upgrades section and the new modifier badge appears on the tile.
2. **Given** a tile's pre-loaded modifier has been swapped with a session-applied modifier, **When** the player presses Revert, **Then** the session-applied modifier is removed and the original pre-loaded modifier reappears on the tile (tile returns to original pre-load state).
3. **Given** a tile has a pre-loaded modifier, **When** the player attempts to drag that same modifier to another tile, **Then** the drag is forbidden (visual feedback shows invalid drop zone) because the modifier is already in use.

---

### User Story 4 - Revert Session Changes (Priority: P1)

The player can press the Revert button at any time while in the shop. This clears all modifiers applied in the current shop session, returning tiles to their original state (keeping any pre-loaded modifiers intact). The same 10 tiles remain visible. Revert does not close the shop.

**Why this priority**: Revert is essential for player agency. Without it, a misplaced drag could force an unwanted purchase. This is a critical safety valve.

**Independent Test**: Open shop, apply some modifiers to clean tiles, then click Revert. Verify: (1) all player-applied modifiers disappear, (2) all pre-loaded modifiers remain unchanged, (3) shop stays open and same 10 tiles are still displayed, (4) Upgrades section shows all original modifiers again (including those just reverted).

**Acceptance Scenarios**:

1. **Given** the player has applied modifiers to tiles in the shop, **When** they click the Revert button, **Then** all player-applied modifiers are removed from tiles, but all pre-loaded modifiers remain unchanged.
2. **Given** Revert has been pressed, **When** the player looks at the Upgrades section, **Then** all originally available modifiers are selectable again (previously dragged modifiers are back in the pool).
3. **Given** the shop is open and Revert is pressed, **When** the action completes, **Then** the shop remains open with the same 10 tiles still displayed, allowing the player to make different modifier choices.

---

### User Story 5 - Commit Changes and Return to Hand (Priority: P1)

The player clicks the Commit button to lock in all modifier assignments (both session-applied and pre-loaded unchanged tiles). The shop then slides out the top of the screen while the board slides back in from the bottom. The committed tiles are added to the player's hand for the next round. Any unused modifiers are discarded and will not appear in future shops.

**Why this priority**: Commit is the transaction finalization. Without it, there's no way to lock in purchases and proceed to the next round. This is the critical path to progression.

**Independent Test**: Open shop, apply modifiers to some tiles, click Commit. Verify: (1) shop slides out top of screen and board slides in from bottom simultaneously, (2) animation completes within 500ms, (3) modified tiles appear in the player's hand in the next round, (4) pre-loaded modifiers are also present on their tiles in the next round.

**Acceptance Scenarios**:

1. **Given** the player has previewed modifier assignments in the shop, **When** they click the Commit button, **Then** the shop slides out the top of the screen while the board slides in from the bottom within 500ms.
2. **Given** the player has committed to modifier assignments, **When** the next round begins, **Then** the tiles with session-applied modifiers are added to their hand with those modifiers active.
3. **Given** the player has committed, **When** the next round begins, **Then** any tiles with pre-loaded modifiers still have those modifiers active (pre-loaded state persists).
4. **Given** the player used only 1 of 2 available modifiers in the shop, **When** Commit is pressed and the next shop appears, **Then** the unused modifier does not appear again (it was a one-time offer).

---

### User Story 6 - Keyboard Navigation and Accessibility (Priority: P2)

The player can navigate the shop using only keyboard input. TAB cycles through focusable elements (modifier cards, tiles, Revert button, Commit button). Arrow keys move focus between tiles in logical directions. Enter/Space activates a focused modifier card (selects it) or presses a focused button. This supports players who prefer or require keyboard-only control.

**Why this priority**: Accessibility and inclusive design ensure all players can use the feature regardless of input preference or ability. TAB navigation is expected in modern UIs.

**Independent Test**: Open shop and play through the entire upgrade flow using only keyboard (TAB, arrow keys, Enter). Verify: (1) TAB cycles through all focusable elements in logical order, (2) arrow keys move focus between adjacent tiles (left/right/up/down based on scattered layout), (3) Enter activates focused modifier (selects it for drag), (4) a selected modifier can be "dragged" via keyboard to a focused tile using arrow keys + Enter, (5) Revert and Commit buttons are reachable and activatable via keyboard.

**Acceptance Scenarios**:

1. **Given** the shop is open, **When** the player presses TAB repeatedly, **Then** focus cycles through modifier cards, then tiles, then Revert/Commit buttons, then loops back to start.
2. **Given** a modifier is focused, **When** the player presses Enter, **Then** the modifier is selected (visual state changes to "selected").
3. **Given** a selected modifier is active, **When** the player presses arrow keys to navigate to a tile and presses Enter, **Then** the modifier is applied to that tile (simulating drag-and-drop via keyboard).
4. **Given** the shop is open, **When** the player presses TAB to reach the Revert or Commit buttons and presses Enter, **Then** the button action executes.

---

### User Story 7 - Scattered Tile Layout Without Overlaps (Priority: P2)

The 10 tiles in the shop are displayed in a scattered, naturalistic layout across the tiles section, with no visual overlaps and no grid pattern. Tiles appear "thrown" or "spread" as if placed randomly on a surface, creating visual interest and distinction from the orderly board grid.

**Why this priority**: This is the visual identity and UX differentiation of the shop. The scattered layout creates the feeling of a separate space and encourages exploration. However, it's secondary to core functionality.

**Independent Test**: Open shop multiple times and examine the tile layout. Verify: (1) no two tiles overlap visually, (2) tiles are positioned with apparent randomness (not in a regular grid), (3) tile positions vary between shop visits (not hardcoded), (4) all 10 tiles fit within the Tiles section without being clipped.

**Acceptance Scenarios**:

1. **Given** the shop has generated 10 tiles, **When** they are displayed in the Tiles section, **Then** no two tiles visually overlap or cover each other.
2. **Given** 10 tiles have been positioned in the Tiles section, **When** the player examines them across multiple shop visits, **Then** the positions vary from visit to visit (not deterministic/hardcoded).
3. **Given** the Tiles section has a defined viewport/bounds, **When** 10 tiles are scattered, **Then** all tiles are fully visible and not clipped by section boundaries.

---

### Edge Cases

- **Multiple pre-loaded tiles**: If the 10-tile pool includes 3+ tiles with pre-loaded modifiers, the player can still only swap/reassign those modifiers as their original tiles allow.
- **Dragging over non-tile areas**: If the player drags a modifier over empty space (not over any tile), the ghost continues to follow, but there is no drop target feedback. Releasing the drag outside a valid tile cancels the drag (no-op).
- **Rapid successive drags**: If the player drags modifier A onto tile 1, then immediately drags modifier B onto tile 2 without releasing the first drag, the first drag completes on release and the second drag begins normally (no queueing or conflict).
- **All modifiers applied**: If the player applies all available modifiers (2 or 3) to tiles, the Upgrades section is empty but the player can still view applied modifiers and Revert if desired.
- **Closing shop without committing**: If the player closes the shop without pressing Commit (e.g., via ESC key or other route), all preview changes are discarded and the next shop visit will have newly randomized tiles and modifiers.

## Requirements *(mandatory)*

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right functional requirements.
-->

### Functional Requirements

- **FR-001**: The shop MUST appear as a full-screen Control node anchored to fill the viewport, matching the RunSetupView structural pattern (no CanvasLayer, no floating panels).
- **FR-002**: Shop entrance MUST animate from the bottom of the screen, sliding upward while the board simultaneously slides upward off-screen, both animations completing within 500ms.
- **FR-003**: Shop exit (on Commit) MUST animate out the top of the screen, sliding upward while the board simultaneously slides back in from the bottom, both animations completing within 500ms.
- **FR-004**: The shop MUST display exactly 10 randomly selected TileStates from the active deck (determined by run config: Standard, Cursed, or Equal). Tiles are retrieved via `RunManager.get_shop_tiles(count=10)`.
- **FR-005**: The shop MUST display 2 modifier options for normal rounds and 3 modifier options for boss rounds, each modifier randomly selected from available modifier pool. Modifiers are retrieved via `RunManager.get_shop_modifiers(count)` where count is 2 or 3 based on boss round status. Duplicate modifiers are allowed (same modifier can appear multiple times in the options for a single visit).
- **FR-006**: Each tile in the Tiles section MUST be positioned in a scattered, non-overlapping layout with apparent randomness (not grid-based). Tiles MUST NOT overlap with each other.
- **FR-007**: The shop MUST support drag-and-drop interaction: player clicks a modifier card to select it, then drags it onto a tile to apply it.
- **FR-008**: A custom ghost visual MUST appear and follow the cursor during a modifier drag. The ghost MUST be a full modifier card (matching the visual design of the card in the Upgrades section) that animates smoothly following the cursor position.
- **FR-009**: The shop MUST prevent dropping a modifier onto a tile that already has a modifier (max 1 modifier per tile). Invalid drop targets MUST show a red X prohibition overlay and trigger the ShakeTileAnimation (existing game animation) when the player attempts an invalid drop.
- **FR-010**: When a modifier is successfully dropped onto a tile, a modifier badge MUST appear on that tile immediately, visually indicating the modifier is applied.
- **FR-011**: If a tile has a pre-loaded modifier (came from deck with modifier already applied), that pre-loaded modifier MUST be swappable via drag-and-drop with a different modifier. Swapping MUST NOT remove the pre-loaded modifier permanently; Revert MUST restore it.
- **FR-012**: The Revert button MUST clear all player-applied (session) modifiers from tiles, returning them to their original state. Pre-loaded modifiers MUST remain unchanged after Revert.
- **FR-013**: The Commit button MUST finalize all modifier assignments and trigger the shop-exit animation (slide out top, board slide in from bottom).
- **FR-014**: On Commit, the modified tiles (copies with applied modifiers) MUST be created as new TileState instances and made available for the next round's gameplay. RunManager receives the commit signal and processes tile creation and hand population.
- **FR-015**: On Commit, all unused modifiers MUST be discarded and MUST NOT carry over to the next shop visit.
- **FR-016**: The shop MUST remain open after Revert (not close). The same 10 tiles and modifiers MUST remain visible for further editing.
- **FR-017**: The shop MUST support keyboard-only navigation: TAB to cycle focus, arrow keys to move between tiles, Enter to select a modifier or activate a button.
- **FR-018**: On Commit or shop close, all preview copies of tiles MUST be discarded (not persisted).
- **FR-019**: The shop MUST appear after every successful round, including boss rounds.
- **FR-020**: Each shop visit MUST re-randomize the 10 tiles and 2-3 modifiers (no carryover from previous shop visits).

### Key Entities *(include if feature involves data)*

- **ShopSession**: Represents the current shop visit state
  - `available_modifiers`: Array of ModifierType (2-3 random, determined by round type)
  - `available_tiles`: Array of TileState (10 random from deck)
  - `pending_assignments`: Dict mapping TileState → ModifierType (player-applied mods in preview mode)
  - `is_boss_round`: Boolean (true if shop is for a boss round, determines modifier count)

- **TileState**: Immutable representation of a tile in the shop preview
  - `tile_id`: Unique identifier
  - `character`: The tile's letter/character
  - `pre_loaded_modifier`: ModifierInstance | null (modifier that came from deck, cannot be removed)
  - `session_modifier`: ModifierInstance | null (modifier applied by player in this shop, can be reverted)

- **ModifierInstance**: Represents a single applied modifier effect
  - `modifier_type`: ModifierType (e.g., EXPO, MULTI, BONUS)
  - `applied_tile`: Reference to the tile it's applied to

- **ShopAnimation**: Animation strategy for enter/exit transitions
  - Inherits from TileAnimationStrategy or similar pattern
  - Defines shop slide-in (from bottom) and slide-out (to top) behavior
  - Board counterpart animations (slide out/in from top)

## Success Criteria *(mandatory)*

<!--
  ACTION REQUIRED: Define measurable success criteria.
  These must be technology-agnostic and measurable.
-->

### Measurable Outcomes

- **SC-001**: Shop animations (entrance and exit) complete within 500ms, both animations (shop + board) start and end simultaneously with no stagger or delay.
- **SC-002**: Drag-and-drop interaction is responsive: modifier ghost appears immediately on drag start (within 50ms of mouse down), follows cursor with no perceptible lag (60fps smooth motion).
- **SC-003**: Player can complete a full shop interaction (view, apply 1-2 modifiers, commit) in under 30 seconds for a typical play session (measured from shop open to commit confirmation).
- **SC-004**: All 10 tiles display without visual overlaps in 100% of shop visits (verified across multiple random layouts).
- **SC-005**: Keyboard-only navigation works without mouse input: all focusable elements are reachable via TAB, all buttons activatable via Enter, and tile selection/application possible via arrow keys + Enter.
- **SC-006**: Modified tiles correctly appear in the player's hand in the next round with all committed modifiers active (zero loss of modifier data on commit).
- **SC-007**: Revert button successfully clears all player-applied modifiers and restores tiles to pre-load state within 100ms of button press.
- **SC-008**: Each shop visit re-randomizes tiles and modifiers with no carryover from previous visits (verified by opening shop multiple times and confirming variety).

## Clarifications

### Session 2026-04-19

- Q: How should the shop retrieve the 10 tiles and modifier pool? → A: RunManager provides tiles via `RunManager.get_shop_tiles(count=10)` which draws from the active run's deck; modifier pool similarly from RunManager.
- Q: How should committed tiles be added to the player's hand? → A: RunManager manages the commit transaction: shop signals completion to RunManager, which creates the modified tiles and makes them available for the next round's gameplay.
- Q: What if modifier pool doesn't have enough unique modifiers for 2-3 options? → A: Duplicates are allowed. Same modifier can appear multiple times in the 2-3 options per visit (e.g., "EXPO" twice for normal round).
- Q: Should pre-loaded modifiers be guaranteed in every shop, or random? → A: Random distribution based on deck. If deck tile definitions include pre-loaded modifiers, they appear randomly in the 10-tile pool. No minimum guarantee.
- Q: What visual feedback for invalid drops (occupied tiles)? → A: Red X prohibition overlay on the tile + reuse existing ShakeTileAnimation to provide motion feedback when drag is rejected.

## Assumptions

- The active deck (Standard, Cursed, or Equal) is determined by run config and is available to ShopSession at initialization.
- TileState objects used in the shop are independent copies and do not directly mutate the player's hand. Committed tiles are new instances created from the previewed copies.
- Animation infrastructure follows the existing TileAnimationStrategy pattern; shop slide animations reuse or extend this pattern rather than creating a new animation system.
- Modifier pool includes all modifier types in the game (e.g., EXPO, MULTI, BONUS, etc.). The shop randomly selects 2-3 unique modifiers per visit.
- Keyboard navigation follows standard web/UI convention: TAB moves forward, Shift+TAB moves backward, arrow keys move between adjacent focusable elements.
- "Scattered layout" is acceptable if achieved via simple grid-with-jitter algorithm (no complex physics simulation required).
- Boss rounds are identified by `current_round_config.is_boss_round` flag in RunManager.
- Pre-loaded modifiers come from the deck's initial tile definitions and are immutable for the duration of the shop session (they can only be swapped, not removed individually). Distribution is random based on what tiles are drawn; no minimum count is guaranteed.
- Mouse-based drag-and-drop is the primary interaction, with keyboard fallback for accessibility (keyboard "drag" simulated via focus + arrow keys + Enter).
