# Keyboard & Controller Input Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Full keyboard/controller support for all gameplay actions, plus a Controls tab in OptionsPopup for key rebinding.

**Architecture:** A new `FocusCursor` Control node navigates hand tiles and board cells, emitting signals that `GameplayController` acts on. `KeybindingConfig` autoload persists InputMap overrides to `user://keybindings.cfg`.

**Tech Stack:** Godot 4 GDScript, `InputMap` API, Godot `ConfigFile` for persistence.

---

## Task 1: Register New Input Actions

**Files:**
- Modify: `project.godot`

**Step 1: Insert new actions into `[input]` section**

Open `project.godot`. Find the `[input]` section. Insert the following entries **before** the closing `[rendering]` section, after the existing `pause_game` entry:

```
navigate_left={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":65,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null), Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194319,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null), Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":13,"pressure":0.0,"pressed":false,"script":null)
]
}
navigate_right={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":68,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null), Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194321,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null), Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":14,"pressure":0.0,"pressed":false,"script":null)
]
}
navigate_up={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":87,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null), Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194320,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null), Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":11,"pressure":0.0,"pressed":false,"script":null)
]
}
navigate_down={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":83,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null), Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194322,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null), Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":12,"pressure":0.0,"pressed":false,"script":null)
]
}
confirm_action={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":32,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null), Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":0,"pressure":0.0,"pressed":false,"script":null)
]
}
cancel_action={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194344,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null), Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194324,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null), Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":1,"pressure":0.0,"pressed":false,"script":null)
]
}
play_hand={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":80,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null), Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":10,"pressure":0.0,"pressed":false,"script":null)
]
}
draw_tiles={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":76,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null), Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":9,"pressure":0.0,"pressed":false,"script":null)
]
}
```

Also update the existing `discard_tiles` entry to add the Triangle/Y controller button (button_index 3):

```
discard_tiles={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":90,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null), Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":3,"pressure":0.0,"pressed":false,"script":null)
]
}
```

**Step 2: Verify**

Open the Godot editor → Project → Project Settings → Input Map tab. Confirm all 8 new actions appear with correct key labels. `navigate_left` should show "A", "Left", and a joypad button. `discard_tiles` should now have a joypad button alongside the Z key.

**Step 3: Commit**

```bash
git add project.godot
git commit -m "feat: register keyboard and controller input actions"
```

---

## Task 2: KeybindingConfig Autoload

**Files:**
- Create: `scripts/managers/keybinding_config.gd`
- Modify: `project.godot` (`[autoload]` section)

**Step 1: Create `scripts/managers/keybinding_config.gd`**

```gdscript
extends Node
class_name KeybindingConfig

## Manages saving and loading InputMap overrides from user://keybindings.cfg.
## Acts as an autoload; call load_and_apply() once on game start.

const SAVE_PATH := "user://keybindings.cfg"

const KEYBINDABLE_ACTIONS: Array[StringName] = [
	&"navigate_left", &"navigate_right", &"navigate_up", &"navigate_down",
	&"confirm_action", &"cancel_action",
	&"play_hand", &"draw_tiles", &"discard_tiles",
	&"pause_game", &"toggle_multi_select",
]

const ACTION_DISPLAY_NAMES: Dictionary = {
	&"navigate_left":       "Navigate Left",
	&"navigate_right":      "Navigate Right",
	&"navigate_up":         "Navigate Up",
	&"navigate_down":       "Navigate Down",
	&"confirm_action":      "Confirm / Place",
	&"cancel_action":       "Cancel / Return",
	&"play_hand":           "Play Hand",
	&"draw_tiles":          "Draw Tiles",
	&"discard_tiles":       "Discard Tiles",
	&"pause_game":          "Pause",
	&"toggle_multi_select": "Multi-Select",
}


## Postcondition: any saved overrides in user://keybindings.cfg applied to InputMap.
func load_and_apply() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for action: StringName in KEYBINDABLE_ACTIONS:
		if cfg.has_section_key("bindings", action):
			var event: Variant = cfg.get_value("bindings", action)
			if event is InputEvent:
				InputMap.action_erase_events(action)
				InputMap.action_add_event(action, event)


## Precondition : action is in KEYBINDABLE_ACTIONS.
## Postcondition: InputMap updated; binding persisted to disk.
func save_binding(action: StringName, event: InputEvent) -> void:
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("bindings", action, event)
	cfg.save(SAVE_PATH)


## Postcondition: InputMap restored to project defaults; keybindings.cfg cleared.
func reset_to_defaults() -> void:
	InputMap.load_from_project_settings()
	var cfg := ConfigFile.new()
	cfg.save(SAVE_PATH)


## Returns a human-readable display name for an action.
func get_display_name(action: StringName) -> String:
	return ACTION_DISPLAY_NAMES.get(action, String(action))


## Returns a short display string for an action's current keyboard binding(s).
func get_event_display_text(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "—"
	var parts: PackedStringArray = []
	for ev in events:
		if ev is InputEventKey:
			parts.append(ev.as_text_keycode())
	return "  /  ".join(parts) if parts.size() > 0 else "—"
```

