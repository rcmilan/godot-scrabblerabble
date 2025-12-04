extends Node

# GameManager: Controls the main game loop and state.

var _turn_manager = preload("res://scripts/logic/turn_manager.gd").new()
var _board_model = preload("res://scripts/core/board_model.gd").new()
var _scoring = preload("res://scripts/logic/scoring.gd").new()

var _current_score = 0
var _target_score = 100 # Example target score
const MAX_TURNS = 10 # Example turn limit
const TILES_PER_TURN = 7

var _tiles_placed_this_turn: int = 0

func _ready():
	# Connect to signals from the EventBus
	EventBus.connect("tile_placed", Callable(self, "_on_tile_placed"))
	EventBus.connect("turn_ended", Callable(self, "_on_turn_ended"))

	# Ensure TileBag is available and expose remaining tiles if needed
	if TileBag:
		# TileBag is an autoload; nothing to do here but keep reference
		pass

	start_new_game()

func start_new_game():
	_current_score = 0
	_turn_manager.reset()
	_board_model._initialize_grid() # Reset the board model

	# Add child nodes for script instances to process
	add_child(_turn_manager)
	add_child(_board_model)
	add_child(_scoring)

	start_next_turn()

func start_next_turn():
	if _turn_manager.get_current_turn() > MAX_TURNS:
		end_game()
		return

	_tiles_placed_this_turn = 0
	_turn_manager.next_turn()
	# Emit the turn_started signal; UI and Rack should react to draw tiles.
	EventBus.emit_signal("turn_started", _turn_manager.get_current_turn())
	# Optionally pre-fetch tiles from the TileBag (Rack also requests tiles when it hears turn_started)
	if TileBag:
		TileBag.draw_tiles(TILES_PER_TURN)

func _on_tile_placed(tile_data, grid_position):
	# Provisional scoring for placing a tile
	_current_score += tile_data.value
	EventBus.emit_signal("score_updated", _current_score)

	# Place the tile in the board model
	_board_model.place_tile(tile_data, grid_position)

	_tiles_placed_this_turn += 1
	# If the player placed all tiles for this turn, end the turn
	if _tiles_placed_this_turn >= TILES_PER_TURN:
		# Emit turn_ended to trigger scoring and next turn
		EventBus.emit_signal("turn_ended", _turn_manager.get_current_turn())

func _on_turn_ended(turn_number):
	# Evaluate the entire board for words and score them
	var board_state = _board_model.get_grid_state()
	var turn_score = _scoring.evaluate_board(board_state)
	_current_score += turn_score
	EventBus.emit_signal("score_updated", _current_score)

	# Start the next turn
	start_next_turn()

func end_game():
	if _current_score >= _target_score:
		# Player wins
		EventBus.emit_signal("game_over", _current_score, true)
	else:
		# Player loses
		EventBus.emit_signal("game_over", _current_score, false)

# TODO: Add logic for level progression and increasing target scores.
