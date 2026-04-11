class_name BossTimerRelay
extends RefCounted

## Lightweight per-round countdown timer for boss time-attack mechanics.
## Emits the same signal signatures as RunQuality so MainHUD can display it.

signal time_updated(time_remaining: float)
signal time_expired()

var _time_remaining: float = 0.0
var _is_active: bool = false


func start(time_limit: float) -> void:
	_time_remaining = time_limit
	_is_active = true
	print("[BossTimerRelay] Started with %.1fs" % time_limit)


func stop() -> void:
	_is_active = false


func is_active() -> bool:
	return _is_active


func on_process(delta: float) -> void:
	if not _is_active:
		return
	_time_remaining = maxf(0.0, _time_remaining - delta)
	time_updated.emit(_time_remaining)
	if _time_remaining <= 0.0:
		_is_active = false
		time_expired.emit()
