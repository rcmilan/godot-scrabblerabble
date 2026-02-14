extends Node

## RunManager: Orchestrates the run lifecycle across multiple rounds.
## Owns RunState and ProgressionRules. Coordinates round transitions.
## Dispatches lifecycle events to RunQuality modifiers.

# =============================================================================
# STATE
# =============================================================================

var run_state: RunState = null
var progression_rules: ProgressionRules = null
var current_round_config: RoundConfig = null

# Run builder integration
var _active_run: Run = null
var _quality_connections: Array[Dictionary] = []

# Debug overrides
var _debug_override_board_size: Vector2i = Vector2i.ZERO  # Zero = no override
var _debug_auto_win: bool = false


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	EventBus.round_ended.connect(_on_round_ended)
	print("[RunManager] Ready")


func _process(delta: float) -> void:
	if _active_run == null:
		return
	if not GameManager.is_playing():
		return
	for quality in _active_run.qualities:
		quality.on_process(delta)


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

	_active_run = null
	print("[RunManager] Run initialized - Plays/round: %d | Hand: %d" % [plays_per_round, hand_size])


## Initializes a run from a Run object built by RunBuilder.
func initialize_run_from_builder(run: Run) -> void:
	_active_run = run

	# Set up RunState from the Run config
	run_state = RunState.new()
	run_state.start_run(run.plays_per_round, run.hand_size, run.bag_config)

	# Apply quality modifications to run state
	for quality in run.qualities:
		quality.apply_to_run_state(run_state)

	# Set up progression
	var prog_config := run.progression_config
	if prog_config == null:
		prog_config = load("res://Data/Progression/progression_default.tres")
	progression_rules = ProgressionRules.new(prog_config)

	# Connect quality lifecycle signals
	_connect_quality_signals()

	print("[RunManager] Run initialized from builder - Plays/round: %d | Hand: %d | Qualities: %d" % [
		run_state.plays_per_round, run_state.hand_size, run.qualities.size()
	])


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


## Returns the active Run object (null if using legacy initialize_run).
func get_active_run() -> Run:
	return _active_run


## Resets all run state (for returning to title).
func reset() -> void:
	_disconnect_quality_signals()
	_active_run = null
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
# QUALITY SIGNAL MANAGEMENT
# =============================================================================

func _connect_quality_signals() -> void:
	_disconnect_quality_signals()

	if _active_run == null:
		return

	# Connect EventBus signals to forward to qualities
	var round_started_cb := func(round_number: int) -> void:
		for quality in _active_run.qualities:
			quality.on_round_started(round_number)
	EventBus.round_started.connect(round_started_cb)
	_quality_connections.append({"signal": EventBus.round_started, "callable": round_started_cb})

	var play_completed_cb := func(plays_remaining: int) -> void:
		for quality in _active_run.qualities:
			quality.on_play_completed(plays_remaining)
	EventBus.play_completed.connect(play_completed_cb)
	_quality_connections.append({"signal": EventBus.play_completed, "callable": play_completed_cb})

	var score_updated_cb := func(total_score: int, delta: int) -> void:
		for quality in _active_run.qualities:
			quality.on_score_updated(total_score, delta)
	EventBus.score_updated.connect(score_updated_cb)
	_quality_connections.append({"signal": EventBus.score_updated, "callable": score_updated_cb})

	# Connect timer expiry signals from each quality
	for quality in _active_run.qualities:
		var expired_cb := func() -> void:
			_on_quality_time_expired()
		quality.time_expired.connect(expired_cb)
		_quality_connections.append({"signal": quality.time_expired, "callable": expired_cb})


func _disconnect_quality_signals() -> void:
	for conn in _quality_connections:
		var sig: Signal = conn["signal"]
		var cb: Callable = conn["callable"]
		if sig.is_connected(cb):
			sig.disconnect(cb)
	_quality_connections.clear()


func _on_quality_time_expired() -> void:
	print("[RunManager] Timer quality expired - forcing round end")
	GameManager.force_round_end(false)


# =============================================================================
# PRIVATE
# =============================================================================

func _advance_to_next_round() -> void:
	# Get config BEFORE advancing (get_next_round_number uses current_round + 1)
	current_round_config = progression_rules.get_round_config(run_state)

	# Now advance the round counter to match
	run_state.advance_round()

	# Apply quality modifications to round config
	if _active_run:
		for quality in _active_run.qualities:
			quality.apply_to_round_config(current_round_config)

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

	# Forward to qualities
	if _active_run:
		for quality in _active_run.qualities:
			quality.on_round_ended(round_number, success)

	if success:
		run_state.complete_round(GameManager.get_current_score())

		# Check custom win conditions from qualities
		if _active_run:
			for quality in _active_run.qualities:
				if quality.has_custom_win_condition():
					var result := quality.check_run_end_condition(run_state)
					if result.get("should_end", false):
						var victory: bool = result.get("victory", false)
						run_state.end_run()
						EventBus.run_ended.emit(victory, run_state.total_score)
						print("[RunManager] Quality '%s' ended run - Victory: %s" % [quality.get_quality_name(), victory])
						return

		EventBus.run_shop_requested.emit(run_state.current_round)
		print("[RunManager] Round %d won - proceeding to shop" % round_number)
	else:
		run_state.end_run()
		EventBus.run_ended.emit(false, run_state.total_score)
		print("[RunManager] Round %d lost - run ended" % round_number)
