# Keyboard & Controller Input Design

**Date**: 2026-02-21
**Status**: Approved

---

## Overview

Replace the current half-baked keyboard handling with a complete, rebindable input system
that supports keyboard, mouse, and game controller equally. All mouse-only actions gain
keyboard/controller equivalents through a new `FocusCursor` node that navigates the hand
and board in a directional, game-console-style fashion. Key rebinding is exposed in a new
Controls tab inside the existing `OptionsPopup`.

---

## Design Principles

- OOP + DDD: `FocusCursor` is a self-contained scene; `KeybindingConfig` is a pure-logic autoload.
- Spec-Driven: every public method carries behavioural contracts as doc comments.
- Cyclomatic complexity ≤ 5; decompose any method that exceeds it.
- No new autoloads except `KeybindingConfig` (stateless I/O helper with no scene dependency).
- Existing mouse/drag interactions are untouched — keyboard is additive.

---

## Section 1: Input Actions

All actions registered in `project.godot`. All are rebindable via the Controls tab.

| Action | Default Keyboard | Controller |
|---|---|---|
| `navigate_left` | A, Left Arrow | D-pad Left / Left stick left |
| `navigate_right` | D, Right Arrow | D-pad Right / Left stick right |
| `navigate_up` | W, Up Arrow | D-pad Up / Left stick up |
| `navigate_down` | S, Down Arrow | D-pad Down / Left stick down |
| `confirm_action` | Space | A / Cross |
| `cancel_action` | Backspace, Delete | B / Circle |
| `play_hand` | P | R2 / RT |
| `draw_tiles` | L | L1 / LB |
| `discard_tiles` | Z (existing) | Triangle / Y |
| `pause_game` | Escape (existing) | Start |
| `toggle_multi_select` | Q (existing) | X / Square |

---

## Section 2: FocusCursor

### Location

`scenes/ui/focus_cursor/FocusCursor.tscn` + `focus_cursor.gd`

Added as a child of `Main`, injected into `GameplayController` via `setup()`.

### Domain Model

```gdscript
## Invariant : only one zone is active at a time.
## Invariant : _hand_index is always in [0, hand.get_tile_count() - 1] when HAND zone.
## Invariant : _board_coords is always within board bounds when BOARD zone.
## Invariant : _held_tile is null when zone is HAND and no tile has been confirmed.

enum Zone { HAND, BOARD }

var _zone: Zone = Zone.HAND
var _hand_index: int = 0
var _board_coords: Vector2i = Vector2i(0, 0)
var _held_tile: Tile = null
var _is_active: bool = false
```

### Public API

```gdscript
## Precondition : board and hand are valid non-null references.
func setup(board: Board, hand: Hand) -> void

## Postcondition: cursor becomes visible and processes input.
func activate() -> void

## Postcondition: cursor hides, stops processing input, clears held tile.
func deactivate() -> void

## Postcondition: _held_tile set; tile.modulate.a = 0.5 (faded in hand).
func set_held_tile(tile: Tile) -> void

## Postcondition: _held_tile = null; tile.modulate.a = 1.0 restored.
func clear_held_tile() -> void

## Returns the BoardCell at _board_coords, or null if zone is HAND.
func get_current_cell() -> BoardCell
```

### Signals

```gdscript
## position is int (hand index) when zone == HAND, Vector2i (col, row) when zone == BOARD.
signal cursor_confirmed(zone: Zone, position: Variant)
signal cursor_cancelled(zone: Zone, position: Variant)
signal cursor_moved(zone: Zone, position: Variant)
```

### Navigation Logic

**HAND zone:**

| Input | Result |
|---|---|
| `navigate_left` | `_hand_index -= 1`, wraps to last tile |
| `navigate_right` | `_hand_index += 1`, wraps to first tile |
| `navigate_up` | switch to BOARD zone; land on bottom row, col nearest to `_hand_index` |
| `navigate_down` | no-op |
| `confirm_action` | emit `cursor_confirmed(HAND, _hand_index)` |
| `cancel_action` | emit `cursor_cancelled(HAND, _hand_index)` |

**BOARD zone:**

| Input | Result |
|---|---|
| `navigate_left` | `_board_coords.x -= 1`, clamp to [0, columns-1] |
| `navigate_right` | `_board_coords.x += 1`, clamp to [0, columns-1] |
| `navigate_up` | `_board_coords.y -= 1`, clamp to [0, rows-1] |
| `navigate_down` (row > 0) | `_board_coords.y += 1` |
| `navigate_down` (row == bottom) | switch to HAND zone; `_hand_index` = nearest col |
| `confirm_action` | emit `cursor_confirmed(BOARD, _board_coords)` |
| `cancel_action` | emit `cursor_cancelled(BOARD, _board_coords)` → cursor returns to HAND |

### Tile Preview Rendering

When `_held_tile != null` and zone is BOARD:
- Cursor highlight renders at the target cell position.
- A semi-transparent ghost (tile letter + background colour at 50% alpha) is drawn inside
  the cursor rect using `draw_*` calls in `_draw()`.
- If the target cell is occupied → cursor tints red; if free → tints white/green.

When `_held_tile != null` and zone is HAND:
- No special rendering; tile is faded in hand (set by `set_held_tile`).

---

## Section 3: GameplayController Changes

### New `_unhandled_input` handlers

```gdscript
## Postcondition: play is attempted if board state allows.
if event.is_action_pressed("play_hand"):
    _on_play_requested()

## Postcondition: draw is attempted if bag has tiles.
if event.is_action_pressed("draw_tiles"):
    _on_draw_requested()
```

