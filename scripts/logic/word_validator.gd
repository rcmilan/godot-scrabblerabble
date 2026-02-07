extends RefCounted
class_name WordValidator

## WordValidator: Service for validating words and calculating scores.
## Provides word validation, scoring, and placement validation logic.
## This is a RefCounted class - instantiate it where needed.

# =============================================================================
# CONFIGURATION
# =============================================================================

## Minimum word length for validation
const MIN_WORD_LENGTH: int = 2

## Point values for each letter (Scrabble-style)
const LETTER_POINTS: Dictionary = {
	"A": 1, "B": 3, "C": 3, "D": 2, "E": 1, "F": 4, "G": 2, "H": 4,
	"I": 1, "J": 8, "K": 5, "L": 1, "M": 3, "N": 1, "O": 1, "P": 3,
	"Q": 10, "R": 1, "S": 1, "T": 1, "U": 1, "V": 4, "W": 4, "X": 8,
	"Y": 4, "Z": 10
}

# =============================================================================
# STATE
# =============================================================================

var _valid_words: Dictionary = {}
var _is_loaded: bool = false


# =============================================================================
# PUBLIC API: WORD VALIDATION
# =============================================================================

## Checks if a word is valid.
func is_valid_word(word: String) -> bool:
	if word.length() < MIN_WORD_LENGTH:
		return false

	var upper_word: String = word.to_upper()

	# If dictionary is loaded, check against it
	if _is_loaded:
		return _valid_words.has(upper_word)

	# Fallback: accept any word of minimum length (for testing)
	return true


