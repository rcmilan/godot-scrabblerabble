extends Node

# ValidationHelper: Shared validation logic for incremental word validation.
# Used by both Main.tscn and Debug.tscn to validate temp tile placements.

var word_checker = null

func _init(checker = null):
	word_checker = checker

func run_incremental_validation(board: Node, temp_positions: Array) -> Dictionary:
	# Validates current temp placements and returns validation state.
	# Returns a dictionary with keys:
	#   - is_valid: bool (overall validity)
	#   - valid_ranges: Array (ranges that form valid words)
	#   - any_valid: bool (at least one valid word found)
	#   - all_temp_covered: bool (all temp tiles are part of valid words)
	if temp_positions.size() == 0:
		return {
			"is_valid": false,
			"valid_ranges": [],
			"any_valid": false,
			"all_temp_covered": false
		}
	
	# Get candidate word ranges from board
	var ranges = board.get_candidate_ranges_for_positions(temp_positions)
	var combined = board.get_combined_grid_view()
	
	var any_valid = false
	var valid_ranges = []
	
	# Evaluate each candidate range
	for r in ranges:
		var word = extract_word_from_range(combined, r.start, r.end)
		var is_valid = word_checker.is_valid_word(word)
		if is_valid:
			any_valid = true
			valid_ranges.append(r)
	
	# Check that every temp tile is part of at least one valid range
	var all_temp_covered = true
	for pos in temp_positions:
		var covered = false
		for vr in valid_ranges:
			var s = vr.start
			var e = vr.end
			if s.y == e.y:  # Horizontal range
				if pos.y == s.y and pos.x >= s.x and pos.x <= e.x:
					covered = true
					break
			else:  # Vertical range
				if pos.x == s.x and pos.y >= s.y and pos.y <= e.y:
					covered = true
					break
		if not covered:
			all_temp_covered = false
			break
	
	var overall_valid = any_valid and all_temp_covered
	
	return {
		"is_valid": overall_valid,
		"valid_ranges": valid_ranges,
		"any_valid": any_valid,
		"all_temp_covered": all_temp_covered
	}


func extract_word_from_range(grid: Array, start: Vector2i, end: Vector2i) -> String:
	# Extracts a word from the grid given a start and end position.
	# Handles both horizontal and vertical ranges.
	var word = ""
	if start.y == end.y:  # Horizontal
		for x in range(start.x, end.x + 1):
			var tile = grid[start.y][x]
			word += (tile.letter if tile else "")
	else:  # Vertical
		for y in range(start.y, end.y + 1):
			var tile = grid[y][start.x]
			word += (tile.letter if tile else "")
	return word
