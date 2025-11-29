extends Node

const Scoring = preload("res://scripts/logic/scoring.gd")

## GameManager autoload for managing game state and flow
## Handles turns, scoring, and game loop for ScrabbleRabble

# Game state variables
var current_turn: int = 0
var total_score: int = 0
var target_score: int = 100  # Default target score
var max_turns: int = 10      # Default max turns
var tiles_per_turn: int = 7  # Default tiles per turn

# Component references
var board: Node
var rack: Node
var scoring: Scoring
var event_bus: Node

# Internal state
var tiles_placed_this_turn: int = 0

func _ready() -> void:
	# Get references to game components
	board = get_node("/root/Main/Board")  # Assuming Board is child of Main
	rack = get_node("/root/Main/Rack")    # Assuming Rack is child of Main
	event_bus = get_node("/root/EventBus")
	scoring = Scoring.new()

	# TODO: Make paths configurable or find nodes dynamically

## Initialize and start a new game
func start_game() -> void:
	current_turn = 0
	total_score = 0
	tiles_placed_this_turn = 0
	board.board_model.clear_temporary_tiles()
	board.board_model.commit_tiles()  # Reset permanent
	rack.clear_rack()  # Assuming method exists, TODO: implement if not
	start_turn()

## Start a new turn
func start_turn() -> void:
	current_turn += 1
	tiles_placed_this_turn = 0
	rack.refill(tiles_per_turn)
	event_bus.emit_signal("turn_started", current_turn)

## End the current turn, evaluate score, and check game over
func end_turn() -> void:
	var score_added = scoring.evaluate_board(board)
	total_score += score_added
	board.commit_tiles()
	event_bus.emit_signal("turn_ended", current_turn, score_added)

	if current_turn >= max_turns:
		var won = total_score >= target_score
		event_bus.emit_signal("game_over", won)
	else:
		start_turn()

## Place a tile on the board at the given position
func place_tile(tile: Node2D, pos: Vector2i) -> void:
	if board.place_tile(tile, pos):
		tiles_placed_this_turn += 1
		# Remove from rack
		var index = rack.tiles.find(tile)
		if index >= 0:
			rack.remove_tile(index)
		# Check if all tiles placed
		if tiles_placed_this_turn >= tiles_per_turn:
			on_all_tiles_placed()

## Called when all tiles for the turn have been placed
func on_all_tiles_placed() -> void:
	end_turn()

# TODO: Add method to reset game
# TODO: Add method to pause/resume game
# TODO: Add validation for word placement (dictionary check)
# TODO: Add support for multiple players
# TODO: Add game settings configuration
# TODO: Add save/load game state