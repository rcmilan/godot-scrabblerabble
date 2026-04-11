# Research: Boss Entities System

**Feature**: 005-boss-entities
**Date**: 2026-04-10

## R1: Boss Entity Architecture Pattern

**Decision**: Boss as an immutable domain value object (RefCounted) with a composable hooks interface.

**Rationale**: The existing codebase uses immutable value objects (TileState, BoardState) for domain state and RefCounted for domain services. A Boss is a definition -- it does not mutate during a round. Its identity (name, color) and behavior (hooks) are fixed at creation time. This aligns with Constitution Principle III (Immutable Domain Objects) and Principle I (DDD -- no Godot dependencies in domain).

**Alternatives considered**:
- **Boss as RunQuality subclass**: RunQuality already has lifecycle hooks (on_round_started, on_play_completed, etc.), so extending it for bosses seems natural. However, RunQuality is designed for run-wide modifiers (e.g., time attack across all rounds), while bosses are per-round entities with different hook types (cell rules, post-play effects). Mixing concerns would bloat RunQuality and violate single responsibility. Furthermore, bosses need hooks RunQuality does not provide (cell unavailability, play button validation, tile rules).
- **Boss as Resource**: Godot Resources are persistent, serializable, and exportable. However, bosses are pure domain logic with no need for editor integration or disk serialization. Using Resource would introduce a Godot dependency in the domain layer, violating the constitution.
- **Boss as Node/Autoload**: Would enable _process callbacks for time-based bosses, but violates DDD (domain must not depend on Godot). Timer bosses can use RunQuality's existing on_process hook instead.

---

## R2: Boss Hook System Design

**Decision**: A base `BossHooks` class with virtual methods for each hook category. Each boss subclass overrides only the hooks it uses. Game systems query the active boss's hooks at well-defined integration points.

**Rationale**: The hook categories span multiple game systems (board, hand, scoring, play button, post-play). Rather than creating separate interfaces per system, a single BossHooks base class with no-op defaults lets each boss override only what it needs. This is the same pattern as RunQuality (base class with virtual methods). Game systems check `if boss != null: boss.hooks.get_X()` and use defaults when no hook is active.

**Hook Categories and Integration Points**:

| Hook | Game System | When Queried | Default (no boss / no override) |
|------|-------------|--------------|--------------------------------|
| `get_unavailable_cells(board_rows, board_cols)` | Board (resize/init) | Round start, after board resize | Empty array (all cells available) |
| `get_tile_rules(position)` | Scoring service | During score calculation | No extra multiplier (1x) |
| `can_play(hand_count, board_tile_count, play_number)` | PlayExecutor | Before play submission | Always true |
| `get_post_play_movements(grid, positions, rows, cols)` | PlayExecutor | After tiles locked, before scoring | [] (no movements) |
| `get_plays_override()` | ProgressionRules | Round config generation | null (use default) |
| `get_target_score_override()` | ProgressionRules | Round config generation | null (use default) |
| `get_hand_modifications()` | HandManager | Round start | null (no modification) |
| `get_time_attack_config()` | RunQuality / Timer | Round start | null (no timer) |

**Alternatives considered**:
- **Signal-based hooks**: Each boss emits signals that systems subscribe to. This would work but adds complexity for hooks that need return values (e.g., `can_play()` returns bool, `get_unavailable_cells()` returns array). Direct method calls are simpler for query-style hooks.
- **Dictionary-based config**: Boss defines a dictionary of key-value pairs that systems interpret. This loses type safety and makes it harder to discover available hooks. Virtual methods are self-documenting.
- **Separate interface per hook**: Creates many small classes but adds registration complexity. A single base class with no-op defaults is simpler and matches the RunQuality pattern.

---

## R3: Gravity Drop Implementation

**Decision**: Create a new `DropTileAnimation` strategy and `DropAnimationExecutor` that animate tiles from their current position to the lowest available cell in their column. The drop is a post-play effect executed between tile locking and scoring.

**Rationale**: The existing animation system (strategy + executor pattern) is well-suited for this. The GlideTileAnimation/ReturnAnimationExecutor demonstrate how to animate position transitions with tweens. The drop animation is conceptually similar but with a fixed direction (downward) and per-column target calculation.

**Animation Flow**:
1. PlayExecutor locks tiles (sets LOCKED modifier)
2. PlayExecutor builds grid_occupancy snapshot and collects unplayed positions
3. PlayExecutor calls `boss.hooks.get_post_play_movements(grid, positions, rows, cols)` -- returns domain-safe [{from, to}] data
4. PlayExecutor calls TileAnimator.animate_drop_batch(tiles) with the newly locked tiles
5. Drop animation calculates target positions per tile (bottom of column or above existing tile)
6. All tiles animate downward simultaneously (stagger optional for visual effect)
7. After animation completes, tiles are re-bound to their new cells
8. Scoring runs on the final (dropped) positions

