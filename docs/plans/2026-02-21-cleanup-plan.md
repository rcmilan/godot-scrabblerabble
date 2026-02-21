# Cleanup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove dead code, enforce encapsulation and immutability, reduce cyclomatic complexity to ≤ 5, and unify high-frequency patterns.

**Architecture:** Three sequential phases — Phase 1 is pure subtraction (safe to merge alone), Phase 2 is behavior-preserving restructuring, Phase 3 introduces two new types and rewires signal plumbing.

**Tech Stack:** Godot 4.5.1, GDScript. No test framework — verification is editor error-free + F5 run.

---

## Phase 1 — Dead Code + Encapsulation

---

### Task 1: Remove `is_wild` and `point_modifier` from Tile

**Files:**
- Modify: `scenes/tile/tile.gd`

**Step 1: Remove the two dead fields and fix their sole usages**

In `tile.gd`, find and apply all four edits below:

Remove lines 37–38 (the two field declarations):
```gdscript
# DELETE these two lines:
var point_modifier: int = 0        # Bonus/penalty to base points
var is_wild: bool = false          # Wild card tile (unused)
```

Fix `get_points()` (was using `point_modifier`):
```gdscript
# BEFORE (line ~162):
func get_points() -> int:
	return base_points + point_modifier

# AFTER:
func get_points() -> int:
	return base_points
```

Fix `reset()` (was resetting `point_modifier`):
```gdscript
# BEFORE (line ~266) — remove the point_modifier line:
	point_modifier = 0
	modifiers.clear()

# AFTER:
	modifiers.clear()
```

**Step 2: Search for any other callers**

```
grep -r "point_modifier\|is_wild" --include="*.gd" .
```

Expected: zero results after editing. If any appear, remove them.

**Step 3: Verify in Godot**

Open Godot editor. Check Output panel for script errors. Expected: none.

**Step 4: Commit**

```bash
git add scenes/tile/tile.gd
git commit -m "refactor: remove unused Tile.is_wild and legacy Tile.point_modifier"
```

---

### Task 2: Remove `start_alpha` from DrawTileAnimation

**Files:**
- Modify: `scripts/animation/draw/draw_tile_animation.gd`

**Step 1: Delete the unused export**

```gdscript
# DELETE line 13:
@export var start_alpha: float = 0.0  # Currently unused; alpha set directly in on_animation_start
```

The comment in `on_animation_start` is now redundant too — clean it:

```gdscript
# BEFORE (lines 37–39):
func on_animation_start(tile: Tile) -> void:
	# Disable interaction during animation
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Apply modifier visual first (tint + invert), then set alpha to 0
	tile._apply_modifier_visual()
	tile.modulate.a = 0.0

# AFTER:
func on_animation_start(tile: Tile) -> void:
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile._apply_modifier_visual()
	tile.modulate.a = 0.0
```

**Step 2: Verify in Godot**

Open editor. Expected: no errors. Draw a tile via F5 — animation should still fade in from below.

**Step 3: Commit**

```bash
git add scripts/animation/draw/draw_tile_animation.gd
git commit -m "refactor: remove unused DrawTileAnimation.start_alpha export"
```

---

### Task 3: Remove legacy `RunManager.initialize_run()`

**Files:**
- Modify: `autoload/run_manager.gd`

**Step 1: Find the function**

```
grep -n "func initialize_run\b" autoload/run_manager.gd
```

**Step 2: Find all callers**

```
grep -rn "initialize_run(" --include="*.gd" .
```

Expected callers: only `initialize_run_from_builder` (different name). If `initialize_run(` (without `_from_builder`) appears anywhere, update those callers to use the builder path before proceeding.

**Step 3: Delete the function**

Remove the entire `func initialize_run(...)` block from `run_manager.gd`. It spans roughly 15 lines with parameters `bag_config`, `plays_per_round`, `hand_size`, `progression_config`.

**Step 4: Verify**

```
grep -rn "\.initialize_run(" --include="*.gd" .
```

Expected: zero results (only `initialize_run_from_builder` should remain).

Open Godot. Expected: no errors.

**Step 5: Commit**

```bash
git add autoload/run_manager.gd
git commit -m "refactor: remove legacy RunManager.initialize_run() in favour of builder path"
```

---

### Task 4: Encapsulate `TileBag` state arrays

**Files:**
- Modify: `autoload/tile_bag.gd`
- Modify: `scripts/domain/qualities/random_modifiers_quality.gd`
- Modify: `scripts/domain/qualities/all_reset_quality.gd`

**Step 1: Find all direct callers of the public arrays**

```
grep -rn "TileBag\.available_tiles\|TileBag\.drawn_tiles\|TileBag\.current_distribution" --include="*.gd" .
```

Note every file and line that appears.

**Step 2: Rename fields and add getters in `tile_bag.gd`**

