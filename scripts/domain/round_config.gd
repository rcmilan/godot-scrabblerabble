extends RefCounted
class_name RoundConfig

## RoundConfig: Immutable value object describing a single round's parameters.
## Created by ProgressionRules, consumed by GameManager and Main.

var round_number: int = 1
var board_rows: int = 6
var board_columns: int = 6
var target_score: int = 100
var plays_per_round: int = 2
var hand_size: int = 10
var is_boss_round: bool = false


func _init(
	p_round: int = 1,
	p_rows: int = 6,
	p_cols: int = 6,
	p_target: int = 100,
	p_plays: int = 2,
	p_hand_size: int = 10,
	p_is_boss: bool = false
) -> void:
	round_number = p_round
	board_rows = p_rows
	board_columns = p_cols
	target_score = p_target
	plays_per_round = p_plays
	hand_size = p_hand_size
	is_boss_round = p_is_boss


func _to_string() -> String:
	var boss_marker := " (Boss)" if is_boss_round else ""
	return "Round %d%s: %dx%d board, target=%d, plays=%d" % [
		round_number, boss_marker, board_rows, board_columns, target_score, plays_per_round
	]
