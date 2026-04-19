class_name SelectionState
extends RefCounted

## Immutable value object representing the current selection.
## All mutations return new instances.

enum Mode { SINGLE, MULTI }

var _mode: Mode
var _tile_ids: Array[int]  # Ordered list of selected tile instance IDs

static var _empty: SelectionState = null


static func empty() -> SelectionState:
	if _empty == null:
		_empty = SelectionState.new(Mode.MULTI, [])
	return _empty


func _init(mode: Mode, tile_ids: Array[int]) -> void:
	_mode = mode
	_tile_ids = tile_ids.duplicate()


func get_mode() -> Mode:
	return _mode


func get_tile_ids() -> Array[int]:
	return _tile_ids.duplicate()


func size() -> int:
	return _tile_ids.size()


func is_empty() -> bool:
	return _tile_ids.is_empty()


func is_multi() -> bool:
	return _mode == Mode.MULTI


func has(tile_id: int) -> bool:
	return tile_id in _tile_ids


func get_order(tile_id: int) -> int:
	return _tile_ids.find(tile_id)


# === Immutable Mutations ===

func with_selected(tile_id: int) -> SelectionState:
	if tile_id in _tile_ids:
		return self
	var new_ids: Array[int] = _tile_ids.duplicate()
	new_ids.append(tile_id)
	return SelectionState.new(_mode, new_ids)


func with_deselected(tile_id: int) -> SelectionState:
	if tile_id not in _tile_ids:
		return self
	var new_ids: Array[int] = _tile_ids.duplicate()
	new_ids.erase(tile_id)
	return SelectionState.new(_mode, new_ids)


func with_all_deselected() -> SelectionState:
	if _tile_ids.is_empty():
		return self
	var empty_ids: Array[int] = []
	return SelectionState.new(_mode, empty_ids)


func with_toggled_mode() -> SelectionState:
	var new_mode: Mode = Mode.SINGLE if _mode == Mode.MULTI else Mode.MULTI
	# Switching to SINGLE clears selection
	if new_mode == Mode.SINGLE:
		var empty_ids: Array[int] = []
		return SelectionState.new(new_mode, empty_ids)
	return SelectionState.new(new_mode, _tile_ids)


func with_mode(new_mode: Mode) -> SelectionState:
	if _mode == new_mode:
		return self
	if new_mode == Mode.SINGLE:
		var empty_ids: Array[int] = []
		return SelectionState.new(new_mode, empty_ids)
	return SelectionState.new(new_mode, _tile_ids)
