class_name WordHighlightHandler
extends RefCounted

## Manages real-time word scanning and cell highlight state.
## Uses WordFinder for word detection and PlayStateManager for grid state.

var _board: Board = null
var _word_finder: WordFinder = null
var _play_state_manager: PlayStateManager = null
var _current_valid_words: Array = []
var _highlighted_positions: Array[Vector2i] = []


func setup(board: Board, word_finder: WordFinder, play_state_manager: PlayStateManager) -> void:
	_board = board
	_word_finder = word_finder
	_play_state_manager = play_state_manager


## Runs word finder on the current board state and updates cell highlights.
func run_scan() -> void:
	clear()

	if not _play_state_manager.has_temporary_tiles():
		_current_valid_words.clear()
		return

	var grid: Array[Array] = _play_state_manager.get_grid()
	_current_valid_words = _word_finder.find_valid_words(grid)

	var valid_positions: Array[Vector2i] = _word_finder.get_valid_word_positions(_current_valid_words)
	_apply_highlights(valid_positions)

	if _current_valid_words.size() > 0:
		for fw in _current_valid_words:
			print("[Gameplay] Word found: '%s' (%s)" % [fw.word, fw.direction])


## Clears all word highlights from the board.
func clear() -> void:
	for pos in _highlighted_positions:
		var cell: BoardCell = _board.get_cell(pos.y, pos.x)
		if cell:
			cell.clear_word_highlight()
	_highlighted_positions.clear()


## Clears highlights and cached words (e.g., after play committed).
func clear_all() -> void:
	clear()
	_current_valid_words.clear()


func get_current_valid_words() -> Array:
	return _current_valid_words


func _apply_highlights(positions: Array[Vector2i]) -> void:
	_highlighted_positions = positions
	for pos in positions:
		var cell: BoardCell = _board.get_cell(pos.y, pos.x)
		if cell:
			cell.show_word_highlight()
