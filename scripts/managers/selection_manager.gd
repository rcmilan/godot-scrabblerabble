extends Node
class_name SelectionManager

## SelectionManager: Central source of truth for tile selection state and mode.
## Manages single/multi-select modes and maintains ordered selection.
## Internal state managed via immutable SelectionState value object.
## Created as a local node by Main and injected into consumers via setup().

# =============================================================================
# SIGNALS
# =============================================================================

signal mode_changed(is_multi: bool)
signal selection_changed(selected_tiles: Array)

# =============================================================================
# ENUMS (backward compat aliases)
# =============================================================================

enum SelectionMode {
	SINGLE,
	MULTI
}

# =============================================================================
# STATE
# =============================================================================

var _state: SelectionState = SelectionState.empty()
var _tile_lookup: Dictionary = {}  # int (instance_id) → Tile

## Backward-compat: mode as public readable property
var mode: SelectionMode:
	get: return SelectionMode.SINGLE if _state.get_mode() == SelectionState.Mode.SINGLE else SelectionMode.MULTI

# =============================================================================
# MODE MANAGEMENT
# =============================================================================

func toggle_mode() -> void:
	var new_state: SelectionState = _state.with_toggled_mode()
	_apply_state(new_state)
	mode_changed.emit(is_multi_select_enabled())


func set_mode(new_mode: SelectionMode) -> void:
	var target: SelectionState.Mode = SelectionState.Mode.SINGLE if new_mode == SelectionMode.SINGLE else SelectionState.Mode.MULTI
	var new_state: SelectionState = _state.with_mode(target)
	if new_state == _state:
		return
	_apply_state(new_state)
	mode_changed.emit(is_multi_select_enabled())


func is_multi_select_enabled() -> bool:
	return _state.is_multi()

# =============================================================================
# SELECTION OPERATIONS
# =============================================================================

func select_tile(tile: Tile) -> void:
	if tile == null:
		return

	_tile_lookup[tile.get_instance_id()] = tile

	match _state.get_mode():
		SelectionState.Mode.SINGLE:
			_select_single(tile)
		SelectionState.Mode.MULTI:
			_toggle_multi(tile)


func deselect_tile(tile: Tile) -> void:
	if tile == null:
		return
	var tid: int = tile.get_instance_id()
	if not _state.has(tid):
		return

	var new_state: SelectionState = _state.with_deselected(tid)
	tile.set_selected(false)
	tile.set_selection_order(-1)
	_apply_state(new_state)
	_sync_tile_orders()
	selection_changed.emit(get_selected_tiles())


func deselect_all() -> void:
	for tid in _state.get_tile_ids():
		var tile: Tile = _tile_lookup.get(tid)
		if tile and is_instance_valid(tile):
			tile.set_selected(false)
			tile.set_selection_order(-1)

	_apply_state(_state.with_all_deselected())
	selection_changed.emit([])


func get_selected_tiles() -> Array[Tile]:
	var valid_tiles: Array[Tile] = []
	for tid in _state.get_tile_ids():
		var tile: Tile = _tile_lookup.get(tid)
		if tile and is_instance_valid(tile):
			valid_tiles.append(tile)
	return valid_tiles


func get_selection_count() -> int:
	return get_selected_tiles().size()


func get_tile_order(tile: Tile) -> int:
	if tile == null:
		return -1
	return _state.get_order(tile.get_instance_id())


func has_selection() -> bool:
	return not _state.is_empty()


## Returns the current SelectionState value object.
func get_state() -> SelectionState:
	return _state

# =============================================================================
# PRIVATE HELPERS
# =============================================================================

func _select_single(tile: Tile) -> void:
	var tid: int = tile.get_instance_id()
	if _state.has(tid):
		deselect_tile(tile)
		return

	# Deselect all others
	for old_tid in _state.get_tile_ids():
		var old_tile: Tile = _tile_lookup.get(old_tid)
		if old_tile and is_instance_valid(old_tile):
			old_tile.set_selected(false)
			old_tile.set_selection_order(-1)

	var empty_ids: Array[int] = []
	var new_state: SelectionState = SelectionState.new(_state.get_mode(), empty_ids)
	new_state = new_state.with_selected(tid)

	tile.set_selected(true)
	tile.set_selection_order(0)

	_apply_state(new_state)
	selection_changed.emit(get_selected_tiles())


func _toggle_multi(tile: Tile) -> void:
	var tid: int = tile.get_instance_id()
	if _state.has(tid):
		deselect_tile(tile)
	else:
		var new_state: SelectionState = _state.with_selected(tid)
		tile.set_selected(true)
		tile.set_selection_order(new_state.size() - 1)
		_apply_state(new_state)
		selection_changed.emit(get_selected_tiles())


func _apply_state(new_state: SelectionState) -> void:
	_state = new_state


func _sync_tile_orders() -> void:
	var ids: Array[int] = _state.get_tile_ids()
	for i in ids.size():
		var tile: Tile = _tile_lookup.get(ids[i])
		if tile and is_instance_valid(tile):
			tile.set_selection_order(i)
