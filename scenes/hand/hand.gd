extends Control
class_name Hand

## Player's hand containing tiles available for placement.
## Supports single and multi-select operations.
## Provides methods for tile management and selection queries.

# === Signals ===
signal tile_added(tile: Tile)
signal tile_removed(tile: Tile)
signal hand_empty()

# === Dependencies ===
var _selection: SelectionManager = null

# === Layout ===
var _fan_layout: HandFanLayout = null

# === Node References ===
@onready var tile_container: Control = $TileContainer


func _ready() -> void:
	_fan_layout = HandFanLayout.new()
	_fan_layout.setup(tile_container)
	tile_container.child_order_changed.connect(_on_tile_order_changed)
	tile_container.resized.connect(_on_tile_order_changed)


## Sets the SelectionManager reference (injected by Main).
func set_selection_manager(sm: SelectionManager) -> void:
	_selection = sm


## Returns the HandFanLayout instance for this hand.
func get_fan_layout() -> HandFanLayout:
	return _fan_layout


# === Public API: Tile Management ===

## Adds a tile to the hand.
func add_tile(tile: Tile) -> bool:
	tile_container.add_child(tile)
	tile.location = Tile.TileLocation.IN_HAND
	tile_added.emit(tile)
	return true


## Removes a specific tile from the hand.
func remove_tile(tile: Tile) -> bool:
	if not _has_tile(tile):
		return false

	# Deselect if selected (via SelectionManager)
	if _selection:
		_selection.deselect_tile(tile)

	tile_container.remove_child(tile)
	tile_removed.emit(tile)

	if is_empty():
		hand_empty.emit()

	return true


## Removes and returns all tiles from the hand.
func clear_hand() -> Array[Tile]:
	var tiles: Array[Tile] = get_tiles()

	# Deselect tiles that are in hand
	for tile in tiles:
		if _selection:
			_selection.deselect_tile(tile)
		tile_container.remove_child(tile)

	hand_empty.emit()

	return tiles


# === Public API: Selection (delegates to SelectionManager) ===

## Selects a tile (mode-aware via SelectionManager).
func select_tile(tile: Tile) -> void:
	if not _has_tile(tile) or not _selection:
		return
	_selection.select_tile(tile)


## Toggles selection state of a tile (for multi-select).
func toggle_tile_selection(tile: Tile) -> void:
	if not _has_tile(tile) or not _selection:
		return
	# In multi-select mode, SelectionManager.select_tile toggles
	_selection.select_tile(tile)


## Deselects all tiles.
func deselect_all() -> void:
	if _selection:
		_selection.deselect_all()


## Selects all tiles in the hand.
func select_all() -> void:
	if not _selection:
		return
	for tile in get_tiles():
		_selection.select_tile(tile)


## Returns currently selected tiles that are in this hand.
func get_selected_tiles() -> Array[Tile]:
	if not _selection:
		return []
	var all_selected: Array[Tile] = _selection.get_selected_tiles()
	var in_hand: Array[Tile] = []
	for tile in all_selected:
		if _has_tile(tile):
			in_hand.append(tile)
	return in_hand


## Returns true if any tiles in hand are selected.
func has_selection() -> bool:
	return not get_selected_tiles().is_empty()


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


## Reorders tiles in the hand based on a comparator callable.
## The comparator should return true if tile_i should come after tile_j.
func sort_tiles(comparator: Callable) -> void:
	for i in range(get_child_count()):
		for j in range(i + 1, get_child_count()):
			var tile_i = get_child(i)
			var tile_j = get_child(j)
			if comparator.call(tile_i, tile_j):
				move_child(tile_j, i)
	_on_tile_order_changed()


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


func _on_tile_order_changed() -> void:
	if _fan_layout:
		_fan_layout.update_layout()
