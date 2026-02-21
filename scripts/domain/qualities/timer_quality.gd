class_name TimerQuality
extends RunQuality

## Base class for RunQuality types that implement a countdown timer.
## Subclasses set _time_remaining and _is_active in on_round_started().
## The shared countdown + emission logic lives here.

var _time_remaining: float = 0.0
var _is_active: bool = false


func has_timer() -> bool:
	return true


func on_round_ended(_round_number: int, _success: bool) -> void:
	_is_active = false


func on_process(delta: float) -> void:
	if not _is_active:
		return
	_time_remaining = maxf(0.0, _time_remaining - delta)
	time_updated.emit(_time_remaining)
	if _time_remaining <= 0.0:
		_is_active = false
		time_expired.emit()
