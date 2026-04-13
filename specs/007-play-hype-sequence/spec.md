# Feature Specification: Play Hype Sequence

**Feature Branch**: `007-play-hype-sequence`
**Created**: 2026-04-13
**Status**: Draft
**Input**: User description: "Standardize the Play action animation across all tile types and rounds, maximizing player excitement (hype) while leveraging existing systems. The sequence must scale with tile count, provide clear feedback, and intensify dynamically based on scoring impact."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Staged Play Feedback With Lift Phase (Priority: P1)

When the player presses Play, all placed tiles first animate upward together (a uniform "lift" that signals anticipation), then each tile executes its assigned animation (stomp or spin) before scoring resolves. The player perceives the play as a single choreographed event rather than a mechanical tile-flip.

**Why this priority**: This is the foundational sequence -- without the lift phase and synchronization, none of the hype escalation in later stories has a proper setup. It is also the most visible, immediate change.

**Independent Test**: Place any number of tiles, press Play, and observe that all tiles lift simultaneously before any scoring animation begins. Delivers a perceivable "anticipation beat" even without dynamic intensity.

**Acceptance Scenarios**:

1. **Given** tiles are placed on the board, **When** Play is pressed, **Then** all placed tiles scale up and offset upward at the same moment before any tile-specific animation runs.
2. **Given** the lift phase begins, **When** it completes, **Then** each tile transitions directly into its assigned animation (stomp or spin) without any gap or reset.
3. **Given** the sequence is running, **When** it is in progress, **Then** the player cannot place, remove, move, or discard tiles until the full sequence (animations + scoring) is complete.
4. **Given** a Hurry Boss round is active, **When** Play is pressed and the sequence begins, **Then** the countdown timer pauses for the duration of the animation and scoring sequence, then resumes when the sequence completes.

---

### User Story 2 - Adaptive Speed Scaling By Tile Count (Priority: P2)

As the player places more tiles and presses Play, the entire animation sequence visibly accelerates. A single-tile play feels deliberate and readable; a seven-tile play feels urgent and energetic. The acceleration is exponential, not linear, so the difference between 3 and 7 tiles is dramatic.

**Why this priority**: This is the core "hype" mechanic. Without it, a full-board play feels identical to a single-tile play, which undercuts the reward of large combos.

**Independent Test**: Play a 1-tile word, then play a 7-tile word. The 7-tile sequence must visibly complete faster and feel more intense. No scoring or pulse changes are needed to validate this story alone.

**Acceptance Scenarios**:

1. **Given** a 1-tile play, **When** the sequence runs, **Then** animation speed is at or near the minimum (slow, readable) end of the scale.
2. **Given** a 7-tile play, **When** the sequence runs, **Then** animation speed is noticeably faster than a 3-tile play, approaching the maximum allowed speed.
3. **Given** the speed multiplier is computed, **When** the tile count increases, **Then** the multiplier grows exponentially (not linearly), making high tile counts feel disproportionately fast.
4. **Given** the multiplier is at its maximum, **When** more tiles are added beyond the threshold, **Then** animation speed does not increase further (clamped) and no animation falls below the minimum readable threshold.

---

### User Story 3 - Per-Tile Score Pop With Score Transfer (Priority: P3)

After each tile animates, a score value visually "pops" above that tile, then travels toward the score display in the top-left corner. The score counter only increments when each flying value arrives at the display. The player can see their score building tile by tile.

**Why this priority**: This makes the scoring feel earned and visible. Without it, the score just jumps, and the connection between tiles and points is lost.

**Independent Test**: Play any word and observe that floating score numbers appear above tiles, travel to the HUD, and the score counter increments only upon arrival. Can be validated before dynamic pulse intensity is added.

**Acceptance Scenarios**:

