extends Node
class_name WordFinder

## WordFinder is responsible for scanning the board and identifying valid words.
## It scans horizontally (rows) and vertically (columns) for consecutive tiles forming words.
## Words must be at least 2 letters long. Diagonals are not supported yet.

# Signal emitted when word finding is complete, with the found words and a summary.
signal words_found(words: Array[Dictionary], summary: String)

# The board size constant, matching BoardModel
const BOARD_SIZE: int = 15

## Finds all words on the given board model.
## Scans each row and column for consecutive non-empty tiles.
## Returns an array of dictionaries, each containing "word": String and "positions": Array[Vector2i].
## Emits words_found signal with the results and a summary.
func find_words(board_model: BoardModel) -> Array[Dictionary]:
	var words: Array[Dictionary] = []
	
	# Scan rows for horizontal words
	for y: int in range(BOARD_SIZE):
		var current_word: String = ""
		var current_positions: Array[Vector2i] = []
		for x: int in range(BOARD_SIZE):
			var tile: TileModel = board_model.grid[x][y]
			if tile != null and not tile.is_blank():
				current_word += tile.letter
				current_positions.append(Vector2i(x, y))
			else:
				# End of word, check if valid
				if current_word.length() >= 2:
					words.append({"word": current_word, "positions": current_positions})
				current_word = ""
				current_positions = []
		# Check for word at end of row
		if current_word.length() >= 2:
			words.append({"word": current_word, "positions": current_positions})
	
	# Scan columns for vertical words
	for x: int in range(BOARD_SIZE):
		var current_word: String = ""
		var current_positions: Array[Vector2i] = []
		for y: int in range(BOARD_SIZE):
			var tile: TileModel = board_model.grid[x][y]
			if tile != null and not tile.is_blank():
				current_word += tile.letter
				current_positions.append(Vector2i(x, y))
			else:
				# End of word, check if valid
				if current_word.length() >= 2:
					words.append({"word": current_word, "positions": current_positions})
				current_word = ""
				current_positions = []
		# Check for word at end of column
		if current_word.length() >= 2:
			words.append({"word": current_word, "positions": current_positions})
	
	# Create summary
	var summary: String = "Found %d words on the board." % words.size()
	
	# Emit signal
	words_found.emit(words, summary)
	
	return words

# TODO: Add support for diagonal word scanning.
# Diagonals should be scanned in both directions (top-left to bottom-right and top-right to bottom-left).
# Ensure diagonals don't overlap with existing row/column words incorrectly.