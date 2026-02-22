# Keyboard Controller Improvements — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor the keyboard/controller input system with typed domain objects, a shared modal guard mixin, live key-hint bar, categorised controls tab, joypad conflict fix, and multi-select indicator.

**Architecture:** New value objects (`KeyAction`, `CursorPosition`, `CursorState`) live in `scripts/input/`. `ModalInputGuard` (RefCounted) is composed into each popup. `FocusCursor` replaces four mutable vars with a single `CursorState`. A new `KeyboardHintBar` HBoxContainer reads live from `KeybindingConfig`.

**Tech Stack:** Godot 4.5, GDScript. No automated test framework — each task ends with a manual verification step in the Godot editor or by reading the changed files.

---

## Task 1: `KeyAction` — centralised action name constants

**Files:**
- Create: `scripts/input/key_action.gd`
- Modify: `scenes/ui/focus_cursor/focus_cursor.gd` (all raw action strings)
- Modify: `scripts/controllers/gameplay_controller.gd` (all raw action strings)

**Step 1: Create the constants file**

```gdscript
# scripts/input/key_action.gd
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

**Step 2: Replace raw strings in `focus_cursor.gd`**

In `_unhandled_input()`, every `event.is_action_pressed("navigate_left")` etc. becomes `event.is_action_pressed(KeyAction.NAVIGATE_LEFT)`. Full mapping:

| Old string | New constant |
|---|---|
| `"navigate_left"` | `KeyAction.NAVIGATE_LEFT` |
| `"navigate_right"` | `KeyAction.NAVIGATE_RIGHT` |
| `"navigate_up"` | `KeyAction.NAVIGATE_UP` |
| `"navigate_down"` | `KeyAction.NAVIGATE_DOWN` |
| `"confirm_action"` | `KeyAction.CONFIRM` |
| `"cancel_action"` | `KeyAction.CANCEL` |
| `"switch_zone"` | `KeyAction.SWITCH_ZONE` |

**Step 3: Replace raw strings in `gameplay_controller.gd`**

In `_unhandled_input()`:

| Old string | New constant |
|---|---|
| `"pause_game"` | `KeyAction.PAUSE_GAME` |
| `"toggle_multi_select"` | `KeyAction.TOGGLE_MULTI` |
| `"discard_tiles"` | `KeyAction.DISCARD_TILES` |
| `"play_hand"` | `KeyAction.PLAY_HAND` |
| `"draw_tiles"` | `KeyAction.DRAW_TILES` |

**Step 4: Verify** — Open the Godot editor. The project should load without errors. Run a game session and confirm keyboard navigation and actions still work (WASD moves, Space confirms, Backspace cancels, P plays, L draws).

**Step 5: Commit**

```bash
git add scripts/input/key_action.gd \
        scenes/ui/focus_cursor/focus_cursor.gd \
        scripts/controllers/gameplay_controller.gd
git commit -m "refactor: centralise action names in KeyAction constants class"
```

---

## Task 2: `CursorPosition` — typed value object

**Files:**
- Create: `scripts/input/cursor_position.gd`

**Step 1: Create the value object**

```gdscript
# scripts/input/cursor_position.gd
class_name CursorPosition
extends RefCounted

enum Zone { HAND, BOARD }

var zone: Zone           = Zone.HAND
var hand_index: int      = 0
var board_coords: Vector2i = Vector2i.ZERO


## Factory: position in hand zone.
static func hand(index: int) -> CursorPosition:
	var p := CursorPosition.new()
	p.zone = Zone.HAND
	p.hand_index = index
	return p


## Factory: position in board zone.
static func board(coords: Vector2i) -> CursorPosition:
	var p := CursorPosition.new()
	p.zone = Zone.BOARD
	p.board_coords = coords
	return p


func is_hand()  -> bool: return zone == Zone.HAND
func is_board() -> bool: return zone == Zone.BOARD
```

**Step 2: Verify** — No game changes yet; verify the file has no parse errors by checking the Godot editor Output panel (no red errors on scene load).

**Step 3: Commit**

```bash
git add scripts/input/cursor_position.gd
git commit -m "feat: add CursorPosition typed value object"
```

---

## Task 3: `CursorState` — aggregate value object

**Files:**
- Create: `scripts/input/cursor_state.gd`

**Step 1: Create the aggregate**

```gdscript
# scripts/input/cursor_state.gd
class_name CursorState
extends RefCounted

