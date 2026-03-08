# Code Quality & DDD Refactor Design

## Date: 2026-03-07

## Goals

- Full DDD: pure domain layer with value objects, domain events, domain services
- Full immutability: domain state changes produce new objects via `with_*` builders
- Cyclomatic complexity cap: CC<=5 (exception: flat match/enum dispatch with single-expression arms)
- Low verbosity/high frequency: eliminate duplication, prefer concise idioms
- Phased migration: passthroughs on nodes during transition, removed once callers migrate

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Priority | Code quality first | Root cause of other issues; makes controls/animation work easier later |
| DDD level | Full DDD | Pure domain layer, domain events, value objects, aggregates |
| Tile split approach | Phased | Passthroughs during migration, avoid big-bang breakage |
| CC enforcement | CC<=5 with flat match exception | Pragmatic — enum dispatch allowed beyond 5 if single-expression arms |
| Immutability | Full | `with_*` builders, new objects on mutation, event sourcing style |
| Sequencing | Vertical slices | One domain concept at a time, full depth per slice |

## Approach: Vertical Slices

Each slice goes full depth: domain type -> service -> node adapter -> caller migration.

## Foundational Patterns

### Immutable Value Objects

All domain types are RefCounted, all fields private, all mutations return new instances.

```gdscript
class_name TileState extends RefCounted

var _letter: String
var _base_points: int
var _modifiers: ModifierCollection

func _init(letter: String, base_points: int, modifiers: ModifierCollection) -> void:
    _letter = letter
    _base_points = base_points
    _modifiers = modifiers

func get_letter() -> String: return _letter
func get_base_points() -> int: return _base_points
func get_modifiers() -> ModifierCollection: return _modifiers

func with_modifier(modifier: ModifierInstance) -> TileState:
    return TileState.new(_letter, _base_points, _modifiers.with_added(modifier))

func without_modifier(type: ModifierTypes.Type) -> TileState:
    return TileState.new(_letter, _base_points, _modifiers.without(type))
```

### Domain Events

Pure GDScript event objects, decoupled from Godot signals.

```gdscript
class_name DomainEvent extends RefCounted

class_name TileStateChanged extends DomainEvent
var _tile_id: int
var _old_state: TileState
var _new_state: TileState

class_name DomainEventBus extends RefCounted
# subscribe(event_type, handler), publish(event)
```

### Node Adapter Pattern

Godot nodes own a domain object and expose passthroughs during migration:

```gdscript
var state: TileState
var letter: String:
    get: return state.get_letter()
```

### CC<=5 via Composition

- Lookup tables: Dictionary mapping condition -> handler callable
- Small focused methods: each handles one branch
- Polymorphic dispatch: behavior objects handle their own case
- Flat match exception: single-level match on enums allowed beyond 5 arms

---

## Slice 1: Modifier System

### Problems
- `Tile.modifiers` is public mutable Dictionary
- `add_modifier()` spawns TileSparkEffect (visual side effect in domain op)
- `_update_modifier_visual()` called inside domain mutations
- Modifier iteration pattern duplicated 4+ times
- `consume_modifiers()` and `clear_round_modifiers()` have overlapping logic

### New Domain Types

**ModifierCollection** (immutable value object):
- `with_added(modifier) -> ModifierCollection`
- `without(type) -> ModifierCollection`
- `without_lifetime(lifetime) -> ModifierCollection` (replaces clear_round_modifiers)
- `without_consumables() -> ModifierCollection` (replaces consume_modifiers)
- `has(type) -> bool`
- `get(type) -> ModifierInstance?`
- `get_all() -> Array[ModifierInstance]`
- `get_by_lifetime(lifetime) -> Array[ModifierInstance]`
- `is_empty() -> bool`, `size() -> int`
- `static EMPTY: ModifierCollection`

**TileState** (immutable value object):
- `_letter`, `_base_points`, `_modifiers: ModifierCollection`, `_location: TileLocation`
- `with_modifier()`, `without_modifier()`, `with_location()`
- `with_consumed_modifiers()`, `with_cleared_round_modifiers()`
- `is_locked() -> bool` (derived: has LOCKED modifier)
- `get_points() -> int` (delegates to ModifierScoring)
- `static create(letter, points) -> TileState`

### Refactored Nodes

**TileNode** (refactored Tile.gd):
- `_state: TileState` (private, immutable)
- `_domain_events: DomainEventBus` (injected)
- Passthroughs: `letter`, `is_locked`, `get_points()`, `modifiers`
- `update_state(new_state)`: sets state, publishes TileStateChanged

**TileVisualReactor** (new Node, child of TileNode):
- Subscribes to DomainEventBus for TileStateChanged
- Compares old vs new modifiers -> triggers visual updates
- Owns: BadgeContainer, TileSparkEffect, locked_border

### Caller Migration