```gdscript
# BEFORE (lines 20–22):
var available_tiles: Array[Tile] = []
var drawn_tiles: Array[Tile] = []
var current_distribution: BagDistribution = null

# AFTER:
var _available_tiles: Array[Tile] = []
var _drawn_tiles: Array[Tile] = []
var _current_distribution: BagDistribution = null
```

Add getters immediately after the state block (before `_ready`):

```gdscript
func get_available_tiles() -> Array[Tile]:
	return _available_tiles.duplicate()

func get_drawn_tiles() -> Array[Tile]:
	return _drawn_tiles.duplicate()

func get_current_distribution() -> BagDistribution:
	return _current_distribution
```

**Step 3: Fix all internal usages in `tile_bag.gd`**

Every reference to `available_tiles`, `drawn_tiles`, `current_distribution` inside the file must gain the underscore prefix. Use search-and-replace within the file only:

- `available_tiles` → `_available_tiles`
- `drawn_tiles` → `_drawn_tiles`
- `current_distribution` → `_current_distribution`

Key lines to verify after:
- `populate_bag()`: uses `_available_tiles.append(tile)`, sets `_current_distribution = distribution`
- `shuffle_bag()`: calls `_available_tiles.shuffle()`
- `reset_bag()`: iterates `_drawn_tiles`, appends to `_available_tiles`
- `draw_tile()`: pops from `_available_tiles`, appends to `_drawn_tiles`
- `tiles_remaining()`: returns `_available_tiles.size()`
- `is_empty()`: checks `_available_tiles.is_empty()`

**Step 4: Update `random_modifiers_quality.gd`**

```gdscript
# BEFORE (line 38):
	for tile in TileBag.available_tiles:

# AFTER:
	for tile in TileBag.get_available_tiles():
```

```gdscript
# BEFORE (line 45–46):
	print("[RandomModifiers] Assigned %d modifiers to %d available tiles" % [
		count, TileBag.available_tiles.size()
	])

# AFTER:
	print("[RandomModifiers] Assigned %d modifiers to %d available tiles" % [
		count, TileBag.tiles_remaining()
	])
```

**Step 5: Update `all_reset_quality.gd`**

Open the file. Find every `TileBag.available_tiles` reference and replace with `TileBag.get_available_tiles()`.

**Step 6: Update any remaining callers from the grep in Step 1**

**Step 7: Verify**

```
grep -rn "TileBag\.available_tiles\|TileBag\.drawn_tiles\|TileBag\.current_distribution" --include="*.gd" .
```

Expected: zero results.

Open Godot. F5 — run a game, confirm tiles draw normally.

**Step 8: Commit**

```bash
git add autoload/tile_bag.gd scripts/domain/qualities/random_modifiers_quality.gd scripts/domain/qualities/all_reset_quality.gd
git commit -m "refactor: encapsulate TileBag state arrays behind read-only getters"
```

---

### Task 5: Encapsulate `HandManager.discard_pile`

**Files:**
- Modify: `autoload/hand_manager.gd`

**Step 1: Find all direct callers**

```
grep -rn "HandManager\.discard_pile\b" --include="*.gd" .
```

Note each caller. Any code reading `HandManager.discard_pile` directly should use `HandManager.get_discard_pile()` instead (that getter already exists).

**Step 2: Rename the field**

```gdscript
# BEFORE (line 24):
var discard_pile: Array[Tile] = []

# AFTER:
var _discard_pile: Array[Tile] = []
```

**Step 3: Fix internal usages in `hand_manager.gd`**

Replace all `discard_pile` with `_discard_pile` within the file. The public `get_discard_pile()`, `clear_discard_pile()`, `discard_tile()` methods should all update their internal references.

**Step 4: Fix any external callers from Step 1**

For each caller found: replace direct array access with the appropriate method (`get_discard_pile()`, `discard_tile()`, `clear_discard_pile()`).

**Step 5: Verify**

```
grep -rn "HandManager\.discard_pile\b" --include="*.gd" .
```

Expected: zero results.

Open Godot. F5 — discard tiles, confirm they move to discard pile correctly.

**Step 6: Commit**

```bash
git add autoload/hand_manager.gd
git commit -m "refactor: encapsulate HandManager.discard_pile as _discard_pile"
```

---

### Task 6: Make `GameplayController` internal state private

**Files:**
- Modify: `scripts/controllers/gameplay_controller.gd`

**Step 1: Find external readers**

```
grep -rn "gameplay_controller\.\(interaction_mode\|selected_tile\)\|controller\.\(interaction_mode\|selected_tile\)" --include="*.gd" .
```

If any external caller reads `interaction_mode`, add `func get_interaction_mode() -> InteractionMode: return _interaction_mode`. Same for `selected_tile`.

**Step 2: Rename the fields**

```gdscript
# BEFORE (lines 30–31):
var interaction_mode: InteractionMode = InteractionMode.IDLE
var selected_tile: Tile = null

# AFTER:
var _interaction_mode: InteractionMode = InteractionMode.IDLE
var _selected_tile: Tile = null
```

**Step 3: Fix all internal usages**

In `_update_interaction_state()` (line ~375):