**Step 2: Register autoload in `project.godot`**

Find the `[autoload]` section and add this line after `RunManager`:

```
KeybindingConfig="*res://scripts/managers/keybinding_config.gd"
```

**Step 3: Verify**

Run the game once. No errors in Output. Open the Godot debugger and call `KeybindingConfig.get_display_name(&"play_hand")` in the remote inspector — should return `"Play Hand"`.

**Step 4: Commit**

```bash
git add scripts/managers/keybinding_config.gd project.godot
git commit -m "feat: add KeybindingConfig autoload for input persistence"
```

---

## Task 3: FocusCursor Scene + Base Script

**Files:**
- Create: `scenes/ui/focus_cursor/FocusCursor.tscn`
- Create: `scenes/ui/focus_cursor/focus_cursor.gd`

**Step 1: Create `scenes/ui/focus_cursor/FocusCursor.tscn`**

```
[gd_scene load_steps=2 format=3 uid="uid://focus_cursor_v1"]

[ext_resource type="Script" path="res://scenes/ui/focus_cursor/focus_cursor.gd" id="1_fcursor"]

[node name="FocusCursor" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
z_index = 50
script = ExtResource("1_fcursor")

[node name="CursorRect" type="Panel" parent="."]
visible = false
layout_mode = 0
offset_right = 64.0
offset_bottom = 64.0
mouse_filter = 2

[node name="GhostLabel" type="Label" parent="CursorRect"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2
horizontal_alignment = 1
vertical_alignment = 1
```

**Step 2: Create `scenes/ui/focus_cursor/focus_cursor.gd`**

