extends Node

# Scoring: Handles word validation and score calculation.
# Designed to be extensible with new scoring rules.

var _word_finder = preload("res://scripts/logic/word_finder.gd").new()
var _word_checker = preload("res://scripts/core/word_checker.gd").new()
var _scoring_rules = []

func _ready():
	# Add child nodes for script instances to process
	add_child(_word_finder)
	add_child(_word_checker)
	
	# Register the basic scoring rule (store owner+method to remain compatible across Godot versions)
	_register_rule(self, "_calculate_basic_word_score")
	
	# TODO: Add a public method to register new scoring rules from other scripts.
	# Example: Scoring.register_rule(funcref(PalindromeScoring, "calculate_score"))

func evaluate_board(grid: Array) -> int:
	# Backwards-compatible wrapper: return the integer total score (sum of final_score for each word)
	var breakdown = evaluate_board_with_breakdown(grid)
	return int(breakdown.get("total_score", 0))


func evaluate_board_with_breakdown(grid: Array) -> Dictionary:
	# Returns a dictionary with per-word breakdowns and total_score.
	# Each word breakdown contains: base_sum, tile_multiplier_sum, board_multiplier_sum, final_score
	var found_words = _word_finder.find_words(grid)
	var words = []
	var total_score = 0

	for word_info in found_words:
		if _word_checker.is_valid_word(word_info["word"]):
			var breakdown = _calculate_word_score(word_info, grid)
			words.append(breakdown)
			total_score += int(breakdown.get("final_score", 0))

	return {"total_score": total_score, "words": words}


func _process_cell(cell) -> Array:
	# Returns [cell_base, cell_tile_mul, cell_board_mul]
	var cell_base = 0.0
	var cell_tile_mul = 1.0
	var cell_board_mul = 1.0

	if cell == null:
		return [cell_base, cell_tile_mul, cell_board_mul]

	# If the cell is a TileModel instance (declared via class_name TileModel)
	if typeof(cell) == TYPE_OBJECT and cell is TileModel:
		cell_base = float(cell.effective_letter_value())
		cell_tile_mul = float(cell.placement_multiplier)
		return [cell_base, cell_tile_mul, cell_board_mul]

	# If the grid stores a dictionary with explicit fields
	if typeof(cell) == TYPE_DICTIONARY:
		cell_base = float(cell.get("value", 0))
		cell_tile_mul = float(cell.get("placement_multiplier", 1))
		cell_board_mul = float(cell.get("board_multiplier", 1))
		return [cell_base, cell_tile_mul, cell_board_mul]

	# Fallback: try to read a .value property if present
	if typeof(cell) == TYPE_OBJECT and cell.has_method("get"):
		# many Godot objects implement get(property) — try value
		var v = cell.get("value")
		if v != null:
			cell_base = float(v)

	return [cell_base, cell_tile_mul, cell_board_mul]


func _calculate_word_score(word_info: Dictionary, grid: Array) -> Dictionary:
	# Implements the requested formula:
	# final_score = sum_of_tiles_multipliers * sum_of_tiles_base_score * sum_of_relevant_board_multipliers
	var base_sum: float = 0.0
	var tile_multiplier_sum: float = 0.0
	var board_multiplier_sum: float = 0.0

	var word = word_info.get("word", "")
	var start = word_info.get("start")
	var end = word_info.get("end")

	# traverse positions

	# traverse positions
	if start == null or end == null:
		return {"word": word, "base_sum": 0, "tile_multiplier_sum": 0, "board_multiplier_sum": 0, "final_score": 0}

	if start.y == end.y: # Horizontal
		for x in range(start.x, end.x + 1):
			var cell = grid[start.y][x]
			var vals = _process_cell(cell)
			base_sum += vals[0]
			tile_multiplier_sum += vals[1]
			board_multiplier_sum += vals[2]
	else: # Vertical
		for y in range(start.y, end.y + 1):
			var cell = grid[y][start.x]
			var vals = _process_cell(cell)
			base_sum += vals[0]
			tile_multiplier_sum += vals[1]
			board_multiplier_sum += vals[2]

	# Ensure sensible minimums to avoid zeroing out a score unexpectedly
	tile_multiplier_sum = max(1.0, tile_multiplier_sum)
	board_multiplier_sum = max(1.0, board_multiplier_sum)

	var final_score = base_sum * tile_multiplier_sum * board_multiplier_sum

	return {
		"word": word,
		"base_sum": int(base_sum),
		"tile_multiplier_sum": tile_multiplier_sum,
		"board_multiplier_sum": board_multiplier_sum,
		"final_score": int(final_score)
	}

func _register_rule(owner, method_name: String):
	# Store rules as a small dict so we avoid relying on FuncRef/Callable types
	_scoring_rules.append({"owner": owner, "method": method_name})

# --- Scoring Rule Implementations ---

func _calculate_basic_word_score(word_info: Dictionary, grid: Array) -> int:
	# Basic score is the sum of the values of the tiles in the word.
	var score = 0
	var word = word_info["word"]
	var start = word_info["start"]
	var end = word_info["end"]
	
	if start.y == end.y: # Horizontal word
		for x in range(start.x, end.x + 1):
			score += grid[start.y][x].value
	else: # Vertical word
		for y in range(start.y, end.y + 1):
			score += grid[y][start.x].value
			
	return score

# --- TODO: Future Extensibility Examples ---
# func _calculate_palindrome_bonus(word_info, grid):
#     if word_info["word"] == word_info["word"].reverse():
#         return _calculate_basic_word_score(word_info, grid) * 2 # Triple the base score
#     return 0
