class_name DragInteractionHandler
extends RefCounted

## DragInteractionHandler: Owns the full drag lifecycle for tile interaction.
## Extracted from GameplayController to satisfy SRP. Handles candidate collection,
## drag start/end events, drop resolution, and same-cell detection.

var _drag_mgr: DragManager = null
var _drop: DropExecutor = null
var _coordinator: BoardStateCoordinator = null
var _discard: DiscardHandler = null
var _selection: SelectionManager = null
var _board: Board = null
var _play: PlayExecutor = null
var _word_highlight: WordHighlightHandler = null
var _discard_pile: Control = null

## Called after any state-mutating drag action to sync interaction mode.
var _post_action: Callable


func setup(
	drag_mgr: DragManager,
	drop: DropExecutor,
	coordinator: BoardStateCoordinator,
	discard: DiscardHandler,
	selection: SelectionManager,
	board: Board,
	play: PlayExecutor,
	word_highlight: WordHighlightHandler,
	discard_pile: Control,
	post_action: Callable
) -> void:
	_drag_mgr = drag_mgr
	_drop = drop
	_coordinator = coordinator
	_discard = discard
	_selection = selection
	_board = board
	_play = play
	_word_highlight = word_highlight
	_discard_pile = discard_pile
	_post_action = post_action


# =============================================================================
# PUBLIC API
# =============================================================================

## Builds the candidate tile list for a drag from the current selection + initiating tile.
func collect_drag_candidates(tile: Tile) -> Array[Tile]:
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


## Called when tile_drag_started fires (guard already applied by caller).
func on_drag_started(tile: Tile) -> void:
	var valid_tiles := collect_drag_candidates(tile)
	if valid_tiles.is_empty():
		print("[DragHandler] No valid tiles to drag")
		return

	_drag_mgr.start_drag(tile, valid_tiles)

	for t in valid_tiles:
		if t.location == Tile.TileLocation.ON_BOARD and t.current_cell:
			_coordinator.unregister_tile(t.current_cell.grid_position)

	if _any_tiles_on_board(valid_tiles):
		_word_highlight.run_scan()
		_play.update_play_button_state()

	if valid_tiles.size() > 1:
		print("[DragHandler] Multi-drag started with %d tiles" % valid_tiles.size())


## Called when tile_drag_ended fires. Lead-tile guard applied by caller.
func on_drag_ended(tile: Tile) -> void:
	if not _drag_mgr.is_dragging or tile != _drag_mgr.lead_tile:
		return
	handle_release(tile.get_viewport())


## Core drop resolution. Accepts Viewport to avoid Node dependency on this RefCounted.
func handle_release(viewport: Viewport) -> void:
	if not _drag_mgr.is_dragging:
		return

	var dragged_tiles: Array[Tile] = _drag_mgr.get_dragged_tiles()
	var mouse_pos: Vector2 = viewport.get_mouse_position()

	if _discard_pile and _discard_pile.is_drop_target(mouse_pos):
		_discard.handle_drop_on_discard_pile(dragged_tiles)
		_drag_mgr.end_drag(false)
		return

	var cell: BoardCell = _coordinator.get_cell_under_mouse(viewport)

	# Fast path: same-cell drop (no-op)
	if _is_dropping_on_same_cells(dragged_tiles, cell):
		_handle_same_cell_drop(dragged_tiles)
		_drag_mgr.end_drag(true)
		return

	# Single-tile swap on occupied unlocked cell
	if dragged_tiles.size() == 1 and cell != null and cell.is_occupied():
		var tile_to_place: Tile = dragged_tiles[0]
		var tile_on_cell: Tile = cell.tile
		if not tile_on_cell.is_locked:
			_drag_mgr.restore_tiles_to_parents()
			_coordinator.swap_tiles(tile_to_place, tile_on_cell, cell)
			_selection.deselect_all()
			_word_highlight.run_scan()
			_post_action.call()
			_play.update_play_button_state()
			_drag_mgr.end_drag(true)
			return

	# Unified drop handling
	var success := _drop.handle_tile_drop(cell, dragged_tiles)

	if success:
		for t in dragged_tiles:
			_coordinator.register_dropped_tile(t)
	else:
		for t in dragged_tiles:
			if t.location == Tile.TileLocation.ON_BOARD and t.current_cell:
				_coordinator.restore_psm_for_tile(t)

	_word_highlight.run_scan()
	_post_action.call()
	_play.update_play_button_state()
	_drag_mgr.end_drag(success)


# =============================================================================
# PRIVATE HELPERS
# =============================================================================

func _any_tiles_on_board(tiles: Array[Tile]) -> bool:
	for tile in tiles:
		if tile.location == Tile.TileLocation.ON_BOARD:
			return true
	return false


func _is_dropping_on_same_cells(tiles: Array[Tile], drop_cell: BoardCell) -> bool:
	if drop_cell == null:
		return false

	for i in tiles.size():
		var tile: Tile = tiles[i]
		if tile.location != Tile.TileLocation.ON_BOARD or tile.current_cell == null:
			return false

		var expected_cell: BoardCell
		if tiles.size() == 1:
			expected_cell = drop_cell
		else:
			var lead_tile: Tile = _drag_mgr.lead_tile
			var lead_index: int = tiles.find(lead_tile)
			if lead_index == -1:
				lead_index = 0
			var offset: int = i - lead_index
			var target_pos: Vector2i = drop_cell.grid_position + Vector2i(offset, 0)
			expected_cell = _board.get_cell(target_pos.y, target_pos.x)
			if expected_cell == null:
				return false

		if tile.current_cell != expected_cell:
			return false

	return true


func _handle_same_cell_drop(tiles: Array[Tile]) -> void:
	print("[DragHandler] Same-cell drop detected - restoring state for %d tile(s)" % tiles.size())
	_drag_mgr.restore_tiles_to_parents()

	for tile in tiles:
		if tile.location == Tile.TileLocation.ON_BOARD and tile.current_cell:
			_coordinator.restore_psm_for_tile(tile)
			_coordinator.return_to_original_cell(tile)

	_word_highlight.run_scan()
	_play.update_play_button_state()
	_post_action.call()
	_coordinator.clear_all_cell_hovers()
