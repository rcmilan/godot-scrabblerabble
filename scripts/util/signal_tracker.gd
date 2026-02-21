class_name SignalTracker
extends RefCounted

## Tracks signal connections and disconnects all at once.
## Replaces ad-hoc _connections arrays and _safe_connect/_disconnect_all patterns.

var _connections: Array[Dictionary] = []


## Connects sig to fn and records the connection for later cleanup.
func track(sig: Signal, fn: Callable) -> void:
	sig.connect(fn)
	_connections.append({s = sig, f = fn})


## Disconnects all tracked connections and clears the list.
func disconnect_all() -> void:
	for c in _connections:
		if c.s.is_connected(c.f):
			c.s.disconnect(c.f)
	_connections.clear()