```gdscript
extends Control
class_name FocusCursor

## FocusCursor: keyboard/controller navigation cursor for hand and board zones.
## Owns cursor position state, renders a highlight rect, and emits signals.
## GameplayController connects to signals and executes game actions.

# =============================================================================
# SIGNALS
# =============================================================================

## position is int (hand index) for HAND zone, Vector2i (col, row) for BOARD zone.
signal cursor_confirmed(zone: Zone, position: Variant)
signal cursor_cancelled(zone: Zone, position: Variant)
signal cursor_moved(zone: Zone, position: Variant)

# =============================================================================
# ENUMS
# =============================================================================

enum Zone { HAND, BOARD }

# =============================================================================
# STATE
# =============================================================================

## Invariant: _hand_index in [0, hand.get_tile_count()-1] when HAND zone active.
## Invariant: _board_coords within board bounds when BOARD zone active.
## Invariant: _held_tile is null when no tile has been confirmed for placement.
var _zone: Zone = Zone.HAND
var _hand_index: int = 0
var _board_coords: Vector2i = Vector2i(0, 0)
var _held_tile: Tile = null
var _is_active: bool = false

# =============================================================================
# DEPENDENCIES (injected via setup)
# =============================================================================

var _board: Board = null
var _hand: Hand = null

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _cursor_rect: Panel = $CursorRect
@onready var _ghost_label: Label = $CursorRect/GhostLabel

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	set_process_unhandled_input(false)
	_cursor_rect.hide()


## Precondition: board and hand are valid non-null references.
func setup(board: Board, hand: Hand) -> void:
	_board = board
	_hand = hand


## Postcondition: cursor becomes visible and processes input.
func activate() -> void:
	_is_active = true
	_hand_index = 0
	_zone = Zone.HAND
	_cursor_rect.show()
	set_process_unhandled_input(true)


## Postcondition: cursor hides, stops processing input, held tile restored.
func deactivate() -> void:
	_is_active = false
	clear_held_tile()
	_cursor_rect.hide()
	set_process_unhandled_input(false)


## Postcondition: _held_tile set; tile faded to 50% alpha in hand.
func set_held_tile(tile: Tile) -> void:
	_held_tile = tile
	if tile:
		tile.modulate.a = 0.5
	_update_ghost_display()


## Postcondition: _held_tile cleared; tile alpha restored to 1.0.
func clear_held_tile() -> void:
	if _held_tile:
		_held_tile.modulate.a = 1.0
	_held_tile = null
	_update_ghost_display()


## Returns the BoardCell at _board_coords, or null if zone is HAND.
func get_current_cell() -> BoardCell:
	if _zone != Zone.BOARD or _board == null:
		return null
	return _board.get_cell(_board_coords.y, _board_coords.x)

# =============================================================================
# VISUAL UPDATE
# =============================================================================

func _process(_delta: float) -> void:
	if not _is_active:
		return
	_update_cursor_rect()


func _update_cursor_rect() -> void:
	var target_rect := _get_target_rect()
	if target_rect == Rect2():
		_cursor_rect.hide()
		return
	_cursor_rect.show()
	_cursor_rect.position = target_rect.position - global_position
	_cursor_rect.size = target_rect.size
	_update_cursor_tint()


func _get_target_rect() -> Rect2:
	match _zone:
		Zone.HAND:
			var tile := _hand.get_tile_at(_hand_index)
			if tile == null:
				return Rect2()
			return tile.get_global_rect()
		Zone.BOARD:
			var cell := _board.get_cell(_board_coords.y, _board_coords.x)
			if cell == null:
				return Rect2()
			return cell.get_global_rect()
	return Rect2()


func _update_cursor_tint() -> void:
	if _zone == Zone.BOARD and _held_tile != null:
		var cell := _board.get_cell(_board_coords.y, _board_coords.x)
		if cell and cell.is_occupied():
			_cursor_rect.modulate = Color(1.0, 0.3, 0.3)
			return
	_cursor_rect.modulate = Color.WHITE


func _update_ghost_display() -> void:
	if _held_tile != null and _zone == Zone.BOARD:
		_ghost_label.text = _held_tile.letter
		_ghost_label.show()
	else:
		_ghost_label.hide()
```

**Step 3: Verify**

The scene file imports cleanly in Godot (no parse errors in Output on editor open). The script has no syntax errors.

**Step 4: Commit**

```bash
git add scenes/ui/focus_cursor/
git commit -m "feat: add FocusCursor base scene and script"
```

---

## Task 4: FocusCursor Navigation

**Files:**
- Modify: `scenes/ui/focus_cursor/focus_cursor.gd`

**Step 1: Add `_unhandled_input` and navigation methods to `focus_cursor.gd`**

Append the following sections to `focus_cursor.gd`, after the `_update_ghost_display` method:

