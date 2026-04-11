## BossPool: Mutable run-scoped object tracking boss selection.
##
## Maintains a shuffled list of bosses and ensures random-without-replacement
## selection (no boss repeats until all are exhausted). Supports resetting
## for future endless mode without architectural changes.
##
## No Godot engine dependencies -- pure data structure.
class_name BossPool
extends RefCounted


## Shuffled list of all bosses for this run (immutable after creation)
var _shuffled_bosses: Array[Boss] = []

## Index of the next boss to select (0-based)
var _current_index: int = 0


## Constructor: duplicates and shuffles the input boss array
func _init(bosses: Array) -> void:
	_shuffled_bosses = bosses.duplicate()
	_shuffled_bosses.shuffle()
	_current_index = 0


## Returns true if unselected bosses remain
func has_next() -> bool:
	return _current_index < _shuffled_bosses.size()


## Returns the next boss and advances the index
## Returns null if pool is exhausted (caller should check has_next first)
func next() -> Boss:
	if not has_next():
		return null
	var boss = _shuffled_bosses[_current_index]
	_current_index += 1
	return boss


## Returns the next boss WITHOUT advancing the index
## Returns null if pool is exhausted
func peek() -> Boss:
	if not has_next():
		return null
	return _shuffled_bosses[_current_index]


## Resets the pool: re-shuffles and resets index (for future endless mode)
func reset() -> void:
	_shuffled_bosses.shuffle()
	_current_index = 0


## Returns the total number of bosses in the pool
func get_total_count() -> int:
	return _shuffled_bosses.size()


## Returns the number of unselected bosses remaining
func get_remaining_count() -> int:
	return max(0, _shuffled_bosses.size() - _current_index)