## Immutable-by-convention aggregate for FocusCursor state.
## Never mutate fields directly — use the with_* helpers to get a new instance.

var position: CursorPosition = null  ## Never null after construction.
var held_tile: Tile          = null  ## null when no tile is being placed.


## Factory: initial state — hand zone, index 0, no held tile.
static func at_hand(index: int) -> CursorState:
	var s := CursorState.new()
	s.position = CursorPosition.hand(index)
	return s


## Returns a new CursorState with hand_index changed; zone forced to HAND.
func with_hand_index(i: int) -> CursorState:
	var s := CursorState.new()
	s.position  = CursorPosition.hand(i)
	s.held_tile = held_tile
	return s


## Returns a new CursorState with board_coords changed; zone forced to BOARD.
func with_board_coords(c: Vector2i) -> CursorState:
	var s := CursorState.new()
	s.position  = CursorPosition.board(c)
	s.held_tile = held_tile
	return s


## Returns a new CursorState with held_tile set; position unchanged.
func with_held_tile(t: Tile) -> CursorState:
	var s := CursorState.new()
	s.position  = position
	s.held_tile = t
	return s


## Returns a new CursorState with held_tile cleared; position unchanged.
func cleared_tile() -> CursorState:
	var s := CursorState.new()
	s.position  = position
	s.held_tile = null
	return s
```

**Step 2: Verify** — No game changes; confirm no parse errors in editor Output.

**Step 3: Commit**

```bash
git add scripts/input/cursor_state.gd
git commit -m "feat: add CursorState aggregate value object"
```

---

## Task 4: Refactor `FocusCursor` — use `CursorState` + `CursorPosition`

**Files:**
- Modify: `scenes/ui/focus_cursor/focus_cursor.gd`

This is the largest single-file change. Work top to bottom through the file.

**Step 1: Replace the `Zone` enum and state vars**

Remove:
```gdscript
enum Zone { HAND, BOARD }

var _zone: Zone = Zone.HAND
var _hand_index: int = 0
var _board_coords: Vector2i = Vector2i(0, 0)
var _held_tile: Tile = null
```

Add (keep `_is_active` and `_highlighted_hand_tile` as-is):
```gdscript
## Re-export so external code can still write FocusCursor.Zone if needed.
const Zone := CursorPosition.Zone

var _state: CursorState = null  ## Initialised in activate().
```

**Step 2: Update signals**

```gdscript
# Before
signal cursor_confirmed(zone: Zone, position: Variant)
signal cursor_cancelled(zone: Zone, position: Variant)
signal cursor_moved(zone: Zone, position: Variant)

# After
signal cursor_confirmed(pos: CursorPosition)
signal cursor_cancelled(pos: CursorPosition)
signal cursor_moved(pos: CursorPosition)
```

**Step 3: Update `activate()` and `deactivate()`**

```gdscript
func activate() -> void:
	_is_active = true
	_state = CursorState.at_hand(0)
	set_process_unhandled_input(true)
	_update_hand_tile_highlight()


func deactivate() -> void:
	_is_active = false
	_clear_hand_tile_highlight()
	clear_held_tile()
	_cursor_rect.hide()
	set_process_unhandled_input(false)
```

**Step 4: Update `set_held_tile()` and `clear_held_tile()`**

```gdscript
func set_held_tile(tile: Tile) -> void:
	_clear_hand_tile_highlight()
	_state = _state.with_held_tile(tile)
	if tile:
		tile.self_modulate.a = 0.5
	_update_ghost_display()


func clear_held_tile() -> void:
	if _state and _state.held_tile:
		_state.held_tile.self_modulate.a = 1.0
	_state = _state.cleared_tile()
	_update_ghost_display()
```

**Step 5: Update `get_current_cell()`**

```gdscript
func get_current_cell() -> BoardCell:
	if _state == null or not _state.position.is_board() or _board == null:
		return null
	return _board.get_cell(_state.position.board_coords.y, _state.position.board_coords.x)
```

**Step 6: Update `_update_cursor_rect()`**

```gdscript
func _update_cursor_rect() -> void:
	if _state.position.is_hand():
		_cursor_rect.hide()
		_update_hand_tile_highlight()
		return
	if _highlighted_hand_tile:
		_clear_hand_tile_highlight()
	var cell := _board.get_cell(
		_state.position.board_coords.y,
		_state.position.board_coords.x
	)
	if cell == null:
		_cursor_rect.hide()
		return
	_cursor_rect.show()
	_cursor_rect.position = cell.get_global_rect().position - global_position
	_cursor_rect.size     = cell.get_global_rect().size
	_update_cursor_tint()
