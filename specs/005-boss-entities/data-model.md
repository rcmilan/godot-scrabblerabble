# Data Model: Boss Entities System

**Feature**: 005-boss-entities
**Date**: 2026-04-10

## Entities

### Boss

**Purpose**: Immutable value object representing a boss definition with identity, visual properties, and gameplay hooks.

**Fields**:

| Field | Type | Description |
|-------|------|-------------|
| id | StringName | Unique identifier (e.g., &"gravity") |
| display_name | String | Human-readable name shown in UI (e.g., "Gravity") |
| background_color | Color | Background color during this boss's round |
| hooks | BossHooks | Customization hooks for game mechanics |

**Constraints**:
- `id` must be unique across all bosses in the registry
- `background_color` must be a valid Color (not transparent)
- `hooks` is never null; defaults to base BossHooks (no-op) if not overridden

**Relationships**:
- Referenced by RoundConfig (one boss per boss round)
- Registered in BossRegistry (one entry per boss)
- Selected from BossPool (consumed during run)

---

### BossHooks

**Purpose**: Base class providing no-op defaults for all boss customization hooks. Each boss subclass overrides only the hooks it uses.

**Virtual Methods**:

| Method | Return Type | Parameters | Default | Description |
|--------|-------------|------------|---------|-------------|
| get_unavailable_cells | Array[Vector2i] | rows: int, cols: int | [] | Cells where tiles cannot be placed |
| get_tile_multiplier | float | position: Vector2i | 1.0 | Score multiplier for tiles at a given position |
| can_play | bool | hand_count: int, board_unplayed_count: int, play_number: int | true | Whether Play button is enabled |
| get_post_play_movements | Array[Dictionary] | grid_occupancy: Array, unplayed_positions: Array[Vector2i], board_rows: int, board_cols: int | [] | Post-play tile movements (returns [{from: Vector2i, to: Vector2i}]) |
| get_plays_override | int | -- | -1 | Override plays per round (-1 = use default) |
| get_target_score_override | int | -- | -1 | Override target score (-1 = use default) |
| get_hand_modifications | Array[Dictionary] | -- | [] | Hand tile changes at round start |
| get_time_attack_config | Dictionary | -- | {} | Time attack settings (empty = no timer) |

**Notes**:
- All methods are pure (no side effects, no Godot dependencies)
- Return -1 or empty for "no override" to distinguish from valid zero values
- `get_post_play_movements` accepts a grid occupancy snapshot (2D array of booleans) and unplayed tile positions (Vector2i). Returns movement instructions as [{from: Vector2i, to: Vector2i}]. The controller layer resolves positions back to Board/Cell/Tile references and handles animation.

---

### BossPool

**Purpose**: Mutable run-scoped object tracking boss selection with random-without-replacement ordering.

**Fields**:

| Field | Type | Description |
|-------|------|-------------|
| _shuffled_bosses | Array[Boss] | Shuffled list of all bosses for this run |
| _current_index | int | Next boss to select (0-based) |

**Methods**:

| Method | Return Type | Parameters | Description |
|--------|-------------|------------|-------------|
| _init | void | bosses: Array[Boss] | Shuffles bosses using Fisher-Yates |
| has_next | bool | -- | True if unselected bosses remain |
| next | Boss | -- | Returns next boss, advances index |
| peek | Boss | -- | Returns next boss without advancing |
| reset | void | -- | Re-shuffles and resets index (for future endless mode) |
| get_total_count | int | -- | Total number of bosses |
| get_remaining_count | int | -- | Number of unselected bosses |

**Constraints**:
- `next()` returns null if pool is exhausted (caller must check `has_next()` first)
- Shuffle uses Godot's built-in `Array.shuffle()` (seeded by default randomize)

**Relationships**:
- Owned by RunState (created on run initialization)
- Queried by ProgressionRules during round config generation

---

### BossRegistry

**Purpose**: Static registry of all available boss definitions. Single source of truth for what bosses exist in the game.

**Methods**:

| Method | Return Type | Parameters | Description |
|--------|-------------|------------|-------------|
| get_all_bosses | Array[Boss] | -- | Returns all registered bosses |
| get_boss_by_id | Boss | id: StringName | Returns boss by ID (null if not found) |
| get_boss_count | int | -- | Number of registered bosses |