```gdscript
# BEFORE:
	if has_selection:
		interaction_mode = InteractionMode.TILE_SELECTED
		selected_tile = _selection.get_selected_tiles()[0] if _selection.get_selection_count() == 1 else null
		...
	else:
		interaction_mode = InteractionMode.IDLE
		selected_tile = null

# AFTER:
	if has_selection:
		_interaction_mode = InteractionMode.TILE_SELECTED
		_selected_tile = _selection.get_selected_tiles()[0] if _selection.get_selection_count() == 1 else null
		...
	else:
		_interaction_mode = InteractionMode.IDLE
		_selected_tile = null
```

**Step 4: Verify**

```
grep -n "\binteraction_mode\b\|\bselected_tile\b" scripts/controllers/gameplay_controller.gd
```

Expected: all remaining hits have `_` prefix.

Open Godot. F5 — select tiles, verify placement still works.

**Step 5: Commit**

```bash
git add scripts/controllers/gameplay_controller.gd
git commit -m "refactor: make GameplayController.interaction_mode and selected_tile private"
```

---

### Task 7: Remove `DropHandler.last_placement_success` state flag

**Files:**
- Modify: `scripts/controllers/drop_handler.gd`
- Modify: `scripts/controllers/gameplay_controller.gd`

**Step 1: Remove the field from `drop_handler.gd`**

```gdscript
# DELETE lines 17–18:
## Tracks whether the last drop was successful (read by coordinator).
var last_placement_success: bool = false
```

Remove all `last_placement_success = false` and `last_placement_success = true` assignments inside `handle_tile_drop()`. The function already returns `bool` at every exit — that is the source of truth.

Final `handle_tile_drop()` shape (assignments removed, returns unchanged):

```gdscript
func handle_tile_drop(drop_cell: BoardCell, tiles: Array[Tile]) -> bool:
	if tiles.is_empty():
		return false

	var has_board_tiles: bool = _any_tiles_on_board(tiles)
	var target_cells: Array[BoardCell] = _get_target_cells_for_drop(drop_cell, tiles)

	if target_cells.is_empty():
		_handle_invalid_drop(tiles, has_board_tiles, drop_cell)
		return false

	_execute_valid_drop(tiles, target_cells)
	return true
```

**Step 2: Update the caller in `gameplay_controller.gd`**

```gdscript
# BEFORE (lines 263–265):
	_drop.handle_tile_drop(cell, dragged_tiles)
	_update_interaction_state()
	_play.update_play_button_state()
	_drag_mgr.end_drag(_drop.last_placement_success)

# AFTER:
	var success := _drop.handle_tile_drop(cell, dragged_tiles)
	_update_interaction_state()
	_play.update_play_button_state()
	_drag_mgr.end_drag(success)
```

**Step 3: Verify**

```
grep -rn "last_placement_success" --include="*.gd" .
```

Expected: zero results.

Open Godot. F5 — drag tiles to valid and invalid cells, confirm placement and cancel animations behave correctly.

**Step 4: Commit**

```bash
git add scripts/controllers/drop_handler.gd scripts/controllers/gameplay_controller.gd
git commit -m "refactor: replace DropHandler.last_placement_success flag with return value"
```

---

## Phase 2 — Complexity Reduction

---

### Task 8: Extract `_categorize_tiles_by_animation()` in PlayHandler

**Files:**
- Modify: `scripts/controllers/play_handler.gd`

The identical 11-line categorization block appears twice: in `on_play_requested()` (lines 55–62) and `_auto_end_round()` (lines 102–110). Extract it once.

**Step 1: Add the helper method**

Add this anywhere in the private section of `play_handler.gd`:

```gdscript
## Splits tiles into spin (EXTRA/MULTI/EXPO) and stomp (RESET/plain) groups.
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

**Step 2: Replace the first duplicated block in `on_play_requested()`**

```gdscript
# BEFORE (lines 55–62):
	var spin_tiles: Array[Tile] = []
	var stomp_tiles: Array[Tile] = []
	for tile in all_tiles:
		if tile.has_modifier(ModifierTypes.Type.RESET):
			stomp_tiles.append(tile)
		elif tile.has_modifier(ModifierTypes.Type.EXTRA) \
			or tile.has_modifier(ModifierTypes.Type.MULTI) \
			or tile.has_modifier(ModifierTypes.Type.EXPO):
			spin_tiles.append(tile)
		else:
			stomp_tiles.append(tile)

# AFTER:
	var cats := _categorize_tiles_by_animation(all_tiles)
	var spin_tiles: Array[Tile] = cats.spin
	var stomp_tiles: Array[Tile] = cats.stomp
```

**Step 3: Replace the second duplicated block in `_auto_end_round()`**

```gdscript
# BEFORE (lines 102–110):
	var spin_tiles: Array[Tile] = []
	var stomp_tiles: Array[Tile] = []
	for tile in all_tiles:
		if tile.has_modifier(ModifierTypes.Type.RESET):
			stomp_tiles.append(tile)
		elif tile.has_modifier(ModifierTypes.Type.EXTRA) \
			or tile.has_modifier(ModifierTypes.Type.MULTI) \
			or tile.has_modifier(ModifierTypes.Type.EXPO):
			spin_tiles.append(tile)
		else:
			stomp_tiles.append(tile)

