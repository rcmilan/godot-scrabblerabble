# Tasks: Boss Entities System

**Input**: Design documents from `/specs/005-boss-entities/`
**Prerequisites**: plan.md, spec.md, data-model.md, research.md, quickstart.md

**Tests**: Not requested. Manual testing per Constitution Principle V.

**Organization**: Tasks grouped by user story. US3 (Customization Options), US4 (Pool/Randomization), and US5 (Round Integration) are combined into a single phase because they share implementation with US1 foundational work and add incremental verification on top.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Exact file paths included in descriptions

---

## Phase 1: Setup

**Purpose**: Create directory structure for new files

- [x] T001 Create bosses subdirectory at scripts/domain/bosses/
- [x] T002 Create drop animation subdirectory at scripts/animation/drop/

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core domain objects that ALL user stories depend on. MUST be complete before any story work begins.

**CRITICAL**: No user story work can begin until this phase is complete.

- [ ] T003 Create Boss value object (immutable, RefCounted) with fields: id (StringName), display_name (String), background_color (Color), hooks (BossHooks). Constructor takes all four fields. No Godot engine dependencies. File: scripts/domain/boss.gd
- [ ] T004 Create BossHooks base class (RefCounted) with virtual methods returning no-op defaults: get_unavailable_cells(rows, cols) -> Array (empty), get_tile_multiplier(position: Vector2i) -> float (1.0), can_play(hand_count, board_unplayed_count, play_number) -> bool (true), get_post_play_movements(grid_occupancy: Array, unplayed_positions: Array[Vector2i], board_rows: int, board_cols: int) -> Array (empty), get_plays_override() -> int (-1), get_target_score_override() -> int (-1), get_hand_modifications() -> Array (empty), get_time_attack_config() -> Dictionary (empty). No Godot engine dependencies -- all parameters are primitive types (Vector2i, Array, int, float, bool, Dictionary), never Godot node references. File: scripts/domain/boss_hooks.gd
- [ ] T005 Extend RoundConfig with optional boss field. Add p_boss: Boss = null parameter to constructor. Update _to_string() to include boss display_name when present. File: scripts/domain/round_config.gd
- [ ] T006 Extend RunState with _boss_pool: BossPool field. Add get_boss_pool() -> BossPool getter. BossPool initialization happens in start_run() (implemented in US1 phase). File: scripts/domain/run_state.gd

**Checkpoint**: Core domain objects exist. Boss, BossHooks, and extended RoundConfig/RunState are ready for story implementation.

---

## Phase 3: User Story 1 - Boss Selection and Appearance (Priority: P1) -- MVP

