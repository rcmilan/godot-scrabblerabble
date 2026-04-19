extends Node

## TileBag: Manages the pool of available tiles (the "deck").
## Handles tile creation, shuffling, drawing, and recycling.
## Acts as a factory for Tile instances based on distribution configuration.

# =============================================================================
# RESOURCES
# =============================================================================

const TILE_SCENE_PATH: String = "res://scenes/tile/tile.tscn"
const TILE_DATA_PATH: String = "res://data/tile_data/tiles/tile_%s.tres"

var _tile_scene: PackedScene = null

# =============================================================================
# STATE
# =============================================================================

var _available_tiles: Array[Tile] = []
var _drawn_tiles: Array[Tile] = []
var _current_distribution: BagDistribution = null
var _initial_count: int = 0


func get_available_tiles() -> Array[Tile]:
	return _available_tiles.duplicate()

func get_drawn_tiles() -> Array[Tile]:
	return _drawn_tiles.duplicate()

func get_current_distribution() -> BagDistribution:
	return _current_distribution


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

	_clear_all_tiles()
	_current_distribution = distribution

	for letter in distribution.distribution.keys():
		var count: int = distribution.distribution[letter]
		var tile_data: LetterTileData = _load_tile_data(letter)

		if tile_data == null:
			continue

		for i in count:
			var tile: Tile = _create_tile(tile_data)
			if tile:
				_available_tiles.append(tile)

	_initial_count = _available_tiles.size()
	shuffle_bag()

	print("[TileBag] Populated with %d tiles" % _available_tiles.size())
	return true


## Shuffles the available tiles randomly.
func shuffle_bag() -> void:
	_available_tiles.shuffle()


## Resets the bag to initial state (returns all drawn tiles).
func reset_bag() -> void:
	for tile in _drawn_tiles:
		tile.reset()
		_available_tiles.append(tile)

	_drawn_tiles.clear()
	shuffle_bag()

	print("[TileBag] Reset - %d tiles available" % _available_tiles.size())


# =============================================================================
# PUBLIC API: DRAWING
# =============================================================================

## Draws a single tile from the bag.
func draw_tile() -> Tile:
	if _available_tiles.is_empty():
		print("[TileBag] Empty - cannot draw")
		return null

	var tile: Tile = _available_tiles.pop_back()
	_drawn_tiles.append(tile)

	EventBus.tile_drawn.emit(tile)
	print("[TileBag] Drew: %s | Remaining: %d" % [tile.letter, _available_tiles.size()])

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


## Resets bag for a new round: returns all drawn tiles (preserving permanent modifiers) and reshuffles.
## Use this between rounds instead of populate_bag to preserve tile identity and modifiers.
func reshuffle_for_round() -> void:
	var skipped: int = 0
	for tile in _drawn_tiles:
		if not is_instance_valid(tile):
			skipped += 1
			continue
		if tile.get_parent():
			tile.get_parent().remove_child(tile)
		tile.reset()
		_available_tiles.append(tile)
	_drawn_tiles.clear()
	shuffle_bag()
	if skipped > 0:
		push_warning("[TileBag] reshuffle_for_round: skipped %d freed tile(s)" % skipped)
	print("[TileBag] Reshuffled for new round - %d tiles available" % _available_tiles.size())


## Returns a tile to the bag (for special effects).
func return_tile(tile: Tile) -> void:
	if tile in _drawn_tiles:
		_drawn_tiles.erase(tile)

	tile.reset()
	_available_tiles.append(tile)
	shuffle_bag()

	print("[TileBag] Returned: %s | Available: %d" % [tile.letter, _available_tiles.size()])


# =============================================================================
# PUBLIC API: QUERIES
# =============================================================================

## Returns the number of tiles remaining in the bag.
func tiles_remaining() -> int:
	return _available_tiles.size()


## Returns true if the bag is empty.
func is_empty() -> bool:
	return _available_tiles.is_empty()


## Returns the initial tile count when bag was populated.
func get_initial_count() -> int:
	return _initial_count


## Returns the number of tiles that have been drawn.
func get_drawn_count() -> int:
	return _drawn_tiles.size()


## Peeks at the top N tiles without drawing them (for debugging).
func peek_tiles(count: int) -> Array[Tile]:
	var result: Array[Tile] = []
	var peek_count: int = mini(count, _available_tiles.size())

	for i in range(_available_tiles.size() - peek_count, _available_tiles.size()):
		result.append(_available_tiles[i])

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
	for tile in _available_tiles:
		if is_instance_valid(tile):
			tile.queue_free()
	for tile in _drawn_tiles:
		if is_instance_valid(tile):
			tile.queue_free()

	_available_tiles.clear()
	_drawn_tiles.clear()
	_initial_count = 0
