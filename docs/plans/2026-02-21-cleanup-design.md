# Cleanup Design — OOP/DDD Enforcement, Immutability, Complexity Reduction

**Date:** 2026-02-21
**Branch:** cleanup (from decks)
**Status:** Approved

---

## Goals

1. Remove dead and half-baked code.
2. Enforce encapsulation — no public mutable state that should be private.
3. Enforce immutability at API boundaries — public getters return copies, not references.
4. Cyclomatic complexity ≤ 5 on all functions; decompose any that exceed it.
5. High-frequency, low-verbosity patterns — one canonical way to do each recurring concern.

---

## Design Principles

- OOP: state owned by one class, accessed through its API.
- DDD: domain handlers have zero UI knowledge; controllers wire signals to UI.
- Immutability: autoload state arrays exposed read-only via getters returning duplicates.
- YAGNI: remove unused code, not replace it with more abstractions.
- Cyclomatic complexity ≤ 5: extract named helpers at the point of violation.

---

## Phase 1 — Dead Code + Encapsulation

**Scope:** Pure subtraction and renaming. Zero behavior change. Safe to merge independently.

### Dead code removed

| File | Symbol | Reason |
|------|---------|--------|
| `scenes/tile/tile.gd` | `is_wild: bool` | Marked "(unused)" in docstring |
| `scenes/tile/tile.gd` | `point_modifier` | Marked "Legacy" |
| `scripts/animation/draw/draw_tile_animation.gd` | `start_alpha: float` | `@export` var never read; alpha hardcoded in `on_animation_start()` |
| `autoload/run_manager.gd` | `initialize_run()` | Legacy path with inconsistent defaults; `initialize_run_from_builder()` is the only path |

### Encapsulation fixes

**TileBag** — all three state arrays become private:

```gdscript
# before
var available_tiles: Array[Tile] = []
var drawn_tiles: Array[Tile] = []
var current_distribution: BagDistribution = null

# after
var _available_tiles: Array[Tile] = []
var _drawn_tiles: Array[Tile] = []
var _current_distribution: BagDistribution = null

func get_available_tiles() -> Array[Tile]:
    return _available_tiles.duplicate()

func get_drawn_tiles() -> Array[Tile]:
    return _drawn_tiles.duplicate()

func get_current_distribution() -> BagDistribution:
    return _current_distribution
```

Callers updated: `RandomModifiersQuality`, `AllResetQuality`, any debug commands.

**HandManager** — discard pile becomes private:

```gdscript
# before
var discard_pile: Array[Tile] = []

# after
var _discard_pile: Array[Tile] = []
# get_discard_pile() already exists — no new API needed
```

**GameplayController** — internal state becomes private:

```gdscript
# before
var interaction_mode: InteractionMode = InteractionMode.IDLE
var selected_tile: Tile = null

# after
var _interaction_mode: InteractionMode = InteractionMode.IDLE
var _selected_tile: Tile = null
# Add getters only if external callers exist
```

**DropHandler** — remove state flag, use return value:

```gdscript
# before
var last_placement_success: bool = false  # read by coordinator
# handle_tile_drop() already returns bool

# after
# field removed; callers use: var ok := _drop.handle_tile_drop(...)
```

---

## Phase 2 — Complexity Reduction

**Scope:** Behavior-preserving restructuring. Each function after refactor does the same thing with CC ≤ 5.

### PlayHandler — animation dispatch deduplication

The 11-line categorization block is identical in `on_play_requested()` and `_auto_end_round()`.

```gdscript
# extracted helper (CC 3)
func _categorize_tiles_by_animation(tiles: Array[Tile]) -> Dictionary:
    var spin: Array[Tile] = []
    var stomp: Array[Tile] = []
    for tile in tiles:
        if tile.has_modifier(ModifierTypes.Type.RESET):
            stomp.append(tile)
        elif tile.has_modifier(ModifierTypes.Type.EXTRA) \
            or tile.has_modifier(ModifierTypes.Type.MULTI) \
            or tile.has_modifier(ModifierTypes.Type.EXPO):
            spin.append(tile)
        else:
            stomp.append(tile)
    return {spin = spin, stomp = stomp}
```

Both callers replaced with one line: `var cats := _categorize_tiles_by_animation(tiles)`.

CC `on_play_requested()`: 7 → ≤ 5
CC `_auto_end_round()`: 6 → ≤ 5

### GameplayController — drag and cell-click decomposition

`_on_tile_drag_started()` (CC 7): extract `_collect_drag_candidates(tile) -> Array[Tile]`.
`_on_cell_clicked()` (CC 6): extract `_place_tiles_on_cell(movable: Array[Tile], cell: BoardCell)`.
`_on_tile_selected()` (CC 5): replace sequential `if/elif` with `match tile.location`.

### RunManager — win condition check extraction

`_on_round_ended()` (CC 6): extract `_check_quality_win_conditions() -> Dictionary` returning `{should_end, victory}`.

### RandomModifiersQuality — weighted picker deduplication

`_pick_weighted_type()` and `_pick_weighted_tier()` are identical in structure (CC 6 each).

