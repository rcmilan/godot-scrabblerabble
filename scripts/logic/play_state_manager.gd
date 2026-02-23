extends RefCounted
class_name PlayStateManager

## PlayStateManager: Tracks tile placement state with a fast grid cache.
## Separates temporary (current turn) from permanent (locked) tiles
## and provides O(1) tile lookups by grid position.
##
## BoardCell remains the visual source of truth; this is a logic-side mirror
## that enables efficient word finding without scanning every cell.

# =============================================================================
# CONFIGURATION
# =============================================================================

var _rows: int = 0
var _cols: int = 0

# =============================================================================
# STATE
# =============================================================================

## Fast grid cache: _grid[row][col] = Tile or null
## Combines both temporary and permanent tiles for O(1) lookup.
var _grid: Array[Array] = []

## Tiles placed THIS turn (not yet committed/locked).
## Key: Vector2i(col, row), Value: Tile
var _temporary_tiles: Dictionary = {}

## Tiles committed in PREVIOUS turns (locked on board).
## Key: Vector2i(col, row), Value: Tile
var _permanent_tiles: Dictionary = {}


# =============================================================================
# PUBLIC API: INITIALIZATION
# =============================================================================

## Initializes the grid cache to match the board dimensions.
## Call once when the board is ready.
func initialize_grid(rows: int, cols: int) -> void:
	_rows = rows
	_cols = cols
	_grid = []

	for row in range(rows):
		var row_array: Array = []
		row_array.resize(cols)
		row_array.fill(null)
		_grid.append(row_array)

	_temporary_tiles.clear()
	_permanent_tiles.clear()

	print("[PlayStateManager] Initialized %dx%d grid" % [rows, cols])


# =============================================================================
# PUBLIC API: TEMPORARY TILE OPERATIONS
# =============================================================================

## Records a tile placed on the board this turn.
## pos uses Vector2i(col, row) to match BoardCell.grid_position convention.
func place_temporary_tile(tile: Tile, pos: Vector2i) -> void:
	if not _is_valid_position(pos):
		push_error("[PlayStateManager] Invalid position: %s" % pos)
		return

	var row: int = pos.y
	var col: int = pos.x

	_grid[row][col] = tile
	_temporary_tiles[pos] = tile


## Removes a temporary tile from the grid cache.
## Returns the removed Tile, or null if no temporary tile at that position.
func remove_temporary_tile(pos: Vector2i) -> Tile:
	if not _temporary_tiles.has(pos):
		return null

	var tile: Tile = _temporary_tiles[pos]
	_temporary_tiles.erase(pos)
	_grid[pos.y][pos.x] = null

	return tile


## Removes ANY tile (temporary or permanent) from the grid cache.
## Checks temporary first, then permanent. Returns the removed Tile or null.
## Use this when the tile state is uncertain (e.g., moving a tile that may
## have been committed in a previous turn).
func remove_tile_at(pos: Vector2i) -> Tile:
	if not _is_valid_position(pos):
		return null

	# Try temporary first (most common case)
	if _temporary_tiles.has(pos):
		return remove_temporary_tile(pos)

	# Try permanent
	if _permanent_tiles.has(pos):
		var tile: Tile = _permanent_tiles[pos]
		_permanent_tiles.erase(pos)
		_grid[pos.y][pos.x] = null
		return tile

	# Grid might have a stale reference — clear it defensively
	if _grid[pos.y][pos.x] != null:
		push_warning("[PlayStateManager] Grid had tile at %s not tracked in temp/perm dicts" % pos)
		var tile: Tile = _grid[pos.y][pos.x]
		_grid[pos.y][pos.x] = null
		return tile

	return null


## Locks all temporary tiles as permanent (end of turn).
## Returns the array of committed tiles.
func commit_temporary_tiles() -> Array[Tile]:
	var committed: Array[Tile] = []

	for pos in _temporary_tiles:
		var tile: Tile = _temporary_tiles[pos]
		_permanent_tiles[pos] = tile
		committed.append(tile)

	_temporary_tiles.clear()
	return committed


## Cancels all temporary placements and removes them from the grid cache.
## Returns the array of cancelled tiles (caller is responsible for
## returning them to hand or wherever they belong).
func clear_temporary_tiles() -> Array[Tile]:
	var cancelled: Array[Tile] = []

	for pos in _temporary_tiles:
		var tile: Tile = _temporary_tiles[pos]
		_grid[pos.y][pos.x] = null
		cancelled.append(tile)

	_temporary_tiles.clear()
	return cancelled


# =============================================================================
# PUBLIC API: QUERIES
# =============================================================================

## Returns the tile at a grid position, or null.
## Checks both temporary and permanent tiles (via grid cache).
func get_tile_at(pos: Vector2i) -> Tile:
	if not _is_valid_position(pos):
		return null
	return _grid[pos.y][pos.x]


## Returns the full grid cache (combined temp + permanent).
## This is a reference to the internal array — do NOT modify it.
func get_grid() -> Array[Array]:
	return _grid


## Returns all temporary tile positions as an array.
func get_temporary_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for pos in _temporary_tiles:
		positions.append(pos)
	return positions


## Returns all temporary tiles as an array.
func get_temporary_tiles() -> Array[Tile]:
	var tiles: Array[Tile] = []
	for tile in _temporary_tiles.values():
		tiles.append(tile)
	return tiles


## Returns true if there are any temporary (unplayed) tiles.
func has_temporary_tiles() -> bool:
	return not _temporary_tiles.is_empty()


## Returns the count of temporary tiles.
func get_temporary_count() -> int:
	return _temporary_tiles.size()


## Returns true if the position holds a temporary tile.
func is_temporary(pos: Vector2i) -> bool:
	return _temporary_tiles.has(pos)


## Returns true if the position holds a permanent tile.
func is_permanent(pos: Vector2i) -> bool:
	return _permanent_tiles.has(pos)


# =============================================================================
# PRIVATE
# =============================================================================

func _is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < _cols and pos.y >= 0 and pos.y < _rows
