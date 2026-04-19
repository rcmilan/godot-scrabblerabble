class_name TileStateChanged
extends DomainEvent

## Emitted when a tile's domain state changes.

var tile_id: int
var old_state: TileState
var new_state: TileState


func _init(p_tile_id: int, p_old_state: TileState, p_new_state: TileState) -> void:
	tile_id = p_tile_id
	old_state = p_old_state
	new_state = p_new_state