# AFTER:
	var cats := _categorize_tiles_by_animation(all_tiles)
	var spin_tiles: Array[Tile] = cats.spin
	var stomp_tiles: Array[Tile] = cats.stomp
```

**Step 4: Verify**

Open Godot. F5 — play words with and without modifier tiles. Confirm spin animation fires for EXTRA/MULTI/EXPO tiles and stomp for RESET/plain tiles.

**Step 5: Commit**

```bash
git add scripts/controllers/play_handler.gd
git commit -m "refactor: extract _categorize_tiles_by_animation() to eliminate duplication in PlayHandler"
```

---

### Task 9: Decompose `GameplayController._on_tile_drag_started()`

**Files:**
- Modify: `scripts/controllers/gameplay_controller.gd`

**Step 1: Add helper `_collect_drag_candidates()`**

```gdscript
## Builds the list of tiles to drag. Ensures lead tile is always included.
## Removes followers that refuse drag. Resets selection if lead was not selected.
func _collect_drag_candidates(tile: Tile) -> Array[Tile]:
	var candidates: Array[Tile] = []
	for t in _selection.get_selected_tiles():
		if t.can_interact():
			candidates.append(t)

	if tile not in candidates:
		_selection.deselect_all()
		_selection.select_tile(tile)
		return [tile]

	for t in candidates.duplicate():
		if t != tile and not t.set_as_drag_follower():
			candidates.erase(t)

	return candidates
```

**Step 2: Rewrite `_on_tile_drag_started()`**

```gdscript
func _on_tile_drag_started(tile: Tile) -> void:
	if not _is_active or not tile.can_interact():
		return

	var valid_tiles := _collect_drag_candidates(tile)
	if valid_tiles.is_empty():
		print("[Gameplay] No valid tiles to drag")
		return

	_drag_mgr.start_drag(tile, valid_tiles)
	if valid_tiles.size() > 1:
		print("[Gameplay] Multi-drag started with %d tiles" % valid_tiles.size())
```

**Step 3: Verify**

Open Godot. F5 — test single drag, multi-drag, and dragging a locked tile. Confirm behaviour unchanged.

**Step 4: Commit**

```bash
git add scripts/controllers/gameplay_controller.gd
git commit -m "refactor: extract _collect_drag_candidates() to decompose _on_tile_drag_started (CC 7→3)"
```

---

### Task 10: Decompose `GameplayController._on_cell_clicked()`

**Files:**
- Modify: `scripts/controllers/gameplay_controller.gd`

**Step 1: Add helper `_place_tiles_on_cell()`**

```gdscript
## Places one or more movable tiles starting at the target cell.
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

**Step 2: Rewrite `_on_cell_clicked()`**

```gdscript
func _on_cell_clicked(cell: BoardCell) -> void:
	if not _is_active:
		return

	var selected: Array[Tile] = _selection.get_selected_tiles()
	if selected.is_empty():
		print("[Gameplay] No tile selected")
		return

	var movable: Array[Tile] = selected.filter(func(t): return not t.is_locked)
	if movable.is_empty():
		print("[Gameplay] All selected tiles are locked")
		_selection.deselect_all()
		_update_interaction_state()
		return

	if cell.is_occupied():
		print("[Gameplay] Cell occupied: %s" % cell.name)
		return

	_place_tiles_on_cell(movable, cell)
```

**Step 3: Verify**

Open Godot. F5 — click-to-place a single tile, click-to-place multiple selected tiles, attempt to place on occupied cell. All should behave identically to before.

**Step 4: Commit**

```bash
git add scripts/controllers/gameplay_controller.gd
git commit -m "refactor: extract _place_tiles_on_cell() to decompose _on_cell_clicked (CC 6→4)"
```

---

### Task 11: Simplify `GameplayController._on_tile_selected()` with match

**Files:**
- Modify: `scripts/controllers/gameplay_controller.gd`

**Step 1: Rewrite using `match`**

```gdscript
func _on_tile_selected(tile: Tile) -> void:
	if not _is_active:
		return

	print("[Gameplay] Tile selected: %s" % tile.name)

	match tile.location:
		Tile.TileLocation.ON_BOARD:
			if _selection.has_selection():
				print("[Gameplay] Cannot stack tiles")
			else:
				print("[Gameplay] Board tile at cell: %s" % tile.current_cell.name)
		Tile.TileLocation.IN_HAND:
			_selection.select_tile(tile)
			_update_interaction_state()
```

**Step 2: Verify**

Open Godot. F5 — click a hand tile (selects), click a board tile while selection active (prints warning), click a board tile with no selection (prints info). Behaviour unchanged.

**Step 3: Commit**

