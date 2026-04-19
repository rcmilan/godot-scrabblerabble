class_name DragSnapshot
extends RefCounted

## Immutable value object representing the current drag operation.

var _is_active: bool
var _lead_tile_id: int
var _tile_ids: Array[int]
var _original_positions: Dictionary  # int (tile_id) → Vector2

static var _inactive: DragSnapshot = null


static func inactive() -> DragSnapshot:
	if _inactive == null:
		var empty_ids: Array[int] = []
		_inactive = DragSnapshot.new(false, -1, empty_ids, {})
	return _inactive


static func active(lead_tile_id: int, tile_ids: Array[int], original_positions: Dictionary) -> DragSnapshot:
	return DragSnapshot.new(true, lead_tile_id, tile_ids, original_positions)


func _init(is_active: bool, lead_tile_id: int, tile_ids: Array[int], original_positions: Dictionary) -> void:
	_is_active = is_active
	_lead_tile_id = lead_tile_id
	_tile_ids = tile_ids.duplicate()
	_original_positions = original_positions.duplicate()


func is_active() -> bool: return _is_active
func get_lead_tile_id() -> int: return _lead_tile_id
func get_tile_ids() -> Array[int]: return _tile_ids.duplicate()
func get_original_positions() -> Dictionary: return _original_positions.duplicate()
func get_tile_count() -> int: return _tile_ids.size()
