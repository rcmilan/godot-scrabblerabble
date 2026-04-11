# Feature Specification: Boss Entities System

**Feature Branch**: `005-boss-entities`  
**Created**: 2026-04-10  
**Status**: Draft  
**Input**: User description: "Create boss entities that can customize game mechanics. Build on 004-boss-rounds. Each boss has a background color, can modify board cells (unavailable/removed), apply tile rules (e.g., diagonal multipliers), impose Play button rules (tiles on hand/board requirements), post-play effects (e.g., tiles shift right), modify plays/target score per round, multiply tiles in hand, activate time attack modes. Create Gravity boss: after Play, all placed tiles drop to bottom row or lowest available tile (animated, purple #330033 background). Bosses appear once in random order per run; prepare for endless mode."

---

## Clarifications

### Session 2026-04-10

- Q: Does Gravity's drop affect only the current play's unlocked tiles, or all tiles placed across the entire round (including locked tiles from earlier plays)? -> A: Drop only the current play's tiles (unlocked tiles). Tiles locked from earlier plays stay in place. This creates a stacking puzzle where play 1's tiles lock in their dropped positions, then play 2's tiles drop on top of them.
- Q: Should the round indicator display the boss name during boss rounds? -> A: Yes, show the boss name (e.g., "Gravity") instead of generic "Boss Round." Players need to know which boss's rules are active.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Boss Selection and Appearance (Priority: P1)

When a player reaches a Boss Round (established in 004-boss-rounds), the game selects a specific boss from the available pool and applies that boss's visual identity. The player immediately sees the boss's background color and recognizes they are facing a unique challenge.

**Why this priority**: Boss identification is the foundation. Without this, players cannot distinguish between bosses or understand which special rules are active. This story enables all subsequent boss-specific mechanics.

**Independent Test**: Play through 3 rounds until reaching Round 3 (Boss Round). Verify a boss background color displays (not the normal round color). Start multiple runs and verify different boss backgrounds appear on different Round 3 encounters. Create a second boss and verify it has a distinct color.

**Acceptance Scenarios**:

1. **Given** Round 3 (a Boss Round) begins, **When** gameplay transitions to active, **Then** the background displays a boss-specific color (not the normal round light red).
2. **Given** a player completes a run and starts a new one, **When** Round 3 is reached again, **Then** a boss appears (may be the same or different from the previous run, depending on randomization).
3. **Given** multiple bosses exist in the pool (e.g., Gravity and a second boss), **When** different runs are played, **Then** different background colors appear on Round 3 encounters.
4. **Given** Gravity boss is active, **When** the gameplay screen is visible, **Then** the background color is purple (#330033) and the round indicator displays "Gravity".

---

### User Story 2 - Gravity Boss Drop Mechanic (Priority: P1)

When Gravity boss is active and the player presses Play, all tiles that were placed on the board during that round "drop" to either the bottom row of the board or to the lowest available cell in their column. This drop is animated.

**Why this priority**: Gravity is the first implemented boss and its mechanic is the primary showcase of boss customization. This story demonstrates that bosses can fundamentally alter game behavior. It must work perfectly to validate the entire boss architecture.

**Independent Test**: Reach Round 3 with Gravity boss active. Place tiles in the middle of the board and press Play. Verify all placed tiles animate downward and stop at the bottom row or the first occupied cell below them. Verify tiles locked from earlier plays are not affected. Verify the drop animation is visible and smooth.

**Acceptance Scenarios**:

1. **Given** Gravity is active and tiles are placed on empty cells in column A (rows 2-4), **When** the player presses Play, **Then** all placed tiles animate downward and settle on row 8 (bottom row).
2. **Given** Gravity is active and a tile locked from a previous play occupies row 6 in column B, **When** new tiles are placed above it (rows 3-5) in column B and Play is pressed, **Then** the new tiles animate downward and stop at row 5 (directly above the locked tile).
3. **Given** Gravity is active and mixed tiles are placed (some in columns with existing tiles, some in empty columns), **When** Play is pressed, **Then** all placed tiles animate downward simultaneously and settle correctly per their column state.
4. **Given** the drop animation is in progress, **When** the animation completes, **Then** the tiles are locked in their final positions and the Play flow continues (scoring is calculated on the dropped positions).

---

### User Story 3 - Boss Customization Options (Priority: P2)

The boss entity architecture supports a wide range of customization options that allow future bosses to modify board cells, tile multipliers, Play button constraints, post-play effects, round parameters, and time mechanics without requiring code changes. The system is extensible and composable.

**Why this priority**: This establishes the infrastructure for future boss variety. Without a flexible customization system, each new boss will require custom code. Building this seam now enables rapid boss creation in future iterations.

**Independent Test**: Inspect the boss entity structure and verify it exposes hooks or properties for: unavailable cells, tile rules, Play button validation rules, post-play effects, play count, target score, hand modifications, and time attack configuration. Verify a new boss can be created and registered using this structure. Verify existing game systems (board, hand, scoring, play button) can query and react to these customizations.

**Acceptance Scenarios**:

1. **Given** the boss system is implemented, **When** a developer creates a new boss with custom unavailable cells, **Then** the board respects those cells and prevents tile placement on them without custom cell-placement code.
2. **Given** a boss defines tile multiplier rules (e.g., main diagonal = 2x), **When** scoring calculates points for tiles on those positions, **Then** the multiplier is applied without custom scoring code.
3. **Given** a boss defines a Play button rule (e.g., "only available if player has fewer than 4 tiles on hand"), **When** the player places tiles and the hand state matches the rule, **Then** the Play button is enabled/disabled without custom play-button code.
4. **Given** a boss defines a post-play effect (e.g., "tiles shift one cell right"), **When** Play is pressed, **Then** the effect is executed without custom effect code.
5. **Given** a boss defines custom play count (e.g., 2 plays per round instead of default), **When** the round becomes active, **Then** the play limit is enforced.
6. **Given** a boss defines custom target score (e.g., 150 instead of 100), **When** the round ends, **Then** the custom target is used for win/loss calculation.

---

### User Story 4 - Boss Pool and Randomization (Priority: P2)

The game maintains a pool of available bosses. In normal gameplay (non-endless), each boss appears exactly once per run in random order, spread across the boss rounds. When all bosses have been defeated, the run ends (victory or loss based on score). The system is prepared to support endless mode in future iterations.

**Why this priority**: Randomization ensures variety and replayability. Sequential appearance prevents repetition fatigue. The structure must support endless mode as a future option without refactoring.

**Independent Test**: Play multiple runs and track which bosses appear in boss rounds (Rounds 3, 6, 9, etc.). Verify no boss repeats in a single run. Verify different runs show different boss orderings. Verify once all bosses are defeated, the run ends (shop/game over screen appears, not another boss round).

**Acceptance Scenarios**:

1. **Given** a run has 3 bosses in the pool (Gravity, Boss2, Boss3), **When** the player reaches Round 3, 6, and 9, **Then** three different bosses appear in random order, each appearing exactly once.
2. **Given** Gravity appeared in Round 3 of the current run, **When** Round 6 is reached, **Then** Gravity does not appear again; a different boss is selected.
3. **Given** all bosses have been defeated in a run, **When** the next boss round would occur (Round 12 in a 3-boss run with no endless mode), **Then** the run ends instead and the game over/victory screen appears.
4. **Given** a new run is started, **When** Round 3 is reached, **Then** the boss pool is reset; bosses that appeared in the previous run may appear again.

---

### User Story 5 - Boss Integration with Round System (Priority: P2)

Boss entity data integrates cleanly with the existing Round system (from 004-boss-rounds). When a boss round begins, the round-type classification correctly identifies it as a boss, and the selected boss entity is accessible to all game systems so they can apply custom rules.

**Why this priority**: Integration ensures bosses work within the established round framework without creating redundant systems. This allows the two features to compose cleanly.

**Independent Test**: Query the domain round object during a Boss Round. Verify the round-type is "Boss", and verify a reference to the active boss entity is available. Verify game systems (board, hand, play executor) can access and query the boss entity. Verify the boss's background color is applied via the same mechanism as the normal round color transition (1.0s smooth animation).

**Acceptance Scenarios**:

1. **Given** Round 3 is active with Gravity boss selected, **When** any game system queries the current round, **Then** it receives the Boss Round designation and a reference to the Gravity boss entity.
2. **Given** Round 4 (a normal round) begins, **When** any game system queries the current round, **Then** it receives the Normal Round designation and no boss entity reference.
3. **Given** a Boss Round transitions to active, **When** the background color animates to the boss's color, **Then** the animation uses the same 1.0s smooth transition mechanism established in 004-boss-rounds.

---

### Edge Cases

- What happens if the boss pool is empty? System MUST gracefully handle (e.g., treat as non-boss or default to normal round).
- What if a player presses Play before the Gravity drop animation completes? System MUST prevent duplicate Play presses during animation.
- What if a cell is marked unavailable by a boss but already occupied by a tile? System MUST handle (e.g., prevent new tiles on that cell only, or retroactively block it).
- What if a boss defines conflicting rules (e.g., "Play available only if X tiles" AND "Play available only if Y tiles")? System MUST compose rules with clear precedence (e.g., AND logic: all must be true).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A Boss entity MUST be a data structure containing at least: (1) a unique identifier, (2) a display name, (3) a background color (hex or RGB), and (4) references to customization rules/effects.
- **FR-002**: The boss system MUST maintain a global registry of available bosses. Bosses MUST be registered at startup (possibly via asset files or hardcoded definitions).
- **FR-003**: When a Boss Round begins (as classified in 004-boss-rounds), the game MUST select one boss from the available pool using random-without-replacement selection. The boss pool MUST track which bosses have been selected in the current run and MUST ensure no boss repeats until all bosses are exhausted.
- **FR-004**: The selected boss MUST be stored in the active Round domain object so that any game system can query it during that round.
- **FR-005**: The boss's background color MUST be applied to the gameplay screen when the boss round begins, using the same 1.0s smooth transition animation mechanism established in 004-boss-rounds.
- **FR-005a**: The round indicator label MUST display the boss's display_name (e.g., "Gravity") during boss rounds instead of the generic "Boss Round" text established in 004-boss-rounds. During normal rounds, the label continues to display "Round [x]".
- **FR-006**: Gravity boss MUST be implemented with the following behavior: when Play is pressed, all unlocked tiles (tiles placed since the last Play in the current round) MUST animate downward to the bottom row of their respective columns or to the first occupied cell below them, whichever comes first. Tiles locked from earlier plays within the same round MUST NOT move.
- **FR-007**: The Gravity drop animation MUST be executed using the existing animation system pattern (/scripts/animation). The implementation MUST follow the established strategy+executor pattern (extending TileAnimationStrategy and AnimationExecutor base classes) rather than creating a separate animation framework.
- **FR-008**: Gravity boss MUST have a background color of #330033 (purple).
- **FR-009**: The boss customization system MUST support the following extensible hooks (not necessarily all implemented for Gravity, but structure MUST exist):
  - **Cell Unavailability**: A hook to mark cells as unavailable, preventing tile placement on them.
  - **Tile Rules**: A hook to apply multipliers or effects to tiles based on their position or type.
  - **Play Button Validation**: A hook to define constraints (e.g., "available only if hand has <4 tiles").
  - **Post-Play Effects**: A hook to execute effects after Play is submitted (e.g., "all placed tiles shift right").
  - **Play Count**: A hook to override the default plays per round.
  - **Target Score**: A hook to override the default target score for the round.
  - **Hand Modification**: A hook to duplicate/remove/transform tiles in the hand.
  - **Time Attack**: A hook to activate a countdown timer and modify time limits per play.
- **FR-010**: When all bosses in the pool have been defeated in a single run, there MUST NOT be another boss round. The next potential boss round cycle MUST result in run victory (the player has overcome all bosses) instead of selecting a new boss. The game displays the victory screen.
- **FR-011**: The system MUST be structured to support endless mode as a future feature (e.g., resetting the boss pool, cycling through bosses repeatedly, or introducing new bosses) without requiring architectural changes to the core boss entity or registry.
- **FR-012**: Play button interaction MUST be blocked while the Gravity drop animation (or any boss post-play animation) is in progress. No double-submit or out-of-order actions are permitted.

### Key Entities

- **Boss**: A data structure representing a unique boss entity with identity, display name, background color, and customization hooks. Examples: Gravity, Future Boss 2, Future Boss 3.
- **BossPool**: An ordered list of available bosses for a run. Tracks selected bosses to ensure no repeats (random without replacement).
- **BossCustomizationHooks**: An extensible interface that bosses implement to provide behaviors (cell rules, tile effects, post-play actions, etc.).
- **Round** (enhanced from 004-boss-rounds): Carries a reference to an active boss (if it is a Boss Round) in addition to round type classification.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Gravity boss background (#330033 purple) is visible and animates smoothly (1.0s transition) when Round 3 is reached.
- **SC-002**: Gravity drop animation is visually smooth, takes 0.5–1.0 seconds, and all dropped tiles settle in correct final positions (bottom row or first occupied cell below).
- **SC-003**: Gravity boss mechanic works correctly in at least 5 consecutive test runs: tiles drop as expected, no tiles are lost, no animation glitches occur.
- **SC-004**: A player cannot press Play during the Gravity drop animation; the button is disabled until the animation completes.
- **SC-005**: In a multi-boss run, each boss appears in a unique boss round and no boss repeats. Different runs show different random orderings. Note: With only Gravity implemented, verify that Gravity appears exactly once on Round 3 and the run ends after that boss round. Full multi-boss validation deferred until additional bosses are added.
- **SC-006**: Once all bosses are selected in a run, the next potential boss round results in run termination (no infinite boss cycles without endless mode enabled).
- **SC-007**: All customization hooks (cell unavailability, tile rules, play button constraints, post-play effects, etc.) are queryable by game systems without hardcoding boss-specific logic. A future boss can be created and integrated without modifying existing systems.
- **SC-008**: The boss entity integrates with the Round domain without redundancy; no duplication of round-type or round-number tracking.
- **SC-009**: Gravity drop animation follows the existing strategy+executor pattern from /scripts/animation, extending TileAnimationStrategy and AnimationExecutor base classes. No new animation framework or infrastructure beyond the new strategy and executor files is required.

## Assumptions

- Boss pool is non-empty; at least one boss (Gravity) exists at all times.
- Background color transition uses the same easing curve and 1.0s duration established in 004-boss-rounds.
- "Drop" for Gravity means tiles animate from their current position to their final position, following gravity (downward). They do not rotate, flip, or change appearance during the drop.
- Gravity's drop animation is queued and executes fully before scoring is calculated on the dropped positions. The play flow is not concurrent.
- Cells marked unavailable by a boss are visual/logical barriers; tiles cannot be placed on them. The board layout respects this (no rendering of those cells, or rendering them as blocked).
- Boss customization hooks are optional; a boss can implement none, some, or all of them. The system gracefully handles bosses with minimal customization.
- Endless mode is explicitly OUT OF SCOPE for this feature. The structure must prepare for it (e.g., with a future flag or mode selector), but the logic to cycle bosses infinitely is not implemented now.
- Gravity is the only boss implemented in this feature. Customization hooks are defined but may not all be exercised by Gravity; they are scaffolding for future bosses.
- Play button behavior during animations: the Play button is disabled (visually and functionally) during any boss-driven animation. No grace period or spam-click tolerance is needed.
- Timer/Time Attack mode is mentioned as a customization hook but is NOT implemented for Gravity in this feature (out of scope; reserve for a future time-attack boss).
