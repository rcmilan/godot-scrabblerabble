# Cursor Visual Polish Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Four targeted improvements to the keyboard/controller cursor: brightness-only hover, yellow border, keyboard placement animation, and WASD navigation in RunSetupPopup.

**Architecture:** Items 1–3 are single-file edits to existing visual/input logic. Item 4 adds a `execute_place_to_board()` path to the existing `ReturnAnimationExecutor` + `TileAnimator` facade, called from a new `place_tile_on_cell_animated()` method on `TilePlacementHandler`, triggered only from the keyboard cursor confirm path in `GameplayController`.

**Tech Stack:** Godot 4.5, GDScript, Strategy+Executor animation pattern, SignalTracker for signal lifecycle.

---

## Background — key files to understand

Before making any change, skim these files so you have context:

- `scenes/tile/tile.gd` — `_update_visual()` at the bottom controls border/brightness
- `scenes/tile/Tile.tscn` — `StyleBoxFlat_vb0gs` is the Border panel's style resource
- `scenes/title_screen/run_setup_popup.gd` — `_input()` method
- `scripts/animation/glide/return_animation_executor.gd` — `execute_single()` is the pattern to mirror
- `autoload/tile_animator.gd` — thin facade; all `animate_*` methods follow the same shape
- `scripts/controllers/tile_placement_handler.gd` — `place_tile_on_cell_silent()` is where tile is reparented
- `scripts/controllers/gameplay_controller.gd` — `_on_cursor_confirmed()` and `_place_tiles_on_cell()` are the keyboard placement paths

---

## Task 1: Cursor hover = brightness only (no border)

**Files:**
- Modify: `scenes/tile/tile.gd`

### Context

`FocusCursor` calls `tile.set_cursor_highlighted(true)` when navigating over a hand tile. Inside `_update_visual()`, this currently shows the selection border even while just hovering (before the player confirms the tile). The fix: show the border only when `is_selected` is true.

The line to change is in `_update_visual()`. Search for:
```gdscript
border.visible = is_selected or _is_cursor_highlighted
```

### Step 1: Make the change

In `scenes/tile/tile.gd`, find `_update_visual()` and change:

```gdscript
# Before
border.visible = is_selected or _is_cursor_highlighted

# After
border.visible = is_selected
```

The `_apply_modifier_visual()` call underneath still reads `_is_cursor_highlighted` for the brightness — leave that untouched.

### Step 2: Verify in-game

Run the game (`F5`). Start a round. Press Space/Enter to activate the cursor. Navigate over hand tiles with WASD or arrow keys.

Expected: Tile brightens slightly when cursor is over it, **no** green/yellow outline. Outline only appears after pressing confirm (Space) to select the tile.

### Step 3: Commit

```bash
git add scenes/tile/tile.gd
git commit -m "fix: cursor hover shows brightness only, no border"
```

---

## Task 2: Yellow selection border

**Files:**
- Modify: `scenes/tile/Tile.tscn`

### Context

The tile's selection border is a `Panel` node named `Border` using `StyleBoxFlat_vb0gs`. The current `border_color` is green (`Color(0.11350792, 0.60272574, 0.19527751, 1)`). Change it to bright golden yellow.

### Step 1: Make the change

In `scenes/tile/Tile.tscn`, find:
```
border_color = Color(0.11350792, 0.60272574, 0.19527751, 1)
```

Replace with:
```
border_color = Color(1.0, 0.85, 0.1, 1)
```

This is near the top of the file inside the `[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_vb0gs"]` block.

### Step 2: Verify in-game

Run the game. Click a hand tile (mouse). Confirm via keyboard cursor (confirm_action). In both cases the border should now be bright yellow instead of green.

### Step 3: Commit

```bash
git add scenes/tile/Tile.tscn
git commit -m "fix: change tile selection border from green to yellow"
```

---

## Task 3: WASD navigation in RunSetupPopup

**Files:**
- Modify: `scenes/title_screen/run_setup_popup.gd`

### Context

`RunSetupPopup._input()` currently only handles `ui_cancel` (ESC). Arrow keys and D-pad work via Godot's built-in focus traversal which responds to `ui_up`/`ui_down`. WASD doesn't work because W/S/A/D are mapped to `navigate_up`/`navigate_down`/`navigate_left`/`navigate_right` (game actions), not to `ui_*` actions.

Fix: intercept the game navigation actions in `_input()` and re-inject them as the corresponding `ui_*` actions using `Input.parse_input_event()`.

No loop risk: W is **only** in `navigate_up`, not in `ui_up`. The re-injected event won't retrigger.

### Step 1: Make the change

In `scenes/title_screen/run_setup_popup.gd`, find the `_input()` method:

```gdscript
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_popup()
		get_viewport().set_input_as_handled()
```

Add the WASD forwarding block **before** the `ui_cancel` check:

```gdscript
func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Forward WASD (navigate_*) as ui_* so Godot's focus traversal picks them up.
	# navigate_* includes W/S/A/D; ui_* only has arrow keys — no loop risk.
	var nav_map: Dictionary = {
		"navigate_up":    "ui_up",
		"navigate_down":  "ui_down",
		"navigate_left":  "ui_left",
		"navigate_right": "ui_right",
	}
	for game_action: String in nav_map:
		if event.is_action_pressed(game_action):
			var fake := InputEventAction.new()
			fake.action = nav_map[game_action]
			fake.pressed = true
			Input.parse_input_event(fake)
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("ui_cancel"):
		close_popup()
		get_viewport().set_input_as_handled()
```

### Step 2: Verify in-game

Run the game. Click "New Game" to open RunSetupPopup. Press W and S — focus should move between the quality checkboxes and Start/Back buttons. Press A/D — focus should move left/right between columns. Arrow keys should still work.

### Step 3: Commit

```bash
git add scenes/title_screen/run_setup_popup.gd
git commit -m "fix: WASD navigation in RunSetupPopup"
```

---

## Task 4: Keyboard tile placement animation

**Files:**
- Modify: `scripts/animation/glide/return_animation_executor.gd`
- Modify: `autoload/tile_animator.gd`
- Modify: `scripts/controllers/tile_placement_handler.gd`
- Modify: `scripts/controllers/gameplay_controller.gd`

### Context

When the keyboard cursor places a tile (confirm in HAND zone picks it up, confirm in BOARD zone places it), the tile currently teleports. We want it to glide from its hand position to the board cell, reusing `GlideTileAnimation` (0.35s, TRANS_BACK bounce).

The mirror of `ReturnAnimationExecutor.execute_single()` (board→hand):

| Return (board→hand) | Place (hand→board) |
|---------------------|-------------------|
| Capture global pos (on board) | Capture global pos (in hand) |
| Remove from board, add to hand | Remove from hand (already done by `place_tile_on_cell`) |
| `tile.move_to_hand()` | `tile.attach_to_cell(cell)` already done |
| `await process_frame` | `await process_frame` |
| Offset tile.position to board pos | Offset tile.position to hand pos |
| Tween to final hand pos | Tween to `Vector2.ZERO` (cell anchor local origin) |

Key invariant: `place_tile_on_cell_silent()` always sets `tile.position = Vector2.ZERO` after reparenting to `cell.tile_anchor`. So the tween target is always `Vector2.ZERO`.

---

### Step 4a: Add `execute_place_to_board` to ReturnAnimationExecutor

In `scripts/animation/glide/return_animation_executor.gd`, add this method at the end of the file, after `_animate_discard_tile`:

```gdscript
## Animates a tile gliding from a captured hand position to its board cell.
## Pre-condition: tile has already been placed on the cell (reparented to
## cell_anchor, position = Vector2.ZERO) by place_tile_on_cell_silent().
## start_global_pos: tile.global_position captured BEFORE placement.
func execute_place_to_board(
	tile: Tile,
	start_global_pos: Vector2,
	strategy: TileAnimationStrategy
) -> void:
	_context.is_animating = true
	var tiles_array: Array[Tile] = [tile]
	_context.emit_animation_started(tiles_array)

	var start_props: Dictionary = strategy.get_start_properties()
	_apply_properties(tile, start_props)
	strategy.on_animation_start(tile)

	await _context.get_tree().process_frame

	_animate_position_transition(tile, start_global_pos, strategy)
	print("[ReturnAnimationExecutor] Started place-to-board animation for: %s" % tile.name)
```

---

### Step 4b: Add `animate_place_to_board` to TileAnimator

In `autoload/tile_animator.gd`, add this method after `animate_cancel_to_hand`:

```gdscript
## Animates a tile gliding from its hand position to a board cell.
## Call AFTER place_tile_on_cell_silent() has reparented the tile.
## start_global_pos: tile.global_position captured BEFORE placement.
func animate_place_to_board(tile: Tile, start_global_pos: Vector2) -> void:
	if tile == null:
		return
	_ensure_glide_resources()
	_return_executor.execute_place_to_board(tile, start_global_pos, _glide_animation)
```

---

### Step 4c: Add `place_tile_on_cell_animated` to TilePlacementHandler

In `scripts/controllers/tile_placement_handler.gd`, add this method after `place_tile_on_cell`:

