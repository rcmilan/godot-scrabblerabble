extends Node

# TurnManager: Manages the state of turns, including the current turn number.

var _current_turn = 0

func get_current_turn() -> int:
	return _current_turn

func next_turn():
	_current_turn += 1

func reset():
	_current_turn = 0