**Goal**: When a Boss Round begins, the game selects a boss from the pool and displays its background color. Gravity boss shows purple (#330033).

**Independent Test**: Play to Round 3. Verify the background transitions to purple (#330033) instead of the default light red. Verify the round indicator still shows "Boss Round". Start a new run and verify the pool resets.

### Implementation for User Story 1

- [ ] T007 [P] [US1] Create BossPool (RefCounted) with: _init(bosses: Array) that duplicates and shuffles the array, has_next() -> bool, next() -> Boss, peek() -> Boss, reset() (re-shuffles), get_total_count() -> int, get_remaining_count() -> int. next() returns null if exhausted. No Godot engine dependencies. File: scripts/domain/boss_pool.gd
- [ ] T008 [P] [US1] Create GravityBossHooks class extending BossHooks. Override get_post_play_movements(grid_occupancy: Array, unplayed_positions: Array[Vector2i], board_rows: int, board_cols: int) to calculate drop targets. grid_occupancy is a 2D bool array (true = occupied). For each unplayed position, find the lowest row in the same column where grid_occupancy is false (process bottom-to-top within each column to handle stacking). Return Array of Dictionaries: [{from: Vector2i, to: Vector2i}]. Skip positions already at the bottom row or with no empty cells below. Pure logic -- no Godot node references. File: scripts/domain/bosses/gravity_boss.gd
- [ ] T009 [P] [US1] Create BossRegistry (RefCounted) with static methods: get_all_bosses() -> Array[Boss] (returns [Gravity]), get_boss_by_id(id: StringName) -> Boss, get_boss_count() -> int. Register Gravity boss with id=&"gravity", display_name="Gravity", background_color=Color("#330033"), hooks=GravityBossHooks.new(). File: scripts/domain/bosses/boss_registry.gd
- [ ] T010 [US1] Wire BossPool into RunState.start_run(). Import BossRegistry. In start_run(), create BossPool from BossRegistry.get_all_bosses() and assign to _boss_pool. File: scripts/domain/run_state.gd
- [ ] T011 [US1] Extend ProgressionRules.get_round_config() to assign boss. When _is_boss_round(round_number) is true, get boss_pool from run_state. If pool.has_next(), call pool.next() and pass the Boss to the RoundConfig constructor (config.boss = boss). If pool is exhausted (!has_next()), construct the RoundConfig with is_boss_round=true but boss=null. This null boss on a boss round is the signal that RunManager (T014) uses to detect pool exhaustion and trigger run victory. File: scripts/domain/progression_rules.gd
- [ ] T012 [US1] Add boss_activated signal to EventBus: signal boss_activated(boss: Boss). This signal is emitted when a boss round begins, carrying the active boss reference. File: autoload/event_bus.gd
- [ ] T013 [US1] Update Main._on_round_ready(config) to use boss background color. Replace the hardcoded boss color check: if config.boss != null, use config.boss.background_color; else if config.is_boss_round, use BOSS_COLOR fallback; else use DEFAULT_COLOR. Emit EventBus.boss_activated(config.boss) when boss is not null. File: scenes/main.gd
- [ ] T014 [US1] Handle boss pool exhaustion in RunManager._advance_to_next_round(). After ProgressionRules returns config, check if config.is_boss_round and config.boss == null (pool exhausted). If so, emit run_ended(true, run_state.total_score) instead of continuing. This ends the run when all bosses are defeated. File: autoload/run_manager.gd

**Checkpoint**: Boss Selection and Appearance is fully functional. Playing to Round 3 shows Gravity's purple background. The pool tracks used bosses and the run ends when all bosses are defeated.

---

## Phase 4: User Story 2 - Gravity Boss Drop Mechanic (Priority: P1)

**Goal**: After pressing Play during a Gravity boss round, all newly placed tiles animate downward to the lowest available cell in their column. Scoring uses the dropped positions.

**Independent Test**: Reach Round 3 (Gravity). Place tiles in the middle of the board. Press Play. Verify tiles animate downward and land at the bottom row (or above existing tiles). Verify scoring reflects the dropped positions. Verify Play button is disabled during the drop animation.

### Implementation for User Story 2

- [ ] T015 [P] [US2] Create DropTileAnimation strategy extending TileAnimationStrategy. Set duration=0.5, ease_type=EASE_IN, trans_type=TRANS_QUAD (accelerating fall feel), stagger_delay=0.03. Override on_animation_start(tile) to disable mouse filter and set z_index=50. Override on_animation_complete(tile) to re-enable mouse and reset z_index. File: scripts/animation/drop/drop_tile_animation.gd
- [ ] T016 [P] [US2] Create DropAnimationExecutor extending AnimationExecutor. Implement execute(movements: Array[Dictionary], strategy: DropTileAnimation) method. Each movement dict has {tile: Tile, from_cell: BoardCell, to_cell: BoardCell}. For each tile: calculate start_global_pos from from_cell, calculate target as to_cell's tile_anchor global_position. Reparent tile to to_cell.tile_anchor. Wait one frame. Set tile.position with offset so it visually starts at from_cell. Tween position to final position. Use stagger_delay between tiles. Track completion with _create_batch_completion_callback pattern. File: scripts/animation/drop/drop_animation_executor.gd
- [ ] T017 [US2] Register drop animation in TileAnimator autoload. Add lazy-loaded _drop_animation (DropTileAnimation) and _drop_executor (DropAnimationExecutor). Add public method animate_drop_batch(movements: Array[Dictionary]) -> void that calls _drop_executor.execute(movements, _drop_animation). File: autoload/tile_animator.gd
- [ ] T018 [US2] Extend PlayExecutor._execute_play() to check and execute boss post-play effects. After locking tiles (set_locked(true)) and before standard animation (stomp/spin): get active boss from current round config. If boss exists, build grid_occupancy (2D bool array from board.get_grid_state()), collect unplayed_positions (Vector2i from each unplayed tile's cell grid_position), and call boss.hooks.get_post_play_movements(grid_occupancy, unplayed_positions, board.rows, board.cols). If result is non-empty, resolve each {from: Vector2i, to: Vector2i} back to {tile: Tile, from_cell: BoardCell, to_cell: BoardCell} using board.get_cell(). Disable Play button via play_button_changed.emit(false, false), then await TileAnimator.animate_drop_batch(resolved_movements) and wait for TileAnimator.animation_completed signal. PlayExecutor needs access to the current RoundConfig -- add a method to receive it or query from RunManager/GameManager. File: scripts/controllers/play_executor.gd
- [ ] T019 [US2] Implement cell rebinding after drop animation in PlayExecutor. After animate_drop_batch completes: for each resolved movement dict (containing tile, from_cell, to_cell references built in T018), call from_cell.remove_tile() to clear original cell reference, then call to_cell.place_tile(movement.tile) to bind tile to new cell, then call tile.attach_to_cell(to_cell). Process movements from bottom-to-top (highest row index first) to avoid conflicts when multiple tiles drop in the same column. File: scripts/controllers/play_executor.gd
- [ ] T020 [US2] Ensure Play button remains disabled during drop animation and is re-enabled after the full play flow completes. The existing update_play_button_state() call at the end of on_play_requested() handles re-enabling. Verify that no intermediate state update re-enables the button during the await. File: scripts/controllers/play_executor.gd
- [ ] T021 [US2] Pass current RoundConfig to PlayExecutor so it can access the active boss. Options: (a) add a set_round_config(config: RoundConfig) method called from Main._on_round_ready(), or (b) query RunManager.get_current_round_config() directly. Choose option (a) for dependency injection consistency per constitution. Wire the call in Main._on_round_ready() after GameManager.setup_round(config). File: scripts/controllers/play_executor.gd and scenes/main.gd

**Checkpoint**: Gravity drop mechanic is fully functional. Tiles animate downward after Play, land at correct positions, scoring uses dropped positions, and Play button is blocked during animation.

---

## Phase 5: User Story 3 + 4 + 5 - Customization Hooks, Pool Randomization, Round Integration (Priority: P2)

**Goal**: Verify hook extensibility, pool randomization across runs, and clean round system integration.

**Independent Test (US3)**: Inspect BossHooks base class and verify all 8 hook methods exist with correct signatures and no-op defaults. Create a test boss with a custom hook override and verify the game system queries it.

**Independent Test (US4)**: Play 3+ runs and verify bosses appear in different orders. With only Gravity, verify Round 3 has Gravity and the run ends after Round 3's boss is defeated (no Round 6 boss).

**Independent Test (US5)**: During a Boss Round, query the RoundConfig and verify it carries the boss reference. During a Normal Round, verify boss is null. Verify boss_activated signal fires on boss rounds.

### Implementation for User Story 3 + 4 + 5

- [ ] T022 [US3] Verify all 8 BossHooks virtual methods are implemented with correct signatures and return types. Ensure get_unavailable_cells, get_tile_multiplier, can_play, get_post_play_movements, get_plays_override, get_target_score_override, get_hand_modifications, and get_time_attack_config all return correct no-op defaults. Add any missing methods. Note: edge case "cell marked unavailable but already occupied by a tile" is deferred until a boss uses get_unavailable_cells. File: scripts/domain/boss_hooks.gd
- [ ] T023 [US4] Verify BossPool randomization works correctly. Ensure shuffle is called in _init(). Verify has_next() returns false when all bosses are consumed. Verify reset() re-shuffles and resets _current_index to 0, enabling continued selection after exhaustion (FR-011 endless mode prep). With a single boss (Gravity), verify the pool exhausts after one next() call, and that calling reset() then next() returns Gravity again. File: scripts/domain/boss_pool.gd
- [ ] T024 [US4] Verify run termination when boss pool is exhausted. With only Gravity in the registry, play through Round 3 (Gravity appears). After defeating Gravity, verify Round 6 does not occur -- the run should end with victory/game-over screen instead. Trace the flow: ProgressionRules detects boss round -> pool.has_next() returns false -> RunManager handles run end. File: autoload/run_manager.gd and scripts/domain/progression_rules.gd
- [ ] T025 [US5] Verify RoundConfig carries boss reference correctly. During a Boss Round, config.boss should be the Gravity Boss object. During a Normal Round, config.boss should be null. Verify config.is_boss_round and config.boss are consistent (boss implies is_boss_round, but is_boss_round does not imply boss when pool is exhausted). File: scripts/domain/round_config.gd
- [ ] T026 [US5] Verify boss_activated signal fires correctly. In Main._on_round_ready(), confirm EventBus.boss_activated.emit(config.boss) is called when config.boss is not null. Verify the signal is NOT emitted on Normal rounds. File: scenes/main.gd and autoload/event_bus.gd

**Checkpoint**: All customization hooks are defined and queryable. Pool randomization and run termination work correctly. Round system integration is clean with no redundancy.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Edge cases, verification, and cleanup

- [ ] T027 Manual test: Gravity drop with tiles placed in multiple columns simultaneously. Verify each column drops independently and tiles land at correct positions.
- [ ] T028 Manual test: Gravity drop when a column has existing locked tiles from a previous play. Verify new tiles stack above existing tiles, not overlap.
- [ ] T029 Manual test: Gravity drop when tiles are placed at the bottom row already. Verify no animation occurs (tiles stay in place) and no errors.
- [ ] T030 Manual test: Start 5+ runs in sequence (per SC-003). Verify boss pool resets between runs, Gravity always appears on Round 3, tiles drop correctly each time, no tiles are lost, and no animation glitches occur.
- [ ] T031 Manual test: Press Play rapidly during Gravity drop animation. Verify the Play button is disabled and no double-submit occurs.
- [ ] T032 Manual test: Run the quickstart.md validation scenarios end-to-end. Verify all described flows work as documented.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies -- can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion -- BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Foundational (Phase 2)
- **US2 (Phase 4)**: Depends on US1 (Phase 3) -- needs boss in RoundConfig and Gravity boss definition
- **US3+US4+US5 (Phase 5)**: Depends on US1 (Phase 3) -- verification of systems built in US1
- **Polish (Phase 6)**: Depends on US1 + US2 completion

### User Story Dependencies

- **US1 (P1)**: Can start after Foundational (Phase 2). Creates the boss system foundation.
- **US2 (P1)**: Depends on US1 -- needs Gravity boss definition and RoundConfig with boss field. Creates the drop mechanic.
- **US3 (P2)**: Depends on US1 -- verifies hook completeness built in Foundational phase. Minimal new code.
- **US4 (P2)**: Depends on US1 -- verifies pool mechanics built in US1. Tests run termination path.
- **US5 (P2)**: Depends on US1 -- verifies round integration built in US1. Tests signal emission.

### Within Each User Story

- Domain objects before integration (controllers, autoloads)
- Integration before animation
- Animation before play flow changes
- Play flow changes before manual testing

### Parallel Opportunities

**Phase 2 (Foundational)**:
- T003, T004 can run in parallel (Boss and BossHooks are independent files)
- T005, T006 can run in parallel (RoundConfig and RunState are independent files)

**Phase 3 (US1)**:
- T007, T008, T009 can run in parallel (BossPool, GravityBoss, BossRegistry are independent files)

**Phase 4 (US2)**:
- T015, T016 can run in parallel (DropTileAnimation and DropAnimationExecutor are independent files)

---

## Parallel Example: User Story 1

```text
# Parallel batch 1: Create domain objects (T007, T008, T009)
Task: "Create BossPool in scripts/domain/boss_pool.gd"
Task: "Create GravityBoss hooks in scripts/domain/bosses/gravity_boss.gd"
Task: "Create BossRegistry in scripts/domain/bosses/boss_registry.gd"

# Sequential: Wire into existing systems (T010 -> T011 -> T012 -> T013 -> T014)
Task: "Wire BossPool into RunState.start_run()"
Task: "Extend ProgressionRules to assign boss"
Task: "Add boss_activated signal to EventBus"
Task: "Update Main._on_round_ready() for boss background"
Task: "Handle pool exhaustion in RunManager"
```

## Parallel Example: User Story 2

```text
# Parallel batch 1: Create animation files (T015, T016)
Task: "Create DropTileAnimation strategy in scripts/animation/drop/drop_tile_animation.gd"
Task: "Create DropAnimationExecutor in scripts/animation/drop/drop_animation_executor.gd"

# Sequential: Register and integrate (T017 -> T021 -> T018 -> T019 -> T020)
Task: "Register drop animation in TileAnimator"
Task: "Pass RoundConfig to PlayExecutor"
Task: "Extend PlayExecutor for post-play effects"
Task: "Implement cell rebinding after drop"
Task: "Verify Play button blocking during animation"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T002)
2. Complete Phase 2: Foundational (T003-T006)
3. Complete Phase 3: US1 - Boss Selection and Appearance (T007-T014)
4. **STOP and VALIDATE**: Play to Round 3. Verify purple background. Start new run, verify pool resets.
5. This is a playable MVP: bosses appear with distinct colors, round system works.

### Full Delivery (MVP + Gravity Mechanic)

1. Complete MVP (Phases 1-3)
2. Complete Phase 4: US2 - Gravity Drop Mechanic (T015-T021)
3. **STOP and VALIDATE**: Play to Round 3. Place tiles, press Play. Verify drop animation and correct scoring.
4. Complete Phase 5: US3+US4+US5 verification (T022-T026)
5. Complete Phase 6: Polish and edge case testing (T027-T032)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story
- No automated tests -- all verification is manual in Godot editor
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Domain objects (scripts/domain/) must have zero Godot engine dependencies
- Animation follows existing strategy + executor pattern
- Cell rebinding order matters: process bottom-to-top to avoid conflicts
