# Research: Boss Rounds and Round Counter

**Branch**: `004-boss-rounds` | **Date**: 2026-04-06

## Findings

All unknowns were resolved through direct code inspection. No external research was required.

---

### Decision 1: How to represent round type in the domain

**Decision**: Add `var is_boss_round: bool = false` to `RoundConfig` (set at construction, never mutated).

**Rationale**: `RoundConfig` is the existing immutable value object for all per-round parameters. It already flows through `EventBus.run_round_ready` to every consumer. Adding `is_boss_round` here gives every subscriber access without any new signal or direct dependency. A bool is the simplest correct model for the current two-type scenario. An enum can be introduced later if a third round type emerges.

**Alternatives considered**:
- *Separate `boss_round_started` EventBus signal*: Rejected — redundant with `run_round_ready` which already carries the config to all listeners. Two signals for the same event creates ordering ambiguity.
- *RoundType enum now*: Rejected per CLAUDE.md "simplest working solution" — only two types exist today and a bool is unambiguous. Refactor to enum when a third type is needed.
- *GameManager query method*: Rejected — would require callers to reach into GameManager for data already present in the RoundConfig they hold.

---

### Decision 2: Where to compute boss round classification

**Decision**: In `ProgressionRules._is_boss_round(round_number: int) -> bool` — a private helper that returns `round_number % 3 == 0`. Called inside `get_round_config()`.

**Rationale**: `ProgressionRules` is the domain service that already computes all other round parameters (board size, target score). Boss classification is a progression rule, not a UI or controller concern. This keeps the check in one place and satisfies FR-008 (no numeric check in UI code).

**Alternatives considered**:
- *Compute in RunManager*: Rejected — RunManager is an autoload orchestrator, not a domain rules engine. The rule belongs in domain.
- *Store boss cycle in ProgressionConfig resource*: Viable for later if the cycle becomes configurable. For a hardcoded multiple-of-3 rule, the method-level constant is simpler and sufficient.

---

### Decision 3: How MainHUD tracks boss state for round label

**Decision**: Cache `_current_is_boss: bool` as a member variable in `MainHUD`. Set it in `_on_run_round_ready(config)`. Use it in `_update_round(round_number)`.

**Rationale**: The `round_started` signal (emitted after `run_round_ready`) calls `_on_round_started(round_number: int)` which in turn calls `_update_round`. If `_update_round` only received the round number, it would need to recompute boss status — violating FR-008. Caching the boss flag from the richer `run_round_ready` event avoids this without changing signal signatures.

**Alternatives considered**:
- *Remove `_on_round_started` entirely from MainHUD*: Partially viable — `run_round_ready` already fires first and sets plays/target/round. However `_on_round_started` also refreshes `plays_remaining` from `GameManager.get_plays_remaining()` to catch quality-applied overrides. Safer to keep it and cache the flag.
- *Pass is_boss through round_started signal*: Rejected — changing signal signatures has wider blast radius. Cache is local and surgical.

---

### Decision 4: Background ColorRect placement

**Decision**: Add a `ColorRect` named `Background` as the **first child** of the `Main` Control node in `main.tscn`, anchored full-rect (`anchors_preset = 15`). Update color in `main.gd._on_round_ready(config)`.

**Rationale**: `main.tscn` currently has no explicit background (default viewport color shows through). Placing the ColorRect as the first child ensures it renders behind all other nodes without z-index manipulation. `main.gd._on_round_ready` already receives the full `RoundConfig`, making it the natural place to update the background.

**Normal color**: `Color(1.0, 1.0, 1.0, 1.0)` — pure white.
**Boss color**: `Color(1.0, 0.85, 0.85, 1.0)` — soft light red (desaturated, not aggressive).

**Alternatives considered**:
- *Animate color transition*: Out of scope for this iteration per spec assumptions.
- *Handle in MainHUD*: MainHUD is a CanvasLayer; background changes belong in the scene's spatial layer, not the overlay layer.

---

### Decision 5: MultiSelectIndicator removal strategy

**Decision**: Remove the `MultiSelectIndicator` instance node from `main.tscn` and its corresponding `ext_resource` entry. Remove the `@onready var multi_select_indicator` reference and the `multi_select_indicator.set_selection_manager()` call from `main.gd`. The `SelectionManager`, multi-select toggle key, and all underlying multi-select logic remain intact.

**Rationale**: The spec removes the visual indicator, not the mechanic. The indicator's only external dependency is the `set_selection_manager()` call in `main.gd`; removing that call leaves `SelectionManager` fully functional.

**Alternatives considered**:
- *Hide the indicator (visibility = false)*: Rejected — the spec says "remove". Hiding leaves dead nodes and dead code.

---

### Decision 6: AutoWinQuality text changes

**Decision**: Update `get_quality_name()` from `"Auto Win (%d Plays)"` to `"Auto Win (%d Plays)"` — name is already correct. Update `get_description()` from `"Exhaust your %d plays to win each round. Run ends after %d rounds."` — this text already uses "plays" and "rounds" (lowercase). The only change needed: capitalize "Plays" and "Rounds" to match the canonical capitalization used in this spec.

**Rationale**: The description text `"Exhaust your 10 plays to win each round. Run ends after 10 rounds."` already uses the correct domain terms. Minimal update: capitalize consistently with the ubiquitous language definitions.

**Note**: After careful inspection, `get_quality_name()` already says "Auto Win (10 Plays)" which is correct. `get_description()` says "Exhaust your 10 plays to win each round. Run ends after 10 rounds." — both "plays" and "rounds" need capitalization to "Plays" and "Rounds" per spec.
