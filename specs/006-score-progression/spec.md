# Feature Specification: Score Progression and Scoring System Overhaul

**Feature Branch**: `006-score-progression`
**Created**: 2026-04-11
**Status**: Draft
**Input**: User description: "let's fix the game progression and the scoring system"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Cumulative Score Persists Across Rounds (Priority: P1)

A player progresses through multiple rounds and their total score keeps growing without resetting. Points earned in round 1 carry into round 2, and each word scored adds to that growing total. When the run ends (victory or defeat), the game over screen shows the final accumulated score.

**Why this priority**: This is the core fix required. Without persistent scoring, no other scoring feature makes sense. It also establishes the data needed for a future high-score leaderboard.

**Independent Test**: Start a run, score points in round 1, advance to round 2, and confirm the display starts from the round 1 total rather than zero.

**Acceptance Scenarios**:

1. **Given** a player has scored 120 points across three plays in round 1, **When** round 2 begins, **Then** the displayed score starts at 120 (not 0).
2. **Given** a player scores 50 points in round 2's first play, **When** the score updates, **Then** the display shows 170 (120 + 50).
3. **Given** a run ends in defeat, **When** the game over screen appears, **Then** it shows the final accumulated score from all rounds played.
4. **Given** a run ends in victory, **When** the victory screen appears, **Then** it shows the final accumulated score, formatted to be visually prominent.

---

### User Story 2 - Realistic and Rewarding Target Score Progression (Priority: P1)

Each round has a target score. Rounds 1 and 2 are designed so that any engaged player reliably reaches the first boss round (round 3) on a typical playthrough. Targets grow round over round in a curve that stays challenging but never feels impossible in early rounds.

**Why this priority**: Tied with Story 1 because the current 1,000,000 target makes the game unwinnable and breaks the entire run loop. Fixing this immediately makes the game playable.

**Independent Test**: Play rounds 1 and 2 using only common letter plays (no special tiles or multipliers) and confirm both can be cleared comfortably.

**Acceptance Scenarios**:

1. **Given** round 1, **When** a player scores a few ordinary words with no special multipliers, **Then** they can realistically meet or exceed the target within the allowed plays.
2. **Given** round 2, **When** a player continues using mostly common words, **Then** the target is reachable, though it requires more plays or better word choices than round 1.
3. **Given** round 3 (first boss), **When** a player attempts it, **Then** the target is noticeably harder than round 2, introducing meaningful tension for the first time.
4. **Given** subsequent rounds beyond round 3, **When** the player progresses, **Then** each round's target is higher than the previous, scaling at a pace that remains challenging without becoming punishing instantly.

---

### User Story 3 - Score Panel at Top Left with Pulse Animation (Priority: P2)

A dedicated score panel lives at the top left of the gameplay screen, showing the player's current total score (Y) and the round's target (X) in the format "Y / X" (score on the left, target on the right -- e.g., "87 / 120"). After each play is submitted, Y increments visibly with a pulse animation timed stomp by stomp so the player feels each tile contribute to the growing score.

**Why this priority**: This is the primary scoring feedback the player interacts with every play. The debug panel values on the top right are placeholders and will eventually be removed; this panel is the permanent, polished replacement.

**Independent Test**: Submit a play and observe the score panel: Y increases and pulses, and the panel is positioned top left.

**Acceptance Scenarios**:

1. **Given** the gameplay screen is loaded, **When** the round starts, **Then** a score panel is visible at the top left showing "Y / X" where Y is the current cumulative score (left) and X is the round target (right), e.g., "0 / 120".
2. **Given** a play is submitted and the stomp animations run, **When** each individual tile's slam lands, **Then** the Y value in the score panel immediately ticks upward by that tile's score contribution, so the player perceives each stomp adding to the score in real time.
3. **Given** the score panel is updating, **When** Y changes, **Then** a brief pulse animation plays on the panel (scale bounce or glow) to draw attention to the change.
4. **Given** the play animation finishes, **When** the final score is settled, **Then** the displayed Y matches the new cumulative total exactly.

---

### User Story 4 - Particle Celebration When Target Is Beaten (Priority: P2)