**Target Position Calculation**:
For each tile in column C, starting from the bottom row:
- Find the lowest empty cell in column C
- If the column is fully occupied below the tile, it stays in place
- Tiles in the same column that are all dropping should stack: process from bottom to top within the column to avoid conflicts

**Cell Rebinding**:
After animation, each tile must:
1. Detach from its original cell (`tile.detach_from_cell()`)
2. Move the tile node to the new cell's tile_anchor
3. Attach to the new cell (`tile.attach_to_cell(new_cell)`)
4. Update the original cell (clear its tile reference)

**Alternatives considered**:
- **Reuse ReturnAnimationExecutor**: ReturnAnimationExecutor handles reparenting between hand and board, but drop is board-to-board movement. The reparenting logic differs (tile stays on board, just moves between cells). A dedicated executor is cleaner.
- **Instant teleport + stomp**: Skip the drop animation and just move tiles, then play stomp. This loses the visual impact that makes Gravity feel distinct.
- **Physics-based drop**: Use Godot's physics engine for realistic gravity. Overkill for a tile game; tween-based animation matches the existing system.

---

## R4: Boss Pool and Selection Algorithm

**Decision**: BossPool is a domain value object that holds a shuffled array of boss IDs. On each boss round, it pops the next boss. When empty, it signals run termination.

**Rationale**: Random-without-replacement is a standard shuffle-then-iterate pattern. Fisher-Yates shuffle at pool creation ensures randomness. The pool is initialized when the run starts and tracked in RunState alongside other run-level state.

**Run Termination Logic**:
- When ProgressionRules determines a round is a boss round, it asks the pool for the next boss
- If the pool is empty (all bosses used), ProgressionRules signals that no more bosses are available
- RunManager handles this by ending the run (emitting run_ended)

**Endless Mode Preparation**:
- BossPool has a `reset()` method that re-shuffles and restarts iteration
- A future endless mode flag would call `reset()` instead of signaling termination
- No endless mode logic is implemented now, but the interface exists

**Alternatives considered**:
- **Random selection per round**: Pick a random boss each round, track used set separately. This is equivalent but less elegant than shuffle-then-iterate.
- **Boss pool in RunQuality**: Track boss selection as a quality modifier. This conflates two different concerns (qualities modify game parameters; boss pool controls round content).
- **Boss pool as autoload**: Unnecessary global state. The pool is run-scoped and belongs in RunState.

---

## R5: Integration with Existing Round System

**Decision**: Extend RoundConfig with an optional `boss` field. When `is_boss_round` is true and a boss is available, `boss` holds the Boss value object. ProgressionRules assigns bosses from the pool during config generation.

**Rationale**: RoundConfig is the single source of truth for round parameters. Adding the boss reference here means all downstream systems (Main, PlayExecutor, BackgroundManager) can access the boss through the same config object they already receive. No new communication channels needed.

**Background Color Flow**:
- Currently: Main._on_round_ready() checks `config.is_boss_round` and uses hardcoded colors
- New: Main._on_round_ready() checks `config.boss != null` and uses `config.boss.background_color`
- Fallback: If `is_boss_round` is true but `boss` is null (pool exhausted), use default boss color or treat as normal round

**Play Flow Changes**:
- Currently: PlayExecutor._execute_play() locks tiles -> animates (stomp/spin) -> consumes modifiers -> emits signals
- New: PlayExecutor._execute_play() locks tiles -> **execute boss post-play effect** -> animates (stomp/spin) -> consumes modifiers -> emits signals
- The post-play effect (e.g., Gravity drop) runs after locking but before the standard animation and scoring
- The dropped positions become the final positions for scoring

**Alternatives considered**:
- **Separate BossManager autoload**: Creates a parallel state channel. Systems would need to check both RoundConfig and BossManager. Embedding boss in RoundConfig keeps state unified.
- **Boss as EventBus signal payload**: Emit boss_activated(boss) and let systems cache the reference. This works but creates a temporal coupling (must subscribe before the signal fires). RoundConfig is always available synchronously.

---

## R6: Play Button Blocking During Animation

**Decision**: Disable the Play button while any boss post-play animation is in progress. Use the existing TileAnimator.is_animating() check and play_button_changed signal.

**Rationale**: PlayExecutor already manages play button state via `update_play_button_state()`. Adding an animation check is straightforward. The existing pattern emits `play_button_changed(false, false)` to disable the button. After animation completes, the button state is re-evaluated.

**Implementation**:
- Before starting the drop animation, emit `play_button_changed(false, false)` to disable
- After animation completes (via await or signal), proceed with scoring
- After scoring, call `update_play_button_state()` to re-evaluate

**Alternatives considered**:
- **Input blocking via GameManager phase**: Set phase to a "ANIMATING" state. Overkill; the play button is the only input that needs blocking during post-play animation.
- **TileAnimator.is_animating() guard in on_play_requested**: Already exists implicitly (tiles check is_animating before animation starts). Adding explicit button disable makes the state visible to the player.