```bash
git add scripts/controllers/gameplay_controller.gd
git commit -m "refactor: use match for tile location dispatch in _on_tile_selected (CC 5→3)"
```

---

### Task 12: Extract `_check_quality_win_conditions()` from RunManager

**Files:**
- Modify: `autoload/run_manager.gd`

**Step 1: Add helper**

```gdscript
## Checks if any quality wants to end the run. Handles the transition if so.
## Returns true if the run was ended (caller should return early).
func _check_quality_win_conditions() -> bool:
	if _active_run == null:
		return false
	for quality in _active_run.qualities:
		if not quality.has_custom_win_condition():
			continue
		var result := quality.check_run_end_condition(run_state)
		if not result.get("should_end", false):
			continue
		var victory: bool = result.get("victory", false)
		run_state.end_run()
		EventBus.run_ended.emit(victory, run_state.total_score)
		print("[RunManager] Quality '%s' ended run - Victory: %s" % [quality.get_quality_name(), victory])
		return true
	return false
```

**Step 2: Simplify `_on_round_ended()`**

```gdscript
func _on_round_ended(round_number: int, success: bool) -> void:
	if not run_state or not run_state.is_run_active:
		return

	if _active_run:
		for quality in _active_run.qualities:
			quality.on_round_ended(round_number, success)

	if not success:
		run_state.end_run()
		EventBus.run_ended.emit(false, run_state.total_score)
		print("[RunManager] Round %d lost - run ended" % round_number)
		return

	run_state.complete_round(GameManager.get_current_score())
	if _check_quality_win_conditions():
		return
	EventBus.run_shop_requested.emit(run_state.current_round)
	print("[RunManager] Round %d won - proceeding to shop" % round_number)
```

**Step 3: Verify**

Open Godot. F5 — complete a round successfully, lose a round, complete a MaxScoreInNRoundsQuality run. All transitions should behave correctly.

**Step 4: Commit**

```bash
git add autoload/run_manager.gd
git commit -m "refactor: extract _check_quality_win_conditions() to decompose _on_round_ended (CC 6→5)"
```

---

### Task 13: Extract `_pick_weighted()` in RandomModifiersQuality

**Files:**
- Modify: `scripts/domain/qualities/random_modifiers_quality.gd`

**Step 1: Add generic helper**

```gdscript
## Picks a random key from a weights dictionary {key: int_weight}.
func _pick_weighted(weights: Dictionary) -> Variant:
	var total: int = 0
	for w in weights.values():
		total += w
	var roll: int = randi() % total
	var cumulative: int = 0
	for key in weights:
		cumulative += weights[key]
		if roll < cumulative:
			return key
	return weights.keys()[0]
```

**Step 2: Replace `_pick_weighted_type()`**

```gdscript
func _pick_weighted_type() -> ModifierTypes.Type:
	return _pick_weighted(TYPE_WEIGHTS)
```

**Step 3: Replace `_pick_weighted_tier()`**

```gdscript
func _pick_weighted_tier() -> ModifierTypes.Tier:
	return _pick_weighted(TIER_WEIGHTS)
```

**Step 4: Verify**

Open Godot. F5 — start a run with Random Modifiers quality, begin a round, confirm modifier tiles appear with the expected distribution (EXTRA most common, RESET rarest).

**Step 5: Commit**

```bash
git add scripts/domain/qualities/random_modifiers_quality.gd
git commit -m "refactor: extract _pick_weighted() to eliminate duplication in RandomModifiersQuality (CC 6→2 each)"
```

---

## Phase 3 — Architecture Patterns

---

### Task 14: Create `SignalTracker` utility class

**Files:**
- Create: `scripts/util/signal_tracker.gd`

**Step 1: Create the file**

```gdscript
class_name SignalTracker
extends RefCounted

## Tracks signal connections and disconnects all at once.
## Replaces ad-hoc _connections arrays and _safe_connect/_disconnect_all patterns.

var _connections: Array[Dictionary] = []


## Connects sig to fn and records the connection for later cleanup.
func track(sig: Signal, fn: Callable) -> void:
	sig.connect(fn)
	_connections.append({s = sig, f = fn})


## Disconnects all tracked connections and clears the list.
func disconnect_all() -> void:
	for c in _connections:
		if c.s.is_connected(c.f):
			c.s.disconnect(c.f)
	_connections.clear()
```

**Step 2: Verify**

Open Godot. Check Output — no errors loading the new class.

**Step 3: Commit**

```bash
git add scripts/util/signal_tracker.gd
git commit -m "feat: add SignalTracker utility for unified signal lifecycle management"
```

---

### Task 15: Use `SignalTracker` in `GameplayController`

**Files:**
- Modify: `scripts/controllers/gameplay_controller.gd`

**Step 1: Replace `_connections` field and helper methods**

```gdscript
# REMOVE:
var _connections: Array[Dictionary] = []

# ADD:
var _tracker: SignalTracker = SignalTracker.new()
```