```

**Step 7: Update `_update_hand_tile_highlight()`**

```gdscript
func _update_hand_tile_highlight() -> void:
	var new_tile: Tile = _hand.get_tile_at(_state.position.hand_index) if _hand != null else null
	# ... rest unchanged
```

**Step 8: Update `_update_cursor_tint()`**

```gdscript
func _update_cursor_tint() -> void:
	if _state.position.is_board() and _state.held_tile != null:
		var cell := _board.get_cell(
			_state.position.board_coords.y,
			_state.position.board_coords.x
		)
		if cell and cell.is_occupied():
			_cursor_rect.modulate = Color(1.0, 0.3, 0.3)
			return
	_cursor_rect.modulate = Color.WHITE
```

**Step 9: Update `_update_ghost_display()`**

```gdscript
func _update_ghost_display() -> void:
	if _state.held_tile != null and _state.position.is_board():
		_ghost_label.text = _state.held_tile.letter
		_ghost_label.show()
	else:
		_ghost_label.hide()
```

**Step 10: Update `_navigate()`**

```gdscript
func _navigate(direction: Vector2i) -> void:
	if _state.position.is_hand():
		_navigate_hand(direction)
	else:
		_navigate_board(direction)
```

**Step 11: Update `_navigate_hand()`**

```gdscript
func _navigate_hand(direction: Vector2i) -> void:
	var count := _hand.get_tile_count()
	if count == 0:
		return
	match direction:
		Vector2i.LEFT:
			_state = _state.with_hand_index((_state.position.hand_index - 1 + count) % count)
			cursor_moved.emit(_state.position)
		Vector2i.RIGHT:
			_state = _state.with_hand_index((_state.position.hand_index + 1) % count)
			cursor_moved.emit(_state.position)
		Vector2i.UP:
			_switch_to_board_zone()
		# DOWN in HAND zone: intentional no-op
```

**Step 12: Update `_navigate_board()`**

```gdscript
func _navigate_board(direction: Vector2i) -> void:
	if direction == Vector2i.DOWN and _state.position.board_coords.y >= _board.rows - 1:
		_switch_to_hand_zone()
		return
	var coords := Vector2i(
		clampi(_state.position.board_coords.x + direction.x, 0, _board.columns - 1),
		clampi(_state.position.board_coords.y + direction.y, 0, _board.rows - 1)
	)
	_state = _state.with_board_coords(coords)
	cursor_moved.emit(_state.position)
	_update_ghost_display()
```

**Step 13: Update `_switch_to_board_zone()`**

```gdscript
func _switch_to_board_zone() -> void:
	_clear_hand_tile_highlight()
	var count := _hand.get_tile_count()
	var col   := 0
	if count > 0:
		col = clampi(
			int(float(_state.position.hand_index) / float(count) * float(_board.columns)),
			0, _board.columns - 1
		)
	_state = _state.with_board_coords(Vector2i(col, _board.rows - 1))
	cursor_moved.emit(_state.position)
	_update_ghost_display()
```

**Step 14: Update `_switch_to_hand_zone()`**

```gdscript
func _switch_to_hand_zone() -> void:
	var count := _hand.get_tile_count()
	var index := 0
	if count > 0:
		index = clampi(
			int(float(_state.position.board_coords.x) / float(_board.columns) * float(count)),
			0, count - 1
		)
	_state = _state.with_hand_index(index)
	cursor_moved.emit(_state.position)
	_update_ghost_display()
```

**Step 15: Update `_confirm()` and `_cancel()`**

```gdscript
func _confirm() -> void:
	cursor_confirmed.emit(_state.position)


func _cancel() -> void:
	cursor_cancelled.emit(_state.position)
	if _state.position.is_board():
		_switch_to_hand_zone()
