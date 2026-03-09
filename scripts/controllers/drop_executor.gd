class_name DropExecutor
extends RefCounted

## DropExecutor: Executes drop operations based on DropDecision.
## Uses lookup dispatch (CC 1) to route to the correct handler.

# =============================================================================
# DEPENDENCIES (injected via setup)
# =============================================================================

var _placement: PlacementExecutor = null
var hand: Hand = null
var _selection: SelectionManager = null
var _drag_mgr: DragManager = null
var _resolver: DropResolver = null

## Lookup table: DropDecision.Action → handler callable
var _action_handlers: Dictionary = {}


func setup(placement: PlacementExecutor, p_hand: Hand, p_selection: SelectionManager, p_drag_mgr: DragManager) -> void:
	_placement = placement
	hand = p_hand
	_selection = p_selection
	_drag_mgr = p_drag_mgr
	_resolver = DropResolver.new(placement.get_validator(), p_drag_mgr)

	_action_handlers = {
		DropDecision.Action.PLACE: _execute_place,
		DropDecision.Action.SWAP: _execute_swap,
		DropDecision.Action.REJECT: _execute_reject,
	}


func get_resolver() -> DropResolver:
	return _resolver


# =============================================================================
# PUBLIC API
# =============================================================================

## Resolves and executes a drop in one call.
func handle_tile_drop(drop_cell: BoardCell, tiles: Array[Tile]) -> bool:
	var decision: DropDecision = _resolver.resolve(drop_cell, tiles)
	return execute(decision)


## Executes a DropDecision via lookup dispatch (CC 1).
func execute(decision: DropDecision) -> bool:
	var handler: Callable = _action_handlers.get(decision.get_action())
	return handler.call(decision)


# =============================================================================
# ACTION HANDLERS
# =============================================================================

func _execute_place(decision: DropDecision) -> bool:
	_drag_mgr.restore_tiles_to_parents()

	var tiles: Array[Tile] = decision.get_tiles()
	var target_cells: Array[BoardCell] = decision.get_target_cells()

	for i in tiles.size():
		_placement.place_tile_on_cell_silent(tiles[i], target_cells[i])

	_selection.deselect_all()
	print("[Gameplay] Placed %d tile(s) on board" % tiles.size())
	return true


func _execute_swap(decision: DropDecision) -> bool:
	var tiles: Array[Tile] = decision.get_tiles()
	var target_cells: Array[BoardCell] = decision.get_target_cells()

	if tiles.size() != 1 or target_cells.size() != 1:
		return _execute_reject(decision)

	_drag_mgr.restore_tiles_to_parents()
	_placement.swap_tiles(tiles[0], target_cells[0].tile, target_cells[0])
	_selection.deselect_all()
	return true


func _execute_reject(decision: DropDecision) -> bool:
	var tiles: Array[Tile] = decision.get_tiles()
	var reason: String = decision.get_reason()

	if not reason.is_empty():
		print("[Gameplay] Drop rejected: %s" % reason)

	var has_board_tiles: bool = _any_tiles_on_board(tiles)

	if has_board_tiles:
		_drag_mgr.restore_tiles_to_parents()
		for tile in tiles:
			if tile.location == Tile.TileLocation.ON_BOARD:
				_placement.return_to_original_cell(tile)
	else:
		_animate_tiles_back_to_hand(tiles)

	_placement.clear_all_cell_hovers()
	return false


# =============================================================================
# PRIVATE HELPERS
# =============================================================================

func _any_tiles_on_board(tiles: Array[Tile]) -> bool:
	for tile in tiles:
		if tile.location == Tile.TileLocation.ON_BOARD:
			return true
	return false


func _animate_tiles_back_to_hand(tiles: Array[Tile]) -> void:
	if tiles.size() == 1 and not _selection.is_multi_select_enabled():
		_selection.deselect_tile(tiles[0])

	TileAnimator.animate_cancel_to_hand(tiles, hand, _drag_mgr.restore_tiles_to_parents)
	print("[Gameplay] Animating %d tile(s) back to hand" % tiles.size())