Remove the two helper methods entirely:
```gdscript
# DELETE:
func _safe_connect(sig: Signal, handler: Callable) -> void: ...
func _disconnect_all() -> void: ...
```

**Step 2: Update `_connect_signals()`**

Replace every `_safe_connect(sig, fn)` call with `_tracker.track(sig, fn)`:

```gdscript
func _connect_signals() -> void:
	if board:
		_tracker.track(board.cell_clicked, _on_cell_clicked)
		_tracker.track(board.cell_hovered, _on_cell_hovered)
		_tracker.track(board.cell_unhovered, _on_cell_unhovered)

	if discard_pile:
		_tracker.track(discard_pile.tiles_dropped, _on_discard_pile_tiles_dropped)
		_tracker.track(discard_pile.discard_clicked, _on_discard_pile_clicked)
		_tracker.track(discard_pile.peek_requested, _on_discard_pile_peek_requested)

	if main_hud:
		_tracker.track(main_hud.draw_requested, _on_draw_requested)
		_tracker.track(main_hud.play_requested, _on_play_requested)

	_tracker.track(_drag_mgr.drag_release_requested, _handle_drag_release)
	_tracker.track(EventBus.hand_count_changed, _on_tile_supply_changed)
	_tracker.track(EventBus.bag_count_changed, _on_tile_supply_changed)
```

**Step 3: Update `deactivate()`**

```gdscript
# BEFORE:
	_disconnect_all()

# AFTER:
	_tracker.disconnect_all()
```

**Step 4: Verify**

Open Godot. F5 — activate gameplay, deactivate (go to title screen), reactivate. Signals should connect/disconnect cleanly with no double-fire or missing events.

**Step 5: Commit**

```bash
git add scripts/controllers/gameplay_controller.gd
git commit -m "refactor: replace _safe_connect/_disconnect_all with SignalTracker in GameplayController"
```

---

### Task 16: Use `SignalTracker` in `RunManager`

**Files:**
- Modify: `autoload/run_manager.gd`

**Step 1: Find the quality connections infrastructure**

```
grep -n "_quality_connections\|_connect_quality_signals\|_disconnect_quality_signals" autoload/run_manager.gd
```

Note the line numbers.

**Step 2: Replace `_quality_connections` field**

```gdscript
# REMOVE:
var _quality_connections: Array[Dictionary] = []

# ADD:
var _quality_tracker: SignalTracker = SignalTracker.new()
```

**Step 3: Rewrite `_connect_quality_signals()`**

Find the existing method. Replace all `_quality_connections.append(...)` patterns with `_quality_tracker.track(sig, fn)`.

The structure should be:
```gdscript
func _connect_quality_signals() -> void:
	if _active_run == null:
		return
	for quality in _active_run.qualities:
		if quality.has_method("on_process"):
			# on_process is called directly, no signal needed
			pass
		var expired_cb := func(): _on_quality_time_expired()
		_quality_tracker.track(quality.time_expired, expired_cb)
		# add any other quality signal connections here
```

Adapt this to whatever signals the existing `_connect_quality_signals()` actually connects. The key change is `_quality_tracker.track(...)` instead of `_quality_connections.append(...)`.

**Step 4: Rewrite `_disconnect_quality_signals()`**

```gdscript
func _disconnect_quality_signals() -> void:
	_quality_tracker.disconnect_all()
```

**Step 5: Verify**

Open Godot. F5 — start a run with Time Attack quality, complete a round. Timer should stop between rounds (signals disconnected and reconnected cleanly).

**Step 6: Commit**

```bash
git add autoload/run_manager.gd
git commit -m "refactor: replace _quality_connections with SignalTracker in RunManager"
```

---

### Task 17: Create `TimerQuality` base class

**Files:**
- Create: `scripts/domain/qualities/timer_quality.gd`

**Step 1: Create the file**

```gdscript
class_name TimerQuality
extends RunQuality

## Base class for RunQuality types that implement a countdown timer.
## Subclasses set _time_remaining and _is_active in on_round_started().
## The shared countdown + emission logic lives here.

var _time_remaining: float = 0.0
var _is_active: bool = false


func has_timer() -> bool:
	return true


func on_round_ended(_round_number: int, _success: bool) -> void:
	_is_active = false


func on_process(delta: float) -> void:
	if not _is_active:
		return
	_time_remaining = maxf(0.0, _time_remaining - delta)
	time_updated.emit(_time_remaining)
	if _time_remaining <= 0.0:
		_is_active = false
		time_expired.emit()
```

**Step 2: Verify**

Open Godot. Expected: no errors loading the class (it has no scene).

**Step 3: Commit**

```bash
git add scripts/domain/qualities/timer_quality.gd
git commit -m "feat: add TimerQuality base class with shared countdown logic"
```

---

### Task 18: Make `TimeAttackQuality` extend `TimerQuality`

**Files:**
- Modify: `scripts/domain/qualities/time_attack_quality.gd`

**Step 1: Rewrite the file**

