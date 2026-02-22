# Keyboard Controller Improvements — Design

**Date:** 2026-02-22
**Branch:** keyboard
**Approach:** C (full refactor — domain model + player hints + controller polish)

---

## Context

The keyboard/controller system is functional but has several architectural gaps and UX blind spots:

- Cursor signals carry `Variant` position — callers must cast and branch on zone manually
- Raw `StringName` action literals (`"navigate_left"` etc.) are scattered across 8+ files
- Five modal popups duplicate the same input-blocking/close pattern verbatim
- No in-game keyboard hints — players have no discoverability of keybindings
- Joypad Y bound to both `play_hand` and `discard_tiles` (conflict)
- Multi-select mode has no on-screen indicator
- Controls tab is a flat list with no categories and no reset confirmation

---

## Section 1 — Domain Model

Three new value objects / constants in `scripts/input/`.

### `KeyAction` — action name constants

Centralises every `StringName` action name. Eliminates typos and enables IDE completion.

```gdscript
class_name KeyAction

const NAVIGATE_LEFT  := &"navigate_left"
const NAVIGATE_RIGHT := &"navigate_right"
const NAVIGATE_UP    := &"navigate_up"
const NAVIGATE_DOWN  := &"navigate_down"
const CONFIRM        := &"confirm_action"
const CANCEL         := &"cancel_action"
const SWITCH_ZONE    := &"switch_zone"
const PLAY_HAND      := &"play_hand"
const DRAW_TILES     := &"draw_tiles"
const DISCARD_TILES  := &"discard_tiles"
const PAUSE_GAME     := &"pause_game"
const TOGGLE_MULTI   := &"toggle_multi_select"
```

All call sites replace raw string literals with `KeyAction.*` constants.

### `CursorPosition` — typed value object

Replaces `Variant` in all three cursor signals. Static factories are the only creation path; fields are never mutated after construction.

```gdscript
class_name CursorPosition
extends RefCounted

enum Zone { HAND, BOARD }

var zone: Zone
var hand_index: int        # meaningful only when zone == HAND
var board_coords: Vector2i # meaningful only when zone == BOARD

static func hand(index: int) -> CursorPosition: ...
static func board(coords: Vector2i) -> CursorPosition: ...

func is_hand()  -> bool: return zone == Zone.HAND
func is_board() -> bool: return zone == Zone.BOARD
```

Cursor signals become single-argument typed:
```gdscript
signal cursor_confirmed(pos: CursorPosition)
signal cursor_cancelled(pos: CursorPosition)
signal cursor_moved(pos: CursorPosition)
```

### `CursorState` — aggregate value object

Groups `_zone`, `_hand_index`, `_board_coords`, and `_held_tile` into one object.
`FocusCursor` holds `_state: CursorState` and replaces it whole on each navigation step
(replace-whole immutability — never mutate fields directly).

```gdscript
class_name CursorState
extends RefCounted

var position: CursorPosition  # immutable once set
var held_tile: Tile            # null when nothing held

static func at_hand(index: int) -> CursorState: ...

# Copy-with helpers — return a new CursorState, leave self untouched
func with_hand_index(i: int)        -> CursorState: ...
func with_board_coords(c: Vector2i) -> CursorState: ...
func with_held_tile(t: Tile)        -> CursorState: ...
func cleared_tile()                 -> CursorState: ...
```

`_is_active` and `_highlighted_hand_tile` remain plain vars on `FocusCursor` —
they are rendering/lifecycle concerns local to the node, not domain state.

---

## Section 2 — `ModalInputGuard` Mixin

A single `RefCounted` owned by each popup. Centralises guard/block/close logic
currently copy-pasted across five files.

```gdscript
class_name ModalInputGuard
extends RefCounted

signal close_requested

func setup(owner: CanvasLayer) -> ModalInputGuard: ...
func add_close_action(action: StringName) -> ModalInputGuard: ...
func add_blocked_action(action: StringName) -> ModalInputGuard: ...

# Returns true if event was consumed (popup should return early)
func handle(event: InputEvent) -> bool: ...
```

Default blocked set (applied automatically in `setup()`):
`NAVIGATE_*`, `CONFIRM`, `ui_up/down/left/right`.

Each popup shrinks to:

```gdscript
var _guard: ModalInputGuard

func _ready() -> void:
    _guard = ModalInputGuard.new() \
        .setup(self) \
        .add_close_action(KeyAction.CANCEL)
    _guard.close_requested.connect(close_popup)

func _input(event: InputEvent) -> void:
    if _guard.handle(event):
        return
    # popup-specific logic only
```

Per-popup variations (OptionsPopup tab switching, RunSetupPopup WASD forwarding)
stay in the popup's own `_input()` after the guard call.

**Affected files:** `game_over_popup.gd`, `pause_menu.gd`,
`discard_confirmation_dialog.gd`, `options_popup.gd`, `run_setup_popup.gd`,
new `scripts/input/modal_input_guard.gd`.

---

## Section 3 — `FocusCursor` Refactor

### State consolidation

```gdscript
# Before — 3 separate mutable vars + held tile scattered
var _zone: Zone = Zone.HAND
var _hand_index: int = 0
var _board_coords: Vector2i = Vector2i(0, 0)
var _held_tile: Tile = null

# After — one aggregate, replaced whole on each transition
var _state: CursorState = CursorState.at_hand(0)
```

### Navigation becomes declarative

```gdscript
# Before
_hand_index = (_hand_index + 1) % count
cursor_moved.emit(Zone.HAND, _hand_index)

# After
_state = _state.with_hand_index((_state.position.hand_index + 1) % count)
cursor_moved.emit(_state.position)
```