```gdscript
## Places a tile on a cell and starts a glide animation from hand to board.
## Only for single-tile keyboard placements. Synchronous — animation runs async.
func place_tile_on_cell_animated(tile: Tile, cell: BoardCell) -> void:
	if cell.is_occupied():
		return

	# Capture hand position BEFORE reparenting — used as animation start point.
	var start_global_pos: Vector2 = tile.global_position

	# Synchronous placement: reparents tile to cell anchor, sets position = Vector2.ZERO.
	place_tile_on_cell(tile, cell)

	# Fire-and-forget glide animation.
	TileAnimator.animate_place_to_board(tile, start_global_pos)
```

---

### Step 4d: Call `place_tile_on_cell_animated` from GameplayController

In `scripts/controllers/gameplay_controller.gd`, find `_place_tiles_on_cell`. It currently looks like this:

```gdscript
func _place_tiles_on_cell(movable: Array[Tile], cell: BoardCell) -> void:
	if movable.size() > 1:
		var cells: Array[BoardCell] = _placement.get_sequential_cells(cell, movable.size())
		if cells.is_empty():
			print("[Gameplay] Cannot place %d tiles starting at %s" % [movable.size(), cell.name])
			return
		for i in movable.size():
			_placement.place_tile_on_cell_silent(movable[i], cells[i])
		print("[Gameplay] Placed %d tiles starting at %s" % [movable.size(), cell.name])
	else:
		_placement.place_tile_on_cell(movable[0], cell)
	_selection.deselect_all()
	_update_interaction_state()
	_play.update_play_button_state()
	tile_placement_completed.emit(movable[0], cell)
```

Add an `animated` parameter and use `place_tile_on_cell_animated` when true:

```gdscript
func _place_tiles_on_cell(movable: Array[Tile], cell: BoardCell, animated: bool = false) -> void:
	if movable.size() > 1:
		var cells: Array[BoardCell] = _placement.get_sequential_cells(cell, movable.size())
		if cells.is_empty():
			print("[Gameplay] Cannot place %d tiles starting at %s" % [movable.size(), cell.name])
			return
		for i in movable.size():
			_placement.place_tile_on_cell_silent(movable[i], cells[i])
		print("[Gameplay] Placed %d tiles starting at %s" % [movable.size(), cell.name])
	else:
		if animated:
			_placement.place_tile_on_cell_animated(movable[0], cell)
		else:
			_placement.place_tile_on_cell(movable[0], cell)
	_selection.deselect_all()
	_update_interaction_state()
	_play.update_play_button_state()
	tile_placement_completed.emit(movable[0], cell)
```

Then in `_on_cursor_confirmed`, find the line that calls `_place_tiles_on_cell` in the BOARD zone path and pass `animated: true`:

```gdscript
# Before
_place_tiles_on_cell(movable, cell)

# After
_place_tiles_on_cell(movable, cell, true)
```

The exact location in `_on_cursor_confirmed`:
```gdscript
FocusCursor.Zone.BOARD:
    ...
    if _selection.has_selection():
        var movable: Array[Tile] = _selection.get_selected_tiles().filter(...)
        if not movable.is_empty() and not cell.is_occupied():
            _place_tiles_on_cell(movable, cell, true)   # ← add true here
            if _cursor:
                _cursor.clear_held_tile()
```

---

### Step 4e: Verify in-game

Run the game. Start a round, activate the keyboard cursor:
1. Navigate to a hand tile with WASD/arrows
2. Press Space (confirm) — tile should show selection highlight (held state)
3. Navigate Up to board zone
4. Navigate to an empty cell
5. Press Space (confirm) — tile should **glide** from the hand area to the board cell with the bounce effect (~0.35s)

Also verify that:
- Mouse drag-and-drop placement has **no** animation change (still instant)
- Mouse click-to-select + click-on-cell placement has **no** animation change (still instant)
- Multi-tile keyboard placement (select multiple + confirm) still places instantly

### Step 4f: Commit

```bash
git add scripts/animation/glide/return_animation_executor.gd
git add autoload/tile_animator.gd
git add scripts/controllers/tile_placement_handler.gd
git add scripts/controllers/gameplay_controller.gd
git commit -m "feat: glide animation for keyboard tile placement"
```

---

## Final verification checklist

Run the game and manually verify all 4 changes work together:

- [ ] Cursor hover over hand tile → brightness only, no yellow border
- [ ] Clicking or confirming a hand tile → yellow border appears (not green)
- [ ] In RunSetupPopup → W/S/A/D move focus between checkboxes and buttons
- [ ] Keyboard cursor placing tile on board → smooth glide animation
- [ ] Mouse drag still works with no animation
- [ ] Right-click return-to-hand glide still works correctly