1. **Given** a tile animation completes, **When** the tile's score contribution is non-zero, **Then** a score value label appears above that tile with a scale + fade-in entrance.
2. **Given** the score label has appeared, **When** it begins moving, **Then** it travels toward the score display position in the top-left HUD.
3. **Given** the score label is in transit, **When** it reaches the score display, **Then** the score counter updates by exactly that tile's contribution.
4. **Given** multiple tiles score in quick succession, **When** their labels are all in flight, **Then** each label moves and arrives independently (not merged), and each increments the counter on arrival.
5. **Given** the global speed multiplier is active, **When** score labels travel, **Then** their travel speed scales with the same multiplier applied to tile animations.

---

### User Story 4 - Dynamic Pulse Intensity on Score Update (Priority: P4)

When the score display increments, the pulse animation it plays intensifies based on how much progress the tile's score contribution represents toward the round target. A tile that covers 5% of the target pulses mildly; a tile that exceeds the entire target pulses dramatically.

**Why this priority**: This creates the "payoff" beat. Small plays feel modest; high-scoring plays feel explosive. It is a secondary enhancement that only matters once scoring feedback (Story 3) is working.

**Independent Test**: Two plays -- one contributing ~5% of the round target, one contributing ~100%. The second pulse must be visually larger or more intense. Testable independently of score pop travel.

**Acceptance Scenarios**:

1. **Given** a tile's score contribution is 5% of the target, **When** the score display updates, **Then** the pulse scale is 1.05x the base pulse scale.
2. **Given** a tile's score contribution is 110% of the target, **When** the score display updates, **Then** the pulse scale is 2.10x the base pulse scale.
3. **Given** the pulse intensity is computed, **When** the value would produce extreme distortion, **Then** intensity is clamped so score text remains readable.
4. **Given** very high intensity (e.g., 2x or above), **When** the pulse triggers, **Then** at least one secondary visual effect (glow or shake) also activates in addition to the scale change.

---

### User Story 5 - Data-Driven Animation Mapping (Priority: P5)

The mapping from tile type to animation preset is defined in a configuration resource, not in code. Adding a new tile type and assigning it an animation requires only a data change, not a code change.

**Why this priority**: This is an extensibility requirement, not a player-facing feature. It matters for long-term maintenance but does not affect the current play experience directly.

**Independent Test**: Modify the animation mapping resource to assign a different animation to an existing tile type. Verify the change takes effect without any code modification.

**Acceptance Scenarios**:

1. **Given** the animation mapping resource, **When** a tile type is added to the map with an animation preset key, **Then** tiles of that type play the assigned animation during the Play sequence.
2. **Given** a tile type not present in the mapping, **When** the system categorizes it, **Then** it falls back to a defined default animation without error.
3. **Given** timing parameters and speed scaling curve values, **When** they are changed in the configuration resource, **Then** the runtime behavior reflects those changes without code edits.

---

### Edge Cases

- What happens when the player plays a single tile? Lift and animation phases still run; speed multiplier is at its minimum; score pop appears for that one tile.
- What happens when a tile contributes zero score? The score pop does not appear for that tile; the score display does not update or pulse for it.
- What happens when the target score is zero or undefined? The progress ratio calculation must not divide by zero; pulse intensity defaults to 1.0 (base).
- What happens if the animation sequence is interrupted (e.g., the game is paused)? The player lock remains in place until the sequence fully resolves or the round ends.
- What happens when a Hurry Boss round ends by time-out mid-sequence? The sequence completes its current animation beat, then round-end logic resolves normally after the sequence finishes.
- What happens with the maximum tile count (full board)? Speed is clamped to maximum; no animation falls below the minimum readable threshold; no visual overload.
- What happens if score labels overlap in flight? Each label is independent and may visually overlap; no merging or collision resolution is required.

## Clarifications

### Session 2026-04-13

- Q: Should the developer be able to control overall sequence speed via a standalone parameter, separate from tile-count scaling, to prepare for a future player-facing options screen? -> A: Yes. A master game speed multiplier must exist as a dedicated parameter that is settable at runtime and designed to be exposed to players via a future options screen. It is distinct from the tile-count-based adaptive scaling.
- Q: How should the master game speed multiplier and the tile-count-based multiplier combine? -> A: Multiplicative -- `effectiveMultiplier = tileCountMultiplier * masterSpeed`. Both always apply independently.
- Q: What is the allowed range for the master game speed multiplier on the future player options screen? -> A: 0.5x (minimum) to 2.0x (maximum). Default is 1.0x.