When a player's total score (Y) surpasses the round target (X), the score panel triggers a particle animation. The intensity of the particles scales with how far Y exceeds X: barely beating the target gets nothing or a small burst; significantly beating it gets an impressive effect. This motivates players to keep scoring beyond the minimum requirement.

**Why this priority**: Directly tied to the rewarding score panel experience. It rewards overachievement and adds emotional payoff without blocking progression.

**Independent Test**: Score just over the target and observe minimal or no particles. Then score well above the target (e.g., 30%+ beyond) and observe a visible and more intense particle effect.

**Acceptance Scenarios**:

1. **Given** Y is exactly at or up to 5% above X, **When** the score updates, **Then** no particles play (or only a faint hint).
2. **Given** Y is between 5% and 15% above X, **When** the score updates, **Then** a small, subtle particle burst plays on the score panel.
3. **Given** Y is between 15% and 30% above X, **When** the score updates, **Then** a moderate particle effect plays.
4. **Given** Y is more than 30% above X, **When** the score updates, **Then** a full, impressive particle burst plays.
5. **Given** the target has already been beaten, **When** additional plays are submitted, **Then** particle intensity re-evaluates based on the new ratio of Y to X.

---

### User Story 5 - Hard Boss (Priority: P2)

A new boss called "Hard Boss" appears in the boss rotation. When active, it doubles the per-round scoring requirement, making that round significantly harder to clear. Specifically: the score the player must earn within that boss round is doubled (the cumulative total from previous rounds is not affected). Its visual identity uses a metallic gray background. Like all other bosses, its effect lasts only while the boss is the active round boss, and the next non-boss round returns to normal targets.

**Why this priority**: Extends the existing boss system with minimal new mechanics. The per-round requirement doubling pairs naturally with the overhaul of the target score system. Full cumulative-target doubling was rejected because it would make the boss round impossible to clear (a player starting a R3 Hard Boss round with 65 pts would need 175 more in 2 plays -- not 55 more -- which may be doable with good tiles). The doubled per-round delta is the correct interpretation.

**Independent Test**: Trigger a Hard Boss round and confirm the displayed target is double what it would normally be that round. Complete or fail the round and confirm the next normal round uses the regular target formula.

**Acceptance Scenarios**:

1. **Given** a Hard Boss round begins, **When** the round loads, **Then** the target score shown in the score panel equals the previous round's cumulative total plus double the normal per-round delta for that position (not double the full cumulative target).
2. **Given** a Hard Boss round is active, **When** the background renders, **Then** it uses a metallic gray color scheme consistent with the other boss background styles.
3. **Given** the Hard Boss round ends (win or lose), **When** the next round begins, **Then** the target score returns to the normal progression formula (not doubled).
4. **Given** the Hard Boss effect is active, **When** checking boss-related hooks, **Then** only the target score is doubled; tile values, plays per round, and hand size are unaffected.

---

### User Story 6 - Target Score and Points Removed from Debug Panel (Priority: P3)

The Score and Target labels in the top-right debug/HUD panel are removed, since that information is now surfaced through the dedicated score panel at top left. The remaining HUD fields (round, plays, deck, hand, discard, timer) stay intact.

**Why this priority**: Clean-up that prevents duplication. Lower priority because it does not affect gameplay, only UI polish.

**Independent Test**: Open a round and confirm the top-right panel no longer shows "Score: ..." or "Target: ...". Confirm the score panel at top left still shows both values correctly.

**Acceptance Scenarios**:

1. **Given** the game is running, **When** the HUD renders, **Then** no "Score" or "Target" labels appear in the top-right panel.
2. **Given** the top-right panel is updated after a play, **When** an observer checks it, **Then** no score or target values are present; all other labels (round, plays, deck, etc.) still update normally.

---

### Edge Cases

