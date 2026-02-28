extends RefCounted
class_name RoundConfig

## RoundConfig: Immutable value object describing a single round's parameters.
## Created by ProgressionRules, consumed by GameManager and Main.

var round_number: int = 1
var board_rows: int = 6
var board_columns: int = 6
var target_score: int = 100
var plays_per_round: int = 2


func _init(
	p_round: int = 1,
	p_rows: int = 6,
	p_cols: int = 6,
	p_target: int = 100,
	p_plays: int = 2
) -> void:
	round_number = p_round
	board_rows = p_rows
	board_columns = p_cols
	target_score = p_target
	plays_per_round = p_plays


func _to_string() -> String:
	return "Round %d: %dx%d board, target=%d, plays=%d" % [
		round_number, board_rows, board_columns, target_score, plays_per_round
	]
