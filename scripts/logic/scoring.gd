extends Node

## Scoring system for ScrabbleRabble
## Calculates points for words formed on the board

# Reference to board for evaluation
var board: Board

## Evaluate the current board state and return the score for the turn
## For now, sums the point values of all tiles on the board
## TODO: Implement proper Scrabble scoring with word/letter multipliers and cross-words
func evaluate_board(board_ref: Board) -> int:
	board = board_ref
	var total_score: int = 0
	var words = board.get_all_words()
	for word_data in words:
		var word: String = word_data["word"]
		var positions: Array[Vector2i] = word_data["positions"]
		# For each word, sum the point values of its tiles
		for pos in positions:
			var tile = board.board_model.grid[pos.x][pos.y]
			if tile != null:
				total_score += tile.point_value
	return total_score

# TODO: Implement bonus points for using all tiles
# TODO: Implement bingo bonus (7 tiles placed)
# TODO: Handle special squares (double letter, triple word, etc.)