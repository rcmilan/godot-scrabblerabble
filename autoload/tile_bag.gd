extends Node

## TileBag autoload for managing the pool of tiles in Scrabble
## Provides methods to draw tiles from the bag

# Signal emitted when tiles are drawn, with summary
signal tiles_drawn(drawn_count: int, remaining_count: int)

# Preload TileModel
const TileModel = preload("res://scripts/core/tile_model.gd")

# Available tiles with their counts and point values (simplified Scrabble distribution)
# TODO: Implement proper tile distribution for full Scrabble game
var tile_distribution: Dictionary = {
	"A": {"count": 9, "points": 1},
	"B": {"count": 2, "points": 3},
	"C": {"count": 2, "points": 3},
	"D": {"count": 4, "points": 2},
	"E": {"count": 12, "points": 1},
	"F": {"count": 2, "points": 4},
	"G": {"count": 3, "points": 2},
	"H": {"count": 2, "points": 4},
	"I": {"count": 9, "points": 1},
	"J": {"count": 1, "points": 8},
	"K": {"count": 1, "points": 5},
	"L": {"count": 4, "points": 1},
	"M": {"count": 2, "points": 3},
	"N": {"count": 6, "points": 1},
	"O": {"count": 8, "points": 1},
	"P": {"count": 2, "points": 3},
	"Q": {"count": 1, "points": 10},
	"R": {"count": 6, "points": 1},
	"S": {"count": 4, "points": 1},
	"T": {"count": 6, "points": 1},
	"U": {"count": 4, "points": 1},
	"V": {"count": 2, "points": 4},
	"W": {"count": 2, "points": 4},
	"X": {"count": 1, "points": 8},
	"Y": {"count": 2, "points": 4},
	"Z": {"count": 1, "points": 10},
	"?": {"count": 2, "points": 0}  # Blank tiles
}

# Remaining tiles in the bag
var remaining_tiles: Array[String] = []

func _ready() -> void:
	initialize_bag()

## Initialize the tile bag with all tiles
func initialize_bag() -> void:
	remaining_tiles.clear()
	for letter in tile_distribution.keys():
		for i in range(tile_distribution[letter]["count"]):
			remaining_tiles.append(letter)

## Draw n tiles from the bag
## Returns an array of TileModel instances
func draw_tiles(n: int) -> Array[TileModel]:
	var drawn: Array[TileModel] = []
	for i in range(min(n, remaining_tiles.size())):
		var random_index: int = randi() % remaining_tiles.size()
		var letter: String = remaining_tiles[random_index]
		remaining_tiles.remove_at(random_index)
		var tile_model: TileModel = TileModel.new(letter, tile_distribution[letter]["points"])
		drawn.append(tile_model)
	# Signal completion with summary
	tiles_drawn.emit(drawn.size(), remaining_tiles.size())
	return drawn

## Check if the bag is empty
func is_empty() -> bool:
	return remaining_tiles.is_empty()

## Get remaining tile count
func get_remaining_count() -> int:
	return remaining_tiles.size()