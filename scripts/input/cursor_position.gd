# scripts/input/cursor_position.gd
class_name CursorPosition
extends RefCounted

enum Zone { HAND, BOARD }

var zone: Zone           = Zone.HAND
var hand_index: int      = 0
var board_coords: Vector2i = Vector2i.ZERO


## Factory: position in hand zone.
static func hand(index: int) -> CursorPosition:
	var p := CursorPosition.new()
	p.zone = Zone.HAND
	p.hand_index = index
	return p


## Factory: position in board zone.
static func board(coords: Vector2i) -> CursorPosition:
	var p := CursorPosition.new()
	p.zone = Zone.BOARD
	p.board_coords = coords
	return p


func is_hand()  -> bool: return zone == Zone.HAND
func is_board() -> bool: return zone == Zone.BOARD
