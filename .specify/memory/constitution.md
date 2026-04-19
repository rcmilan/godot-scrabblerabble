<!-- SYNC IMPACT REPORT (Generated 2026-04-03)
Version: 1.0.0 (initial)
New Principles: 5 (Domain-Driven Design, Decoupled Communication, Immutable Domain, Thin Controllers, Manual Testing First)
Added Sections: Architecture Constraints, Development Workflow
No prior version to compare; initial constitution establishment.
Follow-up: None - all placeholders resolved.

Patch 1.0.1 (2026-04-03): Removed pre-commit hook enforcing snake_case filenames.
Hook was broken and blocking commits. File naming convention (snake_case) remains
the expected practice but is no longer enforced at commit time.

Patch 1.0.2 (2026-04-03): Added constraint forbidding modals, popups, and dialogs.
Rationale: Modal overlays cause input leakage between UI layers. Replace with
view-swapping (sibling Control visibility toggles) or scene changes. Learned during
title screen refactor: modals can never fully prevent focus bleed to hidden UI.

Patch 1.0.3 (2026-04-19): Added Principle VI: Non-Representable Invalid States.
Rationale: Complement to immutability principle. Structure data so invalid states
cannot exist in the type system. Example: TileState.pre_loaded_modifier and
session_modifier are mutually exclusive—only one can be active. Don't validate
at runtime; make the invalid state impossible to construct. Prevents entire
categories of bugs from existing in the codebase.
-->

# Wordatro Constitution

## Core Principles

### I. Domain-Driven Design

Pure business logic and game rules live in `/scripts/domain` with zero Godot engine dependencies. Domain layer contains immutable value objects (BoardState, TileState, Deck systems, Modifiers) and services (scoring, word validation, game rule logic). Controllers and UI never directly implement game rules; all rule changes flow through domain services.

**Rationale**: Enables independent testing and reasoning about game mechanics without engine overhead. Decouples business logic from framework specifics, making the game portable and testable in isolation.

### II. Decoupled Communication via EventBus

Systems communicate through EventBus signals rather than direct references. Controllers and autoloads emit and subscribe to events (tile_placed, round_started, etc.). Direct references are used only for tight-coupling orchestration scenarios (e.g., GameplayController routing input to PlacementExecutor).

**Rationale**: Reduces coupling between systems, enables parallel development, and simplifies testing by allowing selective event subscription.

### III. Immutable Domain Objects

Domain value objects (BoardState, TileState) never mutate in place. All state transitions return new instances. Services return new copies of modified state, never modifying arguments.

**Rationale**: Prevents subtle bugs from shared state mutations, enables replay and undo mechanics, simplifies debugging and reasoning about state flow.

### IV. Thin Controllers

Controllers (`/scripts/controllers`) perform orchestration only: routing input events, calling domain services, emitting EventBus signals, and updating UI state. No business logic or rule enforcement in controllers. Controllers receive scene node references (Board, Hand, etc.) via setup injection.

**Rationale**: Maintains clear separation between UI interaction and game logic. Controllers become simple state machines rather than logic centers, reducing complexity and improving maintainability.

### V. Manual Testing First

Before automated testing frameworks are integrated, manual testing in the Godot editor is the verification method. When writing features, verify behavior by playing the game. Document edge cases that need manual verification. When automated tests are added later, these manual cases become the acceptance criteria.

**Rationale**: Allows rapid iteration without test infrastructure overhead while the codebase stabilizes. Manual testing directly validates user experience and catches integration issues that unit tests might miss.

### VI. Non-Representable Invalid States

Structure domain data so invalid states cannot be constructed or represented in the type system. Rather than validating at runtime ("this state is invalid"), design the data so invalid states are impossible. Example: Instead of allowing a tile to have both pre_loaded_modifier AND session_modifier simultaneously, use an enum or union type that enforces "exactly one or neither."

**Rationale**: Eliminates entire categories of bugs. Impossible states can't leak into controllers or cause runtime errors. Forces design clarity: what are the truly valid state combinations? Answer that question in the type structure, not in validation code.

## Architecture Constraints

- **No Godot Code in Domain**: `/scripts/domain` must not import any Godot classes or engine features. Domain is pure GDScript logic—testable outside the engine.
- **EventBus as Communication Hub**: Inter-system communication defaults to EventBus signals. Direct function calls are permitted only for tightly coupled layers (domain → controller data flows).
- **Autoload Registry**: All global singletons must be declared in `project.godot` under `[autoload]` with explicit names. No dynamic singleton creation.
- **Scene Dependency Injection**: Controllers receive scene node references (Board, Hand, TileAnimator, etc.) through explicit setup methods, never through `get_tree()` lookups.
- **No Modals, Popups, or Dialogs**: UI state transitions MUST use view-swapping (hide/show sibling controls) instead of modal overlays. Modals cause input leakage between hidden and visible UI layers. Use full-screen or split-pane `Control` nodes with visibility toggling. If modal-like behavior is needed, implement as separate scenes reached via `change_scene_to_file()`, not overlay components.

## Development Workflow

**Code Review Checklist**:
- Does the change modify domain logic? → Must be in `/scripts/domain` with no Godot dependencies.
- Does the change need UI updates? → Controllers and scenes handle this; emit EventBus signals for system-wide effects.
- Does this introduce coupling? → Prefer EventBus signals over direct references.
- Have the changes been tested manually in the editor?

**Adding Features**:
1. Identify if change is domain logic (rules), controller logic (input), or UI (scenes).
2. Implement in appropriate layer; domain first.
3. Emit/subscribe EventBus events for cross-layer communication.
4. Test manually in the Godot editor before commit.
5. Document any manual edge cases that might become automated tests later.

**Refactoring**:
- Preserve the three-layer architecture (domain, controllers, scenes).
- Never move business logic into controllers or scenes.
- Prefer moving logic down into domain; moving up violates DDD.

## Governance

This constitution supersedes all prior informal practices. Amendments must be documented in `.specify/memory/constitution.md` with a version bump and rationale. Breaking changes (principle removals or redefinitions) require MAJOR version bumps. New guidance or principle expansion requires MINOR bumps. Clarifications and wording fixes require PATCH bumps.

All code reviews MUST verify compliance with Core Principles I–V and Architecture Constraints. Deviations are permitted only if a Complexity Tracking justification is documented in the PR description.

When manual testing is insufficient, failing tests MUST be added before implementation begins (Test-First discipline per CLAUDE.md). No code is considered complete until manually verified in the editor and any documented edge cases are confirmed.

**Version**: 1.0.2 | **Ratified**: 2026-04-03 | **Last Amended**: 2026-04-03