```gdscript
extends TimerQuality
class_name TimeAttackQuality

## TimeAttackQuality: Each round has a fixed countdown timer.
## When time expires, the round is lost.

const DEFAULT_TIME: float = 120.0


func get_quality_id() -> StringName:
	return &"time_attack"

func get_quality_name() -> String:
	return "Time Attack"

func get_description() -> String:
	return "Each round has a %d second time limit." % int(DEFAULT_TIME)


func on_round_started(_round_number: int) -> void:
	_time_remaining = DEFAULT_TIME
	_is_active = true


func to_dict() -> Dictionary:
	return {"quality_id": get_quality_id(), "default_time": DEFAULT_TIME}
```

Removed: `_time_remaining`, `_is_active` fields, `has_timer()`, `on_round_ended()`, `on_process()` — all inherited from `TimerQuality`.

**Step 2: Verify**

Open Godot. F5 — start a Time Attack run. Timer should count down, expire, and end the round on timeout.

**Step 3: Commit**

```bash
git add scripts/domain/qualities/time_attack_quality.gd
git commit -m "refactor: TimeAttackQuality extends TimerQuality (removes 15 lines of duplicated logic)"
```

---

### Task 19: Make `LimitedTimeWithIncrementQuality` extend `TimerQuality`

**Files:**
- Modify: `scripts/domain/qualities/limited_time_with_increment_quality.gd`

**Step 1: Rewrite the file**

```gdscript
extends TimerQuality
class_name LimitedTimeWithIncrementQuality

## LimitedTimeWithIncrementQuality: Countdown timer that adds time on each play.

const DEFAULT_TIME: float = 60.0
const INCREMENT_PER_PLAY: float = 15.0


func get_quality_id() -> StringName:
	return &"limited_time_with_increment"

func get_quality_name() -> String:
	return "Time + Increment"

func get_description() -> String:
	return "%ds per round, +%ds per play." % [int(DEFAULT_TIME), int(INCREMENT_PER_PLAY)]


func on_round_started(_round_number: int) -> void:
	_time_remaining = DEFAULT_TIME
	_is_active = true


func on_play_completed(_plays_remaining: int) -> void:
	if _is_active:
		_time_remaining += INCREMENT_PER_PLAY
		time_incremented.emit(INCREMENT_PER_PLAY)
		time_updated.emit(_time_remaining)


func to_dict() -> Dictionary:
	return {
		"quality_id": get_quality_id(),
		"default_time": DEFAULT_TIME,
		"increment": INCREMENT_PER_PLAY,
	}
```

Removed: `_time_remaining`, `_is_active`, `has_timer()`, `on_round_ended()`, `on_process()` — all inherited.

**Step 2: Verify**

Open Godot. F5 — start a Limited Time + Increment run. Timer counts down, each successful play adds 15s, expiry ends the round.

**Step 3: Commit**

```bash
git add scripts/domain/qualities/limited_time_with_increment_quality.gd
git commit -m "refactor: LimitedTimeWithIncrementQuality extends TimerQuality (removes 15 lines of duplicated logic)"
```

---

### Task 20: Decouple `PlayHandler` from `MainHUD` via signals

**Files:**
- Modify: `scripts/controllers/play_handler.gd`
- Modify: `scripts/controllers/gameplay_controller.gd`

**Step 1: Add signals and remove `main_hud` from `play_handler.gd`**

In the signals section, add:
```gdscript
signal draw_blocked_changed(blocked: bool)
signal play_button_changed(enabled: bool, end_round_mode: bool)
```

Remove the `main_hud` field:
```gdscript
# DELETE:
var main_hud: CanvasLayer = null
```

Update `setup()` — remove `p_hud` parameter:
```gdscript
# BEFORE:
func setup(p_board: Board, p_hud: CanvasLayer, p_selection: SelectionManager) -> void:
	board = p_board
	main_hud = p_hud
	_selection = p_selection
	_word_validator = WordValidator.new()

# AFTER:
func setup(p_board: Board, p_selection: SelectionManager) -> void:
	board = p_board
	_selection = p_selection
	_word_validator = WordValidator.new()
```

**Step 2: Replace all `main_hud` calls with signal emissions**

In `on_play_requested()`:
```gdscript
# BEFORE:
	main_hud.set_draw_button_blocked(true)
# AFTER:
	draw_blocked_changed.emit(true)

# BEFORE:
	main_hud.set_draw_button_blocked(false)
# AFTER:
	draw_blocked_changed.emit(false)
```

In `_auto_end_round()`:
```gdscript
# BEFORE:
	main_hud.set_play_button_enabled(false)
# AFTER:
	play_button_changed.emit(false, false)
```

