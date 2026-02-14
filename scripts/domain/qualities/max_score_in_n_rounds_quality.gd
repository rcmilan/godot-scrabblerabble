extends RunQuality
class_name MaxScoreInNRoundsQuality

## MaxScoreInNRoundsQuality: The run ends after N rounds.
## Player wins if they survive all rounds (custom win condition).

const DEFAULT_ROUNDS: int = 3

var _max_rounds: int = DEFAULT_ROUNDS


func get_quality_id() -> StringName:
	return &"max_score_in_n_rounds"


func get_quality_name() -> String:
	return "Sprint (%d Rounds)" % _max_rounds


func get_description() -> String:
	return "Run ends after %d rounds. Survive them all to win!" % _max_rounds


func has_custom_win_condition() -> bool:
	return true


func check_run_end_condition(run_state: RunState) -> Dictionary:
	if run_state.rounds_completed >= _max_rounds:
		return {"should_end": true, "victory": true}
	return {"should_end": false}


func to_dict() -> Dictionary:
	return {
		"quality_id": get_quality_id(),
		"max_rounds": _max_rounds,
	}
