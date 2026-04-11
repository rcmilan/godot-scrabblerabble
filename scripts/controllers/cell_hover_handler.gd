class_name CellHoverHandler
extends RefCounted

## Handles cell hover preview logic (valid/invalid placement indicators).
## Uses PlacementValidator for validation.

var _selection: SelectionManager = null
var _placement: PlacementExecutor = null


func setup(selection: SelectionManager, placement: PlacementExecutor) -> void:
	_selection = selection
	_placement = placement


func on_cell_hovered(cell: BoardCell) -> void:
	if not _selection.has_selection():
		return

	var selected_count: int = _selection.get_selection_count()

	if cell.is_unavailable():
		cell.show_invalid_hover()
		return

	if selected_count > 1:
		var cells: Array[BoardCell] = _placement.get_sequential_cells(cell, selected_count)
		if cells.is_empty():
			cell.show_invalid_hover()
		else:
			for c in cells:
				c.show_valid_hover()
	else:
		if cell.is_occupied():
			if cell.tile.is_locked:
				cell.show_invalid_hover()
			else:
				cell.show_valid_hover()
		else:
			cell.show_valid_hover()


func on_cell_unhovered(cell: BoardCell) -> void:
	cell.clear_hover()
