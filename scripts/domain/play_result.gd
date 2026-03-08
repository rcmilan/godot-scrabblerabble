class_name PlayResult
extends RefCounted

## Immutable value object representing the result of a play validation.

var _words: Array[WordResult]
var _score: int
var _tiles_to_lock: Array[Tile]
var _tiles_to_consume: Array[Tile]
var _is_valid: bool


func _init(
	words: Array[WordResult],
	score: int,
	tiles_to_lock: Array[Tile],
	tiles_to_consume: Array[Tile],
	is_valid: bool
) -> void:
	_words = words
	_score = score
	_tiles_to_lock = tiles_to_lock
	_tiles_to_consume = tiles_to_consume
	_is_valid = is_valid


static func valid(
	words: Array[WordResult],
	score: int,
	tiles_to_lock: Array[Tile],
	tiles_to_consume: Array[Tile]
) -> PlayResult:
	return PlayResult.new(words, score, tiles_to_lock, tiles_to_consume, true)


static func invalid() -> PlayResult:
	var empty_words: Array[WordResult] = []
	var empty_tiles: Array[Tile] = []
	return PlayResult.new(empty_words, 0, empty_tiles, empty_tiles, false)


func is_valid() -> bool: return _is_valid
func get_words() -> Array[WordResult]: return _words
func get_score() -> int: return _score
func get_tiles_to_lock() -> Array[Tile]: return _tiles_to_lock
func get_tiles_to_consume() -> Array[Tile]: return _tiles_to_consume