```gdscript
# =============================================================================
# INPUT HANDLING
# =============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not _is_active:
		return
	if event.is_action_pressed("navigate_left"):
		_navigate(Vector2i.LEFT)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("navigate_right"):
		_navigate(Vector2i.RIGHT)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("navigate_up"):
		_navigate(Vector2i.UP)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("navigate_down"):
		_navigate(Vector2i.DOWN)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("confirm_action"):
		_confirm()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel_action"):
		_cancel()
		get_viewport().set_input_as_handled()


func _navigate(direction: Vector2i) -> void:
	match _zone:
		Zone.HAND:  _navigate_hand(direction)
		Zone.BOARD: _navigate_board(direction)


func _navigate_hand(direction: Vector2i) -> void:
	var count := _hand.get_tile_count()
	if count == 0:
		return
	match direction:
		Vector2i.LEFT:
			_hand_index = (_hand_index - 1 + count) % count
			cursor_moved.emit(Zone.HAND, _hand_index)
		Vector2i.RIGHT:
			_hand_index = (_hand_index + 1) % count
			cursor_moved.emit(Zone.HAND, _hand_index)
		Vector2i.UP:
			_switch_to_board_zone()


func _navigate_board(direction: Vector2i) -> void:
	if direction == Vector2i.DOWN and _board_coords.y >= _board.rows - 1:
		_switch_to_hand_zone()
		return
	_board_coords = Vector2i(
		clampi(_board_coords.x + direction.x, 0, _board.columns - 1),
		clampi(_board_coords.y + direction.y, 0, _board.rows - 1)
	)
	cursor_moved.emit(Zone.BOARD, _board_coords)
	_update_ghost_display()


func _switch_to_board_zone() -> void:
	_zone = Zone.BOARD
	var count := _hand.get_tile_count()
	var col := 0
	if count > 0:
		col = clampi(
			int(float(_hand_index) / float(count) * float(_board.columns)),
			0, _board.columns - 1
		)
	_board_coords = Vector2i(col, _board.rows - 1)
	cursor_moved.emit(Zone.BOARD, _board_coords)
	_update_ghost_display()


func _switch_to_hand_zone() -> void:
	_zone = Zone.HAND
	var count := _hand.get_tile_count()
	if count > 0:
		_hand_index = clampi(
			int(float(_board_coords.x) / float(_board.columns) * float(count)),
			0, count - 1
		)
	else:
		_hand_index = 0
	cursor_moved.emit(Zone.HAND, _hand_index)
	_update_ghost_display()


func _confirm() -> void:
	match _zone:
		Zone.HAND:  cursor_confirmed.emit(Zone.HAND, _hand_index)
		Zone.BOARD: cursor_confirmed.emit(Zone.BOARD, _board_coords)


func _cancel() -> void:
	match _zone:
		Zone.HAND:
			cursor_cancelled.emit(Zone.HAND, _hand_index)
		Zone.BOARD:
			cursor_cancelled.emit(Zone.BOARD, _board_coords)
			_switch_to_hand_zone()
```

**Step 2: Manual verification**

Run the game. Open the Godot editor remote debugger while game runs. You should be able to navigate the cursor with WASD or arrows — the highlight rect should move over hand tiles, jump to the board on W/Up, return to hand on S/Down from the bottom board row.

**Step 3: Commit**

```bash
git add scenes/ui/focus_cursor/focus_cursor.gd
git commit -m "feat: add FocusCursor navigation logic (HAND/BOARD zones)"
```

---

## Task 5: GameplayController — Cursor Integration + New Keyboard Actions

**Files:**
- Modify: `scripts/controllers/gameplay_controller.gd`

**Step 1: Add `_cursor` field and update `setup()`**

Add to the `# STATE` section:
```gdscript
var _cursor: FocusCursor = null
```

Change the `setup()` signature to add `p_cursor` as a final optional parameter:
```gdscript
func setup(p_board: Board, p_hand: Hand, p_discard_pile: Control, p_discard_dialog: CanvasLayer, p_hud: CanvasLayer, p_selection: SelectionManager, p_cursor: FocusCursor = null) -> void:
```

At the end of `setup()`, before the handler creation lines, add:
```gdscript
	_cursor = p_cursor
```

**Step 2: Add cursor signal connections in `_connect_signals()`**

Add at the end of `_connect_signals()`:
```gdscript
	if _cursor:
		_tracker.track(_cursor.cursor_confirmed, _on_cursor_confirmed)
		_tracker.track(_cursor.cursor_cancelled, _on_cursor_cancelled)
		_tracker.track(_cursor.cursor_moved,     _on_cursor_moved)
```

**Step 3: Add `play_hand` and `draw_tiles` to `_unhandled_input()`**

In `_unhandled_input()`, after the existing `discard_tiles` block, add:
```gdscript
	if event.is_action_pressed("play_hand"):
		_on_play_requested()
		get_viewport().set_input_as_handled()

	if event.is_action_pressed("draw_tiles"):
		_on_draw_requested()
		get_viewport().set_input_as_handled()
```