| Current | Becomes |
|---|---|
| `tile.modifiers[type]` | `tile.get_modifiers().get(type)` |
| `tile.add_modifier(mod)` | `tile.update_state(tile.state.with_modifier(mod))` |
| `tile.remove_modifier(type)` | `tile.update_state(tile.state.without_modifier(type))` |
| `tile.consume_modifiers()` | `tile.update_state(tile.state.with_consumed_modifiers())` |
| `tile.clear_round_modifiers()` | `tile.update_state(tile.state.with_cleared_round_modifiers())` |
| `tile.is_locked` | `tile.is_locked()` |
| `tile.set_locked(val)` | `tile.update_state(tile.state.with_modifier(LOCKED))` or `without` |

### Migration Steps
1. Build ModifierCollection and TileState as standalone files
2. Add TileVisualReactor as child node in Tile.tscn
3. Refactor Tile.gd: replace modifiers Dictionary with _state TileState, add passthroughs
4. Move visual side effects from add/remove_modifier into TileVisualReactor
5. Migrate external callers one file at a time
6. Remove passthroughs once all callers migrated

---

## Slice 2: Scoring & Play

### Problems
- PlayHandler mixes domain logic with orchestration (animation, auto-end-round, UI blocking)
- `_categorize_tiles_by_animation()` type-checks modifier types (domain knowledge in orchestration)
- `_auto_end_round()` has procedural while loop with await
- `on_play_requested()` has CC ~7

### New Domain Types

**PlayResult** (immutable value object):
- `_words: Array[WordResult]`, `_score: int`
- `_tiles_to_lock`, `_tiles_to_consume`
- `is_valid() -> bool`, `get_updated_tile_states() -> Dictionary[int, TileState]`

**WordResult** (immutable value object):
- `_word: String`, `_positions: Array[Vector2i]`
- `_tile_scores: Array[int]`, `_total: int`

### New Services

**PlayValidator** (pure domain service, RefCounted):
- `validate(board_state, tile_states) -> PlayResult`
- Uses WordFinder and ModifierScoring
- No Godot dependencies

**AnimationCategorizer** (pure, RefCounted):
- `categorize(tiles) -> Dictionary[AnimationType, Array]`
- Dictionary lookup replaces if/elif chain

### Refactored Nodes

**PlayExecutor** (refactored from PlayHandler, Node for await):
- Delegates validation to PlayValidator
- Dispatches animations via AnimationCategorizer lookup
- Applies state changes from PlayResult
- CC 3

**AutoPlayHandler** (new Node):
- Owns the while loop for auto-end-round
- Delegates each play to PlayExecutor
- Single responsibility

### CC Reduction

| Function | Before | After |
|---|---|---|
| `on_play_requested()` | CC ~7 | CC 3 |
| `_categorize_tiles_by_animation()` | CC 4 | CC 1 |
| `_auto_end_round()` | CC 5 | CC 2 |

### Migration Steps
1. Build PlayResult, WordResult as pure value objects
2. Extract PlayValidator from PlayHandler
3. Build AnimationCategorizer with lookup table
4. Refactor PlayHandler -> PlayExecutor
5. Extract AutoPlayHandler
6. Update GameplayController to use PlayExecutor

---

## Slice 3: Board & Placement

### Problems
- TilePlacementHandler mixes placement, swap, return, hover clearing (276 LOC)
- DropHandler validates AND executes (mixed query + command)
- `_handle_drag_release()` CC 7-8, PSM sync duplicated 3+ places
- `_on_cursor_confirmed()` CC 6-7

### New Domain Types

**BoardState** (immutable value object):
- `_grid: Dictionary[Vector2i, TileState]`
- `with_tile_at()`, `without_tile_at()`, `with_swapped()`
- `get_tile_at()`, `is_occupied()`, `is_locked_at()`
- `static EMPTY`

**DropDecision** (immutable value object):
- `enum Action { PLACE, SWAP, REJECT }`
- `_action`, `_target_cells`, `_tiles`, `_reason`
- `static place()`, `swap()`, `reject(reason)`

### New Services

**PlacementValidator** (pure, RefCounted):
- `can_place()`, `can_swap()`, `can_place_sequence()`

**DropResolver** (pure, RefCounted):
- `resolve(board, tiles, target) -> DropDecision`
- Uses PlacementValidator internally
- Replaces CC 7-8 branching

### Refactored Nodes

**PlacementExecutor** (refactored from TilePlacementHandler):
- `place_tile()`, `swap_tiles()`, `return_tile_to_hand()`
- No validation — caller checks DropResolver first
- Publishes domain events (TilePlaced, TilesSwapped)

**DropExecutor** (refactored from DropHandler):
- `execute(decision)` via lookup dispatch (CC 1)

**PlayStateManager** becomes event-driven (subscribes to domain events, no manual sync).

### CC Reduction

| Function | Before | After |
|---|---|---|
| `_handle_drag_release()` | CC 7-8 | CC 2 |
| `_on_cursor_confirmed()` | CC 6-7 | CC 3 |
| `swap_tiles()` | CC 3 | CC 1 |

