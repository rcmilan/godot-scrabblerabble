extends RunQuality
class_name AutoWinQuality

## AutoWinQuality: Enables auto-win mode with 10 plays per round.
## Exhausting plays wins the round. Run ends with victory after 10 rounds.

const PLAYS_PER_ROUND: int = 10
const MAX_ROUNDS: int = 10


func get_quality_id() -> StringName:
	return &"auto_win"


func get_quality_name() -> String:
	return "Auto Win (%d Plays)" % PLAYS_PER_ROUND


func get_description() -> String:
	return "Exhaust your %d Plays to win each Round. Run ends after %d Rounds." % [PLAYS_PER_ROUND, MAX_ROUNDS]


func apply_to_run_state(run_state: RunState) -> void:
	run_state.plays_per_round = PLAYS_PER_ROUND
	RunManager.set_debug_auto_win(true)


func on_round_started(_round_number: int) -> void:
	RunManager.set_debug_auto_win(true)


func has_custom_win_condition() -> bool:
	return true


func check_run_end_condition(run_state: RunState) -> Dictionary:
	if run_state.rounds_completed >= MAX_ROUNDS:
		return {"should_end": true, "victory": true}
	return {"should_end": false}


func to_dict() -> Dictionary:
	return {
		"quality_id": get_quality_id(),
		"plays_per_round": PLAYS_PER_ROUND,
		"max_rounds": MAX_ROUNDS,
	}