```

**Step 16: Verify** — Load project in editor. The FocusCursor scene should parse cleanly. Run a game: navigate hand left/right, switch to board (W/Up), place a tile. Confirm all zone transitions and placement animations work as before.

**Step 17: Commit**

```bash
git add scenes/ui/focus_cursor/focus_cursor.gd
git commit -m "refactor: FocusCursor uses CursorState aggregate and CursorPosition signals"
```

---

## Task 5: Update `GameplayController` — new signal signatures

**Files:**
- Modify: `scripts/controllers/gameplay_controller.gd`

**Step 1: Update `_on_cursor_confirmed`**

```gdscript
func _on_cursor_confirmed(pos: CursorPosition) -> void:
	if not _is_active:
		return

	if pos.is_hand():
		var tile: Tile = hand.get_tile_at(pos.hand_index)
		if tile == null:
			return
		_on_tile_selected(tile)
		if _selection.has_selection() and _cursor:
			_cursor.set_held_tile(tile)

	elif pos.is_board():
		var cell: BoardCell = board.get_cell(pos.board_coords.y, pos.board_coords.x)
		if cell == null:
			return
		if _selection.has_selection():
			var movable: Array[Tile] = _selection.get_selected_tiles().filter(
				func(t: Tile) -> bool: return not t.is_locked
			)
			if not movable.is_empty() and not cell.is_occupied():
				_place_tiles_on_cell(movable, cell, true)
				if _cursor:
					_cursor.clear_held_tile()
			elif cell.is_occupied():
				print("[Gameplay] Cursor: target cell occupied at %s" % pos.board_coords)
				TileAnimator.animate_shake(movable[0])
		elif cell.is_occupied():
			var board_tile: Tile = cell.tile
			if not board_tile.is_locked:
				_placement.return_tile_to_hand(board_tile)
				_selection.select_tile(board_tile)
				if _cursor:
					_cursor.set_held_tile(board_tile)
				_update_interaction_state()
				tile_returned_to_hand.emit(board_tile)
			else:
				TileAnimator.animate_shake(board_tile)
```

**Step 2: Update `_on_cursor_cancelled`**

```gdscript
func _on_cursor_cancelled(_pos: CursorPosition) -> void:
	if not _is_active:
		return
	_selection.deselect_all()
	if _cursor:
		_cursor.clear_held_tile()
	_update_interaction_state()
	_play.update_play_button_state()
```

**Step 3: Update `_on_cursor_moved`**

```gdscript
func _on_cursor_moved(pos: CursorPosition) -> void:
	if not _is_active:
		return
	_placement.clear_all_cell_hovers()
	if pos.is_board():
		var cell: BoardCell = board.get_cell(pos.board_coords.y, pos.board_coords.x)
		if cell:
			_on_cell_hovered(cell)
```

**Step 4: Verify** — Full gameplay test: navigate hand, pick tile, place on board. Multi-tile selection and batch placement. Return board tile to hand (confirm on occupied cell). All should work identically to before.

**Step 5: Commit**

```bash
git add scripts/controllers/gameplay_controller.gd
git commit -m "refactor: update GameplayController to typed CursorPosition signal args"
```

---

## Task 6: `ModalInputGuard` — composition mixin

**Files:**
- Create: `scripts/input/modal_input_guard.gd`

**Step 1: Create the mixin**

```gdscript
# scripts/input/modal_input_guard.gd
class_name ModalInputGuard
extends RefCounted

## Shared input guard for modal CanvasLayer popups.
## Blocks gameplay navigation from bleeding through, and closes the popup
## on configured close actions. Compose via ModalInputGuard.new().setup(self).

signal close_requested

var _owner: CanvasLayer = null
var _close_actions:   Array[StringName] = []
var _blocked_actions: Array[StringName] = [
	KeyAction.NAVIGATE_LEFT,
	KeyAction.NAVIGATE_RIGHT,
	KeyAction.NAVIGATE_UP,
	KeyAction.NAVIGATE_DOWN,
	KeyAction.CONFIRM,
	&"ui_up", &"ui_down", &"ui_left", &"ui_right",
]


## Fluent — call .setup(self) first, then chain .add_close_action() as needed.
func setup(owner: CanvasLayer) -> ModalInputGuard:
	_owner = owner
	return self


func add_close_action(action: StringName) -> ModalInputGuard:
	_close_actions.append(action)
	return self


func add_blocked_action(action: StringName) -> ModalInputGuard:
	_blocked_actions.append(action)
	return self


## Call from _input(event). Returns true if the event was consumed.
func handle(event: InputEvent) -> bool:
	if not _owner.visible:
		return false
	for action: StringName in _close_actions:
		if event.is_action_pressed(action):
			close_requested.emit()
			_owner.get_viewport().set_input_as_handled()
			return true
	for action: StringName in _blocked_actions:
		if event.is_action_pressed(action):
			_owner.get_viewport().set_input_as_handled()
			return true
	return false