## Requirements *(mandatory)*

### Functional Requirements

**Play Sequence**

- **FR-001**: System MUST execute a synchronous lift phase on all placed tiles simultaneously when Play is pressed, before any tile-specific animation begins.
- **FR-002**: The lift phase MUST apply a uniform scale-up and upward vertical offset to all tiles at the same moment.
- **FR-003**: After the lift phase, each tile MUST execute its assigned animation as determined by the data-driven animation mapping.
- **FR-004**: The system MUST block all player interaction (tile placement, tile removal, tile movement, discard) for the entire duration of the Play sequence (lift + tile animations + score transfer).
- **FR-005**: System MUST resume the Hurry Boss countdown timer only after the full Play sequence -- including all score transfers -- has completed.
- **FR-006**: System MUST pause the Hurry Boss countdown timer at the moment Play is pressed and keep it paused for the entire sequence.

**Adaptive Speed Scaling**

- **FR-007**: System MUST compute a tile-count speed multiplier using an exponential formula: `tileCountMultiplier = clamp(1 + k * tileCount^n, minSpeed, maxSpeed)` where n > 1.
- **FR-008**: The constants k, n, minSpeed, and maxSpeed MUST be defined in a configuration resource (not hardcoded).
- **FR-009**: System MUST apply a combined effective speed multiplier to all animation durations, including the lift phase, tile animations, and score label travel. The effective multiplier is computed as `effectiveMultiplier = tileCountMultiplier * masterSpeed`, so both factors always apply independently.
- **FR-010**: No animation phase MUST fall below a defined minimum readable duration threshold, even at maximum combined speed.
- **FR-011**: Both parallel (simultaneous) and staggered (inter-tile delay) execution MUST be supported; the inter-tile delay value MUST also scale with the effective speed multiplier.
- **FR-029**: System MUST expose a master game speed multiplier as a dedicated, runtime-settable parameter, independent of tile-count scaling. This parameter is designed to be surfaced on a future player-facing options screen and must control the perceived speed of the entire Play sequence (lift, tile animations, score pop travel, stagger delays) uniformly.
- **FR-030**: The master game speed multiplier MUST be readable and writable at runtime without restarting the game or reloading the scene.
- **FR-031**: The master game speed multiplier default value MUST be 1.0x, with an allowed player-facing range of 0.5x to 2.0x. Both values MUST be defined in the HypeConfig configuration resource.

**Score Pop and Transfer**

- **FR-012**: After each tile's animation reaches its defined completion threshold, a score value label MUST appear above that tile with a scale + fade-in entrance animation.
- **FR-013**: The score label MUST travel from its origin position toward the score display in the top-left HUD.
- **FR-014**: The score display counter MUST increment only when the traveling score label arrives at the display (not before).
- **FR-015**: Each tile's score label MUST travel and arrive independently (not merged with other labels).
- **FR-016**: Score label travel speed MUST respect the global speed multiplier.
- **FR-017**: Tiles with zero score contribution MUST NOT emit a score label.

**Dynamic Pulse Intensity**

- **FR-018**: The score display pulse animation MUST scale in intensity based on `pulseIntensity = 1 + (delta / targetScore)` where delta is the tile's score contribution. If targetScore is zero or undefined, pulse intensity MUST default to 1.0 (neutral pulse, no scoring active) to avoid division by zero.
- **FR-019**: Pulse visual scale MUST be `baseScale * pulseIntensity`.
- **FR-020**: Pulse intensity MUST be clamped to a maximum value defined in configuration to prevent extreme visual distortion.
- **FR-021**: At intensity levels at or above a defined threshold, the system MUST activate at least one secondary visual effect (e.g., glow or shake) on the score display.
- **FR-022**: Score text MUST remain readable at all pulse intensity levels (text scale or color must not degrade legibility).

**Data-Driven Configuration**

