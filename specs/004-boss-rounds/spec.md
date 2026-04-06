# Feature Specification: Boss Rounds and Round Counter

**Feature Branch**: `004-boss-rounds`  
**Created**: 2026-04-06  
**Status**: Draft  
**Input**: User description: "let's improve our 'Round' feature. first we have to set the ubiquous language: by Round I mean a number of Plays, by 'Play' I mean the player's action to press Enter (or click the Play button) triggering the flow that will lock the tiles on the board. The Play action is already implemented. Right now the game runs on some kind of 'endless mode'. After a number of rounds (we can stabilsh this as a multiple of 3) the player will face a 'Boss' round, eg: Rounds 1 and 2 are normal, 3 is a boss, 4 and 5 normal, 6 boss etc... In the future Boss rounds will have special rules that may affect any one of the game's features eg: the hand, the board, the score, the tile modifiers etc... we should prepare for that. Right now we'll only signal we're on a boss round by changing the background color: white for normal, light red for boss. Remove the MULTI [Q] icon, replace it with a text to display 'Round [x]' or 'Boss Round', where [x] is the round number, needless to say that this number resets when a new game is starts. We should modify the text of our 'Autowin' run modifier to fit the ubiquous language"

---

## Clarifications

### Session 2026-04-06

- Q: Where should the "Round X / Boss Round" label be positioned -- top-left (where MULTI [Q] was) or updating the existing top-right RoundLabel? -> A: Top-left (where MULTI [Q] was). A new standalone label replaces the MULTI [Q] indicator in that position. The top-right stats column (RoundLabel, PlaysLabel, ScoreLabel, etc.) is a debug panel scheduled for removal in a future feature; it is not the canonical round display.
- Q: How long should the background color transition take? -> A: 1.0 seconds. The transition must be smooth (eased), apply whenever the background changes between any two colors, and be generic enough to support future background colors without modifying the animation mechanism.

---

## Ubiquitous Language

These terms are canonical and must be used consistently across all code, UI text, and documentation:

- **Play**: The player action of pressing Enter (or clicking the Play button) that locks the tiles currently placed on the board and triggers scoring.
- **Round**: A game unit consisting of one or more Plays. The player progresses through Rounds in sequence.
- **Normal Round**: A Round with standard rules and no special modifiers.
- **Boss Round**: Every 3rd Round (3, 6, 9, ...). Currently distinguished only by visual cues; future versions may impose special rules.
- **Round Number**: A 1-based integer tracking the current Round within a game run. Resets to 1 when a new game starts.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Round Counter Display (Priority: P1)

When playing the game, the player can always see which Round they are on. The MULTI [Q] mode indicator is removed from the HUD and replaced with a Round label that displays "Round [x]" for Normal rounds and "Boss Round" for Boss rounds.

**Why this priority**: The Round Counter is the foundational UI change required by all other stories. Without it no round awareness is communicated to the player.

**Independent Test**: Start a new game. Verify the HUD displays "Round 1". Complete a Round and verify it updates to "Round 2". Reach Round 3 and verify it displays "Boss Round". Start a new game and confirm the display resets to "Round 1".

**Acceptance Scenarios**:

1. **Given** a game has just started, **When** the HUD is visible, **Then** it displays "Round 1".
2. **Given** the player completes Round 2 and Round 3 begins, **When** the HUD updates, **Then** it displays "Boss Round".
3. **Given** the player completes Round 3 and Round 4 begins, **When** the HUD updates, **Then** it displays "Round 4".
4. **Given** a new game starts after a previous run, **When** the HUD is first shown, **Then** the Round label resets to "Round 1".
5. **Given** the MULTI [Q] icon previously existed in the HUD, **When** the game runs, **Then** no MULTI [Q] indicator is visible anywhere.

---

### User Story 2 - Boss Round Visual Signal (Priority: P2)

When a Boss Round begins, the game background color changes to light red, giving the player an immediate environmental cue that the stakes are higher. Normal rounds use a white or near-white background.

**Why this priority**: Visual differentiation of Boss rounds is the main feature deliverable. It establishes the Boss Round as a distinct game state visible at a glance, laying groundwork for future Boss-specific rules.

**Independent Test**: Play through 3 Rounds. On Round 3 (Boss Round) verify the background is light red. On Round 4 (Normal Round) verify the background returns to white or near-white.

**Acceptance Scenarios**:

1. **Given** a Normal Round is active, **When** the gameplay screen is visible, **Then** the background color is white or near-white.
2. **Given** Round 3 begins (first Boss Round), **When** the gameplay screen transitions to active, **Then** the background color changes to light red.
3. **Given** Round 4 begins after a Boss Round, **When** the gameplay screen is active, **Then** the background color returns to white or near-white.
4. **Given** a new game starts, **When** Round 1 begins, **Then** the background is white or near-white regardless of the previous run's last round type.

---

### User Story 3 - Boss Round Domain Extensibility (Priority: P2)

The game's round progression logic exposes a concept of round type (Normal vs Boss) that future features can query and react to. No special Boss rules are implemented now, but the structure must exist so future rules can be added without re-architecting the domain.

**Why this priority**: Without a round-type abstraction in the domain layer, adding Boss Round rules later will require scattered hacks. Building the seam now costs little and prevents expensive retrofits.

**Independent Test**: Inspect the domain layer for a round-type property or equivalent on the round configuration or progression rules. Verify that the Boss Round visual change is driven by this domain concept, not by a hardcoded round-number check in the UI layer.

**Acceptance Scenarios**:

1. **Given** Round 3 is active, **When** any game system queries the current round type, **Then** it receives "Boss" or equivalent domain value.
2. **Given** Round 4 is active, **When** any game system queries the current round type, **Then** it receives "Normal".
3. **Given** a Boss Round begins, **When** the background color changes to light red, **Then** that change is triggered by the round-type domain concept, not a raw numeric check in the visual layer.

---

### User Story 4 - Autowin Modifier Language Update (Priority: P3)

The Auto Win run modifier name and description are updated to use the canonical terms "Plays" and "Rounds" so they are consistent with the rest of the game's language.

**Why this priority**: Language consistency is lower urgency but prevents confusion when players read the modifier description alongside other in-game text that now uses the new terminology.

**Independent Test**: Open the run modifier selection screen, find the Auto Win modifier. Read its name and description and verify they use "Plays" and "Rounds" with no legacy synonyms such as "moves" or "turns".

**Acceptance Scenarios**:

1. **Given** the Auto Win modifier is shown in the UI, **When** the player reads its name and description, **Then** the text uses "Plays" and "Rounds" as defined in the ubiquitous language.
2. **Given** the modifier is active during a run, **When** any in-game text describes its effect, **Then** no terms outside the canonical language ("turn", "move", "multi", etc.) are used.

---

### Edge Cases

- What happens when Round Number is very large (long run)? The "Round [x]" display must render correctly for any positive integer without truncation or overflow.
- What happens if the player starts a new game while on a Boss Round? Background and Round label must both reset to their Normal Round state for Round 1.
- What happens during the Shop screen between rounds? The gameplay background color is only relevant on the gameplay screen; the Shop screen is unaffected.
- What if the Auto Win modifier's run ends on a Boss Round? No special end-of-run behavior is needed; the run ends normally.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The game MUST track a Round Number (1-based integer) that increments each time a new Round begins and resets to 1 when a new game starts.
- **FR-002**: The game domain MUST classify each Round as either Normal or Boss, where every Round whose number is a multiple of 3 is a Boss Round and all others are Normal.
- **FR-003**: A new standalone label MUST be placed at the top-left of the gameplay screen (in the position previously occupied by the MULTI [Q] indicator), showing "Round [x]" for Normal rounds and "Boss Round" for Boss rounds, where [x] is the current Round Number. This is the canonical round display; the existing top-right stats panel is not authoritative.
- **FR-004**: The MULTI [Q] indicator MUST be removed from the HUD entirely.
- **FR-005**: During a Normal Round, the gameplay background MUST be white or near-white.
- **FR-006**: During a Boss Round, the gameplay background MUST be light red.
- **FR-007**: Background color changes MUST occur when a new Round begins, not mid-Round.
- **FR-007a**: The background color change MUST animate smoothly from the previous color to the target color over 1.0 seconds using an easing curve, starting when the new Round's gameplay screen becomes active.
- **FR-007b**: The background color transition mechanism MUST be generic -- it receives only a target color and animates to it, with no knowledge of round types. Any future round type that introduces a new background color MUST work without modifying the animation logic.
- **FR-008**: The round-type classification (Normal vs Boss) MUST be a domain concept accessible to any game system, not a numeric check embedded in UI code.
- **FR-009**: The Auto Win run modifier name and description MUST use "Plays" and "Rounds" as defined in the ubiquitous language.

### Key Entities

- **Round**: A game unit identified by its Round Number. Carries a RoundType (Normal or Boss). Contains one or more Plays.
- **Play**: A discrete player action that locks board tiles and triggers scoring. One or more Plays constitute a Round.
- **RoundType**: A classification with two values: Normal and Boss. Determined from the Round Number; multiples of 3 yield Boss, all others yield Normal.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The Round label is visible and correct on every Round transition from Round 1 through at least Round 9, covering three full Normal/Boss cycles.
- **SC-002**: The background color transitions smoothly from the outgoing color to the incoming color over exactly 1.0 seconds with a visible easing curve; no abrupt cuts or flicker occur at any point during the transition.
- **SC-003**: No MULTI [Q] text or icon appears anywhere during gameplay after this feature ships.
- **SC-004**: The Auto Win modifier description contains no synonyms outside the canonical ubiquitous language (no "turn", "move", "multi", etc.).
- **SC-005**: A future game system can determine whether the current round is a Boss Round by querying a single domain property, without parsing or computing the Round Number itself.

---

## Assumptions

- Boss Round frequency (every 3rd Round) is fixed and not player-configurable.
- "White or near-white" background for Normal rounds means a clean, light color; exact shade is a visual design decision made during implementation.
- "Light red" for Boss rounds is a soft, desaturated red sufficient to signal elevated stakes without being visually aggressive; exact shade is a visual design decision.
- The multi-select mechanic (toggled by Q) continues to exist as gameplay; only its HUD indicator is removed, not the underlying functionality.
- The Round label is a new standalone node placed at the top-left of the gameplay screen, in the same position previously occupied by the MULTI [Q] indicator (approximately 20px from the top-left corner).
- The existing top-right stats panel (RoundLabel, PlaysLabel, ScoreLabel, etc. in MainHUD) is a debug panel scheduled for removal in a future feature. It is left untouched by this feature.
- The Shop screen between rounds is out of scope for Boss Round visual treatment.
- The background color change IS animated (1.0s smooth transition). No other audio or particle effects are added for Boss Round entry in this iteration.
- The Auto Win modifier's numeric constants (10 Plays per Round, 10 Rounds per run) are unchanged; only the display text is updated.