```

**Step 2: Commit**

```bash
git add scripts/input/modal_input_guard.gd
git commit -m "feat: add ModalInputGuard composition mixin for modal popups"
```

---

## Task 7: Wire `ModalInputGuard` into all five popups

**Files:**
- Modify: `scenes/ui/game_over_popup/game_over_popup.gd`
- Modify: `scenes/ui/pause_menu/pause_menu.gd`
- Modify: `scenes/ui/discard_confirmation_dialog/discard_confirmation_dialog.gd`
- Modify: `scenes/title_screen/options_popup.gd`
- Modify: `scenes/title_screen/run_setup_popup.gd`

For each popup, the pattern is:

1. Add `var _guard: ModalInputGuard` near the top (with other state vars).
2. In `_ready()`, initialise the guard and connect its signal.
3. In `_input()`, call `if _guard.handle(event): return` at the very top (after the visible check if it has one — the guard already checks `_owner.visible` internally, but the existing early return can stay for clarity).
4. Remove the old duplicated blocking/close code.

**`game_over_popup.gd`** — closes on `ui_accept` (Enter button):

```gdscript
var _guard: ModalInputGuard

func _ready() -> void:
    _return_button.pressed.connect(_on_return_pressed)
    _guard = ModalInputGuard.new().setup(self).add_close_action(&"ui_accept")
    _guard.close_requested.connect(_on_return_pressed)
    hide()

func _input(event: InputEvent) -> void:
    if _guard.handle(event):
        return
```

**`pause_menu.gd`** — Read the file first to confirm its exact close action, then apply the same pattern with `KeyAction.PAUSE_GAME` or `KeyAction.CANCEL` as close action.

**`discard_confirmation_dialog.gd`** — Read the file. Confirm uses `ui_accept`; cancel uses `KeyAction.CANCEL`. Set up two close actions or handle popup-specific logic after the guard.

**`run_setup_popup.gd`** — `KeyAction.CANCEL` closes. The WASD forwarding block stays in `_input()` but now runs after `_guard.handle()`:

```gdscript
var _guard: ModalInputGuard

func _ready() -> void:
    # ... existing setup ...
    _guard = ModalInputGuard.new().setup(self)
    # Do NOT add CANCEL as close action here — the guard's default
    # blocked set already handles navigate_*, but we want ui_cancel
    # to close (handled below in _input).

func _input(event: InputEvent) -> void:
    if _guard.handle(event):
        return
    # WASD forwarding block (unchanged)
    var nav_map: Dictionary = { ... }
    for game_action in nav_map:
        if event.is_action_pressed(game_action):
            ...
    if event.is_action_pressed("ui_cancel"):
        close_popup()
        get_viewport().set_input_as_handled()
```

**`options_popup.gd`** — Has complex tab-switching and rebind-mode logic. Only use guard for blocking; its specific close/tab logic stays in `_input()` after the guard:

```gdscript
var _guard: ModalInputGuard

func _ready() -> void:
    # ... existing setup ...
    _guard = ModalInputGuard.new().setup(self)

func _input(event: InputEvent) -> void:
    if _guard.handle(event):
        return
    # Existing rebind-mode handling, tab switch, close button logic (unchanged)
```

**Step: Verify** — Open each popup in a game session. Confirm: (a) navigating behind the popup doesn't move game tiles, (b) the correct key closes each popup, (c) options rebinding still works.

**Step: Commit**

```bash
git add scenes/ui/game_over_popup/game_over_popup.gd \
        scenes/ui/pause_menu/pause_menu.gd \
        scenes/ui/discard_confirmation_dialog/discard_confirmation_dialog.gd \
        scenes/title_screen/options_popup.gd \
        scenes/title_screen/run_setup_popup.gd