### Cursor signal handlers (connected in `_connect_signals`)

```gdscript
_tracker.track(_cursor.cursor_confirmed, _on_cursor_confirmed)
_tracker.track(_cursor.cursor_cancelled, _on_cursor_cancelled)
_tracker.track(_cursor.cursor_moved,     _on_cursor_moved)
```

**`_on_cursor_confirmed(zone, position)`**:

```
HAND zone:
  tile = hand.get_tiles()[position]
  → _on_tile_selected(tile)
  → _cursor.set_held_tile(tile)

BOARD zone + _held_tile set:
  cell = board.get_cell(position.y, position.x)
  → _place_tiles_on_cell([_held_tile], cell)
  → _cursor.clear_held_tile()

BOARD zone + no held tile + cell occupied:
  tile = cell.tile
  → if not tile.is_locked: re-select tile for repositioning
  → _cursor.set_held_tile(tile)
```

**`_on_cursor_cancelled(zone, position)`**:

```
→ _selection.deselect_all()
→ _cursor.clear_held_tile()
→ (cursor internally returns to HAND zone)
```

**`_on_cursor_moved(zone, position)`** (BOARD only):

```
→ _on_cell_hovered(board.get_cell(position.y, position.x))
  (clears previous hover via existing _hovered_cell tracking in Board)
```

### `setup()` signature change

```gdscript
## Added p_cursor parameter.
func setup(p_board, p_hand, p_discard_pile, p_discard_dialog, p_hud, p_selection, p_cursor) -> void
```

---

## Section 4: KeybindingConfig (new Autoload)

### Location

`scripts/managers/keybinding_config.gd`, registered as autoload `KeybindingConfig`.

### Keybindable actions

`navigate_left`, `navigate_right`, `navigate_up`, `navigate_down`,
`confirm_action`, `cancel_action`, `play_hand`, `draw_tiles`,
`discard_tiles`, `pause_game`, `toggle_multi_select`

### API

```gdscript
## Postcondition: any saved overrides in user://keybindings.cfg are applied to InputMap.
## Call once from Main._ready() and TitleScreen._ready().
static func load_and_apply() -> void

## Precondition : action is in the keybindable actions list.
## Postcondition: InputMap updated; binding persisted to user://keybindings.cfg.
static func save_binding(action: StringName, event: InputEvent) -> void

## Postcondition: InputMap restored to project defaults; user://keybindings.cfg cleared.
static func reset_to_defaults() -> void

## Returns a human-readable display name for an action (e.g. "Navigate Left").
static func get_display_name(action: StringName) -> String

## Returns human-readable text for an InputEvent (e.g. "Space", "A / Left").
static func get_event_display_text(event: InputEvent) -> String
```

### Persistence

Uses Godot `ConfigFile` → `user://keybindings.cfg`. Each entry stores the serialised
`InputEvent` variant. On `load_and_apply`, saved bindings replace project defaults via
`InputMap.action_erase_events` + `InputMap.action_add_event`.

---

## Section 5: OptionsPopup Rework

### New scene structure

```
OptionsPopup (Control)
└── Panel
    └── MarginContainer
        └── VBoxContainer
            ├── Label            "Options"
            ├── TabContainer
            │   ├── VBoxContainer  [tab name: "Display"]
            │   │   ├── FullscreenCheck
            │   │   ├── VsyncCheck
            │   │   └── HBoxContainer
            │   │       ├── VolumeSlider
            │   │       └── VolumeValueLabel
            │   └── VBoxContainer  [tab name: "Controls"]
            │       ├── Button     "Reset to Defaults"
            │       └── ScrollContainer
            │           └── ActionList (VBoxContainer, populated dynamically)
            └── CloseButton
```

### Controls tab — action row (built in `_populate_controls_tab()`)

```
HBoxContainer
├── Label   (KeybindingConfig.get_display_name(action))
└── Button  (KeybindingConfig.get_event_display_text(current_event), click → rebind)
```

### Rebind flow

```
## Spec: clicking a binding button sets _listening_action and changes button text to
##        "Press any key…".
## Spec: next InputEvent that is not a modifier key → save_binding → update button text
##        → clear _listening_action.
## Spec: pressing Escape during listen → cancel, restore previous button text.
## Spec: Reset to Defaults button calls KeybindingConfig.reset_to_defaults() then
##        rebuilds the action list.
```

---

## File Map

### New Files

| Path | Purpose |
|---|---|
| `scenes/ui/focus_cursor/FocusCursor.tscn` | Cursor scene |
| `scenes/ui/focus_cursor/focus_cursor.gd` | Cursor logic |
| `scripts/managers/keybinding_config.gd` | Binding persistence + InputMap bridge |

### Modified Files

| Path | Change |
|---|---|
| `project.godot` | Register new input actions + KeybindingConfig autoload |
| `scenes/main.gd` | Create FocusCursor, pass to gameplay_controller.setup() |
| `scripts/controllers/gameplay_controller.gd` | Cursor signals, play_hand/draw_tiles actions, setup() param |
| `scenes/title_screen/options_popup.gd` | Add Controls tab, rebind flow |
| `scenes/title_screen/OptionsPopup.tscn` | Add TabContainer, restructure Display tab |

---

## Out of Scope

- Controller rumble / haptic feedback (future: polish phase).
- Saving selected tab between sessions (future: save system).
- Keybinding support in the pause menu Options button (pause menu has no Options link today).
- Mouse cursor auto-hide when gamepad is in use (future: UX polish).
- Multi-tile keyboard selection (keyboard confirm selects one tile at a time; multi-select
  via Q + clicking remains mouse-only for now).
