# Quickstart: Boss Entities System

**Feature**: 005-boss-entities
**Date**: 2026-04-10

## What This Feature Does

Adds a boss system to Wordatro where each boss round (every 3rd round) features a unique boss with custom mechanics. The first boss, Gravity, causes all newly placed tiles to drop to the bottom of their columns after each Play.

## Key Files to Read First

1. **`/specs/005-boss-entities/spec.md`** -- Full feature specification
2. **`/specs/005-boss-entities/data-model.md`** -- Entity definitions and state transitions
3. **`/specs/005-boss-entities/research.md`** -- Design decisions and rationale

## Existing Code to Understand

Before implementing, read these files to understand the systems being extended:

| File | Why |
|------|-----|
| `/scripts/domain/round_config.gd` | Extended with boss field |
| `/scripts/domain/run_state.gd` | Extended with BossPool |
| `/scripts/domain/progression_rules.gd` | Assigns bosses to boss rounds |
| `/scripts/controllers/play_executor.gd` | Insert post-play effects (Gravity drop) |
| `/autoload/run_manager.gd` | Initializes BossPool, handles run termination when pool exhausted |
| `/autoload/background_manager.gd` | Boss-specific background colors |
| `/scenes/main.gd` | Round ready handler uses boss color |
| `/autoload/tile_animator.gd` | Add drop animation API |
| `/scripts/animation/base/tile_animation_strategy.gd` | Base class for new drop animation |
| `/scripts/animation/glide/return_animation_executor.gd` | Reference for position-transition animation pattern |
| `/scenes/board/board.gd` | Board cell access for drop target calculation |
| `/scenes/board/board_cell.gd` | Cell occupancy and tile binding |

## Implementation Order

### Phase 1: Domain Layer (Boss Entity + Pool)

1. Create `Boss` value object (`/scripts/domain/boss.gd`)
2. Create `BossHooks` base class (`/scripts/domain/boss_hooks.gd`)
3. Create `BossPool` (`/scripts/domain/boss_pool.gd`)
4. Create `BossRegistry` (`/scripts/domain/bosses/boss_registry.gd`)
5. Create `GravityBoss` hooks (`/scripts/domain/bosses/gravity_boss.gd`)
6. Extend `RoundConfig` with boss field
7. Extend `RunState` with BossPool

### Phase 2: Integration Layer (Round System + Selection)

8. Extend `ProgressionRules` to assign bosses from pool
9. Extend `RunManager` to initialize pool and handle exhaustion
10. Add `boss_activated` signal to `EventBus`
11. Update `Main._on_round_ready()` to use boss background color

### Phase 3: Animation Layer (Gravity Drop)

12. Create `DropTileAnimation` strategy (`/scripts/animation/drop/drop_tile_animation.gd`)
13. Create `DropAnimationExecutor` (`/scripts/animation/drop/drop_animation_executor.gd`)
14. Add `animate_drop_batch()` to `TileAnimator`

### Phase 4: Controller Layer (Play Flow + Effects)

15. Extend `PlayExecutor._execute_play()` to check and execute post-play effects
16. Implement Gravity drop cell rebinding (detach/attach tiles to new cells)
17. Add Play button blocking during post-play animation

### Phase 5: Testing and Polish

18. Manual testing: Gravity drop in all column configurations
19. Manual testing: Boss rotation across multiple runs
20. Manual testing: Run termination when all bosses defeated
21. Manual testing: Play button blocking during animation

## Architecture Constraints

- Boss domain objects (`Boss`, `BossHooks`, `BossPool`) MUST have zero Godot engine dependencies
- Boss hooks return data (positions, multipliers, booleans), never execute actions directly
- The controller layer (PlayExecutor) interprets hook return values and orchestrates effects
- Animation uses the existing strategy+executor pattern; no new animation infrastructure
- Communication between systems uses EventBus signals except for tight controller orchestration

## Common Pitfalls

- **Cell rebinding order**: When dropping tiles in the same column, process from bottom to top to avoid overwriting target cells
- **Scoring position**: Score must be calculated AFTER drop animation and cell rebinding, not before
- **Tile locking**: Tiles are locked BEFORE the drop, so `is_locked` is true during the drop animation. The drop operates on locked tiles, not unplayed tiles.
- **Animation blocking**: The drop animation must complete before stomp/spin animations run. Use `await TileAnimator.animation_completed` or signal-based sequencing.
- **Pool exhaustion**: When `boss_pool.has_next()` returns false on a boss round, the run must end. This is distinct from a normal round -- the run termination logic triggers instead of shop transition.