**Step 4: Add the three cursor signal handlers**

Add these methods in the `# TILE SELECTION HANDLERS` section:

```gdscript
func _on_cursor_confirmed(zone: FocusCursor.Zone, position: Variant) -> void:
	if not _is_active:
		return
	match zone:
		FocusCursor.Zone.HAND:
			var tile: Tile = hand.get_tile_at(int(position))
			if tile == null:
				return
			_on_tile_selected(tile)
			if _selection.has_selection() and _cursor:
				_cursor.set_held_tile(tile)

		FocusCursor.Zone.BOARD:
			var coords := position as Vector2i
			var cell: BoardCell = board.get_cell(coords.y, coords.x)
			if cell == null:
				return
			if _selection.has_selection():
				var movable: Array[Tile] = _selection.get_selected_tiles().filter(
					func(t: Tile) -> bool: return not t.is_locked
				)
				if not movable.is_empty() and not cell.is_occupied():
					_place_tiles_on_cell(movable, cell)
					if _cursor:
						_cursor.clear_held_tile()
				elif cell.is_occupied():
					print("[Gameplay] Cursor: target cell occupied at %s" % coords)
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


func _on_cursor_cancelled(_zone: FocusCursor.Zone, _position: Variant) -> void:
	if not _is_active:
		return
	_selection.deselect_all()
	if _cursor:
		_cursor.clear_held_tile()
	_update_interaction_state()
	_play.update_play_button_state()


func _on_cursor_moved(zone: FocusCursor.Zone, position: Variant) -> void:
	if not _is_active:
		return
	_placement.clear_all_cell_hovers()
	if zone == FocusCursor.Zone.BOARD:
		var coords := position as Vector2i
		var cell: BoardCell = board.get_cell(coords.y, coords.x)
		if cell:
			_on_cell_hovered(cell)
```

**Step 5: Manual verification**

Run the game. Press P — play should trigger. Press L — draw should trigger. No errors in output.

**Step 6: Commit**

```bash
git add scripts/controllers/gameplay_controller.gd
git commit -m "feat: integrate FocusCursor into GameplayController"
```

---

## Task 6: Main — Wire FocusCursor + KeybindingConfig

**Files:**
- Modify: `scenes/main.gd`

**Step 1: Add field and call `load_and_apply` in `_ready()`**

Add to the `# LOCAL MANAGERS` section:
```gdscript
var _focus_cursor: FocusCursor = null
```

Add as the first line of `_ready()`, before `_setup_selection_manager()`:
```gdscript
	KeybindingConfig.load_and_apply()
```

**Step 2: Create and inject FocusCursor in `_setup_controllers()`**

Replace the existing `_setup_controllers()` body with:
```gdscript
func _setup_controllers() -> void:
	var cursor_scene := preload("res://scenes/ui/focus_cursor/FocusCursor.tscn")
	_focus_cursor = cursor_scene.instantiate() as FocusCursor
	_focus_cursor.name = "FocusCursor"
	add_child(_focus_cursor)
	_focus_cursor.setup(board, hand)

	_gameplay_controller = GameplayController.new()
	_gameplay_controller.name = "GameplayController"
	add_child(_gameplay_controller)
	_gameplay_controller.setup(board, hand, discard_pile, discard_dialog, main_hud, _selection_manager, _focus_cursor)
	_gameplay_controller.play_completed.connect(_on_play_completed)
	_gameplay_controller.pause_requested.connect(_on_pause_requested)
```

**Step 3: Mirror cursor activate/deactivate alongside gameplay controller**

Search `main.gd` for every `_gameplay_controller.activate()` and `_gameplay_controller.deactivate()` call. Add the matching cursor call on the line immediately after each:

```gdscript
# Wherever you see:
_gameplay_controller.activate()
# Add below it:
_focus_cursor.activate()

# Wherever you see:
_gameplay_controller.deactivate()
# Add below it:
_focus_cursor.deactivate()
```

There are 9 such calls total (check the existing file — grep for activate/deactivate in main.gd).

**Step 4: Manual verification**

