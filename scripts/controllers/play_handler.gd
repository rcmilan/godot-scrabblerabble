class_name PlayHandler
extends RefCounted

## PlayHandler: Manages play submission, scoring, and end-round logic.
## Handles the Play/End Round button state, auto-end-round when no valid
## moves remain, and word validation for played tiles.

# =============================================================================
# SIGNALS
# =============================================================================

signal play_completed(tiles: Array[Tile], words: Array)
signal play_button_changed(enabled: bool, end_round_mode: bool)

# =============================================================================
# DEPENDENCIES (injected via setup)
# =============================================================================

var board: Board = null
var _word_validator: WordValidator = null
var _selection: SelectionManager = null


func setup(p_board: Board, p_selection: SelectionManager) -> void:
	board = p_board
	_selection = p_selection
	_word_validator = WordValidator.new()


## Returns the word validator instance for external scoring.
func get_word_validator() -> WordValidator:
	return _word_validator


# =============================================================================
# PLAY HANDLING
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

	var positions: Array[Vector2i] = []
	for tile in unplayed_tiles:
		if tile.current_cell:
			positions.append(tile.current_cell.grid_position)

	# Find all words formed by the placed tiles
	var words: Array = _word_validator.find_formed_words(board, positions)

	for word_info in words:
		print("[Gameplay] Word formed: '%s' (%s, %d letters)" % [
			word_info.word, word_info.direction, word_info.word.length()
		])

	# Lock unplayed tiles via modifier system
	for tile in unplayed_tiles:
		tile.set_locked(true)

	_selection.deselect_all()

	# Animate ALL board tiles (locked and newly locked)
	var all_tiles: Array[Tile] = _get_all_board_tiles()

	# Split by animation type BEFORE consuming (modifiers still present)
	var cats := _categorize_tiles_by_animation(all_tiles)
	var spin_tiles: Array[Tile] = cats.spin
	var stomp_tiles: Array[Tile] = cats.stomp

	# Hide locked border during animations (on_animation_complete restores it)
	for tile in all_tiles:
		if tile.locked_border:
			tile.locked_border.visible = false

	var animation_count: int = 0
	if not stomp_tiles.is_empty():
		TileAnimator.animate_stomp_batch(stomp_tiles)
		animation_count += 1
	if not spin_tiles.is_empty():
		TileAnimator.animate_spin_batch(spin_tiles)
		animation_count += 1

	# Wait for all animations to complete before committing the play
	for i in animation_count:
		await TileAnimator.animation_completed

	# Consume CONSUMABLE modifiers on newly played tiles after animation
	for tile in unplayed_tiles:
		tile.consume_modifiers()

	EventBus.tiles_played.emit(unplayed_tiles, words)
	play_completed.emit(unplayed_tiles, words)

	# Auto-refill hand after a brief delay so player sees the result
	await board.get_tree().create_timer(0.5).timeout
	HandManager.refill_hand()

	update_play_button_state()
	print("[Gameplay] Play accepted: %d tiles locked, %d words found" % [
		unplayed_tiles.size(), words.size()
	])


# =============================================================================
# AUTO END ROUND
# =============================================================================

func _auto_end_round() -> void:
	print("[Gameplay] Auto end round: consuming %d remaining plays" % GameManager.get_plays_remaining())

	# Disable button during auto-play sequence
	play_button_changed.emit(false, false)

	# Get all board tiles and their positions
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

	# Split ALL tiles by animation type (once, modifiers don't change between loops)
	var cats := _categorize_tiles_by_animation(all_tiles)
	var spin_tiles: Array[Tile] = cats.spin
	var stomp_tiles: Array[Tile] = cats.stomp

	# Loop: hide borders -> animate -> await -> commit for each remaining play
	while GameManager.get_current_phase() == GameManager.GamePhase.PLAYING and GameManager.get_plays_remaining() > 0:
		# Hide locked border during animations (on_animation_complete restores it)
		for tile in all_tiles:
			if tile.locked_border:
				tile.locked_border.visible = false
		var animation_count: int = 0
		if not stomp_tiles.is_empty():
			TileAnimator.animate_stomp_batch(stomp_tiles)
			animation_count += 1
		if not spin_tiles.is_empty():
			TileAnimator.animate_spin_batch(spin_tiles)
			animation_count += 1
		for i in animation_count:
			await TileAnimator.animation_completed
		GameManager.commit_play(total_score)

	update_play_button_state()
	print("[Gameplay] Auto end round complete")


# =============================================================================
# BOARD QUERIES
# =============================================================================

## Gets all unlocked (unplayed) tiles currently on the board.
func _get_unplayed_board_tiles() -> Array[Tile]:
	var tiles: Array[Tile] = []
	for cell in board.get_all_cells():
		if cell.is_occupied() and not cell.tile.is_locked:
			tiles.append(cell.tile)
	return tiles


## Gets all tiles currently on the board.
func _get_all_board_tiles() -> Array[Tile]:
	var tiles: Array[Tile] = []
	for cell in board.get_all_cells():
		if cell.is_occupied():
			tiles.append(cell.tile)
	return tiles


## Splits tiles into spin (EXTRA/MULTI/EXPO) and stomp (RESET/plain) groups.
func _categorize_tiles_by_animation(tiles: Array[Tile]) -> Dictionary:
	var spin: Array[Tile] = []
	var stomp: Array[Tile] = []
	for tile in tiles:
		if tile.has_modifier(ModifierTypes.Type.RESET):
			stomp.append(tile)
		elif tile.has_modifier(ModifierTypes.Type.EXTRA) \
			or tile.has_modifier(ModifierTypes.Type.MULTI) \
			or tile.has_modifier(ModifierTypes.Type.EXPO):
			spin.append(tile)
		else:
			stomp.append(tile)
	return {spin = spin, stomp = stomp}


## Checks if the player has any valid moves remaining.
func has_valid_moves() -> bool:
	# Valid moves exist if there are unplayed tiles on the board
	if not _get_unplayed_board_tiles().is_empty():
		return true

	# Otherwise, check if the player can still place tiles:
	# Need tiles available (hand or bag) AND empty cells on the board
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

## Updates the Play/End Round button state based on current board state.
func update_play_button_state() -> void:
	var has_unplayed: bool = not _get_unplayed_board_tiles().is_empty()
	if has_unplayed:
		play_button_changed.emit(true, false)
	elif not has_valid_moves() and GameManager.get_plays_remaining() > 0:
		play_button_changed.emit(true, true)
	else:
		play_button_changed.emit(false, false)
