extends TimerQuality
class_name LimitedTimeWithIncrementQuality

## LimitedTimeWithIncrementQuality: Countdown timer that adds time on each play.

const DEFAULT_TIME: float = 60.0
const INCREMENT_PER_PLAY: float = 15.0


func get_quality_id() -> StringName:
	return &"limited_time_with_increment"

func get_quality_name() -> String:
	return "Time + Increment"

func get_description() -> String:
	return "%ds per round, +%ds per play." % [int(DEFAULT_TIME), int(INCREMENT_PER_PLAY)]


func on_round_started(_round_number: int) -> void:
	_time_remaining = DEFAULT_TIME
	_is_active = true


func on_play_completed(_plays_remaining: int) -> void:
	if _is_active:
		_time_remaining += INCREMENT_PER_PLAY
		time_incremented.emit(INCREMENT_PER_PLAY)
		time_updated.emit(_time_remaining)


func to_dict() -> Dictionary:
	return {
		"quality_id": get_quality_id(),
		"default_time": DEFAULT_TIME,
		"increment": INCREMENT_PER_PLAY,
	}