**Notes**:
- Bosses are registered statically (hardcoded definitions or loaded from data files)
- No runtime registration/unregistration (pool of bosses is fixed per game version)
- This is a domain service, not an autoload

---

### RoundConfig (Enhanced)

**Purpose**: Existing immutable value object with added boss field.

**New Field**:

| Field | Type | Description |
|-------|------|-------------|
| boss | Boss | Active boss for this round (null for normal rounds) |

**Changes**:
- Constructor gains optional `p_boss: Boss = null` parameter
- `_to_string()` includes boss name if present

---

### RunState (Enhanced)

**Purpose**: Existing mutable run state with added boss pool tracking.

**New Field**:

| Field | Type | Description |
|-------|------|-------------|
| _boss_pool | BossPool | Pool for boss selection during this run |

**New Methods**:

| Method | Return Type | Description |
|--------|-------------|-------------|
| get_boss_pool | BossPool | Returns the boss pool |

**Changes**:
- `start_run()` initializes BossPool from BossRegistry.get_all_bosses()

---

## State Transitions

### Boss Lifecycle Within a Round

```
Run Start
  |
  v
RunState.start_run() --> BossPool created (shuffled)
  |
  v
ProgressionRules.get_round_config()
  |-- is_boss_round? --> pool.has_next()?
  |     |-- YES: config.boss = pool.next()
  |     |-- NO: run ends (emit run_ended)
  |-- not boss round: config.boss = null
  |
  v
Main._on_round_ready(config)
  |-- config.boss != null?
  |     |-- YES: background = boss.background_color
  |     |-- NO: background = DEFAULT_COLOR
  |
  v
PlayExecutor._execute_play()
  |-- config.boss != null?
  |     |-- YES: build grid_occupancy + unplayed_positions
  |     |       movements = boss.hooks.get_post_play_movements(grid, positions, rows, cols)
  |     |       |-- not empty? --> resolve to cells, execute drop/shift animation
  |     |       |-- empty? --> skip
  |     |-- NO: skip
  |
  v
Standard play flow continues (animate, score, commit)
```

### Gravity Drop Within a Play

```
Player presses Play
  |
  v
PlayExecutor._execute_play(unplayed_tiles)
  |
  v
Lock unplayed tiles (set_locked(true))
  |
  v
Check boss post-play effect
  |-- Gravity: get_post_play_movements(grid_occupancy, unplayed_positions, rows, cols)
  |     |
  |     v
  |   Calculate target positions per column:
  |     For each position, find lowest empty row in same column
  |     Process columns bottom-to-top to avoid conflicts
  |     |
  |     v
  |   Return [{from: Vector2i, to: Vector2i}, ...]
  |
  v
Disable Play button
  |
  v
Execute drop animation (TileAnimator.animate_drop_batch)
  |-- Each tile tweens from current position to target position
  |-- Duration: ~0.5s per tile, staggered by column
  |
  v
Rebind tiles to new cells:
  |-- tile.detach_from_cell()
  |-- original_cell.remove_tile()
  |-- new_cell.place_tile(tile)
  |-- tile.attach_to_cell(new_cell)
  |
  v
Standard animation (stomp/spin on ALL board tiles)
  |
  v
Score on final (dropped) positions
  |
  v
Re-enable Play button via update_play_button_state()
```

## Entity Relationship Diagram

```
BossRegistry (static)
  |
  | get_all_bosses()
  v
BossPool (per-run, owned by RunState)
  |
  | next()
  v
Boss (immutable value object)
  |-- id: StringName
  |-- display_name: String
  |-- background_color: Color
  |-- hooks: BossHooks
        |
        |-- get_unavailable_cells()
        |-- get_tile_multiplier()
        |-- can_play()
        |-- get_post_play_tiles()
        |-- get_plays_override()
        |-- get_target_score_override()
        |-- get_hand_modifications()
        |-- get_time_attack_config()

RoundConfig
  |-- round_number: int
  |-- is_boss_round: bool
  |-- boss: Boss (nullable)
  |-- target_score: int
  |-- plays_per_round: int
  |-- ...

RunState
  |-- _boss_pool: BossPool
  |-- _current_round: int
  |-- ...
```
