extends Node2D

## Rack class for managing player's tile rack in Scrabble
## Handles tile storage, selection, and visual arrangement
## Design: Uses an array of Tile instances for easy management and visual updates.
## Signals tile selection for external handling (e.g., board placement).

# Signals
signal tile_selected(tile: Node2D)

# Preloads
const TileScene = preload("res://scenes/tile/Tile.tscn")
const TileModel = preload("res://scripts/core/tile_model.gd")

# References
@onready var tile_bag: Node = get_node("/root/TileBag")

# Rack properties
var tiles: Array[Node2D] = []  # Array of Tile instances
var selected_index: int = -1  # Index of currently selected tile (-1 means none)
const TILE_SPACING: int = TILE_SIZE + 10  # Spacing between tiles in pixels
const TILE_SIZE: int = 64     # Size of each tile

func _ready() -> void:
	# Initialize with empty rack
	update_visuals()


## Add a tile to the rack
## tile_model: The TileModel to add
func add_tile(tile_model: TileModel) -> void:
	var tile_instance := TileScene.instantiate()
	tile_instance.set_tile_model(tile_model)
	tile_instance.connect("tile_selected", Callable(self, "_on_tile_selected"))
	add_child(tile_instance)
	tiles.append(tile_instance)
	tile_instance.index = tiles.size() - 1
	update_visuals()

## Remove a tile from the rack at the given index
## index: The index of the tile to remove
## keep_alive: If true, return the tile Node2D without freeing it
## Returns: The TileModel of the removed tile, or the Tile Node2D if keep_alive is true
func remove_tile(index: int, keep_alive: bool = false) -> Variant:
	if index < 0 or index >= tiles.size():
		return null

	var tile: Node2D = tiles[index]
	tiles.remove_at(index)
	if keep_alive:
		print("Removing tile from rack, keeping alive: ", tile.name)
	if not keep_alive:
		tile.queue_free()

	# Adjust selected index if necessary
	if selected_index == index:
		selected_index = -1
		SelectionManager.rack_cursor = -1
	elif selected_index > index:
		selected_index -= 1
		SelectionManager.rack_cursor -= 1

	update_visuals()
	if keep_alive:
		return tile
	else:
		return tile.tile_model

## Refill the rack with n tiles from the tile bag
## n: Number of tiles to draw
func refill(n: int) -> void:
	var drawn_tiles: Array[TileModel] = tile_bag.draw_tiles(n)
	for tile_model in drawn_tiles:
		add_tile(tile_model)

## Get the currently selected tile
## Returns: The selected Tile instance, or null if none selected
func get_selected_tile() -> Node2D:
	if selected_index >= 0 and selected_index < tiles.size():
		return tiles[selected_index]
	return null

## Select the next tile in the rack
func select_next() -> void:
	if tiles.is_empty():
		return
	selected_index = (selected_index + 1) % tiles.size()
	SelectionManager.rack_cursor = selected_index
	update_selection()

## Select the previous tile in the rack
func select_previous() -> void:
	if tiles.is_empty():
		return
	selected_index = (selected_index - 1 + tiles.size()) % tiles.size()
	SelectionManager.rack_cursor = selected_index
	update_selection()

## Get all tile models in the rack
## Returns: Array of TileModel instances
func get_tiles() -> Array[TileModel]:
	var tile_models: Array[TileModel] = []
	for tile in tiles:
		tile_models.append(tile.tile_model)
	return tile_models

## Clear all tiles from the rack
func clear_rack() -> void:
	for tile in tiles:
		tile.queue_free()
	tiles.clear()
	selected_index = -1
	SelectionManager.rack_cursor = -1
	update_visuals()


## Update the visual positions of tiles in a horizontal row
func update_visuals() -> void:
	var effective_spacing = (TILE_SIZE + 10) * get_global_transform().get_scale().x
	for i in range(tiles.size()):
		var tile: Node2D = tiles[i]
		tile.position = Vector2(i * effective_spacing, 0)
	update_selection()

## Update the selection highlight
func update_selection() -> void:
	# Deselect all tiles
	for tile in tiles:
		tile.deselect_tile()

	# Select the current tile
	if selected_index >= 0 and selected_index < tiles.size():
		var selected_tile = tiles[selected_index]
		selected_tile.is_selected = true
		selected_tile.scale = Vector2(1.2, 1.2)
		selected_tile.z_index = 1
		emit_signal("tile_selected", selected_tile)

## Get the number of tiles in the rack
func get_tile_count() -> int:
	return tiles.size()

## Get the tile at the given index
func get_tile_at(index: int) -> Node2D:
	if index >= 0 and index < tiles.size():
		return tiles[index]
	return null

## Highlight the tile at the given index using scale
func highlight_tile(index: int) -> void:
	if index >= 0 and index < tiles.size():
		tiles[index].scale = Vector2(1.2, 1.2)

## Clear all highlights by resetting scale
func clear_highlights() -> void:
	for tile in tiles:
		tile.scale = Vector2(1, 1)

## Handle tile selection from individual tiles
func _on_tile_selected(index: int) -> void:
	selected_index = index
	SelectionManager.rack_cursor = index
	update_selection()

# Placeholder for animations
# TODO: Implement smooth tile addition/removal animations
func _animate_tile_addition(tile: Node2D) -> void:
	pass  # Placeholder: Add tween for slide-in animation

# TODO: Implement smooth tile removal animations
func _animate_tile_removal(tile: Node2D) -> void:
	pass  # Placeholder: Add tween for slide-out animation

# TODO: Implement selection highlight animations
func _animate_selection_change() -> void:
	pass  # Placeholder: Add color transition animations
