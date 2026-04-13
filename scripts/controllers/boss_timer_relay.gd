class_name BossTimerRelay
extends RefCounted

## Lightweight per-round countdown timer for boss time-attack mechanics.
## Emits the same signal signatures as RunQuality so MainHUD can display it.

signal time_updated(time_remaining: float)
signal time_expired()

var _time_remaining: float = 0.0
var _is_active: bool = false
var _paused: bool = false


func start(time_limit: float) -> void:
	_time_remaining = time_limit
	_is_active = true
	_paused = false
	print("[BossTimerRelay] Started with %.1fs" % time_limit)


func stop() -> void:
	_is_active = false
	_paused = false


func is_active() -> bool:
	return _is_active


func pause() -> void:
	if _is_active:
		_paused = true


func resume() -> void:
	if _is_active:
		_paused = false


func on_process(delta: float) -> void:
	if not _is_active or _paused:
		return
	_time_remaining = maxf(0.0, _time_remaining - delta)
	time_updated.emit(_time_remaining)
	if _time_remaining <= 0.0:
		_is_active = false
		time_expired.emit()
