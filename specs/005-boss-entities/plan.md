# Implementation Plan: Boss Entities System

**Branch**: `005-boss-entities` | **Date**: 2026-04-10 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/005-boss-entities/spec.md`

## Summary

Introduce a Boss entity system that assigns unique bosses to boss rounds (every 3rd round), each with a distinct background color and extensible gameplay hooks. The first boss, Gravity, drops all newly placed tiles to the bottom of their columns after Play is pressed. The system provides a customization interface for future bosses to modify board cells, tile rules, play button constraints, post-play effects, round parameters, and time mechanics without requiring code changes to existing systems.

## Technical Context

**Language/Version**: GDScript (Godot 4.6)
**Primary Dependencies**: Godot Engine 4.6 (autoloads, signals, tweens, scene tree)
**Storage**: N/A (in-memory state, resource files for boss definitions)
**Testing**: Manual testing in Godot editor (per Constitution Principle V)
**Target Platform**: Desktop (Windows/Mac/Linux)
**Project Type**: Desktop game
**Performance Goals**: 60 fps, animations must not cause frame drops
**Constraints**: No Godot dependencies in domain layer; EventBus for cross-system communication
**Scale/Scope**: Currently 1 boss (Gravity); system must support many bosses without architectural changes

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Domain-Driven Design | PASS | Boss entity, BossPool, and hook interfaces live in `/scripts/domain/`. No Godot dependencies in domain layer. |
| II. Decoupled Communication via EventBus | PASS | Boss selection, activation, and post-play effects communicated via EventBus signals. Direct references only for tight controller orchestration. |
| III. Immutable Domain Objects | PASS | Boss definitions are immutable value objects. BossPool returns new instances on mutation. |
| IV. Thin Controllers | PASS | Controllers query boss hooks and delegate to domain services. No business logic in controllers. |
| V. Manual Testing First | PASS | All verification via manual play-testing in Godot editor. |
| No Godot Code in Domain | PASS | Boss, BossPool, and hook interfaces are pure GDScript RefCounted objects. Hook methods accept only primitive types (Vector2i, Array, int, float, bool, Dictionary) -- never Godot node references. Controllers translate between domain data and scene nodes. |
| No Modals/Popups/Dialogs | PASS | No UI overlays introduced. Boss effects are in-game mechanics, not UI dialogs. |
| Autoload Registry | PASS | No new autoloads required. RunManager and GameManager extended to carry boss state. |
| Scene Dependency Injection | PASS | PlayExecutor receives boss reference via existing setup pattern. |

## Project Structure

### Documentation (this feature)

```text
specs/005-boss-entities/
+-- plan.md              # This file
+-- research.md          # Phase 0 output
+-- data-model.md        # Phase 1 output
+-- quickstart.md        # Phase 1 output
+-- checklists/          # Specification quality checklists
+-- tasks.md             # Phase 2 output (NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
scripts/domain/
+-- boss.gd                          # Boss value object (id, name, color, hooks)
+-- boss_pool.gd                     # Boss pool with random-without-replacement selection
+-- boss_hooks.gd                    # Base class for boss customization hooks
+-- bosses/
|   +-- boss_registry.gd            # Static registry of all boss definitions
|   +-- gravity_boss.gd             # Gravity boss definition (hooks + drop logic)

scripts/animation/
+-- drop/
|   +-- drop_tile_animation.gd      # Drop animation strategy (downward glide)
|   +-- drop_animation_executor.gd  # Batch drop executor (per-column settling)

autoload/
+-- tile_animator.gd                 # Extended: add animate_drop_batch() method

scripts/controllers/
+-- play_executor.gd                 # Extended: insert boss post-play effects before scoring

scripts/domain/
+-- round_config.gd                  # Extended: add boss reference field
+-- run_state.gd                     # Extended: add BossPool tracking
+-- progression_rules.gd             # Extended: assign boss to boss rounds via pool

autoload/
+-- run_manager.gd                   # Extended: initialize BossPool, pass to progression
+-- game_manager.gd                  # No changes expected (round lifecycle unchanged)
+-- event_bus.gd                     # Extended: add boss_activated signal
+-- background_manager.gd            # Extended: use boss color instead of hardcoded BOSS_COLOR

scenes/
+-- main.gd                          # Extended: read boss color from RoundConfig instead of hardcoded
```

**Structure Decision**: Follows existing DDD architecture. Boss domain objects go in `/scripts/domain/` alongside existing domain code. Boss definitions go in a `bosses/` subdirectory for organizational clarity. The new drop animation follows the established strategy+executor pattern in `/scripts/animation/drop/`.

## Complexity Tracking

No constitution violations. No complexity justification needed.
