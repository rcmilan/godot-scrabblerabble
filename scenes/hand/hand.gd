extends Control
class_name Hand

## Player's hand containing tiles available for placement.
## Supports single and multi-select operations.
## Provides methods for tile management and selection queries.

# === Signals ===
signal tile_added(tile: Tile)
signal tile_removed(tile: Tile)
signal selection_changed(selected_tiles: Array[Tile])
signal hand_empty()

# === Configuration ===
@export var max_hand_size: int = 10

# === Node References ===
@onready var tile_container: HBoxContainer = $TileContainer

# === State ===
var _selected_tiles: Array[Tile] = []


func _ready() -> void:
	pass


# === Public API: Tile Management ===

## Adds a tile to the hand.
func add_tile(tile: Tile) -> bool:
	if get_tile_count() >= max_hand_size:
		push_warning("[Hand] Cannot add tile - hand is full")
		return false

	tile_container.add_child(tile)
	tile.location = Tile.TileLocation.IN_HAND
	tile_added.emit(tile)
	return true


## Removes a specific tile from the hand.
func remove_tile(tile: Tile) -> bool:
	if not _has_tile(tile):
		return false

	# Deselect if selected
	if tile in _selected_tiles:
		_selected_tiles.erase(tile)
		selection_changed.emit(_selected_tiles)

	tile_container.remove_child(tile)
	tile_removed.emit(tile)

	if is_empty():
		hand_empty.emit()

	return true


## Removes and returns all tiles from the hand.
func clear_hand() -> Array[Tile]:
	var tiles: Array[Tile] = get_tiles()
	for tile in tiles:
		tile_container.remove_child(tile)

	_selected_tiles.clear()
	selection_changed.emit(_selected_tiles)
	hand_empty.emit()

	return tiles


# === Public API: Selection ===

## Selects a single tile, deselecting others.
func select_tile(tile: Tile) -> void:
	if not _has_tile(tile):
		return

	# Deselect all others
	for t in _selected_tiles:
		t.set_selected(false)

	_selected_tiles.clear()
	_selected_tiles.append(tile)
	tile.set_selected(true)

	selection_changed.emit(_selected_tiles)


## Toggles selection state of a tile (for multi-select).
func toggle_tile_selection(tile: Tile) -> void:
	if not _has_tile(tile):
		return

	if tile in _selected_tiles:
		_selected_tiles.erase(tile)
		tile.set_selected(false)
	else:
		_selected_tiles.append(tile)
		tile.set_selected(true)

	selection_changed.emit(_selected_tiles)


## Deselects all tiles.
func deselect_all() -> void:
	for tile in _selected_tiles:
		tile.set_selected(false)

	_selected_tiles.clear()
	selection_changed.emit(_selected_tiles)


## Selects all tiles in the hand.
func select_all() -> void:
	_selected_tiles.clear()
	for tile in get_tiles():
		tile.set_selected(true)
		_selected_tiles.append(tile)

	selection_changed.emit(_selected_tiles)


## Returns currently selected tiles.
func get_selected_tiles() -> Array[Tile]:
	return _selected_tiles.duplicate()


## Returns true if any tiles are selected.
func has_selection() -> bool:
	return not _selected_tiles.is_empty()


# === Public API: Queries ===

## Returns the number of tiles in hand.
func get_tile_count() -> int:
	return tile_container.get_child_count()


## Returns all tiles in the hand.
func get_tiles() -> Array[Tile]:
	var tiles: Array[Tile] = []
	for child in tile_container.get_children():
		if child is Tile:
			tiles.append(child)
	return tiles


## Returns true if the hand is empty.
func is_empty() -> bool:
	return get_tile_count() == 0


## Returns true if the hand is at max capacity.
func is_full() -> bool:
	return get_tile_count() >= max_hand_size


## Returns remaining space in hand.
func get_available_space() -> int:
	return max_hand_size - get_tile_count()


## Returns a tile by index, or null if out of range.
func get_tile_at(index: int) -> Tile:
	if index < 0 or index >= get_tile_count():
		return null
	var child: Node = tile_container.get_child(index)
	return child as Tile if child is Tile else null


## Finds a tile by letter, or null if not found.
func find_tile_by_letter(letter: String) -> Tile:
	for tile in get_tiles():
		if tile.letter == letter:
			return tile
	return null


## Returns all tiles matching a letter.
func find_tiles_by_letter(letter: String) -> Array[Tile]:
	var result: Array[Tile] = []
	for tile in get_tiles():
		if tile.letter == letter:
			result.append(tile)
	return result


# === Private Helpers ===

func _has_tile(tile: Tile) -> bool:
	return tile.get_parent() == tile_container
