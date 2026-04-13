class_name PlayExecutor
extends RefCounted

## PlayExecutor: Handles play submission by delegating to PlayValidator
## and dispatching animations via AnimationCategorizer.
## Replaces PlayHandler's play logic with lower cyclomatic complexity.

# =============================================================================
# SIGNALS
# =============================================================================

signal play_completed(tiles: Array[Tile], words: Array)
signal play_button_changed(enabled: bool, end_round_mode: bool)

# =============================================================================
# DEPENDENCIES (injected via setup)
# =============================================================================

var board: Board = null
var _play_validator: PlayValidator = null
var _word_validator: WordValidator = null
var _selection: SelectionManager = null
var _round_config: RoundConfig = null

# =============================================================================
# HYPE SEQUENCE STATE
# =============================================================================

var _is_sequence_active: bool = false
var _hud: CanvasLayer = null
var _hype_params: Dictionary = {}


func setup(p_board: Board, p_selection: SelectionManager) -> void:
	board = p_board
	_selection = p_selection
	_word_validator = WordValidator.new()
	_play_validator = PlayValidator.new(_word_validator)


## Sets the current round config (called from Main._on_round_ready)
func set_round_config(config: RoundConfig) -> void:
	_round_config = config


## Sets the HUD CanvasLayer for score pop label parenting
func set_hud(hud: CanvasLayer) -> void:
	_hud = hud


## Returns true if a play sequence is currently active
func is_sequence_active() -> bool:
	return _is_sequence_active


func get_word_validator() -> WordValidator:
	return _word_validator


# =============================================================================
# PLAY HANDLING (CC 3)
# =============================================================================

## Called when the player presses the Play/End Round button.
func on_play_requested() -> void:
	var unplayed_tiles: Array[Tile] = _get_unplayed_board_tiles()

	if unplayed_tiles.is_empty():
		if not has_valid_moves() and GameManager.get_plays_remaining() > 0:
			_auto_end_round()
			return
		print("[Gameplay] Play rejected: no unplayed tiles on board")
		return

	await _execute_play(unplayed_tiles)
	update_play_button_state()


## Executes a single play: validate, lock, animate, consume, emit.
func _execute_play(unplayed_tiles: Array[Tile]) -> void:
	# Set sequence lock and notify systems
	_is_sequence_active = true
	EventBus.play_sequence_started.emit()

	# Compute hype parameters for this play
	_hype_params = _compute_hype_params(unplayed_tiles)

	# Lock unplayed tiles via modifier system
	for tile in unplayed_tiles:
		tile.set_locked(true)

	_selection.deselect_all()

	# LIFT PHASE: All tiles lift uniformly before other animations
	var all_tiles_for_lift: Array[Tile] = _get_all_board_tiles()
	if not all_tiles_for_lift.is_empty():
		TileAnimator.animate_lift_batch(all_tiles_for_lift)
		await TileAnimator.animation_completed

	# Execute boss post-play effects (e.g., gravity drop)
	if _round_config and _round_config.boss:
		await _execute_boss_post_play_effects(unplayed_tiles)

	# Build positions AFTER boss effects so words are detected at final positions
	var positions: Array[Vector2i] = []
	for tile in unplayed_tiles:
		if tile.current_cell:
			positions.append(tile.current_cell.grid_position)

	var words: Array = _word_validator.find_formed_words(board, positions)

	for word_info in words:
		print("[Gameplay] Word formed: '%s' (%s, %d letters)" % [
			word_info.word, word_info.direction, word_info.word.length()
		])

	# Calculate total play score for emission
	var total_score: int = 0
	for word_info in words:
		var score_result: Dictionary = _word_validator.calculate_placement_score(
			word_info.tiles, word_info.cells
		)
		total_score += score_result.total
		EventBus.score_calculated.emit(score_result.total, score_result)
		print("[Gameplay] Word '%s' scored: %d" % [word_info.word, score_result.total])

	# Animate ALL board tiles with stagger-matched scoring
	var all_tiles: Array[Tile] = _get_all_board_tiles()
	var cats: Dictionary = AnimationCategorizer.categorize(all_tiles)

	# Launch stagger scoring concurrently (runs during animation)
	_commit_scores_staggered(total_score, cats.stomp.size(), cats.spin.size())
	print("[Gameplay] Play total: %d pts across %d word(s)" % [total_score, words.size()])

	await _animate_play_from_cats(cats)

	# Finalize play (decrement plays, check win/lose condition)
	GameManager.end_play()

	# Consume CONSUMABLE modifiers on newly played tiles after animation
	for tile in unplayed_tiles:
		tile.consume_modifiers()

	EventBus.tiles_played.emit(unplayed_tiles, words)
	play_completed.emit(unplayed_tiles, words)

	# Auto-refill hand after a brief delay so player sees the result
	await board.get_tree().create_timer(0.5).timeout
	HandManager.refill_hand()

	# Sequence cleanup: clear sequence lock and notify
	_is_sequence_active = false
	_hype_params.clear()
	EventBus.play_sequence_ended.emit()

	print("[Gameplay] Play accepted: %d tiles locked, %d words found" % [
		unplayed_tiles.size(), words.size()
	])


