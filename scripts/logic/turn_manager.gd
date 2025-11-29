extends Node

## TurnManager class to handle turn-based gameplay logic
class_name TurnManager

## Signal emitted when a turn is completed, with a summary string
signal turn_completed(summary: String)

## Current turn number
var current_turn: int = 0

## Number of tiles placed in the current turn
var tiles_placed_this_turn: int = 0

## Maximum number of tiles allowed per turn
var max_tiles_per_turn: int = 7  # Default value, can be adjusted

## Starts a new turn with the given turn number
func start_turn(turn_num: int) -> void:
	current_turn = turn_num
	tiles_placed_this_turn = 0
	print("Turn %d started" % current_turn)

## Increments the count of tiles placed this turn
func place_tile() -> void:
	tiles_placed_this_turn += 1
	print("Tile placed. Total tiles this turn: %d" % tiles_placed_this_turn)

## Checks if the current turn is complete based on tiles placed
func is_turn_complete() -> bool:
	return tiles_placed_this_turn >= max_tiles_per_turn

## Ends the current turn and emits completion signal with summary
func end_turn() -> void:
	var summary: String = "Turn %d completed. Tiles placed: %d/%d" % [current_turn, tiles_placed_this_turn, max_tiles_per_turn]
	turn_completed.emit(summary)
	print(summary)

# TODO: Implement advanced turn logic such as time limits, special actions, or turn validation