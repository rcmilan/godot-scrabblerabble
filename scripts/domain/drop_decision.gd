class_name DropDecision
extends RefCounted

## Immutable value object representing the result of a drop resolution.

enum Action { PLACE, SWAP, REJECT }

var _action: Action
var _target_cells: Array[BoardCell]
var _tiles: Array[Tile]
var _reason: String


func _init(action: Action, target_cells: Array[BoardCell], tiles: Array[Tile], reason: String = "") -> void:
	_action = action
	_target_cells = target_cells
	_tiles = tiles
	_reason = reason


static func place(tiles: Array[Tile], target_cells: Array[BoardCell]) -> DropDecision:
	return DropDecision.new(Action.PLACE, target_cells, tiles)


static func swap(tiles: Array[Tile], target_cells: Array[BoardCell]) -> DropDecision:
	return DropDecision.new(Action.SWAP, target_cells, tiles)


static func reject(tiles: Array[Tile], reason: String = "") -> DropDecision:
	var empty_cells: Array[BoardCell] = []
	return DropDecision.new(Action.REJECT, empty_cells, tiles, reason)


func get_action() -> Action: return _action
func get_target_cells() -> Array[BoardCell]: return _target_cells
func get_tiles() -> Array[Tile]: return _tiles
func get_reason() -> String: return _reason
func is_place() -> bool: return _action == Action.PLACE
func is_swap() -> bool: return _action == Action.SWAP
func is_reject() -> bool: return _action == Action.REJECT