## Executes boss post-play effects (e.g., gravity drop).
func _execute_boss_post_play_effects(unplayed_tiles: Array[Tile]) -> void:
	var boss = _round_config.boss
	if not boss:
		return

	# Build grid occupancy (2D bool array)
	var grid_occupancy: Array = []
	for row in range(board.rows):
		var row_array: Array = []
		for col in range(board.columns):
			var cell = board.get_cell(row, col)
			row_array.append(cell != null and (cell.is_occupied() or cell.is_unavailable()))
		grid_occupancy.append(row_array)

	# Collect unplayed positions
	var unplayed_positions: Array[Vector2i] = []
	for tile in unplayed_tiles:
		if tile.current_cell:
			unplayed_positions.append(tile.current_cell.grid_position)

	# Get post-play movements from boss
	var movements_raw: Array = boss.hooks.get_post_play_movements(
		grid_occupancy, unplayed_positions, board.rows, board.columns
	)

	if movements_raw.is_empty():
		return

	# Resolve Vector2i positions to BoardCell references
	var resolved_movements: Array = []
	for movement in movements_raw:
		var from_pos: Vector2i = movement["from"]
		var to_pos: Vector2i = movement["to"]
		var from_cell = board.get_cell(from_pos.y, from_pos.x)
		var to_cell = board.get_cell(to_pos.y, to_pos.x)

		if from_cell and from_cell.is_occupied() and to_cell:
			resolved_movements.append({
				"tile": from_cell.tile,
				"from_cell": from_cell,
				"to_cell": to_cell
			})

	if resolved_movements.is_empty():
		return

	# Disable play button during animation
	play_button_changed.emit(false, false)

	# Execute drop animation
	TileAnimator.animate_drop_batch(resolved_movements)
	await TileAnimator.animation_completed

	# Rebind cells after drop animation
	_rebind_cells_after_drop(resolved_movements)


## Rebinds tiles to their new cells after drop animation.
## Processes from bottom-to-top to avoid conflicts when multiple tiles drop in same column.
func _rebind_cells_after_drop(movements: Array) -> void:
	# Sort movements by row descending (bottom-to-top)
	movements.sort_custom(func(a, b): return a["to_cell"].grid_position.y > b["to_cell"].grid_position.y)

	for movement in movements:
		var tile: Tile = movement["tile"]
		var from_cell: BoardCell = movement["from_cell"]
		var to_cell: BoardCell = movement["to_cell"]

		# Remove tile from original cell
		from_cell.remove_tile()
		# Place tile on new cell
		to_cell.place_tile(tile)
		# Rebind tile to new cell
		tile.attach_to_cell(to_cell)


