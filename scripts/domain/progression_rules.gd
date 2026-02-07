extends RefCounted
class_name ProgressionRules

## ProgressionRules: Computes round parameters based on run state.
## Stateless strategy — inputs come from RunState, outputs are RoundConfig.
## Reads scaling factors from a ProgressionConfig resource.

var _config: ProgressionConfig = null


func _init(config: ProgressionConfig = null) -> void:
	if config:
		_config = config
	else:
		_config = ProgressionConfig.new()


func get_round_config(run_state: RunState) -> RoundConfig:
	var round_num: int = run_state.get_next_round_number()
	var board_size: Vector2i = _calculate_board_size(round_num)
	var target: int = _calculate_target_score(round_num)
	var plays: int = run_state.plays_per_round
	var hand: int = run_state.hand_size

	return RoundConfig.new(
		round_num,
		board_size.y,  # rows
		board_size.x,  # columns
		target,
		plays,
		hand
	)


func _calculate_board_size(round_number: int) -> Vector2i:
	for threshold in _config.board_size_thresholds:
		if round_number <= threshold.get("up_to_round", 0):
			return threshold.get("size", _config.max_board_size)
	return _config.max_board_size


func _calculate_target_score(round_number: int) -> int:
	return _config.base_target_score + (round_number - 1) * _config.target_score_increment
