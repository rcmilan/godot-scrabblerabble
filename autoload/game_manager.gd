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

var _current_phase: GamePhase = GamePhase.SETUP
var _current_round: int = 1
var _current_score: int = 0
var _target_score: int = 100
var _plays_remaining: int = 10
var _plays_per_round: int = 10
var _difficulty: int = 0


# =============================================================================
# GETTERS
# =============================================================================

func get_current_phase() -> GamePhase:
	return _current_phase

func get_current_round() -> int:
	return _current_round

func get_current_score() -> int:
	return _current_score

func get_target_score() -> int:
	return _target_score

func get_plays_remaining() -> int:
	return _plays_remaining

func get_plays_per_round() -> int:
	return _plays_per_round

func get_difficulty() -> int:
	return _difficulty

# =============================================================================
# CONFIGURATION
# =============================================================================

const DEFAULT_HAND_SIZE: int = 10
const DEFAULT_PLAYS_PER_ROUND: int = 2
const DEFAULT_TARGET_SCORE: int = 1000000


func _ready() -> void:
	print("[GameManager] Ready")


# =============================================================================
# PUBLIC API: GAME LIFECYCLE
# =============================================================================

## Ends the current game.
func end_game(victory: bool) -> void:
	_set_phase(GamePhase.VICTORY if victory else GamePhase.GAME_OVER)
	EventBus.game_ended.emit(victory)

	if victory:
		EventBus.game_won.emit()
		print("[GameManager] Victory! Final score: %d" % _current_score)
	else:
		EventBus.game_lost.emit()
		print("[GameManager] Game Over. Final score: %d" % _current_score)


## Pauses the game.
func pause_game() -> void:
	if _current_phase == GamePhase.PLAYING:
		_set_phase(GamePhase.PAUSED)
		EventBus.game_paused.emit()


## Resumes the game.
func resume_game() -> void:
	if _current_phase == GamePhase.PAUSED:
		_set_phase(GamePhase.PLAYING)
		EventBus.game_resumed.emit()


# =============================================================================
# PUBLIC API: ROUND/PLAY MANAGEMENT
# =============================================================================

## Commits the current play and processes scoring.
func commit_play(score: int) -> void:
	if _current_phase != GamePhase.PLAYING:
		return

	# Update score
	_current_score += score

	# Update plays
	_plays_remaining -= 1

	EventBus.score_updated.emit(_current_score, score)
	EventBus.play_completed.emit(_plays_remaining)

	print("[GameManager] Play committed: +%d pts | Total: %d | Plays left: %d" % [
		score, _current_score, _plays_remaining
	])

	# Check win/lose conditions
	if _current_score >= _target_score:
		_complete_round(true)
	elif _plays_remaining <= 0:
		if RunManager.is_debug_auto_win():
			print("[GameManager] Debug auto-win enabled - treating as round win")
			_complete_round(true)
		else:
			_complete_round(false)


## Starts a new round.
func start_round(round_num: int, target: int = DEFAULT_TARGET_SCORE, plays: int = DEFAULT_PLAYS_PER_ROUND) -> void:
	_current_round = round_num
	_target_score = target
	_plays_per_round = plays
	_plays_remaining = plays

	_set_phase(GamePhase.PLAYING)
	EventBus.round_started.emit(_current_round)

	print("[GameManager] Round %d started - Target: %d | Plays: %d" % [
		_current_round, _target_score, _plays_remaining
	])


## Sets up a round from a RoundConfig object.
func setup_round(config: RoundConfig) -> void:
	_current_round = config.round_number
	_target_score = config.target_score
	_plays_per_round = config.plays_per_round
	_plays_remaining = config.plays_per_round
	_current_score = 0

	_set_phase(GamePhase.PLAYING)
	EventBus.round_started.emit(_current_round)

	print("[GameManager] Round %d setup - Target: %d | Plays: %d" % [
		_current_round, _target_score, _plays_remaining
	])


# =============================================================================
# PUBLIC API: FORCED ROUND END (used by timer qualities)
# =============================================================================

## Forces the current round to end. Used by timer qualities to trigger round failure.
func force_round_end(success: bool) -> void:
	if _current_phase == GamePhase.PLAYING:
		_complete_round(success)


# =============================================================================
# PUBLIC API: QUERIES
# =============================================================================

func is_playing() -> bool:
	return _current_phase == GamePhase.PLAYING


func is_game_over() -> bool:
	return _current_phase in [GamePhase.GAME_OVER, GamePhase.VICTORY]


# =============================================================================
# PRIVATE: STATE MANAGEMENT
# =============================================================================

func _set_phase(new_phase: GamePhase) -> void:
	var old_phase: GamePhase = _current_phase
	_current_phase = new_phase
	print("[GameManager] Phase: %s -> %s" % [
		GamePhase.keys()[old_phase],
		GamePhase.keys()[new_phase]
	])


func _complete_round(success: bool) -> void:
	_set_phase(GamePhase.ROUND_END)
	EventBus.round_ended.emit(_current_round, success)

	if success:
		print("[GameManager] Round %d complete! Score: %d/%d" % [
			_current_round, _current_score, _target_score
		])
		# RunManager handles what comes next (shop or victory)
	else:
		print("[GameManager] Round %d failed. Score: %d/%d" % [
			_current_round, _current_score, _target_score
		])
		# RunManager handles game over