## Commits score per animated tile at stagger intervals during animation.
## Runs concurrently (not awaited by caller) so scores tick during stomps/spins.
func _commit_scores_staggered(total_score: int, stomp_count: int, spin_count: int) -> void:
	var tile_count: int = stomp_count + spin_count
	if tile_count <= 0 or total_score <= 0:
		if total_score > 0:
			GameManager.add_tile_score(total_score)
		return

	var per_tile: int = total_score / tile_count
	var remainder: int = total_score % tile_count
	var scored: int = 0

	if stomp_count > 0:
		var stomp_config := StompTileAnimation.new()
		var slam_time: float = stomp_config.rise_duration + stomp_config.slam_duration
		await board.get_tree().create_timer(slam_time).timeout

		for i in stomp_count:
			var score: int = per_tile + (1 if scored < remainder else 0)
			GameManager.add_tile_score(score)
			scored += 1
			if scored < tile_count:
				await board.get_tree().create_timer(stomp_config.stagger_delay).timeout

	if spin_count > 0:
		var spin_config := SpinTileAnimation.new()
		if stomp_count == 0:
			await board.get_tree().create_timer(spin_config.spin_up_duration).timeout

		for i in spin_count:
			var score: int = per_tile + (1 if scored < remainder else 0)
			GameManager.add_tile_score(score)
			scored += 1
			if scored < tile_count:
				await board.get_tree().create_timer(spin_config.stagger_delay).timeout


## Animates tiles from pre-categorized groups.
## Stomp tiles animate first, then spin tiles -- sequential, not parallel.
func _animate_play_from_cats(cats: Dictionary) -> void:
	# Hide locked border during animations
	var all_tiles: Array[Tile] = []
	all_tiles.append_array(cats.stomp)
	all_tiles.append_array(cats.spin)
	for tile in all_tiles:
		if tile.locked_border:
			tile.locked_border.visible = false

	if not cats.stomp.is_empty():
		TileAnimator.animate_stomp_batch(cats.stomp)
		await TileAnimator.animation_completed

	if not cats.spin.is_empty():
		TileAnimator.animate_spin_batch(cats.spin)
		await TileAnimator.animation_completed


## Animates tiles using AnimationCategorizer dispatch.
func _animate_play(all_tiles: Array[Tile]) -> void:
	var cats: Dictionary = AnimationCategorizer.categorize(all_tiles)
	await _animate_play_from_cats(cats)


# =============================================================================
# AUTO END ROUND
# =============================================================================

func _auto_end_round() -> void:
	print("[Gameplay] Auto end round: consuming %d remaining plays" % GameManager.get_plays_remaining())

	play_button_changed.emit(false, false)

	var all_tiles: Array[Tile] = _get_all_board_tiles()
	if all_tiles.is_empty():
		print("[Gameplay] Auto end round: no tiles on board")
		update_play_button_state()
		return

	# Lock any remaining unlocked tiles
	for tile in all_tiles:
		if not tile.is_locked:
			tile.set_locked(true)

	# Calculate score once (board state is constant across all auto-plays)
	var positions: Array[Vector2i] = []
	for tile in all_tiles:
		if tile.current_cell:
			positions.append(tile.current_cell.grid_position)

	var words: Array = _word_validator.find_formed_words(board, positions)
	var total_score: int = 0
	for word_info in words:
		var score_result: Dictionary = _word_validator.calculate_placement_score(
			word_info.tiles, word_info.cells
		)
		total_score += score_result.total
		EventBus.score_calculated.emit(score_result.total, score_result)

	print("[Gameplay] Auto end round: scoring %d pts per play from %d words" % [total_score, words.size()])

	# Categorize once (modifiers don't change between loops)
	var cats: Dictionary = AnimationCategorizer.categorize(all_tiles)

	while GameManager.get_current_phase() == GameManager.GamePhase.PLAYING and GameManager.get_plays_remaining() > 0:
		# Launch stagger scoring concurrently
		_commit_scores_staggered(total_score, cats.stomp.size(), cats.spin.size())

		await _animate_play_from_cats(cats)

		# Finalize play
		GameManager.end_play()

	update_play_button_state()
	print("[Gameplay] Auto end round complete")


# =============================================================================
# HYPE SEQUENCE SUPPORT
# =============================================================================

