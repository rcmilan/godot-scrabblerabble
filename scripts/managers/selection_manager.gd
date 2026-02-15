extends Node
class_name SelectionManager

## SelectionManager: Central source of truth for tile selection state and mode.
## Manages single/multi-select modes and maintains ordered selection.
## Created as a local node by Main and injected into consumers via setup().

# =============================================================================
# SIGNALS
# =============================================================================

signal mode_changed(is_multi: bool)
signal selection_changed(selected_tiles: Array)

# =============================================================================
# ENUMS
# =============================================================================

enum SelectionMode {
	SINGLE,  # Clicking a tile deselects all others first
	MULTI    # Clicking toggles tile selection, order preserved
}

# =============================================================================
# STATE
# =============================================================================

var mode: SelectionMode = SelectionMode.MULTI
var _selected_tiles: Array[Tile] = []

# =============================================================================
# MODE MANAGEMENT
# =============================================================================

## Toggles between single and multi-select modes.
func toggle_mode() -> void:
	if mode == SelectionMode.SINGLE:
		set_mode(SelectionMode.MULTI)
	else:
		set_mode(SelectionMode.SINGLE)


## Sets the selection mode explicitly.
func set_mode(new_mode: SelectionMode) -> void:
	if mode == new_mode:
		return

	var was_multi: bool = mode == SelectionMode.MULTI
	mode = new_mode

	# Leaving multi-select mode deselects all tiles
	if was_multi and mode == SelectionMode.SINGLE:
		deselect_all()

	mode_changed.emit(is_multi_select_enabled())
	print("[SelectionManager] Mode changed to: %s" % SelectionMode.keys()[mode])


## Returns true if multi-select mode is enabled.
func is_multi_select_enabled() -> bool:
	return mode == SelectionMode.MULTI

# =============================================================================
# SELECTION OPERATIONS
# =============================================================================

## Selects a tile (mode-aware behavior).
func select_tile(tile: Tile) -> void:
	if tile == null:
		return

	match mode:
		SelectionMode.SINGLE:
			_select_single(tile)
		SelectionMode.MULTI:
			_toggle_multi(tile)


## Deselects a specific tile.
func deselect_tile(tile: Tile) -> void:
	if tile == null or tile not in _selected_tiles:
		return

	_selected_tiles.erase(tile)
	tile.set_selected(false)
	tile.set_selection_order(-1)

	# Update order for remaining tiles
	_update_selection_orders()

	selection_changed.emit(get_selected_tiles())


## Deselects all tiles.
func deselect_all() -> void:
	for tile in _selected_tiles:
		tile.set_selected(false)
		tile.set_selection_order(-1)

	_selected_tiles.clear()
	selection_changed.emit([])


## Returns the currently selected tiles in selection order.
func get_selected_tiles() -> Array[Tile]:
	# Filter out any tiles that may have been freed
	var valid_tiles: Array[Tile] = []
	for tile in _selected_tiles:
		if is_instance_valid(tile):
			valid_tiles.append(tile)

	if valid_tiles.size() != _selected_tiles.size():
		_selected_tiles = valid_tiles

	return _selected_tiles.duplicate()


## Returns the number of selected tiles.
func get_selection_count() -> int:
	return get_selected_tiles().size()


## Returns the selection order of a tile (-1 if not selected).
func get_tile_order(tile: Tile) -> int:
	if tile == null:
		return -1
	return _selected_tiles.find(tile)


## Returns true if there are any selected tiles.
func has_selection() -> bool:
	return not get_selected_tiles().is_empty()

# =============================================================================
# PRIVATE HELPERS
# =============================================================================

func _select_single(tile: Tile) -> void:
	# If already selected, deselect it
	if tile in _selected_tiles:
		deselect_tile(tile)
		return

	# Deselect all others first
	for t in _selected_tiles:
		t.set_selected(false)
		t.set_selection_order(-1)

	_selected_tiles.clear()

	# Select the new tile
	_selected_tiles.append(tile)
	tile.set_selected(true)
	tile.set_selection_order(0)

	selection_changed.emit(get_selected_tiles())


func _toggle_multi(tile: Tile) -> void:
	if tile in _selected_tiles:
		# Deselect this tile
		deselect_tile(tile)
	else:
		# Add to selection
		_selected_tiles.append(tile)
		tile.set_selected(true)
		tile.set_selection_order(_selected_tiles.size() - 1)

		selection_changed.emit(get_selected_tiles())


func _update_selection_orders() -> void:
	for i in _selected_tiles.size():
		_selected_tiles[i].set_selection_order(i)