- What happens when the player scores 0 points in a play (e.g., a word with all 1-point tiles and no multipliers)?  Y should still be accurate and no particles should play since the target was not newly beaten.
- What happens on the first play of a run when Y starts at 0 and X is already set? Panel should display correctly from the first frame.
- What if a boss round is the very first round encountered (not applicable with current 3-round cycle, but noted for future configurations)?
- What if the Hard Boss and Diagonal Boss both appear in the same run? Each occupies a separate boss slot; they do not stack.
- What happens if Y already exceeds X before a play begins (carried from a previous round's surplus)? Particles should play immediately on the first score update of that round since the threshold is already cleared.

## Requirements *(mandatory)*

### Functional Requirements

**Scoring Persistence**

- **FR-001**: The cumulative score (total points across all plays in all completed and current rounds) MUST persist between rounds within a single run.
- **FR-002**: When a new round starts, the cumulative score MUST be initialized to the total score accumulated up to and including all previously completed rounds, not reset to zero.
- **FR-003**: Each successful play MUST add the play's scored points to the cumulative score.
- **FR-004**: The game over and victory screens MUST display the final cumulative score.
- **FR-005**: The final cumulative score MUST be stored in a structure that supports future retrieval for a high-score leaderboard (i.e., accessible as a named value after a run ends).

**Target Score Progression**

- **FR-006**: The current target score of 1,000,000 MUST be replaced with a realistic base value calibrated against actual average per-play scoring (letter values 1-10, standard multipliers, no special modifiers).
- **FR-007**: The round target MUST increase each round at a rate that allows at least 80% of players to clear rounds 1 and 2 comfortably, with round 3 (first boss) being the first round with meaningful difficulty.
- **FR-008**: The target for each round MUST be calculated using the cumulative model: the round N target represents the total score a player must have accumulated by the end of round N.
- **FR-009**: Target increments between rounds MUST scale progressively (not linearly flat), so later rounds demand more per-round performance than earlier rounds.

**Score Panel UI (Top Left)**

- **FR-010**: A score panel MUST be added to the top-left area of the gameplay screen displaying the format "Y / X" where Y is the current cumulative score (left, the growing number) and X is the current round target (right, the ceiling to surpass). Example: "87 / 120".
- **FR-011**: The score panel MUST update Y stagger-matched to the stomp animation: the play's total score is pre-calculated and distributed across the stomping tiles before animation begins, and each tile's score contribution is added to Y at the moment that tile's slam lands. Increments fire at the same stagger interval as the tiles (approximately 0.06s apart), so the player sees Y tick upward once per tile, stomp by stomp.
- **FR-012**: While Y is incrementing during the stomp sequence, the score panel MUST play a pulse animation (e.g., brief scale-up and return to normal).
- **FR-013**: After a play is fully resolved, the displayed Y MUST exactly match the new cumulative total.

**Particle Celebration**

- **FR-014**: Whenever Y exceeds X during a play resolution, a particle animation MUST play on or near the score panel.
- **FR-015**: The particle intensity MUST scale with the ratio of (Y - X) / X:
  - Ratio 0% to 5%: no particles.
  - Ratio 5% to 15%: small particle burst.
  - Ratio 15% to 30%: moderate particle effect.
  - Ratio above 30%: full-intensity particle effect.
- **FR-016**: If Y already exceeded X before the current play began, particles MUST still play on subsequent score updates to reinforce the player's ongoing overachievement.

**Hard Boss**

- **FR-017**: A new boss entity named "Hard Boss" MUST be added to the boss registry.
- **FR-018**: When the Hard Boss is the active round boss, the per-round scoring requirement MUST be doubled. Specifically: the per-round delta (the difference between the current round's normal cumulative target and the previous round's cumulative target) is multiplied by 2, and the result is added back to the previous cumulative total to form the boss round's target. The cumulative total earned in prior rounds is NOT multiplied. Example: at R3 with a normal per-round delta of 55, the Hard Boss target becomes `65 (R2 total) + 110 (55*2) = 175` instead of 240 (which would be the impossible full-doubling result).
- **FR-019**: The Hard Boss background MUST use a metallic gray color scheme (consistent in style with existing boss background implementations).
- **FR-020**: The Hard Boss per-round requirement doubling MUST apply only while that boss round is active and MUST NOT carry into subsequent rounds.
- **FR-021**: The Hard Boss MUST NOT alter tile values, hand size, plays per round, or board layout beyond what the base boss system already controls.

**Debug Panel Cleanup**

- **FR-022**: The "Score" and "Target" labels in the top-right HUD panel MUST be removed.
- **FR-023**: All other HUD panel labels (round, plays, deck, hand, discard, timer) MUST remain functional and unchanged.

**Logging**

- **FR-024**: The system MUST log each play's scored points, the cumulative total after the play, and the current round target when a play is committed.
- **FR-025**: The system MUST log when a round target is first beaten, including the final cumulative score and the excess above target.
- **FR-026**: The system MUST log Hard Boss activation and the doubled target value when the Hard Boss round config is calculated (in `ProgressionRules.get_round_config()`), which occurs at the point the round configuration is prepared, not necessarily at the moment the round scene loads.

### Key Entities

- **Cumulative Score**: The running total of all points scored across all rounds in a single run. Persists until the run ends. Used for win/lose evaluation, score panel display, and final result reporting.
- **Round Target**: The cumulative score threshold a player must reach by the end of a specific round. Calculated by the progression formula, optionally modified by the active boss.
- **Score Panel**: A UI element at the top left of the gameplay screen showing the round target and cumulative score. Animates on score changes and plays particles when the target is beaten.
- **Hard Boss**: A boss entity whose only mechanical effect is doubling the per-round scoring requirement (not the full cumulative target). Has a metallic gray visual identity.
- **Run Result**: A record produced at run end containing at minimum the final cumulative score, the round reached, and the outcome (victory or defeat). Structured to support leaderboard use in a future feature.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new player attempting rounds 1 and 2 with no special tiles or modifiers can meet both round targets within the normal play count at least 80% of the time.
- **SC-002**: The score panel at top left is visible and accurate within the first second of any round loading.
- **SC-003**: The cumulative score displayed at round 2 start exactly equals the total points scored across all plays in round 1, with zero discrepancy.
- **SC-004**: The game over and victory screens display a non-zero cumulative score that matches the sum of all scored plays in the run.
- **SC-005**: After a play that stomps 4 tiles, the score panel Y value changes exactly 4 times -- once per tile slam, staggered in sequence -- giving the player the sensation of each tile contributing individually to the growing score.
- **SC-006**: When Y is 30% or more above X, a visible particle effect plays on the score panel within 1 second of the final score settling.
- **SC-007**: In a Hard Boss round, the displayed target equals the previous round's cumulative total plus double the normal per-round delta. For example, at R3 (normal delta=55, R2 total=65), Hard Boss target = 65 + 110 = 175 (not 240).
- **SC-008**: After a Hard Boss round ends, the following round's target is not doubled.
- **SC-009**: The top-right HUD panel contains no score or target labels after the cleanup.

## Clarifications

### Session 2026-04-11

- Q: Should the score panel Y value update during each individual tile stomp or after all stomps complete? -> A: Stagger-matched (Option C): score increments fire at the same stagger intervals as the tile stomps, so Y ticks once per tile slam, building suspense stomp by stomp.
- Q: Which value appears first (left) in the score panel -- target or current score? -> A: Score first (Option B): "87 / 120" -- current score on the left (the growing, exciting number), target on the right.

## Assumptions

- A typical unaided play (common 4-5 letter word, no special tiles, one regular multiplier cell) scores approximately 15-40 points based on the existing letter value table and cell multiplier system. Target values will be calibrated to this range.
- Rounds 1 and 2 are treated as the "tutorial difficulty window" where the target can be met by at least 80% of typical players within 3-5 plays of ordinary quality (consistent with SC-001).
- The Hard Boss will be added to the existing boss rotation (every 3rd round); the order within the rotation is a tuning detail left to the planning/implementation phase.
- Score panel particles are rendered using Godot's built-in particle system consistent with the existing stomp tile particle style.
- The high-score leaderboard is explicitly out of scope for this feature. The Run Result entity is only structured to support it, not implemented.
- The debug overlay (word validator, remove tiles, redraw hand buttons) is separate from the HUD panel and is not touched by this feature.
- "Pulse animation" on the score panel means a brief scale-up (e.g., 1.0 to 1.15 and back) lasting under 0.3 seconds, similar in spirit to the existing tile stomp recover phase.
- Score increments during stomp animation will be distributed evenly across the stomping tiles (total play score divided by tile count, applied per tile stomp event) for simplicity.