### `GameplayController` signal handler — typed, no casting

```gdscript
func _on_cursor_confirmed(pos: CursorPosition) -> void:
    if pos.is_hand():
        var tile := hand.get_tile_at(pos.hand_index)
        ...
    elif pos.is_board():
        var cell := board.get_cell(pos.board_coords.y, pos.board_coords.x)
        ...
```

### All raw action strings replaced with `KeyAction.*`

Throughout `_unhandled_input()` in `gameplay_controller.gd` and throughout
`_unhandled_input()` in `focus_cursor.gd`.

**Affected files:** `focus_cursor.gd`, `gameplay_controller.gd`.

---

## Section 4 — Keyboard Hint Bar

A slim read-only panel docked to the bottom of the screen, always visible during
gameplay.

### Layout

```
[P] Play  ·  [L] Draw  ·  [Z] Discard  ·  [Q] Multi  ·  [Tab] Zone  ·  [Esc] Pause
```

When a joypad is the last-used input device, key badges swap to controller glyphs
(`Ⓐ`, `Ⓑ`, `🎮LT` etc.). Detected via `Input.joy_connection_changed`.

### Scene structure

```
KeyboardHintBar (HBoxContainer)
  └── repeating: HintChip (HBoxContainer)
        ├── KeyBadge   (Label, styled Panel background)
        └── ActionLabel (Label)
```

### Configuration

```gdscript
const HINTS: Array[Dictionary] = [
    { action = KeyAction.PLAY_HAND,     label = "Play"    },
    { action = KeyAction.DRAW_TILES,    label = "Draw"    },
    { action = KeyAction.DISCARD_TILES, label = "Discard" },
    { action = KeyAction.TOGGLE_MULTI,  label = "Multi"   },
    { action = KeyAction.SWITCH_ZONE,   label = "Zone"    },
    { action = KeyAction.PAUSE_GAME,    label = "Pause"   },
]
```

### Live updates

`KeybindingConfig` gains a `binding_changed(action: StringName)` signal emitted
after every `save_binding()` call. `KeyboardHintBar` connects to it and refreshes
only the affected chip. `KeybindingConfig.get_event_display_text()` gains an
optional `joypad_only: bool` parameter to filter to controller bindings.

### Placement

Added to `MainHUD` as a fixed-height strip (~24 px) anchored to the bottom.
Hidden when `GameplayController` is inactive.

**New files:** `scenes/ui/keyboard_hint_bar/keyboard_hint_bar.gd` + `.tscn`.
**Modified:** `autoload/keybinding_config.gd`, `scenes/ui/main_hud/main_hud.gd`.

---

## Section 5 — Controls Tab, Joypad Fix & Multi-Select Indicator

### Controls tab — categorised layout

| Group | Actions |
|---|---|
| **Navigation** | Navigate Left/Right/Up/Down, Switch Zone |
| **Tile Actions** | Confirm, Cancel, Multi-Select, Discard |
| **Game Actions** | Play Hand, Draw Tiles, Pause |

`KeybindingConfig` gains a `CATEGORIES` constant (ordered `Array[Dictionary]`,
each entry: `{ label: String, actions: Array[StringName] }`).
`OptionsPopup._populate_controls_tab()` inserts separator labels between groups.

### Reset-to-defaults — confirmation step

The Reset button is replaced inline with `[Confirm reset]` + `[Cancel]` for one
interaction cycle before executing. No new scene needed.

### Joypad Y conflict fix

| Button | Action |
|---|---|
| A | confirm_action *(unchanged)* |
| B | cancel_action *(unchanged)* |
| X | draw_tiles *(unchanged)* |
| Y | play_hand *(unchanged)* |
| LT / RT | switch_zone *(unchanged)* |
| **LB** | toggle_multi_select *(was: keyboard only)* |
| **RB** | discard_tiles *(was: Y — conflict removed)* |
| Start | pause_game |

Two-line change in `project.godot`.

### Multi-select mode indicator

When `SelectionManager` enters multi-select mode, the hand container shows a
coloured top border and a small `[MULTI]` badge. Driven by the existing
`SelectionManager.mode_changed` signal. Implemented as a `StyleBoxFlat` swap +
hidden `Label` node toggled by `MainHUD`.

**Modified:** `options_popup.gd`, `autoload/keybinding_config.gd`,
`project.godot`, `scenes/ui/main_hud/main_hud.gd`, `scenes/hand/Hand.tscn`.

---

## File Inventory

### New files
- `scripts/input/key_action.gd`
- `scripts/input/cursor_position.gd`
- `scripts/input/cursor_state.gd`
- `scripts/input/modal_input_guard.gd`
- `scenes/ui/keyboard_hint_bar/keyboard_hint_bar.gd`
- `scenes/ui/keyboard_hint_bar/keyboard_hint_bar.tscn`

### Modified files
- `scenes/ui/focus_cursor/focus_cursor.gd`
- `scripts/controllers/gameplay_controller.gd`
- `scenes/ui/game_over_popup/game_over_popup.gd`
- `scenes/ui/pause_menu/pause_menu.gd` *(or equivalent path)*
- `scenes/ui/discard_confirmation_dialog/discard_confirmation_dialog.gd`
- `scenes/title_screen/options_popup.gd`
- `scenes/title_screen/run_setup_popup.gd`
- `autoload/keybinding_config.gd`
- `scenes/ui/main_hud/main_hud.gd`
- `scenes/hand/Hand.tscn`
- `project.godot`
