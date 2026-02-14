extends RunQuality
class_name MaxHandSizeQuality

## MaxHandSizeQuality: Increases the hand size to 15 tiles.

const HAND_SIZE: int = 15


func get_quality_id() -> StringName:
	return &"max_hand_size"


func get_quality_name() -> String:
	return "Big Hand"


func get_description() -> String:
	return "Start each round with %d tiles in hand." % HAND_SIZE


func apply_to_run_state(run_state: RunState) -> void:
	run_state.hand_size = HAND_SIZE
