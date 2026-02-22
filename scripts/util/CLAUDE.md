# Util Directory

## Purpose
Utility and helper classes providing reusable infrastructure for signal management and other cross-cutting concerns. Helpers for system-level operations and lifecycle management.

## Key Files
- `signal_tracker.gd` - Signal connection tracking and batch cleanup

## Public Interfaces

### SignalTracker (Signal Management Utility)
```gdscript
class_name SignalTracker extends RefCounted

# Tracks signal connections
func track(sig: Signal, fn: Callable) -> void

# Disconnects all tracked connections
func disconnect_all() -> void
```

**Purpose:** Eliminates boilerplate for managing multiple signal connections. Records each connection and disconnects all at once, ideal for cleanup in `_exit_tree()` or when objects are destroyed.

**Pattern:** Replaces ad-hoc `_connections` arrays and repetitive disconnect loops found throughout codebase.

**Usage:**
```gdscript
var tracker = SignalTracker.new()

# Track connections as they're made
tracker.track(tile.tile_selected, Callable(self, "_on_tile_selected"))
tracker.track(EventBus.tile_placed, Callable(self, "_on_tile_placed"))
tracker.track(button.pressed, Callable(self, "_on_button_pressed"))

# Later, disconnect all at once
tracker.disconnect_all()
```

## Dependencies
- **Internal:** None (pure Godot API wrappers)
- **External:** Godot Signal and Callable API

## Architecture / Patterns
- **RAII Pattern:** Lifecycle management for signal connections
- **Repository Pattern:** Tracks connections in array, provides batch operations
- **Refactoring Helper:** Reduces boilerplate in object setup/teardown

## Constraints
- Only tracks Signal-to-Callable connections (standard Godot connections)
- Does not support custom connection parameters
- Intended for cleanup, not for conditional connection management

## Build / Test
No build step. Test signal tracking behavior in unit tests for managers that use it.

---

## Conventions
- **Naming:** `track()` for recording, `disconnect_all()` for cleanup
- **Lifecycle:** Typically created and owned by a manager for its lifetime
- **Pattern:** Connect → Track → Later Disconnect pattern

## Usage in Context
```gdscript
# In GameplayController or similar manager
var _signals = SignalTracker.new()

func setup(...) -> void:
    _signals.track(EventBus.tile_placed, Callable(self, "_on_tile_placed"))
    _signals.track(EventBus.tile_removed, Callable(self, "_on_tile_removed"))
    _signals.track(_selection.selection_changed, Callable(self, "_on_selection_changed"))

func _exit_tree() -> void:
    _signals.disconnect_all()  # Clean disconnect without individual statements
```

## Future Enhancements
- Conditional connection tracking (connect only if guard passes)
- Named connections for selective disconnection
- Connection validation before disconnect
