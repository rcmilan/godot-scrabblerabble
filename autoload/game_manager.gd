extends Node

## global game state
## tracks turns and round progression, tile/board states, game phases (shop, game over, victory, etc.)

enum GamePhase {
	SETUP,
	PLAYING,
	GAMEOVER,
	RUNVICTORY
}

# Game state variables

# Current game phase
var current_phase: GamePhase = GamePhase.SETUP

# Current turn number (for single-player progression)
var turn_number: int = 1

# Tiles placed this turn (for word validation)
var tiles_placed_this_turn: Array[Tile] = []


func _ready() -> void:
	#connecting to the eventbus to track game events
	EventBus.tile_placed.connect(_on_tile_placed)
	EventBus.tile_removed.connect(_on_tile_removed)
	print("[GameManager] Ready and listening to events from EventBus")
	
#Starting a new game
func start_game(bag_config: BagDistribution, difficulty: int = 0) -> void:
	current_phase = GamePhase.PLAYING
	turn_number = 1
	tiles_placed_this_turn.clear()
	
	# Initialize tile bag with provided configuration
	if bag_config:
		TileBag.populate_bag(bag_config)
	else:
		push_error("[GameManager] No bag configuration provided!")
		return
	
	#draw initial hand
	await get_tree().process_frame
	HandManager.refill_hand()
	
	EventBus.game_started.emit()
	EventBus.turn_started.emit()
	
	print("[GameManager] Game Started! Turn: ", turn_number, " | Difficulty: ", difficulty)


func _on_tile_placed(tile: Tile, cell: BoardCell) -> void:
	tiles_placed_this_turn.append(tile)
	print("[GameManager] Tile placed. Total this turn: ", tiles_placed_this_turn.size())
	
func _on_tile_removed(tile: Tile, cell: BoardCell) -> void:
	tiles_placed_this_turn.erase(tile)
	print("[GameManager] Tile removed. Total this turn: ", tiles_placed_this_turn.size())
