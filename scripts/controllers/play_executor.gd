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


func setup(p_board: Board, p_selection: SelectionManager) -> void:
	board = p_board
	_selection = p_selection
	_word_validator = WordValidator.new()
	_play_validator = PlayValidator.new(_word_validator)


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
	var positions: Array[Vector2i] = []
	for tile in unplayed_tiles:
		if tile.current_cell:
			positions.append(tile.current_cell.grid_position)

	var words: Array = _word_validator.find_formed_words(board, positions)

	for word_info in words:
		print("[Gameplay] Word formed: '%s' (%s, %d letters)" % [
			word_info.word, word_info.direction, word_info.word.length()
		])

	# Lock unplayed tiles via modifier system
	for tile in unplayed_tiles:
		tile.set_locked(true)

	_selection.deselect_all()

	# Animate ALL board tiles
	var all_tiles: Array[Tile] = _get_all_board_tiles()
	await _animate_play(all_tiles)

	# Consume CONSUMABLE modifiers on newly played tiles after animation
	for tile in unplayed_tiles:
		tile.consume_modifiers()

	EventBus.tiles_played.emit(unplayed_tiles, words)
	play_completed.emit(unplayed_tiles, words)

	# Auto-refill hand after a brief delay so player sees the result
	await board.get_tree().create_timer(0.5).timeout
	HandManager.refill_hand()

	print("[Gameplay] Play accepted: %d tiles locked, %d words found" % [
		unplayed_tiles.size(), words.size()
	])


## Animates tiles using AnimationCategorizer dispatch.
func _animate_play(all_tiles: Array[Tile]) -> void:
	var cats: Dictionary = AnimationCategorizer.categorize(all_tiles)

	# Hide locked border during animations
	for tile in all_tiles:
		if tile.locked_border:
			tile.locked_border.visible = false

	var animation_count: int = 0
	if not cats.stomp.is_empty():
		TileAnimator.animate_stomp_batch(cats.stomp)
		animation_count += 1
	if not cats.spin.is_empty():
		TileAnimator.animate_spin_batch(cats.spin)
		animation_count += 1

	for i in animation_count:
		await TileAnimator.animation_completed


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

	print("[Gameplay] Auto end round: scoring %d pts per play from %d words" % [total_score, words.size()])

	# Categorize once (modifiers don't change between loops)
	var cats: Dictionary = AnimationCategorizer.categorize(all_tiles)

	while GameManager.get_current_phase() == GameManager.GamePhase.PLAYING and GameManager.get_plays_remaining() > 0:
		for tile in all_tiles:
			if tile.locked_border:
				tile.locked_border.visible = false

		var animation_count: int = 0
		if not cats.stomp.is_empty():
			TileAnimator.animate_stomp_batch(cats.stomp)
			animation_count += 1
		if not cats.spin.is_empty():
			TileAnimator.animate_spin_batch(cats.spin)
			animation_count += 1

		for i in animation_count:
			await TileAnimator.animation_completed

		GameManager.commit_play(total_score)

	update_play_button_state()
	print("[Gameplay] Auto end round complete")


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
		if not cell.is_occupied():
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
