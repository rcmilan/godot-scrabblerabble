extends Node

## GameManager: Central game state controller.
## Manages game phases, score tracking, and coordinates between systems.
## Acts as the single source of truth for game-wide state.

# =============================================================================
# GAME PHASE STATE MACHINE
# =============================================================================

enum GamePhase {
	SETUP,       # Initial setup, loading resources
	PLAYING,     # Active gameplay
	PAUSED,      # Game paused
	ROUND_END,   # Round ended, processing results
	GAME_OVER,   # Game lost
	VICTORY      # Game/run won
}

# =============================================================================
# GAME STATE
# =============================================================================

var current_phase: GamePhase = GamePhase.SETUP
var current_round: int = 1
var current_score: int = 0
var target_score: int = 100
var plays_remaining: int = 10
var plays_per_round: int = 10
var difficulty: int = 0

# =============================================================================
# TURN STATE
# =============================================================================

var tiles_placed_this_turn: Array[Tile] = []
var words_scored_this_turn: Array[String] = []
var points_earned_this_turn: int = 0

# =============================================================================
# CONFIGURATION
# =============================================================================

const DEFAULT_HAND_SIZE: int = 10
const DEFAULT_PLAYS_PER_ROUND: int = 2
const DEFAULT_TARGET_SCORE: int = 100


func _ready() -> void:
	_connect_signals()
	print("[GameManager] Ready")


# =============================================================================
# PUBLIC API: GAME LIFECYCLE
# =============================================================================

## Starts a new game with the given configuration.
func start_game(bag_config: BagDistribution, game_difficulty: int = 0) -> void:
	if bag_config == null:
		push_error("[GameManager] Cannot start game without bag configuration!")
		return

	# Reset state
	difficulty = game_difficulty
	current_round = 1
	current_score = 0
	plays_remaining = plays_per_round
	tiles_placed_this_turn.clear()
	words_scored_this_turn.clear()
	points_earned_this_turn = 0

	# Initialize bag
	TileBag.populate_bag(bag_config)

	# Transition to playing
	_set_phase(GamePhase.PLAYING)

	# Wait for HandManager to be ready before drawing
	if not HandManager.is_initialized():
		await HandManager.initialized

	HandManager.refill_hand()

	EventBus.game_started.emit()
	EventBus.round_started.emit(current_round)

	print("[GameManager] Game started - Round: %d | Difficulty: %d" % [current_round, difficulty])


## Ends the current game.
func end_game(victory: bool) -> void:
	_set_phase(GamePhase.VICTORY if victory else GamePhase.GAME_OVER)
	EventBus.game_ended.emit(victory)

	if victory:
		EventBus.game_won.emit()
		print("[GameManager] Victory! Final score: %d" % current_score)
	else:
		EventBus.game_lost.emit()
		print("[GameManager] Game Over. Final score: %d" % current_score)


## Pauses the game.
func pause_game() -> void:
	if current_phase == GamePhase.PLAYING:
		_set_phase(GamePhase.PAUSED)
		EventBus.game_paused.emit()


## Resumes the game.
func resume_game() -> void:
	if current_phase == GamePhase.PAUSED:
		_set_phase(GamePhase.PLAYING)
		EventBus.game_resumed.emit()


# =============================================================================
# PUBLIC API: ROUND/PLAY MANAGEMENT
# =============================================================================

## Commits the current play and processes scoring.
func commit_play(score: int) -> void:
	if current_phase != GamePhase.PLAYING:
		return

	# Update score
	current_score += score
	points_earned_this_turn += score

	# Update plays
	plays_remaining -= 1

	EventBus.score_updated.emit(current_score, score)
	EventBus.play_completed.emit(plays_remaining)

	print("[GameManager] Play committed: +%d pts | Total: %d | Plays left: %d" % [
		score, current_score, plays_remaining
	])

	# Check win/lose conditions
	if current_score >= target_score:
		_complete_round(true)
	elif plays_remaining <= 0:
		if RunManager.is_debug_auto_win():
			print("[GameManager] Debug auto-win enabled - treating as round win")
			_complete_round(true)
		else:
			_complete_round(false)


## Returns tiles to hand and resets turn state.
func cancel_play() -> void:
	tiles_placed_this_turn.clear()
	print("[GameManager] Play cancelled")


## Starts a new round.
func start_round(round_num: int, target: int = DEFAULT_TARGET_SCORE, plays: int = DEFAULT_PLAYS_PER_ROUND) -> void:
	current_round = round_num
	target_score = target
	plays_per_round = plays
	plays_remaining = plays
	tiles_placed_this_turn.clear()
	words_scored_this_turn.clear()
	points_earned_this_turn = 0

	_set_phase(GamePhase.PLAYING)
	EventBus.round_started.emit(current_round)

	print("[GameManager] Round %d started - Target: %d | Plays: %d" % [
		current_round, target_score, plays_remaining
	])


## Sets up a round from a RoundConfig object.
func setup_round(config: RoundConfig) -> void:
	current_round = config.round_number
	target_score = config.target_score
	plays_per_round = config.plays_per_round
	plays_remaining = config.plays_per_round
	current_score = 0
	tiles_placed_this_turn.clear()
	words_scored_this_turn.clear()
	points_earned_this_turn = 0

	_set_phase(GamePhase.PLAYING)
	EventBus.round_started.emit(current_round)

	print("[GameManager] Round %d setup - Target: %d | Plays: %d" % [
		current_round, target_score, plays_remaining
	])


# =============================================================================
# PUBLIC API: QUERIES
# =============================================================================

func is_playing() -> bool:
	return current_phase == GamePhase.PLAYING


func is_game_over() -> bool:
	return current_phase in [GamePhase.GAME_OVER, GamePhase.VICTORY]


func get_tiles_placed_count() -> int:
	return tiles_placed_this_turn.size()


func has_placed_tiles() -> bool:
	return not tiles_placed_this_turn.is_empty()


# =============================================================================
# PRIVATE: SIGNAL HANDLERS
# =============================================================================

func _connect_signals() -> void:
	EventBus.tile_placed.connect(_on_tile_placed)
	EventBus.tile_removed.connect(_on_tile_removed)


func _on_tile_placed(tile: Tile, _cell: BoardCell) -> void:
	if current_phase != GamePhase.PLAYING:
		return

	tiles_placed_this_turn.append(tile)
	print("[GameManager] Tile placed: %s | Count: %d" % [tile.letter, tiles_placed_this_turn.size()])


func _on_tile_removed(tile: Tile, _cell: BoardCell) -> void:
	tiles_placed_this_turn.erase(tile)
	print("[GameManager] Tile removed: %s | Count: %d" % [tile.letter, tiles_placed_this_turn.size()])


# =============================================================================
# PRIVATE: STATE MANAGEMENT
# =============================================================================

func _set_phase(new_phase: GamePhase) -> void:
	var old_phase: GamePhase = current_phase
	current_phase = new_phase
	print("[GameManager] Phase: %s -> %s" % [
		GamePhase.keys()[old_phase],
		GamePhase.keys()[new_phase]
	])


func _complete_round(success: bool) -> void:
	_set_phase(GamePhase.ROUND_END)
	EventBus.round_ended.emit(current_round, success)

	if success:
		print("[GameManager] Round %d complete! Score: %d/%d" % [
			current_round, current_score, target_score
		])
		# RunManager handles what comes next (shop or victory)
	else:
		print("[GameManager] Round %d failed. Score: %d/%d" % [
			current_round, current_score, target_score
		])
		# RunManager handles game over
