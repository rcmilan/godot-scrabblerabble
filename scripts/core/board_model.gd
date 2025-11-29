extends Node
class_name BoardModel

# BoardModel manages the game board logic for ScrabbleRabble.
# It handles a 15x15 grid, tile placement, and word detection.
# Architecture: This is a pure logic class, separated from visuals.
# The board controller (scenes/board/board.gd) will use this for game logic.

const BOARD_SIZE: int = 15

# The grid is a 2D array: grid[x][y] = TileModel or null
var grid: Array[Array] = []

# Permanent tiles are those placed and confirmed across turns
var permanent_grid: Array[Array] = []

func _init() -> void:
	# Initialize the grid with null values
	for x in range(BOARD_SIZE):
		grid.append([])
		permanent_grid.append([])
		for y in range(BOARD_SIZE):
			grid[x].append(null)
			permanent_grid[x].append(false)

# Places a tile at the given grid position if valid and empty.
# Returns true if placement succeeded, false otherwise.
func place_tile(tile: TileModel, grid_pos: Vector2i) -> bool:
	print("BoardModel place_tile at ", grid_pos, " tile letter ", tile.letter if tile else "null")
	if not _is_valid_position(grid_pos):
		print("Invalid position")
		return false
	if grid[grid_pos.x][grid_pos.y] != null:
		print("Position occupied")
		return false
	grid[grid_pos.x][grid_pos.y] = tile
	print("Tile placed successfully")
	return true

# Removes a tile from the given grid position if it exists.
# Returns true if removal succeeded, false otherwise.
func remove_tile(grid_pos: Vector2i) -> bool:
	if not _is_valid_position(grid_pos):
		return false
	if grid[grid_pos.x][grid_pos.y] == null:
		return false
	grid[grid_pos.x][grid_pos.y] = null
	return true

# Checks if the position is within the board bounds.
func _is_valid_position(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < BOARD_SIZE and pos.y >= 0 and pos.y < BOARD_SIZE

# Returns all words currently formed on the board.
# Each word is a dictionary: {"word": String, "positions": Array[Vector2i]}
func get_all_words() -> Array:
	var words: Array = []
	# Scan rows
	for y in range(BOARD_SIZE):
		var current_word: String = ""
		var current_positions: Array[Vector2i] = []
		for x in range(BOARD_SIZE):
			var tile = grid[x][y]
			if tile != null:
				current_word += tile.letter
				current_positions.append(Vector2i(x, y))
			else:
				if current_word.length() >= 2:
					words.append({"word": current_word, "positions": current_positions})
				current_word = ""
				current_positions = []
		if current_word.length() >= 2:
			words.append({"word": current_word, "positions": current_positions})
	
	# Scan columns
	for x in range(BOARD_SIZE):
		var current_word: String = ""
		var current_positions: Array[Vector2i] = []
		for y in range(BOARD_SIZE):
			var tile = grid[x][y]
			if tile != null:
				current_word += tile.letter
				current_positions.append(Vector2i(x, y))
			else:
				if current_word.length() >= 2:
					words.append({"word": current_word, "positions": current_positions})
				current_word = ""
				current_positions = []
		if current_word.length() >= 2:
			words.append({"word": current_word, "positions": current_positions})
	
	return words

# Marks all currently placed tiles as permanent (after a turn ends).
func commit_tiles() -> void:
	for x in range(BOARD_SIZE):
		for y in range(BOARD_SIZE):
			if grid[x][y] != null:
				permanent_grid[x][y] = true

# Clears non-permanent tiles (for turn reset or something).
func clear_temporary_tiles() -> void:
	for x in range(BOARD_SIZE):
		for y in range(BOARD_SIZE):
			if not permanent_grid[x][y]:
				grid[x][y] = null

# TODO: Add support for special tiles (e.g., double letter, triple word).
# This could involve a separate grid for multipliers or extending TileModel.

# TODO: Implement board initialization with special squares (e.g., center star, premium squares).
# For now, all squares are equal.

# TODO: Add method to check if placement creates valid cross-words.