git commit -m "refactor: replace duplicated modal input guards with ModalInputGuard mixin"
```

---

## Task 8: `KeybindingConfig` — add signal, categories, and joypad filter

**Files:**
- Modify: `scripts/managers/keybinding_config.gd`

**Step 1: Add `binding_changed` signal**

At the top of the file, add:
```gdscript
signal binding_changed(action: StringName)
```

At the end of `save_binding()`, add:
```gdscript
binding_changed.emit(action)
```

**Step 2: Add `CATEGORIES` constant** (add after `ACTION_DISPLAY_NAMES`):

```gdscript
const CATEGORIES: Array[Dictionary] = [
    {
        "label":   "Navigation",
        "actions": [&"navigate_left", &"navigate_right", &"navigate_up",
                    &"navigate_down", &"switch_zone"],
    },
    {
        "label":   "Tile Actions",
        "actions": [&"confirm_action", &"cancel_action",
                    &"toggle_multi_select", &"discard_tiles"],
    },
    {
        "label":   "Game Actions",
        "actions": [&"play_hand", &"draw_tiles", &"pause_game"],
    },
]
```

**Step 3: Update `get_event_display_text()` to support `joypad_only` filter**

Find the existing method and replace with:

```gdscript
## Returns a formatted string of bound keys for the action.
## joypad_only: when true, returns only joypad bindings (for controller hint bar).
func get_event_display_text(action: StringName, joypad_only: bool = false) -> String:
    var events := InputMap.action_get_events(action)
    var parts: Array[String] = []
    for event: InputEvent in events:
        var is_joypad := event is InputEventJoypadButton or event is InputEventJoypadMotion
        if joypad_only and not is_joypad:
            continue
        if not joypad_only and is_joypad:
            continue
        parts.append(event.as_text())
    return " / ".join(parts)
```

**Step 4: Verify** — Rebind a key in OptionsPopup, open a new session, confirm the binding persists. No visible player changes yet.

**Step 5: Commit**

```bash
git add scripts/managers/keybinding_config.gd
git commit -m "feat: add binding_changed signal, CATEGORIES const, and joypad filter to KeybindingConfig"
```

---

## Task 9: Fix joypad Y button conflict

**Files:**
- Modify: `project.godot`

**Step 1: Locate the conflict**

In `project.godot`, search for `discard_tiles`. It will have a `JOY_BUTTON_Y` entry that duplicates `play_hand`.

**Step 2: Replace `discard_tiles` joypad binding**

Change the joypad entry for `discard_tiles` from `JOY_BUTTON_Y` to `JOY_BUTTON_RIGHT_SHOULDER` (RB).

**Step 3: Add `toggle_multi_select` joypad binding**

In the `toggle_multi_select` input definition, add a new joypad entry for `JOY_BUTTON_LEFT_SHOULDER` (LB). Currently it only has the Q keyboard key.

**Final controller layout:**

| Button | Action |
|---|---|
| A | confirm_action |
| B | cancel_action |
| X | draw_tiles |
| Y | play_hand |
| LT / RT | switch_zone |
| LB | toggle_multi_select |
| RB | discard_tiles |
| Start | pause_game |

**Step 4: Verify** — If a controller is available, test all buttons. Otherwise, verify no parse errors on project load.

**Step 5: Commit**

```bash
git add project.godot
git commit -m "fix: resolve joypad Y conflict — discard→RB, multi-select→LB"
```

---

## Task 10: `KeyboardHintBar` — scene and script

**Files:**
- Create: `scenes/ui/keyboard_hint_bar/keyboard_hint_bar.gd`
- Create: `scenes/ui/keyboard_hint_bar/keyboard_hint_bar.tscn`

**Step 1: Create the script**

```gdscript
# scenes/ui/keyboard_hint_bar/keyboard_hint_bar.gd
extends HBoxContainer
class_name KeyboardHintBar

## Displays live key-binding hints for in-game actions.
## Updates automatically when bindings change or a joypad is connected.

const HINTS: Array[Dictionary] = [
    { action = KeyAction.PLAY_HAND,     label = "Play"    },
    { action = KeyAction.DRAW_TILES,    label = "Draw"    },
    { action = KeyAction.DISCARD_TILES, label = "Discard" },
    { action = KeyAction.TOGGLE_MULTI,  label = "Multi"   },
    { action = KeyAction.SWITCH_ZONE,   label = "Zone"    },
    { action = KeyAction.PAUSE_GAME,    label = "Pause"   },
]

var _chips: Dictionary = {}     ## StringName -> HBoxContainer
var _using_joypad: bool = false


func _ready() -> void:
    _build_chips()
    _refresh_all()
    KeybindingConfig.binding_changed.connect(_on_binding_changed)
    Input.joy_connection_changed.connect(func(_id: int, _connected: bool) -> void:
        _refresh_all()
    )


