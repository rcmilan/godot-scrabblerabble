extends Node

## tile pool manager
## handles tile flow -> drawing from bag, shuffling, refilling/refreshing bag after round is over, etc.

var available_tiles: Array[Tile] = []
var tile_scene: PackedScene = preload("res://Scenes/Tile/Tile.tscn")

##points to current bag configuration
var current_distribution: BagDistribution = null


func _ready() -> void:
	print("[TileBag] is ready")
	
func populate_bag(distribution: BagDistribution) -> void:
	if not distribution or not distribution.is_valid():
		push_error("[TileBag] Invalid distribution provided!")
		return
	
	current_distribution = distribution
	available_tiles.clear()
	
	## Creating tiles
	for letter in distribution.distribution.keys():
		var count = distribution.distribution[letter]
		var tile_data_path = "res://Data/TileData/tiles/tile_%s.tres" % letter.to_lower()
		var tile_data = load(tile_data_path) as LetterTileData
		
		if tile_data == null:
			push_error("[TileBag] failed to load the tile data for letter: %s" % letter)
			continue
		
		##Create count tiles for letter
		for i in count:
			var tile = tile_scene.instantiate() as Tile
			tile.initialize(tile_data)
			tile.location = Tile.TileLocation.IN_BAG
			available_tiles.append(tile)
			
	shuffle_bag()
	print("[TileBag] Populated with %d Tiles" % available_tiles.size())

##Shuffle the bag
func shuffle_bag() -> void:
	available_tiles.shuffle()
	
##Draw a tile
func draw_tile() -> Tile:
	if available_tiles.is_empty():
		print("[TileBag] is empty, cannot draw.")
		return null
	
	var tile = available_tiles.pop_back()
	EventBus.tile_drawn.emit(tile)
	print("[TileBag] Drawing Tile: %s (Remaining %d)" % [tile.letter, available_tiles.size()])
	return tile
	
##get count for remaining tiles
func tiles_remaining() -> int:
	return available_tiles.size()
	
##check if bag is empty
func is_empty() -> bool:
	return available_tiles.is_empty()