```gdscript
# extracted helper
func _pick_weighted(weights: Dictionary) -> Variant:
    var total: int = 0
    for w in weights.values(): total += w
    var roll := randi() % total
    var cumulative := 0
    for key in weights:
        cumulative += weights[key]
        if roll < cumulative:
            return key
    return weights.keys()[0]
```

Both callers become one-liners. CC: 6 → 2 each.

---

## Phase 3 — Architecture Patterns

**Scope:** New types introduced, signal wiring changed. Most reviewable phase in isolation.

### SignalTracker (new file: `scripts/util/signal_tracker.gd`)

One canonical pattern for signal lifecycle management across the codebase.

```gdscript
class_name SignalTracker
extends RefCounted

var _connections: Array[Dictionary] = []

func track(sig: Signal, fn: Callable) -> void:
    sig.connect(fn)
    _connections.append({s = sig, f = fn})

func disconnect_all() -> void:
    for c in _connections:
        if c.s.is_connected(c.f):
            c.s.disconnect(c.f)
    _connections.clear()
```

**GameplayController**: replaces `_safe_connect()`, `_disconnect_all()`, `_connections` array with `_tracker: SignalTracker`.
**RunManager**: replaces `_quality_connections` inline tracking with `_quality_tracker: SignalTracker`.

### TimerQuality base class (new file: `scripts/domain/qualities/timer_quality.gd`)

Shared countdown logic extracted from both timer qualities.

```gdscript
class_name TimerQuality
extends RunQuality

var _time_remaining: float = 0.0

func on_process(delta: float) -> void:
    _time_remaining = maxf(0.0, _time_remaining - delta)
    time_updated.emit(_time_remaining)
    if _time_remaining <= 0.0:
        time_expired.emit()
```

`TimeAttackQuality`: extends `TimerQuality`, sets `_time_remaining` in `on_round_started()`.
`LimitedTimeWithIncrementQuality`: extends `TimerQuality`, adds `_increment` in `on_round_started()`.

### PlayHandler — UI decoupling via signals

```gdscript
# play_handler.gd
signal draw_blocked_changed(blocked: bool)
signal play_button_changed(enabled: bool, end_round_mode: bool)

# replaces: main_hud.set_draw_button_blocked(true)
draw_blocked_changed.emit(true)
```

`setup()` loses `main_hud` parameter. `GameplayController.setup()` connects the two signals to `main_hud` calls after constructing `_play`.

### TileAnimator — generic lazy-loader

5 identical `_ensure_*_resources()` methods collapsed to one helper:

```gdscript
func _ensure(s_ref: RefCounted, e_ref: RefCounted, s_class: GDScript, e_class: GDScript) -> Array:
    if not s_ref: s_ref = s_class.new()
    if not e_ref: e_ref = e_class.new()
    return [s_ref, e_ref]
```

Each of the 5 callers becomes: `[_spin_strategy, _spin_executor] = _ensure(...)`.

---

## Files Changed

| Phase | File | Change type |
|-------|------|-------------|
| 1 | `scenes/tile/tile.gd` | Remove `is_wild`, `point_modifier` |
| 1 | `scripts/animation/draw/draw_tile_animation.gd` | Remove `start_alpha` |
| 1 | `autoload/run_manager.gd` | Remove `initialize_run()` |
| 1 | `autoload/tile_bag.gd` | Private fields + getters |
| 1 | `autoload/hand_manager.gd` | Private `_discard_pile` |
| 1 | `scripts/controllers/gameplay_controller.gd` | Private `_interaction_mode`, `_selected_tile` |
| 1 | `scripts/controllers/drop_handler.gd` | Remove `last_placement_success` |
| 1 | (callers of above) | Update to new API |
| 2 | `scripts/controllers/play_handler.gd` | Extract `_categorize_tiles_by_animation()` |
| 2 | `scripts/controllers/gameplay_controller.gd` | Extract drag/cell helpers, use match |
| 2 | `autoload/run_manager.gd` | Extract `_check_quality_win_conditions()` |
| 2 | `scripts/domain/qualities/random_modifiers_quality.gd` | Extract `_pick_weighted()` |
| 3 | `scripts/util/signal_tracker.gd` | **New file** |
| 3 | `scripts/domain/qualities/timer_quality.gd` | **New file** |
| 3 | `scripts/controllers/gameplay_controller.gd` | Use SignalTracker |
| 3 | `autoload/run_manager.gd` | Use SignalTracker |
| 3 | `scripts/controllers/play_handler.gd` | Signals instead of HUD calls |
| 3 | `scripts/domain/qualities/time_attack_quality.gd` | Extend TimerQuality |
| 3 | `scripts/domain/qualities/limited_time_with_increment_quality.gd` | Extend TimerQuality |
| 3 | `autoload/tile_animator.gd` | Generic `_ensure()` helper |

---

## Out of Scope

- `RunSetupPopup._populate_quality_list()` CC 5 — borderline, layout logic acceptable inline.
- `DebugManager` hardcoded node paths — debug tooling, low priority.
- `tile_placement_handler.gd` missing null check for `tile_anchor` — separate bug fix if needed.
- Game configuration TODOs (refill behavior, plays per round) — product decisions, not code quality.
- `MaxScoreInNRoundsQuality` semantic mismatch ("Sprint") — naming cleanup separate from this.