func _build_chips() -> void:
    for i: int in HINTS.size():
        var hint: Dictionary = HINTS[i]
        var chip := HBoxContainer.new()
        chip.add_theme_constant_override("separation", 4)

        var badge := Label.new()
        badge.name = "Badge"
        chip.add_child(badge)

        var lbl := Label.new()
        lbl.text = hint.label
        chip.add_child(lbl)

        add_child(chip)
        _chips[hint.action] = chip

        if i < HINTS.size() - 1:
            var sep := Label.new()
            sep.text = "  ·  "
            add_child(sep)


func _refresh_all() -> void:
    _using_joypad = Input.get_connected_joypads().size() > 0
    for hint: Dictionary in HINTS:
        _update_chip(hint.action)


func _update_chip(action: StringName) -> void:
    var chip: HBoxContainer = _chips.get(action)
    if chip == null:
        return
    var badge: Label = chip.get_node("Badge")
    var text := KeybindingConfig.get_event_display_text(action, _using_joypad)
    if text.is_empty():
        # Fallback to keyboard if no joypad binding exists
        text = KeybindingConfig.get_event_display_text(action, false)
    badge.text = "[%s]" % text


func _on_binding_changed(action: StringName) -> void:
    _update_chip(action)
```

**Step 2: Create the scene**

In the Godot editor:
1. Create a new scene with root node type `HBoxContainer`
2. Set the root node name to `KeyboardHintBar`
3. Attach the script `scenes/ui/keyboard_hint_bar/keyboard_hint_bar.gd`
4. Set `alignment` to `CENTER`, `size_flags_horizontal` to `Expand+Fill`
5. Save as `scenes/ui/keyboard_hint_bar/keyboard_hint_bar.tscn`

**Step 3: Commit**

```bash
git add scenes/ui/keyboard_hint_bar/
git commit -m "feat: add KeyboardHintBar with live keybinding display"
```

---

## Task 11: Wire `KeyboardHintBar` into `MainHUD`

**Files:**
- Modify: `scenes/ui/main_hud/main_hud.gd`
- Modify: `scenes/ui/main_hud/MainHUD.tscn` (add KeyboardHintBar instance)

**Step 1: Add `KeyboardHintBar` to the HUD scene**

In the Godot editor:
1. Open `scenes/ui/main_hud/MainHUD.tscn`
2. Instantiate `scenes/ui/keyboard_hint_bar/keyboard_hint_bar.tscn` as a child of the root `CanvasLayer > Control`
3. Anchor it to the bottom of the screen (anchor preset: Bottom Wide, or set `anchor_top = 1`, `anchor_bottom = 1`, `offset_top = -28`, `offset_bottom = 0`)
4. Save the scene

**Step 2: Add show/hide control in `main_hud.gd`**

```gdscript
@onready var _hint_bar: KeyboardHintBar = $Control/KeyboardHintBar  # adjust path to match scene

func show_hint_bar() -> void:
    if _hint_bar:
        _hint_bar.show()

func hide_hint_bar() -> void:
    if _hint_bar:
        _hint_bar.hide()
```

Call `hide_hint_bar()` during title / game-over states, `show_hint_bar()` when gameplay starts. The caller is `scenes/main.gd` — find where `main_hud` visibility is already managed and add the hint bar calls alongside.

**Step 3: Verify** — Start a game round. The hint bar should appear at the bottom showing e.g. `[P] Play  ·  [L] Draw  ·  [Z] Discard  ·  [Q] Multi  ·  [Tab] Zone  ·  [Esc] Pause`. Rebind a key in Options and return to gameplay — the chip updates automatically.

**Step 4: Commit**

```bash
git add scenes/ui/main_hud/ scenes/ui/keyboard_hint_bar/
git commit -m "feat: mount KeyboardHintBar in MainHUD, show during gameplay"
```

---

## Task 12: Controls tab — categorised layout

**Files:**
- Modify: `scenes/title_screen/options_popup.gd`

**Step 1: Update `_populate_controls_tab()`**

Find the existing method that populates `_action_list`. Replace its body so it iterates `KeybindingConfig.CATEGORIES`:

```gdscript
func _populate_controls_tab() -> void:
    for child in _action_list.get_children():
        child.queue_free()

    for category: Dictionary in KeybindingConfig.CATEGORIES:
        # Category header label
        var header := Label.new()
        header.text = category.label
        header.add_theme_font_size_override("font_size", 14)
        _action_list.add_child(header)

        # One row per action in the category
        for action: StringName in category.actions:
            _action_list.add_child(_make_action_row(action))

        # Spacer between categories
        var spacer := Control.new()
        spacer.custom_minimum_size = Vector2(0, 8)
        _action_list.add_child(spacer)
