extends Node

# TileBag: Generates and provides letter tiles.

signal tiles_drawn(new_tiles)

# Based on Scrabble letter distribution and values.
const LETTER_DISTRIBUTION = {
	"A": {"count": 9, "value": 1}, "B": {"count": 2, "value": 3},
	"C": {"count": 2, "value": 3}, "D": {"count": 4, "value": 2},
	"E": {"count": 12, "value": 1}, "F": {"count": 2, "value": 4},
	"G": {"count": 3, "value": 2}, "H": {"count": 2, "value": 4},
	"I": {"count": 9, "value": 1}, "J": {"count": 1, "value": 8},
	"K": {"count": 1, "value": 5}, "L": {"count": 4, "value": 1},
	"M": {"count": 2, "value": 3}, "N": {"count": 6, "value": 1},
	"O": {"count": 8, "value": 1}, "P": {"count": 2, "value": 3},
	"Q": {"count": 1, "value": 10}, "R": {"count": 6, "value": 1},
	"S": {"count": 4, "value": 1}, "T": {"count": 6, "value": 1},
	"U": {"count": 4, "value": 1}, "V": {"count": 2, "value": 4},
	"W": {"count": 2, "value": 4}, "X": {"count": 1, "value": 8},
	"Y": {"count": 2, "value": 4}, "Z": {"count": 1, "value": 10}
}

var _tile_pool = []

func _ready():
	_initialize_tile_pool()

func _initialize_tile_pool():
	_tile_pool.clear()
	for letter in LETTER_DISTRIBUTION:
		var data = LETTER_DISTRIBUTION[letter]
		for i in range(data["count"]):
			_tile_pool.append(TileModel.new(letter, data["value"]))
	
	_tile_pool.shuffle()

func draw_tiles(count: int):
	var drawn_tiles = []
	for i in range(count):
		# Use Array.is_empty() in Godot 4; `empty()` is not a method on Array
		if _tile_pool.is_empty():
			# TODO: Handle empty tile bag scenario (e.g., end game)
			break
		drawn_tiles.append(_tile_pool.pop_front())
	
	emit_signal("tiles_drawn", drawn_tiles)
	return drawn_tiles

func get_remaining_tile_count() -> int:
	return _tile_pool.size()

# TODO: Add functionality to return tiles to the bag if needed.
