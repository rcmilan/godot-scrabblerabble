extends Control

@onready var tile_container = $TileContainer

signal tile_selected(tile)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	

func _on_tile_selected(tile):
	tile_selected.emit(tile)
	
func add_tile(tile: Tile) -> void:
	tile_container.add_child(tile)
	
func remove_tile(tile: Tile) -> void:
	if tile_container.has_node(tile.get_path()):
		tile_container.remove_child(tile)
		
func get_tile_count() -> int:
	return tile_container.get_child_count()
	
func get_tiles() -> Array[Tile]:
	var tiles: Array[Tile] = []
	for child in tile_container.get_children():
		if child is Tile:
			tiles.append(child)
	return tiles
