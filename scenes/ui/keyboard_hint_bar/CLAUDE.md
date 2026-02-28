# Keyboard Hint Bar Component

## Purpose
Displays live keyboard and joypad keybinding hints for available in-game actions. Updates automatically when bindings change or input device type changes.

## Key Files
- `keyboard_hint_bar.gd` - Keybinding hint bar controller
- `keyboard_hint_bar.tscn` - Hint bar scene with HBoxContainer layout

## Public Interfaces

### KeyboardHintBar (UI Component)
```gdscript
class_name KeyboardHintBar extends HBoxContainer

# Configurable hints array
var HINTS: Array[Dictionary]  # {action: StringName, label: String}

# Signal when bindings change
# (Listens to KeybindingConfig.binding_changed internally)
```

## Supported Actions
| Action | Label | Purpose |
|--------|-------|---------|
| `PLAY_HAND` | "Play" | Submit word/play |
| `DRAW_TILES` | "Draw" | Draw tiles from bag |
| `DISCARD_TILES` | "Discard" | Discard tiles from hand |
| `TOGGLE_MULTI` | "Multi" | Toggle multi-select mode |
| `SWITCH_ZONE` | "Zone" | Switch hand/board focus |
| `PAUSE_GAME` | "Pause" | Pause gameplay |

## Visual Structure
```
KeyboardHintBar (HBoxContainer)
├── Chip (for each action)
│   ├── Badge (key icon/name)
│   ├── Label (action label)
│   └── Separator (between chips)
```

## Key Methods

### Display & Refresh
```gdscript
# Rebuilds chips and refreshes all bindings
_build_chips() -> void
_refresh_all() -> void

# Updates single chip after binding change
_refresh_chip(action: StringName) -> void
```

### Auto-Update Triggers
- KeybindingConfig.binding_changed → Calls _refresh_chip()
- Joypad connected/disconnected → Calls _refresh_all()

## Dependencies
- **Internal:** KeybindingConfig, KeyAction
- **External:** Godot Input system, Input device detection

## Architecture / Patterns
- **Signal-Driven:** Listens to binding and joypad changes
- **Reactive UI:** Updates display when input context changes
- **Device-Aware:** Detects joypad vs keyboard input
- **Configuration-Driven:** Hints defined in HINTS array

## Constraints
- Display must handle variable key name lengths
- Must support both keyboard and joypad input names
- Should be visible during gameplay (not in modals)
- Hint layout should remain readable on small screens

## Build / Test
Test with:
- Different keybinding configurations
- Keyboard input
- Joypad/controller input
- Dynamic binding changes during gameplay

---

## Conventions
- **Naming:** Label text is concise action descriptions
- **Order:** HINTS array order determines left-to-right display
- **Format:** Displays "[KEY] Label" with icon/text styling
- **Refresh:** _on_binding_changed triggers chip refresh

## Usage in Context
```gdscript
# Automatically created in Main HUD or gameplay scene
# Updates in response to:
# 1. Binding changes via KeybindingConfig
# 2. Joypad connection/disconnection

# To customize hints:
# 1. Edit HINTS array in scene or script
# 2. Add/remove actions as needed
# 3. Labels auto-update when bindings change
```

## Related Components
- **KeybindingConfig:** Manages keybinding storage and change signals
- **KeyAction:** Defines input action constants
