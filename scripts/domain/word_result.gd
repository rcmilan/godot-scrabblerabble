class_name WordResult
extends RefCounted

## Immutable value object representing a scored word from a play.

var _word: String
var _positions: Array[Vector2i]
var _tile_scores: Array[int]
var _total: int
var _direction: String


func _init(
	word: String,
	positions: Array[Vector2i],
	tile_scores: Array[int],
	total: int,
	direction: String
) -> void:
	_word = word
	_positions = positions
	_tile_scores = tile_scores
	_total = total
	_direction = direction


func get_word() -> String: return _word
func get_positions() -> Array[Vector2i]: return _positions
func get_tile_scores() -> Array[int]: return _tile_scores
func get_total() -> int: return _total
func get_direction() -> String: return _direction