In `update_play_button_state()`:
```gdscript
# BEFORE:
func update_play_button_state() -> void:
	if not main_hud:
		return
	var has_unplayed_tiles: bool = not _get_unplayed_board_tiles().is_empty()
	if has_unplayed_tiles:
		main_hud.set_play_button_enabled(true)
		main_hud.set_play_button_mode(false)
	elif not has_valid_moves() and GameManager.get_plays_remaining() > 0:
		main_hud.set_play_button_enabled(true)
		main_hud.set_play_button_mode(true)
	else:
		main_hud.set_play_button_enabled(false)
		main_hud.set_play_button_mode(false)

# AFTER:
func update_play_button_state() -> void:
	var has_unplayed: bool = not _get_unplayed_board_tiles().is_empty()
	if has_unplayed:
		play_button_changed.emit(true, false)
	elif not has_valid_moves() and GameManager.get_plays_remaining() > 0:
		play_button_changed.emit(true, true)
	else:
		play_button_changed.emit(false, false)
```

**Step 3: Update `GameplayController.setup()` to wire the new signals**

```gdscript
# BEFORE:
	_play = PlayHandler.new()
	_play.setup(board, main_hud, _selection)
	_play.play_completed.connect(func(tiles, words): play_completed.emit(tiles, words))

# AFTER:
	_play = PlayHandler.new()
	_play.setup(board, _selection)
	_play.play_completed.connect(func(tiles, words): play_completed.emit(tiles, words))
	_play.draw_blocked_changed.connect(
		func(blocked): main_hud.set_draw_button_blocked(blocked)
	)
	_play.play_button_changed.connect(
		func(enabled, mode):
			main_hud.set_play_button_enabled(enabled)
			main_hud.set_play_button_mode(mode)
	)
```

**Step 4: Verify**

```
grep -n "main_hud" scripts/controllers/play_handler.gd
```

Expected: zero results.

Open Godot. F5 — play tiles: draw button should block during animation and unblock after. Play button should enable when tiles are on board and switch to End Round mode when no valid moves remain.

**Step 5: Commit**

```bash
git add scripts/controllers/play_handler.gd scripts/controllers/gameplay_controller.gd
git commit -m "refactor: decouple PlayHandler from MainHUD via draw_blocked_changed and play_button_changed signals"
```

---

### Task 21: Collapse `TileAnimator._ensure_*_resources()` duplication

**Files:**
- Modify: `autoload/tile_animator.gd`

**Step 1: Add two generic helpers**

```gdscript
## Lazy-initializes a strategy (no constructor args).
func _ensure_strategy(current: Variant, klass: GDScript) -> Variant:
	return current if current != null else klass.new()

## Lazy-initializes an executor (takes _context as constructor arg).
func _ensure_executor(current: Variant, klass: GDScript) -> Variant:
	return current if current != null else klass.new(_context)
```

**Step 2: Replace all five `_ensure_*_resources()` methods**

```gdscript
func _ensure_draw_resources() -> void:
	_draw_animation = _ensure_strategy(_draw_animation, DrawTileAnimation)
	_batch_executor = _ensure_executor(_batch_executor, BatchAnimationExecutor)

func _ensure_glide_resources() -> void:
	_glide_animation = _ensure_strategy(_glide_animation, GlideTileAnimation)
	_return_executor = _ensure_executor(_return_executor, ReturnAnimationExecutor)

func _ensure_shake_resources() -> void:
	_shake_animation = _ensure_strategy(_shake_animation, ShakeTileAnimation)
	_shake_executor = _ensure_executor(_shake_executor, ShakeAnimationExecutor)

func _ensure_stomp_resources() -> void:
	_stomp_animation = _ensure_strategy(_stomp_animation, StompTileAnimation)
	_stomp_executor = _ensure_executor(_stomp_executor, StompAnimationExecutor)

func _ensure_spin_resources() -> void:
	_spin_animation = _ensure_strategy(_spin_animation, SpinTileAnimation)
	_spin_executor = _ensure_executor(_spin_executor, SpinAnimationExecutor)
```

**Step 3: Verify**

Open Godot. F5 — draw tiles (batch), play tiles (stomp + spin), shake on invalid action, discard tiles. All animations should work correctly.

**Step 4: Commit**

```bash
git add autoload/tile_animator.gd
git commit -m "refactor: collapse TileAnimator lazy-loaders into _ensure_strategy/_ensure_executor helpers"
```

---

## Final Verification

After all tasks are complete:

**1. Check for lingering dead symbols:**
```
grep -rn "point_modifier\|is_wild\|start_alpha\|last_placement_success\|available_tiles\b\|drawn_tiles\b\|discard_pile\b" --include="*.gd" .
```
Expected: zero results (these were all removed or renamed).

**2. Check cyclomatic complexity hotspots are gone:**
```
grep -n "def \|func " scripts/controllers/play_handler.gd scripts/controllers/gameplay_controller.gd autoload/run_manager.gd
```
Manually verify the key functions above have been replaced.

**3. Full play session:**
- Start a Standard run — normal gameplay, play tiles, score, advance rounds
- Start a Cursed run — all tiles show RESET, stomp animation only
- Start a Time Attack run — timer counts down and expires
- Start a Limited Time + Increment run — +15s per play
- Start a Random Modifiers run — tiles get random modifiers each round
