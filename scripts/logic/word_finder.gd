extends RefCounted
class_name WordFinder

## WordFinder: Scans the board grid for valid word substrings.
##
## Unlike traditional Scrabble validation (whole sequence must be a word),
## this performs SUBSTRING matching: given a contiguous sequence of tiles,
## it finds the longest valid dictionary words contained within.
##
## Example: Sequence "ACATHE" contains "CAT", "AT", "THE", "HE".
##          Greedy longest-match returns non-overlapping: "CAT", "THE".
##
## Design: Roguelite-first — any placement is valid. Valid words provide
## bonus multiplier scoring, not gate plays.

# =============================================================================
# TYPES
# =============================================================================

## Represents a found word on the board.
class FoundWord:
	var word: String = ""
	var positions: Array[Vector2i] = []    ## Grid positions of each letter
	var tiles: Array[Tile] = []            ## Tile references
	var direction: String = ""             ## "horizontal" or "vertical"
	var is_valid: bool = false             ## True if word is in dictionary

	func _to_string() -> String:
		return "'%s' (%s) valid=%s positions=%s" % [word, direction, is_valid, positions]


# =============================================================================
# CONFIGURATION
# =============================================================================

const MIN_WORD_LENGTH: int = 2


# =============================================================================
# DEPENDENCIES
# =============================================================================

var _validator: WordValidator = null


# =============================================================================
# PUBLIC API
# =============================================================================

## Sets the word validator used for dictionary lookups.
func set_validator(validator: WordValidator) -> void:
	_validator = validator


## Finds all valid word substrings on the board.
## Returns an array of FoundWord objects for all non-overlapping longest matches.
##
## grid: 2D array [row][col] where each element is a Tile or null.
## Returns: Array of FoundWord
func find_valid_words(grid: Array[Array]) -> Array:
	if _validator == null:
		push_error("[WordFinder] No validator set — call set_validator() first")
		return []

	var all_words: Array = []

	var rows: int = grid.size()
	if rows == 0:
		return []
	var cols: int = grid[0].size()

	# Scan horizontal sequences (left to right in each row)
	for row in range(rows):
		var sequences: Array = _extract_sequences_from_line(grid, row, 0, Vector2i(1, 0), cols)
		for seq in sequences:
			var words: Array = _find_longest_matches_in_sequence(seq)
			all_words.append_array(words)

	# Scan vertical sequences (top to bottom in each column)
	for col in range(cols):
		var sequences: Array = _extract_sequences_from_line(grid, 0, col, Vector2i(0, 1), rows)
		for seq in sequences:
			var words: Array = _find_longest_matches_in_sequence(seq)
			all_words.append_array(words)

	return all_words


## Returns all grid positions that are part of any valid word.
## Useful for highlighting cells.
func get_valid_word_positions(found_words: Array) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	var seen: Dictionary = {}  # Avoid duplicates

	for fw in found_words:
		if fw is FoundWord and fw.is_valid:
			for pos in fw.positions:
				if not seen.has(pos):
					seen[pos] = true
					positions.append(pos)

	return positions


# =============================================================================
# PRIVATE: SEQUENCE EXTRACTION
# =============================================================================

## Extracts all contiguous tile sequences along a line (row or column).
## A sequence breaks wherever there's a null (empty cell).
##
## Returns: Array of sequences, where each sequence is:
##   { "tiles": Array[Tile], "positions": Array[Vector2i], "word": String, "direction": String }
func _extract_sequences_from_line(grid: Array[Array], start_row: int, start_col: int, step: Vector2i, length: int) -> Array:
	var sequences: Array = []
	var current_tiles: Array[Tile] = []
	var current_positions: Array[Vector2i] = []
	var current_word: String = ""

	var direction: String = "horizontal" if step.x == 1 else "vertical"

	for i in range(length):
		var row: int = start_row + step.y * i
		var col: int = start_col + step.x * i
		var tile: Tile = grid[row][col] if grid[row][col] is Tile else null

		if tile != null:
			current_tiles.append(tile)
			current_positions.append(Vector2i(col, row))
			current_word += tile.letter
		else:
			# End of a contiguous run — save if long enough
			if current_word.length() >= MIN_WORD_LENGTH:
				sequences.append({
					"tiles": current_tiles.duplicate(),
					"positions": current_positions.duplicate(),
					"word": current_word,
					"direction": direction
				})
			current_tiles.clear()
			current_positions.clear()
			current_word = ""

	# Don't forget the last run
	if current_word.length() >= MIN_WORD_LENGTH:
		sequences.append({
			"tiles": current_tiles.duplicate(),
			"positions": current_positions.duplicate(),
			"word": current_word,
			"direction": direction
		})

	return sequences


# =============================================================================
# PRIVATE: SUBSTRING MATCHING
# =============================================================================

## Finds the longest non-overlapping valid words within a single tile sequence.
##
## Algorithm (greedy longest-first):
##   1. Enumerate ALL substrings of length >= MIN_WORD_LENGTH
##   2. Check each against the dictionary
##   3. Sort valid matches by length descending
##   4. Greedily select non-overlapping matches (longest first)
##
## Performance: O(n²) substring enumeration where n = sequence length.
## For board sizes ≤ 15 this is negligible.
func _find_longest_matches_in_sequence(sequence: Dictionary) -> Array:
	var word: String = sequence.word
	var tiles: Array = sequence.tiles
	var positions: Array = sequence.positions
	var direction: String = sequence.direction
	var n: int = word.length()

	# Step 1: Find all valid substrings
	var valid_matches: Array = []  # Array of { start: int, end: int, substr: String }

	for start in range(n):
		for end in range(start + MIN_WORD_LENGTH, n + 1):
			var substr: String = word.substr(start, end - start)
			if _validator.is_valid_word(substr):
				valid_matches.append({
					"start": start,
					"end": end,  # exclusive
					"substr": substr
				})

	if valid_matches.is_empty():
		return []

	# Step 2: Sort by length descending, then by start position ascending
	valid_matches.sort_custom(func(a, b):
		if a.substr.length() != b.substr.length():
			return a.substr.length() > b.substr.length()
		return a.start < b.start
	)

	# Step 3: Greedy non-overlapping selection
	var used: Array[bool] = []
	used.resize(n)
	used.fill(false)

	var selected: Array = []

	for match_info in valid_matches:
		var s: int = match_info.start
		var e: int = match_info.end

		# Check if any position in this match is already used
		var overlaps: bool = false
		for i in range(s, e):
			if used[i]:
				overlaps = true
				break

		if overlaps:
			continue

		# Mark positions as used
		for i in range(s, e):
			used[i] = true

		# Build FoundWord
		var fw: FoundWord = FoundWord.new()
		fw.word = match_info.substr
		fw.direction = direction
		fw.is_valid = true

		for i in range(s, e):
			fw.positions.append(positions[i])
			fw.tiles.append(tiles[i])

		selected.append(fw)

	return selected
