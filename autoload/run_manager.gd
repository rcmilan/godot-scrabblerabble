extends Node

## RunManager: Orchestrates the run lifecycle across multiple rounds.
## Owns RunState and ProgressionRules. Coordinates round transitions.

# =============================================================================
# STATE
# =============================================================================

var run_state: RunState = null
var progression_rules: ProgressionRules = null
var current_round_config: RoundConfig = null

# Debug overrides
var _debug_override_board_size: Vector2i = Vector2i.ZERO  # Zero = no override
var _debug_auto_win: bool = false


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	EventBus.round_ended.connect(_on_round_ended)
	print("[RunManager] Ready")


# =============================================================================
# PUBLIC API: RUN LIFECYCLE
# =============================================================================

## Initializes a new run. Call BEFORE changing scene to Main.
func initialize_run(
	bag_config: BagDistribution,
	plays_per_round: int = 2,
	hand_size: int = 10,
	progression_config: ProgressionConfig = null
) -> void:
	run_state = RunState.new()
	run_state.start_run(plays_per_round, hand_size, bag_config)

	if progression_config == null:
		progression_config = load("res://Data/Progression/progression_default.tres")
	progression_rules = ProgressionRules.new(progression_config)

	print("[RunManager] Run initialized - Plays/round: %d | Hand: %d" % [plays_per_round, hand_size])


## Starts the run (called by Main._ready after scene loads).
func start_run() -> void:
	if run_state == null:
		push_error("[RunManager] Cannot start run - not initialized")
		return
	_advance_to_next_round()


## Returns the current round config for Main to configure the board/game.
func get_current_round_config() -> RoundConfig:
	return current_round_config


## Called when player leaves shop and is ready for the next round.
func proceed_from_shop() -> void:
	_advance_to_next_round()


## Resets all run state (for returning to title).
func reset() -> void:
	run_state = null
	progression_rules = null
	current_round_config = null
	_debug_override_board_size = Vector2i.ZERO
	print("[RunManager] Reset")


# =============================================================================
# DEBUG API
# =============================================================================

func set_debug_board_override(size: Vector2i) -> void:
	_debug_override_board_size = size
	print("[RunManager] Debug board override set: %s" % size)


func clear_debug_board_override() -> void:
	_debug_override_board_size = Vector2i.ZERO


func set_debug_auto_win(enabled: bool) -> void:
	_debug_auto_win = enabled
	print("[RunManager] Debug auto-win: %s" % enabled)


func is_debug_auto_win() -> bool:
	return _debug_auto_win


# =============================================================================
# PRIVATE
# =============================================================================

func _advance_to_next_round() -> void:
	# Get config BEFORE advancing (get_next_round_number uses current_round + 1)
	current_round_config = progression_rules.get_round_config(run_state)

	# Now advance the round counter to match
	run_state.advance_round()

	# Apply debug overrides (one-shot)
	if _debug_override_board_size != Vector2i.ZERO:
		current_round_config.board_rows = _debug_override_board_size.y
		current_round_config.board_columns = _debug_override_board_size.x
		_debug_override_board_size = Vector2i.ZERO

	EventBus.run_round_ready.emit(current_round_config)
	print("[RunManager] %s" % current_round_config)


func _on_round_ended(round_number: int, success: bool) -> void:
	if not run_state or not run_state.is_run_active:
		return

	if success:
		run_state.complete_round(GameManager.get_current_score())
		EventBus.run_shop_requested.emit(run_state.current_round)
		print("[RunManager] Round %d won - proceeding to shop" % round_number)
	else:
		run_state.end_run()
		EventBus.run_ended.emit(false, run_state.total_score)
		print("[RunManager] Round %d lost - run ended" % round_number)
