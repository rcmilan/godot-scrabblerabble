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
func extract_word(tiles: Array) -> String:
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
func find_formed_words(board: Node, placed_positions: Array[Vector2i]) -> Array:
	var words: Array = []

	if placed_positions.is_empty():
		return words

	# Get the direction of placement
	var validation: Dictionary = validate_placement(placed_positions)
	if not validation.valid:
		return words

	# TODO: Implement full word finding logic
	# This requires checking:
	# 1. The main word formed by the placement
	# 2. All cross-words formed by each placed tile

	return words
