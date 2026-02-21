# Domain/Qualities Directory

## Purpose
Contains all RunQuality implementations and the QualityRegistry. RunQualities are roguelike modifiers that alter gameplay rules (timers, hand size, round limits, random modifiers).

## Key Files
- `quality_registry.gd` - Static factory registry for RunQuality instantiation
- `time_attack_quality.gd` - Countdown timer quality (120s per round)
- `limited_time_with_increment_quality.gd` - Timer with per-play time bonus
- `max_hand_size_quality.gd` - Increases hand size to 15 tiles
- `max_score_in_n_rounds_quality.gd` - Must reach target score within N rounds
- `random_modifiers_quality.gd` - Applies random modifiers to tiles each round
- `all_reset_quality.gd` - All tiles carry RESET modifier
- `auto_win_quality.gd` - Debug quality for instant victory

## Public Interfaces

### QualityRegistry (Static Factory)
```gdscript
class_name QualityRegistry extends RefCounted

static func register(id: StringName, factory: Callable) -> void
static func create_from_dict(data: Dictionary) -> RunQuality
static func create_default(id: StringName) -> RunQuality
static func get_all_quality_ids() -> Array[StringName]
```

### RunQuality (Abstract Base Class)
Defined in parent directory (`scripts/domain/run_quality.gd`):
```gdscript
class_name RunQuality extends RefCounted

# Identity
func get_quality_id() -> StringName
func get_quality_name() -> String
func get_description() -> String

# Lifecycle hooks
func apply_to_run_state(run_state: RunState) -> void
func on_round_started(round_number: int) -> void
func on_round_ended(round_number: int, success: bool) -> void
func on_process(delta: float) -> void

# Serialization
func to_dict() -> Dictionary
func from_dict(data: Dictionary) -> void

# Timer support
func has_timer() -> bool

# Signals
signal time_updated(time_remaining: float)
signal time_expired()
```

## Dependencies

### Internal
- `scripts/domain/run_quality.gd` - Abstract base class
- `scripts/domain/run_state.gd` - Runtime state container
- `scripts/domain/modifiers/modifier_registry.gd` - For random modifier creation
- `autoload/tile_bag.gd` - Access to available tiles for modifier application

### External (Godot)
- `RefCounted` - Base class for quality objects
- `StringName` - For quality IDs

## Architecture / Patterns

**Registry Pattern**: Static factory with lazy initialization. All built-in qualities registered in `_ensure_initialized()`.

**Factory Method**: Each quality ID maps to a lambda that instantiates the concrete quality class.

**Template Method**: RunQuality base class defines lifecycle hooks; subclasses override specific hooks.

**Hook Architecture**:
- `apply_to_run_state()` - Modify initial run configuration (hand size, plays)
- `on_round_started()` - Initialize per-round state (timers, modifiers)
- `on_round_ended()` - Cleanup, check win/loss conditions
- `on_process()` - Per-frame updates (countdown timers)

**Serialization Support**: Qualities can serialize/deserialize from Dictionary via `to_dict()` / `from_dict()`.

## Conventions

### Quality ID Naming
- Snake case StringNames: `&"time_attack"`, `&"max_hand_size"`
- IDs must be unique across all qualities
- Registry lookup returns `null` and logs warning for unknown IDs

### Timer Qualities
- Override `has_timer() -> bool` to return `true`
- Emit `time_updated(float)` signal during `on_process()`
- Emit `time_expired()` when timer reaches zero
- Store timer state in instance variables

### State Modification Qualities
- Override `apply_to_run_state()` to modify `RunState` before run begins
- Examples: `max_hand_size`, `max_score_in_n_rounds`

### Per-Round Modifier Qualities
- Override `on_round_started()` to apply modifiers at round start
- Use `TileBag.available_tiles` to access tiles
- Use `ModifierRegistry.create_modifier()` to instantiate modifiers
- Examples: `random_modifiers_quality`, `all_reset_quality`

### Registration Pattern
```gdscript
_factories[&"quality_id"] = func() -> RunQuality: return ConcreteQuality.new()
```

## Build / Test
Qualities are selected in RunSetupPopup before starting a run. Test by:
1. Launch game (`F5`)
2. Select quality in Run Setup dialog
3. Start run and verify quality behavior
4. Check timer HUD, hand size, or tile modifiers as appropriate

**Debug Quality**: `auto_win` instantly completes rounds for testing.