```

`_make_action_row(action)` is the existing helper that creates a label + rebind button row (leave its internals unchanged).

**Step 2: Verify** — Open Options → Controls. Actions should appear grouped under "Navigation", "Tile Actions", "Game Actions" with visible headers between groups.

**Step 3: Commit**

```bash
git add scenes/title_screen/options_popup.gd
git commit -m "feat: group Controls tab actions by category"
```

---

## Task 13: Reset-to-defaults — inline confirmation

**Files:**
- Modify: `scenes/title_screen/options_popup.gd`

**Step 1: Add confirmation state**

```gdscript
var _reset_confirming: bool = false
```

**Step 2: Update `_on_reset_pressed()`** (or wherever the reset button callback is):

```gdscript
func _on_reset_pressed() -> void:
    if not _reset_confirming:
        _reset_confirming = true
        _reset_button.text = "Confirm reset"
        # Show a cancel button next to reset; reuse an existing node or create one
        _reset_cancel_button.show()
        return
    # Second press — execute reset
    _reset_confirming = false
    _reset_button.text = "Reset to defaults"
    _reset_cancel_button.hide()
    KeybindingConfig.reset_to_defaults()
    _populate_controls_tab()


func _on_reset_cancel_pressed() -> void:
    _reset_confirming = false
    _reset_button.text = "Reset to defaults"
    _reset_cancel_button.hide()
```

Add a `_reset_cancel_button` to `OptionsPopup.tscn` next to `_reset_button`, initially hidden.

**Step 3: Verify** — Click Reset once: button text changes to "Confirm reset" and Cancel appears. Click Cancel: reverts. Click Reset then Confirm: all bindings reset and list repopulates.

**Step 4: Commit**

```bash
git add scenes/title_screen/options_popup.gd scenes/title_screen/OptionsPopup.tscn
git commit -m "feat: add inline reset confirmation to Controls tab"
```

---

## Task 14: Multi-select mode indicator

**Files:**
- Modify: `scenes/ui/main_hud/main_hud.gd`
- Modify: `scenes/ui/main_hud/MainHUD.tscn`
- Modify: `scenes/main.gd` (connect SelectionManager.mode_changed to HUD)

**Step 1: Check existing multi-select indicator**

Read `scenes/ui/multi_select_indicator/` — a CLAUDE.md exists there, meaning the component may already be built. If it is, skip to Step 3. If not, Step 2.

**Step 2: Add indicator node to Hand panel (if not already present)**

In `MainHUD.tscn`, add a `Label` node named `MultiSelectLabel` with text `[ MULTI ]`, positioned at the top of the hand area. Set it hidden by default.

In `main_hud.gd`:
```gdscript
@onready var _multi_label: Label = $Control/MultiSelectLabel  # adjust path

func set_multi_select_active(active: bool) -> void:
    if _multi_label:
        _multi_label.visible = active
```

**Step 3: Connect `SelectionManager.mode_changed` to the HUD**

In `scenes/main.gd`, after `_selection_manager` is set up:
```gdscript
_selection_manager.mode_changed.connect(func(mode) -> void:
    main_hud.set_multi_select_active(mode == SelectionManager.Mode.MULTI)
)
```

**Step 4: Verify** — Press Q during gameplay. A `[ MULTI ]` badge should appear. Press Q again — it disappears.

**Step 5: Commit**

```bash
git add scenes/ui/main_hud/ scenes/main.gd
git commit -m "feat: show multi-select mode indicator in HUD"
```

---

## Final verification

After all tasks:

1. Start a full game round via keyboard only (no mouse). Navigate hand, pick a tile, place it on board.
2. Multi-select (Q) several tiles, place as a batch.
3. Rebind a key in Options → Controls. Confirm hint bar updates.
4. Open and close every popup (Game Over, Pause, Discard, Options, Run Setup) with keyboard. No navigation bleeds through.
5. Confirm grouped categories appear in Controls tab.
6. Confirm reset confirmation works.
7. Confirm hint bar hidden on title screen, visible during gameplay.

Then run the finishing-a-development-branch skill to merge or PR.