Run the game. The cursor highlight rect should appear over the first hand tile immediately on game start. WASD/arrows move it. Space on a hand tile selects it and fades it. Moving to board shows a ghost letter in the cursor rect. Space on a free cell places the tile. Backspace cancels and returns to hand zone.

**Step 5: Commit**

```bash
git add scenes/main.gd
git commit -m "feat: wire FocusCursor and KeybindingConfig into Main"
```

---

## Task 7: OptionsPopup — Add Controls Tab

**Files:**
- Modify: `scenes/title_screen/OptionsPopup.tscn`
- Modify: `scenes/title_screen/options_popup.gd`

**Step 1: Restructure `OptionsPopup.tscn`**

Open `scenes/title_screen/OptionsPopup.tscn`. Make these structural changes:

1. Resize the Panel — change `offset_left`/`offset_right` to `±250` and `offset_top`/`offset_bottom` to `±260`:
   ```
   offset_left = -250.0
   offset_top = -260.0
   offset_right = 250.0
   offset_bottom = 260.0
   ```

2. Remove the `HSeparator`, `SettingsContainer` (and all its children), and `HSeparator2` nodes from `Panel/MarginContainer/VBoxContainer`.

3. Add a `TabContainer` node between `TitleLabel` and `CloseButton`:
   ```
   [node name="TabContainer" type="TabContainer" parent="Panel/MarginContainer/VBoxContainer"]
   layout_mode = 2
   size_flags_vertical = 3
   ```

4. Add a `Display` VBoxContainer as first tab child:
   ```
   [node name="Display" type="VBoxContainer" parent="Panel/MarginContainer/VBoxContainer/TabContainer"]
   layout_mode = 2
   theme_override_constants/separation = 8
   ```

5. Re-add the existing settings nodes as children of `Display` (same content as the old `SettingsContainer` — copy in `GraphicsLabel`, `FullscreenCheck`, `VsyncCheck`, `VolumeLabel`, `VolumeSlider`, `VolumeValueLabel`).

6. Add a `Controls` VBoxContainer as second tab child:
   ```
   [node name="Controls" type="VBoxContainer" parent="Panel/MarginContainer/VBoxContainer/TabContainer"]
   layout_mode = 2
   theme_override_constants/separation = 8
   ```

7. Inside `Controls`, add a `ResetButton` and a `ScrollContainer` with an `ActionList` VBoxContainer:
   ```
   [node name="ResetButton" type="Button" parent="Panel/MarginContainer/VBoxContainer/TabContainer/Controls"]
   layout_mode = 2
   text = "Reset to Defaults"

   [node name="ScrollContainer" type="ScrollContainer" parent="Panel/MarginContainer/VBoxContainer/TabContainer/Controls"]
   layout_mode = 2
   size_flags_vertical = 3

   [node name="ActionList" type="VBoxContainer" parent="Panel/MarginContainer/VBoxContainer/TabContainer/Controls/ScrollContainer"]
   layout_mode = 2
   size_flags_horizontal = 3
   theme_override_constants/separation = 6
   ```

**Step 2: Rewrite `scenes/title_screen/options_popup.gd`**

Replace the entire file content with:

```gdscript
extends Control
class_name OptionsPopup

## Options popup with Display and Controls tabs.
## Controls tab allows key rebinding via KeybindingConfig.

signal closed()

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _close_button: Button      = $Panel/MarginContainer/VBoxContainer/CloseButton
@onready var _fullscreen_check: CheckBox = $Panel/MarginContainer/VBoxContainer/TabContainer/Display/FullscreenCheck
@onready var _vsync_check: CheckBox      = $Panel/MarginContainer/VBoxContainer/TabContainer/Display/VsyncCheck
@onready var _volume_slider: HSlider     = $Panel/MarginContainer/VBoxContainer/TabContainer/Display/VolumeSlider
@onready var _volume_label: Label        = $Panel/MarginContainer/VBoxContainer/TabContainer/Display/VolumeValueLabel
@onready var _reset_button: Button       = $Panel/MarginContainer/VBoxContainer/TabContainer/Controls/ResetButton
@onready var _action_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Controls/ScrollContainer/ActionList

# =============================================================================
# REBIND STATE
# =============================================================================

var _listening_action: StringName = &""
var _listening_button: Button = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	_volume_slider.value_changed.connect(_on_volume_changed)
	_reset_button.pressed.connect(_on_reset_defaults_pressed)
	set_process_input(true)

	_fullscreen_check.button_pressed = false
	_vsync_check.button_pressed = true
	_volume_slider.value = 80
	_update_volume_label()
	_populate_controls_tab()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Capture rebind
	if _listening_action != &"":
		if event is InputEventKey and event.pressed and not event.is_echo():
			if event.keycode == KEY_ESCAPE:
				_listening_button.text = KeybindingConfig.get_event_display_text(_listening_action)
			else:
				KeybindingConfig.save_binding(_listening_action, event)
				_listening_button.text = KeybindingConfig.get_event_display_text(_listening_action)
			_listening_action = &""
			_listening_button = null
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		close_popup()
		get_viewport().set_input_as_handled()

# =============================================================================
# PUBLIC API
# =============================================================================

func show_popup() -> void:
	show()
	_close_button.grab_focus()


func close_popup() -> void:
	hide()
	closed.emit()

# =============================================================================
# CONTROLS TAB
# =============================================================================

func _populate_controls_tab() -> void:
	for child in _action_list.get_children():
		child.queue_free()
	for action: StringName in KeybindingConfig.KEYBINDABLE_ACTIONS:
		_action_list.add_child(_build_action_row(action))


func _build_action_row(action: StringName) -> HBoxContainer:
	var row := HBoxContainer.new()

	var lbl := Label.new()
	lbl.text = KeybindingConfig.get_display_name(action)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var btn := Button.new()
	btn.text = KeybindingConfig.get_event_display_text(action)
	btn.custom_minimum_size = Vector2(130, 0)
	btn.pressed.connect(_on_rebind_pressed.bind(action, btn))
	row.add_child(btn)

	return row


func _on_rebind_pressed(action: StringName, button: Button) -> void:
	if _listening_action != &"":
		return
	_listening_action = action
	_listening_button = button
	button.text = "Press any key…"


func _on_reset_defaults_pressed() -> void:
	KeybindingConfig.reset_to_defaults()
	_populate_controls_tab()

# =============================================================================
# DISPLAY TAB CALLBACKS
# =============================================================================

func _on_close_pressed() -> void:
	close_popup()


func _on_volume_changed(_value: float) -> void:
	_update_volume_label()


func _update_volume_label() -> void:
	_volume_label.text = "Volume: %d%%" % int(_volume_slider.value)
```

**Step 3: Manual verification**

Open the game, go to Title Screen → Options. Two tabs visible: "Display" (existing settings) and "Controls" (list of all actions with current bindings). Click a binding button — text changes to "Press any key…". Press a key — button updates. Press Escape during listen — cancels. "Reset to Defaults" restores all bindings and refreshes the list.

**Step 4: Commit**

```bash
git add scenes/title_screen/OptionsPopup.tscn scenes/title_screen/options_popup.gd
git commit -m "feat: add Controls tab with key rebinding to OptionsPopup"
```

---

## Final Verification Checklist

Run the game and confirm each action works end-to-end:

- [ ] WASD / arrows navigate cursor over hand tiles (wraps left/right)
- [ ] W / Up from hand → cursor jumps to board bottom row
- [ ] S / Down from board bottom row → cursor returns to hand
- [ ] Space on hand tile → tile fades, ghost appears on board as cursor moves
- [ ] Space on empty board cell → tile placed there, ghost clears
- [ ] Space on occupied board cell (no held tile) → tile picked up for repositioning
- [ ] Backspace / Delete → held tile deselected, cursor returns to hand
- [ ] P → play triggered (same as clicking Play button)
- [ ] L → draw triggered (same as clicking Draw button)
- [ ] Z → discard triggered (existing)
- [ ] Mouse drag-and-drop still works (not broken)
- [ ] Options → Controls tab shows all 11 actions with correct key labels
- [ ] Rebind a key → binding persists after game restart (`user://keybindings.cfg` written)
- [ ] Reset to Defaults → original bindings restored
