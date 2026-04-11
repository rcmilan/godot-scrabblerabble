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


## Peeks at next round config WITHOUT consuming from boss pool (safe for previews)
func peek_round_config(run_state: RunState) -> RoundConfig:
	var round_num: int = run_state.get_next_round_number()
	var board_size: Vector2i = _calculate_board_size(round_num)
	var target: int = _calculate_target_score(round_num)
	var plays: int = run_state.plays_per_round
	var hand: int = run_state.hand_size
	var is_boss: bool = _is_boss_round(round_num)

	# Peek at boss WITHOUT consuming from pool
	var boss: Boss = null
	if is_boss:
		var boss_pool = run_state.get_boss_pool()
		if boss_pool and boss_pool.has_next():
			boss = boss_pool.peek()  # Peek, don't consume!
			print("[ProgressionRules] Round %d peeked as boss round | Peeked boss: %s" % [round_num, boss.display_name if boss else "none"])

	return RoundConfig.new(
		round_num,
		board_size.y,  # rows
		board_size.x,  # columns
		target,
		plays,
		hand,
		is_boss,
		boss
	)


func get_round_config(run_state: RunState) -> RoundConfig:
	var round_num: int = run_state.get_next_round_number()
	var board_size: Vector2i = _calculate_board_size(round_num)
	var target: int = _calculate_target_score(round_num)
	var plays: int = run_state.plays_per_round
	var hand: int = run_state.hand_size
	var is_boss: bool = _is_boss_round(round_num)

	# Assign boss if this is a boss round
	var boss: Boss = null
	if is_boss:
		var boss_pool = run_state.get_boss_pool()
		print("[ProgressionRules] Round %d is boss round | Pool state: %s | has_next=%s | remaining=%d" % [
			round_num,
			"exists" if boss_pool else "null",
			boss_pool.has_next() if boss_pool else "N/A",
			boss_pool.get_remaining_count() if boss_pool else 0
		])
		if boss_pool and boss_pool.has_next():
			boss = boss_pool.next()
			print("[ProgressionRules] Boss assigned: %s" % boss.display_name)
		else:
			print("[ProgressionRules] Boss pool exhausted - setting boss=null")
		# If pool is exhausted, boss remains null (signals run should end)

	return RoundConfig.new(
		round_num,
		board_size.y,  # rows
		board_size.x,  # columns
		target,
		plays,
		hand,
		is_boss,
		boss
	)


func _calculate_board_size(round_number: int) -> Vector2i:
	for threshold in _config.board_size_thresholds:
		if round_number <= threshold.get("up_to_round", 0):
			return threshold.get("size", _config.max_board_size)
	return _config.max_board_size


func _calculate_target_score(round_number: int) -> int:
	return _config.base_target_score + (round_number - 1) * _config.target_score_increment


func _is_boss_round(round_number: int) -> bool:
	return round_number % 3 == 0
