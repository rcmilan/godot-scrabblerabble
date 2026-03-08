class_name PlayValidator
extends RefCounted

## Pure domain service for validating plays and computing scores.
## No Godot Node dependencies.

var _word_validator: WordValidator


func _init(word_validator: WordValidator) -> void:
	_word_validator = word_validator


## Validates a play: finds words, computes score, determines which tiles to lock/consume.
func validate(board: Board, unplayed_tiles: Array[Tile]) -> PlayResult:
	if unplayed_tiles.is_empty():
		return PlayResult.invalid()

	var positions: Array[Vector2i] = []
	for tile in unplayed_tiles:
		if tile.current_cell:
			positions.append(tile.current_cell.grid_position)

	var raw_words: Array = _word_validator.find_formed_words(board, positions)
	if raw_words.is_empty():
		return PlayResult.invalid()

	var word_results: Array[WordResult] = []
	var total_score: int = 0

	for word_info in raw_words:
		var score_result: Dictionary = _word_validator.calculate_placement_score(
			word_info.tiles, word_info.cells
		)
		var tile_scores: Array[int] = []
		for entry in score_result.breakdown:
			tile_scores.append(entry.tile_score)

		var wr := WordResult.new(
			word_info.word,
			word_info.positions,
			tile_scores,
			score_result.total,
			word_info.direction
		)
		word_results.append(wr)
		total_score += score_result.total

	# Tiles to lock = the unplayed tiles being committed
	# Tiles to consume = same unplayed tiles (consumable modifiers removed after animation)
	return PlayResult.valid(word_results, total_score, unplayed_tiles, unplayed_tiles)
