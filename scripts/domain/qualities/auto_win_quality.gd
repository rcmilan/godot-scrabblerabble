extends RunQuality
class_name AutoWinQuality

## AutoWinQuality: Enables endless auto-win mode with 3 plays per round.
## Exhausting plays wins the round. Run never ends on its own.

const PLAYS_PER_ROUND: int = 3


func get_quality_id() -> StringName:
	return &"auto_win"


func get_quality_name() -> String:
	return "Auto Win (%d Plays)" % PLAYS_PER_ROUND


func get_description() -> String:
	return "Exhaust your %d Plays to win each Round. Endless mode." % PLAYS_PER_ROUND


func apply_to_run_state(run_state: RunState) -> void:
	run_state.plays_per_round = PLAYS_PER_ROUND
	RunManager.set_debug_auto_win(true)


func on_round_started(_round_number: int) -> void:
	RunManager.set_debug_auto_win(true)


func has_custom_win_condition() -> bool:
	return false


func to_dict() -> Dictionary:
	return {
		"quality_id": get_quality_id(),
		"plays_per_round": PLAYS_PER_ROUND,
	}