- **FR-023**: The animation mapping (tile type -> animation preset) MUST be defined in a configuration resource and loaded at runtime.
- **FR-024**: Adding or reassigning an animation to a tile type MUST require only a data change, with no code modification.
- **FR-025**: A tile type absent from the mapping MUST fall back to a defined default animation without error.
- **FR-026**: All timing parameters, speed scaling constants, pulse scaling behavior, and animation thresholds MUST be readable from a single configuration resource.

**Debug Logging**

- **FR-027**: System MUST emit structured debug logs (toggleable, off by default) covering: tile count and computed speed multiplier on Play pressed; per-tile type, assigned animation, and final scaled duration; per-tile score contribution, cumulative score, progress increase, and pulse intensity.
- **FR-028**: Log format MUST follow: `[Play] tileCount=N speedMultiplier=X.XX`, `[Tile] type=T animation=A duration=X.XX`, `[Score] delta=N progress=X.XX intensity=X.XX`.

### Key Entities

- **HypeConfig**: Configuration resource holding all data-driven parameters -- animation mapping, speed scaling constants (k, n, minSpeed, maxSpeed), minimum animation threshold, pulse intensity max, secondary effect intensity threshold, inter-tile stagger delay, animation completion threshold (0-1 normalized), master game speed multiplier default value and allowed range.
- **ScorePopLabel**: Transient visual element that appears above a tile after its animation, carries a score value, travels to the HUD, and triggers the score counter on arrival.
- **PlaySequenceState**: Runtime state tracking the active sequence -- whether it is in progress, how many tiles have reached completion threshold, and whether the Hurry Boss timer is currently paused by the sequence.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A 7-tile Play sequence runs visibly faster than a 3-tile Play sequence, with the speed difference immediately noticeable to a first-time player.
- **SC-002**: A tile contributing 100% or more of the round target produces a pulse that is at least 2x the visual size of a tile contributing 5% of the target.
- **SC-003**: No Play sequence exceeds 4 seconds total duration at maximum tile count under default configuration.
- **SC-004**: No individual animation phase drops below the minimum readable threshold (no phase appears to "skip") at any tile count.
- **SC-005**: The Hurry Boss timer does not decrement during the Play sequence; time lost to the sequence equals zero.
- **SC-006**: Player interactions (place, remove, move, discard) during an active Play sequence have no effect and produce no errors.
- **SC-007**: Reassigning an animation preset in the configuration resource takes effect on the next Play without requiring a code change or game restart.
- **SC-008**: Debug logs, when enabled, contain all required fields (tile count, multiplier, per-tile type/animation/duration, per-tile score/progress/intensity) with no missing entries for any tile in the sequence.
- **SC-009**: Changing the master game speed multiplier at runtime causes all subsequent Play sequence animation durations, score label travel speed, and stagger delays to reflect the new value immediately, without restarting the game.

## Assumptions

- The existing stomp and spin animations are the initial supported animation presets; no new animation types need to be created as part of this feature.
- The score display position in the HUD is fixed and accessible as a global screen position for score label targeting.
- The Hurry Boss timer is controlled through an existing pause/resume mechanism in the timer management system; this feature consumes that mechanism rather than building a new one.
- The lift phase is a new animation that runs before the existing categorized animations; it does not replace them.
- The animation completion threshold (normalized 0-1) maps to the point in each animation where the tile has visually "committed" (e.g., after stomp rise+slam, before recover) -- not the end of the full animation.
- Score label travel does not need to avoid overlapping with other UI elements; visual overlap is acceptable.
- The secondary visual effect at high pulse intensity is a simple shake or glow on the score display node; no particle system or new scene is required.
- Debug logging is controlled by a single boolean flag in the HypeConfig resource; no separate debug console or UI is required.
- Boss rounds that do not use the Hurry mechanic are unaffected by the timer pause/resume logic (the pause call is a no-op when no timer is active).
- The master game speed multiplier is not a debug/developer-only tool; it is a first-class player-facing setting that happens to be developer-controlled in this iteration. It must be built to be wired into a player-facing options screen without architectural changes.
