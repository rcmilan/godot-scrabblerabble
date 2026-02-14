extends RunQuality
class_name TimeAttackQuality

## TimeAttackQuality: Each round has a countdown timer.
## When time expires, the round is lost.

const DEFAULT_TIME: float = 120.0

var _time_remaining: float = DEFAULT_TIME
var _is_active: bool = false


func get_quality_id() -> StringName:
	return &"time_attack"


func get_quality_name() -> String:
	return "Time Attack"


func get_description() -> String:
	return "Each round has a %d second time limit." % int(DEFAULT_TIME)


func on_round_started(round_number: int) -> void:
	_time_remaining = DEFAULT_TIME
	_is_active = true


func on_round_ended(round_number: int, success: bool) -> void:
	_is_active = false


func on_process(delta: float) -> void:
	if not _is_active:
		return

	_time_remaining -= delta
	time_updated.emit(_time_remaining)

	if _time_remaining <= 0.0:
		_time_remaining = 0.0
		_is_active = false
		time_expired.emit()


func to_dict() -> Dictionary:
	return {
		"quality_id": get_quality_id(),
		"default_time": DEFAULT_TIME,
	}
