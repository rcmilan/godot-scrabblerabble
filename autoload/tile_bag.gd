extends Node

# TileBag: Generates and provides letter tiles.
# Tracks both the active tile pool and discarded tiles for round-based gameplay.

signal tiles_drawn(new_tiles)
signal tiles_discarded(discarded_tiles)
signal hand_refilled(refill_count)
signal rack_count_changed(total_count)

# Letter distribution: vowels (A,E,I,O,U) = 3 copies, common letters = 2 copies, high-point letters = 1 copy
# Point values remain standard Scrabble-like scoring
const LETTER_DISTRIBUTION = {
	"A": {"value": 1, "count": 3}, "B": {"value": 3, "count": 2}, "C": {"value": 3, "count": 2}, "D": {"value": 2, "count": 2},
	"E": {"value": 1, "count": 3}, "F": {"value": 4, "count": 2}, "G": {"value": 2, "count": 2}, "H": {"value": 4, "count": 2},
	"I": {"value": 1, "count": 3}, "J": {"value": 8, "count": 1}, "K": {"value": 5, "count": 1}, "L": {"value": 1, "count": 2},
	"M": {"value": 3, "count": 2}, "N": {"value": 1, "count": 2}, "O": {"value": 1, "count": 3}, "P": {"value": 3, "count": 2},
	"Q": {"value": 10, "count": 1}, "R": {"value": 1, "count": 2}, "S": {"value": 1, "count": 2}, "T": {"value": 1, "count": 2},
	"U": {"value": 1, "count": 3}, "V": {"value": 4, "count": 1}, "W": {"value": 4, "count": 1}, "X": {"value": 8, "count": 1},
	"Y": {"value": 4, "count": 2}, "Z": {"value": 10, "count": 1}
}

var _tile_pool = []
var _discarded_tiles = []  # Tiles that have been discarded this round

func _ready():
	_initialize_tile_pool()

func _initialize_tile_pool():
	_tile_pool.clear()
	# Create tiles based on distribution: vowels (3), common letters (2), high-point letters (1)
	for letter in LETTER_DISTRIBUTION:
		var data = LETTER_DISTRIBUTION[letter]
		var count = data.get("count", 1)
		for i in range(count):
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
	emit_signal("rack_count_changed", _tile_pool.size())
	return drawn_tiles


func return_tiles(tiles: Array) -> void:
	# Return an array of TileModel instances back into the pool and reshuffle.
	for t in tiles:
		if t != null:
			_tile_pool.append(t)
	_tile_pool.shuffle()
	emit_signal("rack_count_changed", _tile_pool.size())

func discard_tiles(tiles: Array) -> void:
	# Discard tiles - they go to discard pile, not back to the active pool.
	# Discarded tiles are removed from play for the current round.
	for t in tiles:
		if t != null:
			_discarded_tiles.append(t)
	emit_signal("tiles_discarded", tiles)
	print("[tile_bag] Discarded ", tiles.size(), " tiles. Discard pile: ", _discarded_tiles.size())

func get_remaining_tile_count() -> int:
	return _tile_pool.size()

func get_discarded_tile_count() -> int:
	return _discarded_tiles.size()

func get_tile_counts_by_letter() -> Dictionary:
	# Returns a dictionary with letter counts currently in the rack (tile pool)
	var counts = {}
	for tile in _tile_pool:
		if tile and tile.letter:
			if not counts.has(tile.letter):
				counts[tile.letter] = 0
			counts[tile.letter] += 1
	return counts

func reset_round() -> void:
	# Reset for a new round: return discarded tiles to pool and reinitialize.
	print("[tile_bag] Resetting round. Returning ", _discarded_tiles.size(), " discarded tiles to pool.")
	# Return discarded tiles to the pool before reinitializing
	for t in _discarded_tiles:
		if t != null:
			_tile_pool.append(t)
	_discarded_tiles.clear()
	_initialize_tile_pool()
	emit_signal("rack_count_changed", _tile_pool.size())