## Computes hype parameters for the current play (tile count, speed multiplier, scaled timings)
func _compute_hype_params(unplayed_tiles: Array[Tile]) -> Dictionary:
	var hype_config: HypeConfig = TileAnimator.hype_config
	if not hype_config:
		return {}

	var tile_count: int = unplayed_tiles.size()
	var tile_count_mult: float = hype_config.get_tile_count_multiplier(tile_count)
	var effective_mult: float = tile_count_mult * hype_config.master_speed_multiplier

	var params := {
		"tile_count": tile_count,
		"tile_count_multiplier": tile_count_mult,
		"effective_multiplier": effective_mult,
		"target_score": _round_config.target_score if _round_config else 0,
	}

	# Compute scaled durations for all animation phases
	# Stomp: rise + slam
	var stomp_config := StompTileAnimation.new()
	var stomp_slam_time: float = stomp_config.rise_duration + stomp_config.slam_duration
	params["stomp_slam_time_scaled"] = hype_config.scale_duration(stomp_slam_time, effective_mult)
	params["stomp_stagger_scaled"] = hype_config.scale_duration(stomp_config.stagger_delay, effective_mult)

	# Spin
	var spin_config := SpinTileAnimation.new()
	params["spin_up_time_scaled"] = hype_config.scale_duration(spin_config.spin_up_duration, effective_mult)
	params["spin_stagger_scaled"] = hype_config.scale_duration(spin_config.stagger_delay, effective_mult)

	# Score pop travel
	params["score_travel_duration_scaled"] = hype_config.scale_duration(hype_config.score_pop_travel_duration, effective_mult)

	if hype_config.debug_logging_enabled:
		print("[Play] tileCount=%d speedMultiplier=%.2f" % [tile_count, effective_mult])

	return params


## Applies duration scaling to an animation strategy before execution
func _apply_duration_scaling(params: Dictionary, strategy: TileAnimationStrategy, base_field: String) -> void:
	if strategy == null or params.is_empty():
		return

	var hype_config: HypeConfig = TileAnimator.hype_config
	if not hype_config:
		return

	var effective_mult: float = params.get("effective_multiplier", 1.0)

	# Scale the animation duration
	var base_value: float = strategy.get(base_field)
	strategy.set(base_field, hype_config.scale_duration(base_value, effective_mult))

	# Also scale stagger
	var base_stagger: float = hype_config.inter_tile_stagger_delay
	strategy.stagger_delay = hype_config.scale_duration(base_stagger, effective_mult)


## Restores animation strategy durations to their original values
func _restore_duration_scaling(strategy: TileAnimationStrategy, base_field: String) -> void:
	if strategy == null:
		return

	# Restore from config defaults
	var hype_config: HypeConfig = TileAnimator.hype_config
	if not hype_config:
		return

	if base_field == "duration":
		# Generic restoration - get fresh instance to get defaults
		if strategy is LiftTileAnimation:
			strategy.duration = hype_config.lift_duration
		elif strategy is StompTileAnimation:
			strategy.duration = 0.35
		elif strategy is SpinTileAnimation:
			strategy.duration = 0.35

	strategy.stagger_delay = hype_config.inter_tile_stagger_delay


# =============================================================================
# BOARD QUERIES
# =============================================================================

func _get_unplayed_board_tiles() -> Array[Tile]:
	var tiles: Array[Tile] = []
	for cell in board.get_all_cells():
		if cell.is_occupied() and not cell.tile.is_locked:
			tiles.append(cell.tile)
	return tiles


func _get_all_board_tiles() -> Array[Tile]:
	var tiles: Array[Tile] = []
	for cell in board.get_all_cells():
		if cell.is_occupied():
			tiles.append(cell.tile)
	return tiles


func has_valid_moves() -> bool:
	if not _get_unplayed_board_tiles().is_empty():
		return true

	var has_tiles_available: bool = not HandManager.is_hand_empty() or not TileBag.is_empty()
	var has_empty_cells: bool = false
	for cell in board.get_all_cells():
		if not cell.is_occupied() and not cell.is_unavailable():
			has_empty_cells = true
			break

	return has_tiles_available and has_empty_cells


# =============================================================================
# PLAY BUTTON STATE
# =============================================================================

func update_play_button_state() -> void:
	var has_unplayed: bool = not _get_unplayed_board_tiles().is_empty()
	if has_unplayed:
		play_button_changed.emit(true, false)
	elif not has_valid_moves() and GameManager.get_plays_remaining() > 0:
		play_button_changed.emit(true, true)
	else:
		play_button_changed.emit(false, false)
