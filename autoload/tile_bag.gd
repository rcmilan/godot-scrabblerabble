extends Node

## TileBag: Manages the pool of available tiles (the "deck").
## Handles tile creation, shuffling, drawing, and recycling.
## Acts as a factory for Tile instances based on distribution configuration.

# =============================================================================
# RESOURCES
# =============================================================================

const TILE_SCENE_PATH: String = "res://scenes/tile/Tile.tscn"
const TILE_DATA_PATH: String = "res://Data/TileData/tiles/tile_%s.tres"

var _tile_scene: PackedScene = null

# =============================================================================
# STATE
# =============================================================================

var available_tiles: Array[Tile] = []
var drawn_tiles: Array[Tile] = []
var current_distribution: BagDistribution = null
var _initial_count: int = 0


func _ready() -> void:
	_tile_scene = preload(TILE_SCENE_PATH)
	print("[TileBag] Ready")


# =============================================================================
# PUBLIC API: BAG MANAGEMENT
# =============================================================================

## Populates the bag with tiles based on the given distribution.
func populate_bag(distribution: BagDistribution) -> bool:
	if distribution == null or not distribution.is_valid():
		push_error("[TileBag] Invalid distribution provided!")
		return false

	# Clear existing tiles
	_clear_all_tiles()

	current_distribution = distribution

	# Create tiles for each letter
	for letter in distribution.distribution.keys():
		var count: int = distribution.distribution[letter]
		var tile_data: LetterTileData = _load_tile_data(letter)

		if tile_data == null:
			continue

		for i in count:
			var tile: Tile = _create_tile(tile_data)
			if tile:
				available_tiles.append(tile)

	_initial_count = available_tiles.size()
	shuffle_bag()

	print("[TileBag] Populated with %d tiles" % available_tiles.size())
	return true


## Shuffles the available tiles randomly.
func shuffle_bag() -> void:
	available_tiles.shuffle()


## Resets the bag to initial state (returns all drawn tiles).
func reset_bag() -> void:
	for tile in drawn_tiles:
		tile.reset()
		available_tiles.append(tile)

	drawn_tiles.clear()
	shuffle_bag()

	print("[TileBag] Reset - %d tiles available" % available_tiles.size())


# =============================================================================
# PUBLIC API: DRAWING
# =============================================================================

## Draws a single tile from the bag.
func draw_tile() -> Tile:
	if available_tiles.is_empty():
		print("[TileBag] Empty - cannot draw")
		return null

	var tile: Tile = available_tiles.pop_back()
	drawn_tiles.append(tile)

	EventBus.tile_drawn.emit(tile)
	print("[TileBag] Drew: %s | Remaining: %d" % [tile.letter, available_tiles.size()])

	return tile


## Draws multiple tiles from the bag.
func draw_tiles(count: int) -> Array[Tile]:
	var result: Array[Tile] = []

	for i in count:
		var tile: Tile = draw_tile()
		if tile == null:
			break
		result.append(tile)

	return result


## Returns a tile to the bag (for special effects).
func return_tile(tile: Tile) -> void:
	if tile in drawn_tiles:
		drawn_tiles.erase(tile)

	tile.reset()
	available_tiles.append(tile)
	shuffle_bag()

	print("[TileBag] Returned: %s | Available: %d" % [tile.letter, available_tiles.size()])


# =============================================================================
# PUBLIC API: QUERIES
# =============================================================================

## Returns the number of tiles remaining in the bag.
func tiles_remaining() -> int:
	return available_tiles.size()


## Returns true if the bag is empty.
func is_empty() -> bool:
	return available_tiles.is_empty()


## Returns the initial tile count when bag was populated.
func get_initial_count() -> int:
	return _initial_count


## Returns the number of tiles that have been drawn.
func get_drawn_count() -> int:
	return drawn_tiles.size()


## Peeks at the top N tiles without drawing them (for debugging).
func peek_tiles(count: int) -> Array[Tile]:
	var result: Array[Tile] = []
	var peek_count: int = mini(count, available_tiles.size())

	for i in range(available_tiles.size() - peek_count, available_tiles.size()):
		result.append(available_tiles[i])

	return result


# =============================================================================
# PRIVATE: TILE CREATION
# =============================================================================

func _load_tile_data(letter: String) -> LetterTileData:
	var path: String = TILE_DATA_PATH % letter.to_lower()
	var data: LetterTileData = load(path) as LetterTileData

	if data == null:
		push_error("[TileBag] Failed to load tile data: %s" % path)

	return data


func _create_tile(data: LetterTileData) -> Tile:
	if _tile_scene == null:
		push_error("[TileBag] Tile scene not loaded!")
		return null

	var tile: Tile = _tile_scene.instantiate() as Tile
	tile.initialize(data)
	tile.location = Tile.TileLocation.IN_BAG

	return tile


func _clear_all_tiles() -> void:
	for tile in available_tiles:
		tile.queue_free()
	for tile in drawn_tiles:
		tile.queue_free()

	available_tiles.clear()
	drawn_tiles.clear()
	_initial_count = 0
