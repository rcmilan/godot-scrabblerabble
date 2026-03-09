class_name DropResolver
extends RefCounted

## Pure domain service that resolves what should happen when tiles are dropped.
## Uses PlacementValidator internally. Returns a DropDecision value object.

var _validator: PlacementValidator
var _drag_mgr: DragManager


func _init(validator: PlacementValidator, drag_mgr: DragManager) -> void:
	_validator = validator
	_drag_mgr = drag_mgr


## Resolves a drop into a DropDecision.
func resolve(drop_cell: BoardCell, tiles: Array[Tile]) -> DropDecision:
	if tiles.is_empty():
		return DropDecision.reject(tiles, "No tiles to drop")

	if drop_cell == null:
		return DropDecision.reject(tiles, "Drop outside board")

	if tiles.size() == 1:
		return _resolve_single(drop_cell, tiles)

	return _resolve_multi(drop_cell, tiles)


func _resolve_single(drop_cell: BoardCell, tiles: Array[Tile]) -> DropDecision:
	if _validator.can_place(drop_cell):
		return DropDecision.place(tiles, [drop_cell])

	if _validator.can_swap(drop_cell):
		return DropDecision.swap(tiles, [drop_cell])

	return DropDecision.reject(tiles, "Cell occupied by locked tile")


func _resolve_multi(drop_cell: BoardCell, tiles: Array[Tile]) -> DropDecision:
	var lead_tile: Tile = _drag_mgr.lead_tile
	var lead_index: int = tiles.find(lead_tile)
	if lead_index == -1:
		lead_index = 0

	var target_cells: Array[BoardCell] = _validator.get_sequential_cells_centered(
		drop_cell, tiles.size(), lead_index
	)

	if target_cells.is_empty():
		return DropDecision.reject(tiles, "Not enough sequential empty cells")

	return DropDecision.place(tiles, target_cells)
