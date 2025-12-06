extends Node

# BoardModel: Data model for the game board.
# Stores the state of the 15x15 grid.

const BOARD_WIDTH = 15
const BOARD_HEIGHT = 15

var _grid = []
var _temp_placements = {} # key: "x,y" -> TileModel for temporary placements this turn
var _placed_positions_this_turn = [] # Array of Vector2i

func _ready():
	_initialize_grid()

func _initialize_grid():
	_grid.resize(BOARD_HEIGHT)
	for y in range(BOARD_HEIGHT):
		_grid[y] = []
		_grid[y].resize(BOARD_WIDTH)
		for x in range(BOARD_WIDTH):
			_grid[y][x] = null

func _pos_key(grid_pos: Vector2i) -> String:
	return str(grid_pos.x) + "," + str(grid_pos.y)

func _key_to_pos(key: String) -> Vector2i:
	var parts = key.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

func place_tile(tile_data, grid_pos: Vector2i, temporary: bool = false) -> bool:
	# If temporary, place into _temp_placements for this turn only.
	if not is_valid_position(grid_pos):
		return false

	var key = _pos_key(grid_pos)
	if temporary:
		# don't allow temp placement on top of a committed tile
		if _grid[grid_pos.y][grid_pos.x] != null:
			return false
		_temp_placements[key] = tile_data
		# track positions placed this turn
		if not _placed_positions_this_turn.has(grid_pos):
			_placed_positions_this_turn.append(grid_pos)
		return true

	# permanent placement: fail if occupied
	if _grid[grid_pos.y][grid_pos.x] != null:
		return false # Position already occupied

	_grid[grid_pos.y][grid_pos.x] = tile_data
	return true

func get_tile(grid_pos: Vector2i):
	if not is_valid_position(grid_pos):
		return null
	return _grid[grid_pos.y][grid_pos.x]

func get_combined_tile(grid_pos: Vector2i):
	# Return the tile at pos, considering temporary placements first
	var key = _pos_key(grid_pos)
	if _temp_placements.has(key):
		return _temp_placements[key]
	return get_tile(grid_pos)

func is_valid_position(grid_pos: Vector2i) -> bool:
	return (grid_pos.x >= 0 and grid_pos.x < BOARD_WIDTH and 
			grid_pos.y >= 0 and grid_pos.y < BOARD_HEIGHT)

func get_grid_state() -> Array:
	return _grid

func get_combined_grid_view() -> Array:
	# Return a lightweight 2D array of tiles (TileModel or null) merging temp placements over committed grid
	var view = []
	view.resize(BOARD_HEIGHT)
	for y in range(BOARD_HEIGHT):
		view[y] = []
		for x in range(BOARD_WIDTH):
			var pos = Vector2i(x, y)
			view[y].append(get_combined_tile(pos))
	return view

func get_temp_positions() -> Array:
	return _placed_positions_this_turn.duplicate()

func remove_temp_tile(grid_pos: Vector2i) -> void:
	var key = _pos_key(grid_pos)
	if _temp_placements.has(key):
		_temp_placements.erase(key)
	# remove from placed positions array
	for i in range(_placed_positions_this_turn.size()-1, -1, -1):
		if _placed_positions_this_turn[i] == grid_pos:
			_placed_positions_this_turn.remove_at(i)

func clear_temp_tiles() -> void:
	_temp_placements.clear()
	_placed_positions_this_turn.clear()

func commit_temp_tiles(turn_id: int) -> void:
	# Move temp placements into the committed grid, mark placement turn on TileModel if available
	for key in _temp_placements.keys():
		var pos = _key_to_pos(key)
		var tile = _temp_placements[key]
		_grid[pos.y][pos.x] = tile
		if typeof(tile) == TYPE_OBJECT and tile.has_method("mark_placed"):
			tile.mark_placed(turn_id)
	clear_temp_tiles()

func get_candidate_ranges_for_positions(positions: Array) -> Array:
	# For each position, scan horizontally and vertically in the combined view and return unique ranges
	var combined = get_combined_grid_view()
	var ranges = []
	var seen = {}

	for pos in positions:
		# horizontal
		var y = pos.y
		var x = pos.x
		var sx = x
		while sx > 0 and combined[y][sx - 1] != null:
			sx -= 1
		var ex = x
		while ex < BOARD_WIDTH - 1 and combined[y][ex + 1] != null:
			ex += 1
		if ex - sx + 1 >= 2:
			var key = str(sx) + ":" + str(y) + "-" + str(ex) + ":" + str(y)
			if not seen.has(key):
				seen[key] = true
				ranges.append({"start": Vector2i(sx, y), "end": Vector2i(ex, y)})

		# vertical
		var sx2 = x
		var sy = pos.y
		var sy_start = sy
		while sy_start > 0 and combined[sy_start - 1][sx2] != null:
			sy_start -= 1
		var sy_end = sy
		while sy_end < BOARD_HEIGHT - 1 and combined[sy_end + 1][sx2] != null:
			sy_end += 1
		if sy_end - sy_start + 1 >= 2:
			var key2 = str(x) + ":" + str(sy_start) + "-" + str(x) + ":" + str(sy_end)
			if not seen.has(key2):
				seen[key2] = true
				ranges.append({"start": Vector2i(x, sy_start), "end": Vector2i(x, sy_end)})

	return ranges

# TODO: Add methods for handling special tiles or board multipliers.