## Loads a word list from a file (one word per line).
func load_word_list(path: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[WordValidator] Failed to load word list: %s" % path)
		return false

	_valid_words.clear()

	while not file.eof_reached():
		var word: String = file.get_line().strip_edges().to_upper()
		if word.length() >= MIN_WORD_LENGTH:
			_valid_words[word] = true

	file.close()
	_is_loaded = true

	print("[WordValidator] Loaded %d words" % _valid_words.size())
	return true


# =============================================================================
# PUBLIC API: SCORING
# =============================================================================

## Calculates the base score for a word (without multipliers).
func calculate_base_score(word: String) -> int:
	var score: int = 0

	for c in word.to_upper():
		if LETTER_POINTS.has(c):
			score += LETTER_POINTS[c]

	return score


## Calculates the full score for placed tiles with cell multipliers.
func calculate_placement_score(tiles: Array, cells: Array) -> Dictionary:
	var letter_score: int = 0
	var word_multiplier: int = 1
	var breakdown: Array = []

	for i in range(tiles.size()):
		var tile: Tile = tiles[i]
		var cell: BoardCell = cells[i] if i < cells.size() else null

		var base: int = tile.get_points()
		var letter_mult: int = cell.get_letter_multiplier() if cell else 1
		var tile_score: int = base * letter_mult

		letter_score += tile_score

		if cell:
			word_multiplier *= cell.get_word_multiplier()

		breakdown.append({
			"letter": tile.letter,
			"base": base,
			"letter_mult": letter_mult,
			"tile_score": tile_score
		})

	var total: int = letter_score * word_multiplier

	return {
		"total": total,
		"letter_score": letter_score,
		"word_multiplier": word_multiplier,
		"breakdown": breakdown
	}


## Calculates score for a word string (simple, no multipliers).
func calculate_word_score(word: String) -> int:
	return calculate_base_score(word)


# =============================================================================
# PUBLIC API: PLACEMENT VALIDATION
# =============================================================================

## Validates that tiles form a valid linear placement.
func validate_placement(positions: Array[Vector2i]) -> Dictionary:
	if positions.is_empty():
		return {"valid": false, "error": "No tiles placed"}

	if positions.size() == 1:
		return {"valid": true, "direction": "single"}

	# Check if all positions are in a line
	var is_horizontal: bool = true
	var is_vertical: bool = true

	var first: Vector2i = positions[0]

	for pos in positions:
		if pos.y != first.y:
			is_horizontal = false
		if pos.x != first.x:
			is_vertical = false

	if not is_horizontal and not is_vertical:
		return {"valid": false, "error": "Tiles must be in a straight line"}

	# Sort positions
	var sorted_positions: Array[Vector2i] = positions.duplicate()
	if is_horizontal:
		sorted_positions.sort_custom(func(a, b): return a.x < b.x)
	else:
		sorted_positions.sort_custom(func(a, b): return a.y < b.y)

	return {
		"valid": true,
		"direction": "horizontal" if is_horizontal else "vertical",
		"sorted_positions": sorted_positions
	}


## Extracts a word from tiles at given positions.
func extract_word(tiles: Array[Tile]) -> String:
	var word: String = ""
	for tile in tiles:
		if tile is Tile:
			word += tile.letter
	return word


# =============================================================================
# PUBLIC API: WORD FINDING
# =============================================================================

## Finds all words formed by the current placement on a board.
## Returns an array of word info dictionaries.
## Each dictionary contains: word, tiles, cells, direction, positions
func find_formed_words(board: Board, placed_positions: Array[Vector2i]) -> Array:
	var words: Array = []

	if placed_positions.is_empty():
		return words

	# Check if tiles form a straight line
	var validation: Dictionary = validate_placement(placed_positions)

	if validation.valid:
		# Collinear placement — find main word + cross words
		words = _find_words_collinear(board, placed_positions, validation.direction)
	else:
		# Scattered placement — find words through each tile individually
		words = _find_words_scattered(board, placed_positions)

	return words


## Finds words when all placed tiles are in a straight line (original logic).
func _find_words_collinear(board: Board, placed_positions: Array[Vector2i], direction: String) -> Array:
	var words: Array = []

	var main_word: Dictionary = _find_word_at_positions(board, placed_positions, direction)
	if main_word.word.length() >= MIN_WORD_LENGTH:
		words.append(main_word)

	var cross_direction: String = "vertical" if direction == "horizontal" else "horizontal"
	if direction == "single":
		for dir in ["horizontal", "vertical"]:
			var word: Dictionary = _find_word_through_position(board, placed_positions[0], dir)
			if word.word.length() >= MIN_WORD_LENGTH:
				words.append(word)
	else:
		for pos in placed_positions:
			var cross_word: Dictionary = _find_word_through_position(board, pos, cross_direction)
			if cross_word.word.length() >= MIN_WORD_LENGTH:
				if not _is_duplicate_word(words, cross_word):
					words.append(cross_word)

	return words


## Finds words when placed tiles are scattered (not in a straight line).
## Checks horizontal and vertical words through each placed position.
func _find_words_scattered(board: Board, placed_positions: Array[Vector2i]) -> Array:
	var words: Array = []

	for pos in placed_positions:
		for direction in ["horizontal", "vertical"]:
			var word: Dictionary = _find_word_through_position(board, pos, direction)
			if word.word.length() >= MIN_WORD_LENGTH:
				if not _is_duplicate_word(words, word):
					words.append(word)

	return words


## Checks if a word already exists in the list (same start position and direction).
func _is_duplicate_word(words: Array, candidate: Dictionary) -> bool:
	for existing in words:
		if existing.positions == candidate.positions and existing.direction == candidate.direction:
			return true
	return false


## Finds a word formed by connected tiles at given positions.
func _find_word_at_positions(board: Board, positions: Array[Vector2i], direction: String) -> Dictionary:
	if positions.is_empty():
		return {"word": "", "tiles": [], "cells": [], "positions": [], "direction": direction}

	# Sort positions
	var sorted_positions: Array[Vector2i] = positions.duplicate()
	if direction == "horizontal":
		sorted_positions.sort_custom(func(a, b): return a.x < b.x)
	else:
		sorted_positions.sort_custom(func(a, b): return a.y < b.y)

	# Extend in both directions to find full word
	var start_pos: Vector2i = sorted_positions[0]
	var end_pos: Vector2i = sorted_positions[sorted_positions.size() - 1]

	# Extend backwards
	start_pos = _extend_word_position(board, start_pos, direction, -1)
	# Extend forwards
	end_pos = _extend_word_position(board, end_pos, direction, 1)

	# Collect all tiles in the word
	return _collect_word_between(board, start_pos, end_pos, direction)


## Finds a word passing through a specific position in a given direction.
func _find_word_through_position(board: Board, pos: Vector2i, direction: String) -> Dictionary:
	# Extend in both directions
	var start_pos: Vector2i = _extend_word_position(board, pos, direction, -1)
	var end_pos: Vector2i = _extend_word_position(board, pos, direction, 1)

	return _collect_word_between(board, start_pos, end_pos, direction)


## Extends a position in a direction until no more tiles are found.
func _extend_word_position(board: Board, pos: Vector2i, direction: String, step: int) -> Vector2i:
	var delta: Vector2i = Vector2i(step, 0) if direction == "horizontal" else Vector2i(0, step)
	var current: Vector2i = pos

	while true:
		var next: Vector2i = current + delta
		var cell: BoardCell = board.get_cell(next.y, next.x)
		if cell == null or not cell.is_occupied():
			break
		current = next

	return current


## Collects all tiles between two positions into a word dictionary.
func _collect_word_between(board: Board, start: Vector2i, end: Vector2i, direction: String) -> Dictionary:
	var word: String = ""
	var tiles: Array[Tile] = []
	var cells: Array[BoardCell] = []
	var positions: Array[Vector2i] = []

	var delta: Vector2i = Vector2i(1, 0) if direction == "horizontal" else Vector2i(0, 1)
	var current: Vector2i = start

	while true:
		var cell: BoardCell = board.get_cell(current.y, current.x)
		if cell and cell.is_occupied():
			var tile: Tile = cell.tile
			# Strip whitespace from letter to handle any data inconsistencies
			var clean_letter: String = tile.letter.strip_edges() if tile.letter else ""
			word += clean_letter
			tiles.append(tile)
			cells.append(cell)
			positions.append(current)

		if current == end:
			break
		current += delta

		# Safety check to prevent infinite loop
		if positions.size() > 100:
			push_error("[WordValidator] _collect_word_between: Safety limit reached")
			break

	return {
		"word": word,
		"tiles": tiles,
		"cells": cells,
		"positions": positions,
		"direction": direction
	}