### Migration Steps
1. Build BoardState, DropDecision as value objects
2. Build PlacementValidator, DropResolver as pure services
3. Refactor TilePlacementHandler -> PlacementExecutor
4. Refactor DropHandler -> DropExecutor
5. Simplify _handle_drag_release and _on_cursor_confirmed
6. Make PlayStateManager event-driven

---

## Slice 4: Selection & Interaction

### Problems
- SelectionManager internal array not truly private
- Two independent highlight systems (cursor vs selection)
- DragManager exposes mutable public fields
- Interaction mode logic scattered in GameplayController

### New Domain Types

**SelectionState** (immutable value object):
- `_mode`, `_tiles: Array[int]`
- `with_selected()`, `with_deselected()`, `with_all_deselected()`, `with_toggled_mode()`
- `has()`, `get_order()`, `get_tile_ids()`, `is_multi()`
- `static EMPTY`

**DragState** (immutable value object):
- `_is_active`, `_lead_tile_id`, `_tile_ids`, `_original_positions`
- `static INACTIVE`, `static active()`

**InteractionState** (immutable value object):
- `_selection: SelectionState`, `_drag: DragState`, `_cursor_held_tile_id`
- `with_selection()`, `with_drag()`, `with_cursor_held()`

**TileHighlightState** (value object):
- `_is_cursor_hovered`, `_is_selected`, `_selection_order`
- `get_visual_priority() -> HighlightType` (CURSOR > SELECTED > NONE)
- Unifies two independent highlight systems

### Refactored Nodes
- SelectionManager: internal SelectionState, immutable
- DragManager: internal DragState, private fields
- TileNode: `_update_highlight(TileHighlightState)` replaces dual highlight logic

### Migration Steps
1. Build SelectionState, DragState, InteractionState
2. Refactor SelectionManager internals
3. Refactor DragManager internals
4. Build TileHighlightState, add _update_highlight to TileNode
5. Unify cursor hover + selection highlight
6. Remove passthrough fields

---

## Slice 5: GameplayController Decomposition

### After Slices 1-4
GameplayController should be ~500 LOC. This slice breaks the remainder into focused handlers.

### New Components

**InputRouter** (RefCounted):
- Dictionary lookup dispatch for input actions (CC 1)

**CellHoverHandler** (RefCounted):
- `on_cell_hovered(cell, interaction)`, `on_cell_unhovered(cell)`
- Uses PlacementValidator for validation
- CC 3 per method

**WordHighlightHandler** (RefCounted):
- `run_scan(board_state)`, `clear()`
- Uses WordFinder
- Replaces _run_realtime_word_scan, _apply_word_highlights, _clear_word_highlights

**DiscardHandler** (RefCounted):
- `request_discard(selection)`, `execute_discard(tiles, target_pos)`
- Replaces _request_discard, _discard_tiles_animated

### Result
GameplayController: ~150 LOC thin orchestrator with setup + cross-handler coordination.

### Migration Steps
1. Extract InputRouter
2. Extract CellHoverHandler
3. Extract WordHighlightHandler
4. Extract DiscardHandler
5. Simplify _connect_signals — each handler owns its connections
6. Audit remaining controller (~150 LOC target)

---

## Slice 6: Cleanup Pass

### Dead Code Removal
- `is_wild: bool` (Tile.gd)
- `point_modifier: int` (Tile.gd)
- `start_alpha: float` (DrawTileAnimation)
- `initialize_run()` (RunManager)
- Duplicate `cell.clear_hover()` (GameplayController:699)
- Deprecated passthroughs after caller migration

### Duplicate Pattern Consolidation
- Clear all cell hovers: single `Board.clear_all_hovers()`
- PSM tile sync: eliminated (event-driven from Slice 3)
- Modifier iteration by lifetime: `ModifierCollection.get_by_lifetime()`
- Tile restore-to-hand: `PlacementExecutor.return_tile_to_hand()`

### Half-Baked Feature Completion
- Animation blocking: wire guard checks in executors
- RunState: make round_scores private, return duplicate via getter

### Mutable State Audit
Verify no public mutable fields remain in domain layer.

---

## Target File Structure

```
scripts/
  domain/
    tile_state.gd
    modifier_collection.gd
    board_state.gd
    selection_state.gd
    drag_state.gd
    interaction_state.gd
    play_result.gd
    word_result.gd
    drop_decision.gd
    domain_event.gd
    domain_event_bus.gd
    services/
      play_validator.gd
      placement_validator.gd
      drop_resolver.gd
      modifier_scoring.gd
      animation_categorizer.gd
  controllers/
    gameplay_controller.gd       (~150 LOC)
    input_router.gd
    cell_hover_handler.gd
    word_highlight_handler.gd
    discard_handler.gd
    play_executor.gd
    auto_play_handler.gd
    drop_executor.gd
    placement_executor.gd
  interaction/
    tile_drag_helper.gd
    board_typing_session.gd
scenes/
  tile/
    tile.gd                      (~200 LOC)
    tile_visual_reactor.gd
```
