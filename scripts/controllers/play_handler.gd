class_name PlayHandler
extends RefCounted

## PlayHandler: Manages play submission, scoring, and end-round logic.
## Handles the Play/End Round button state, auto-end-round when no valid
## moves remain, and word validation for played tiles.

# =============================================================================
# SIGNALS
# =============================================================================

signal play_completed(tiles: Array[Tile], words: Array)

# =============================================================================
# DEPENDENCIES (injected via setup)
# =============================================================================

var board: Board = null
var main_hud: CanvasLayer = null
var _word_validator: WordValidator = null
var _selection: SelectionManager = null


func setup(p_board: Board, p_hud: CanvasLayer, p_selection: SelectionManager) -> void:
	board = p_board
	main_hud = p_hud
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

	# Always lock tiles and commit the play
	for tile in unplayed_tiles:
		tile.set_locked(true)

	_selection.deselect_all()

	# Split tiles by modifier type for distinct animations
	var multi_tiles: Array[Tile] = []
	var normal_tiles: Array[Tile] = []
	for tile in unplayed_tiles:
		if tile.has_modifier(ModifierTypes.Type.MULTI):
			multi_tiles.append(tile)
		else:
			normal_tiles.append(tile)

	# Consume CONSUMABLE modifiers after locking
	for tile in unplayed_tiles:
		tile.consume_modifiers()

	if not normal_tiles.is_empty():
		TileAnimator.animate_stomp_batch(normal_tiles)
	if not multi_tiles.is_empty():
		TileAnimator.animate_spin_batch(multi_tiles)

	EventBus.tiles_played.emit(unplayed_tiles, words)
	play_completed.emit(unplayed_tiles, words)

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
	main_hud.set_play_button_enabled(false)

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

	# Loop: stomp -> await -> commit for each remaining play
	while GameManager.get_current_phase() == GameManager.GamePhase.PLAYING and GameManager.get_plays_remaining() > 0:
		TileAnimator.animate_stomp_batch(all_tiles)
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
	if not main_hud:
		return

	var has_unplayed_tiles: bool = not _get_unplayed_board_tiles().is_empty()

	if has_unplayed_tiles:
		main_hud.set_play_button_enabled(true)
		main_hud.set_play_button_mode(false)
	elif not has_valid_moves() and GameManager.get_plays_remaining() > 0:
		main_hud.set_play_button_enabled(true)
		main_hud.set_play_button_mode(true)
	else:
		main_hud.set_play_button_enabled(false)
		main_hud.set_play_button_mode(false)
