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
var _quality_tracker: SignalTracker = SignalTracker.new()

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

## Initializes a run from a Run object built by RunBuilder.
func initialize_run_from_builder(run: Run) -> void:
	_debug_auto_win = false
	BackgroundManager.reset_to_default()
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
		prog_config = load("res://data/progression/progression_default.tres")
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


## Returns the active Run object (null if not initialized).
func get_active_run() -> Run:
	return _active_run


## Resets all run state (for returning to title).
## Postcondition: all run state is null/zero/false — no previous run bleeds into the next.
func reset() -> void:
	_disconnect_quality_signals()
	_active_run = null
	run_state = null
	progression_rules = null
	current_round_config = null
	_debug_override_board_size = Vector2i.ZERO
	_debug_auto_win = false
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
	_quality_tracker.track(EventBus.round_started, round_started_cb)

	var play_completed_cb := func(plays_remaining: int) -> void:
		for quality in _active_run.qualities:
			quality.on_play_completed(plays_remaining)
	_quality_tracker.track(EventBus.play_completed, play_completed_cb)

	var score_updated_cb := func(total_score: int, delta: int) -> void:
		for quality in _active_run.qualities:
			quality.on_score_updated(total_score, delta)
	_quality_tracker.track(EventBus.score_updated, score_updated_cb)

	# Connect timer expiry signals from each quality
	for quality in _active_run.qualities:
		var expired_cb := func() -> void:
			_on_quality_time_expired()
		_quality_tracker.track(quality.time_expired, expired_cb)


func _disconnect_quality_signals() -> void:
	_quality_tracker.disconnect_all()
	print("[RunManager] Quality signals disconnected")


func _on_quality_time_expired() -> void:
	print("[RunManager] Timer quality expired - forcing round end")
	GameManager.force_round_end(false)


# =============================================================================
# PRIVATE
# =============================================================================

func _advance_to_next_round() -> void:
	# Get config BEFORE advancing — config reads current_round from run_state
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


## Checks if any quality wants to end the run. Handles the transition if so.
## Returns true if the run was ended (caller should return early).
func _check_quality_win_conditions() -> bool:
	if _active_run == null:
		return false
	for quality in _active_run.qualities:
		if not quality.has_custom_win_condition():
			continue
		var result := quality.check_run_end_condition(run_state)
		if not result.get("should_end", false):
			continue
		var victory: bool = result.get("victory", false)
		run_state.end_run()
		EventBus.run_ended.emit(victory, run_state.total_score)
		print("[RunManager] Quality '%s' ended run - Victory: %s" % [quality.get_quality_name(), victory])
		return true
	return false


func _on_round_ended(round_number: int, success: bool) -> void:
	if not run_state or not run_state.is_run_active:
		return

	if _active_run:
		for quality in _active_run.qualities:
			quality.on_round_ended(round_number, success)

	if not success:
		run_state.end_run()
		EventBus.run_ended.emit(false, run_state.total_score)
		print("[RunManager] Round %d lost - run ended" % round_number)
		return

	run_state.complete_round(GameManager.get_current_score())
	if _check_quality_win_conditions():
		return
	EventBus.run_shop_requested.emit(run_state.current_round)
	print("[RunManager] Round %d won - proceeding to shop" % round_number)
