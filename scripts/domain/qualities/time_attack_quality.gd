extends TimerQuality
class_name TimeAttackQuality

## TimeAttackQuality: Each round has a fixed countdown timer.
## When time expires, the round is lost.

const DEFAULT_TIME: float = 120.0


func get_quality_id() -> StringName:
	return &"time_attack"

func get_quality_name() -> String:
	return "Time Attack"

func get_description() -> String:
	return "Each round has a %d second time limit." % int(DEFAULT_TIME)


func on_round_started(_round_number: int) -> void:
	_time_remaining = DEFAULT_TIME
	_is_active = true


func to_dict() -> Dictionary:
	return {"quality_id": get_quality_id(), "default_time": DEFAULT_TIME}
