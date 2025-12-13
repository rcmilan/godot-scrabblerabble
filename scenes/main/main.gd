extends Node2D

# Main: Initializes the game and connects the primary scenes.

@onready var board = $Board
@onready var board_view = $BoardView
@onready var hand = $Hand
@onready var main_hud = $MainHUD

# Preload helper classes
var WordCheckerClass = preload("res://scripts/core/word_checker.gd")
var ScoringClass = preload("res://scripts/logic/scoring.gd")
var RoundManagerClass = preload("res://scripts/logic/round_manager.gd")
var ValidationHelperClass = preload("res://scripts/logic/validation_helper.gd")
var word_checker = null
var scoring = null
var round_manager = null
var validation_helper = null
var current_score: int = 0

# Note: board is now the Board scene (board.gd) which manages BoardModel internally
# All board operations go through board.place_tile(), board.get_temp_positions(), etc.

# Tile selection and placement tracking
var selected_hand_tile = null
var pos_to_hand_tile = {}  # Map board position to hand tile node
var hand_tile_to_pos = {}  # Map hand tile node to board position
var last_overall_valid: bool = false

func _ready():
	# Initialize game logic components
	word_checker = WordCheckerClass.new()
	add_child(word_checker)  # Add as child so dictionary loads in _ready
	scoring = ScoringClass.new()
	add_child(scoring)  # Add as child so _ready runs
	
	# Initialize validation helper with word checker
	validation_helper = ValidationHelperClass.new(word_checker)
	
	# Initialize round manager for gameplay loop
	round_manager = RoundManagerClass.new()
	add_child(round_manager)
	round_manager.start_round(1, 100, 10)  # Round 1, target 100, 10 plays
	
	# The Hand automatically draws tiles in its _ready() method.
	print("[main] Main scene ready")
	
	# Emit initial score
	EventBus.score_updated.emit(current_score)
	
	# Connect hand counter signal to MainHUD
	if hand and hand.has_signal("hand_count_changed"):
		hand.connect("hand_count_changed", Callable(main_hud, "_on_hand_count_changed"))
	
	# Wire board interaction signals
	if board_view:
		board_view.connect("cell_clicked", Callable(self, "_on_board_cell_clicked"))
		board_view.connect("cell_right_clicked", Callable(self, "_on_board_cell_right_clicked"))
	
	# Wire hand tile selection via EventBus (same as word_test.gd)
	if EventBus:
		EventBus.connect("hand_letter_selected", Callable(self, "_on_hand_letter_selected"))
		EventBus.connect("hand_tile_selected", Callable(self, "_on_hand_tile_selected"))
	
	# Initialize Play button state (disabled until valid placement)
	if main_hud and main_hud.has_method("set_play_button_enabled"):
		main_hud.set_play_button_enabled(false)


func _on_discard_pressed() -> void:
	# Discard currently selected tile(s) and draw replacements
	if not selected_hand_tile:
		print("[main] No tile selected to discard")
		return
	
	# Check if the selected tile is already placed on board
	if selected_hand_tile in hand_tile_to_pos:
		print("[main] Cannot discard - tile is placed on board. Remove it first.")
		return
	
	if hand and hand.has_method("discard_tiles"):
		# Discard single selected tile (future: support multi-select)
		var tiles_to_discard = [selected_hand_tile]
		var discarded = hand.discard_tiles(tiles_to_discard)
		if discarded > 0:
			print("[main] Discarded ", discarded, " tile(s)")
			selected_hand_tile = null
		else:
			print("[main] Failed to discard tile")
	else:
		print("[main] Hand node or discard method not found")


func _on_evaluate_pressed() -> void:
	# Only allow evaluate if last validation said overall_valid
	if not last_overall_valid:
		print("[main] evaluate: current placement is not valid")
		return
	
	var combined = board.get_combined_grid_view()
	var breakdown = scoring.evaluate_board_with_breakdown(combined)
	print("[main] scoring breakdown:")
	print(breakdown)
	
	# Update score and emit signal
	var turn_score = breakdown.get("total_score", 0)
	current_score += turn_score
	EventBus.score_updated.emit(current_score)
	print("[main] turn score: ", turn_score, " | total score: ", current_score)
	
	# Count how many tiles were used (for refill)
	var tiles_used = pos_to_hand_tile.size()
	print("[main] Committing ", tiles_used, " tiles to board")
	
	# Commit temp tiles to board permanently
	board.commit_temp_tiles(0)
	print("[main] committed temp tiles")
	
	# Remove committed tiles from hand (they're now on the board permanently)
	for tile_node in pos_to_hand_tile.values():
		if is_instance_valid(tile_node):
			if hand and hand.has_method("remove_one_tile_by_node"):
				hand.remove_one_tile_by_node(tile_node)
	
	# Clear mappings
	pos_to_hand_tile.clear()
	hand_tile_to_pos.clear()
	selected_hand_tile = null
	
	# Refill hand from tile bag
	if hand and hand.has_method("refill_hand"):
		var refilled = hand.refill_hand()
		print("[main] Refilled ", refilled, " tiles to hand")
		EventBus.tiles_committed.emit(tiles_used)
	
	# Notify round manager of completed play
	if round_manager:
		round_manager.complete_play(turn_score, current_score)
	
	# Clear last validation and disable Play button
	last_overall_valid = false
	if main_hud and main_hud.has_method("set_play_button_enabled"):
		main_hud.set_play_button_enabled(false)
	if board_view:
		board_view.show_combined_grid(board.get_combined_grid_view(), board.get_temp_positions())

func _on_board_cell_clicked(pos: Vector2i) -> void:
	# Place selected hand tile on board
	if selected_hand_tile == null:
		print("[main] No tile selected - click a tile in your hand first")
		return
	
	if not selected_hand_tile.tile_data:
		print("[main] Selected tile has no data")
		return
	
	# Check if this hand tile is already placed somewhere
	if selected_hand_tile in hand_tile_to_pos:
		print("[main] Tile already placed on board - remove it first")
		return
	
	# Attempt to place tile on board (temporary placement)
	var letter = selected_hand_tile.tile_data.letter
	var ok = board.place_tile(selected_hand_tile.tile_data, pos, true)
	
	if ok:
		print("[main] Placed tile ", letter, " at ", pos)
		# Track the mapping between board position and hand tile
		pos_to_hand_tile[pos] = selected_hand_tile
		hand_tile_to_pos[selected_hand_tile] = pos
		
		# Mark hand tile as temporarily used
		if selected_hand_tile.has_method("set_temp_used"):
			selected_hand_tile.set_temp_used(true)
		if selected_hand_tile.has_method("deselect"):
			selected_hand_tile.deselect()
		
		selected_hand_tile = null
		
		# Run validation and update board view
		_run_incremental_validation()
		_update_board_view()
	else:
		print("[main] Failed to place tile at ", pos)


func _on_board_cell_right_clicked(pos: Vector2i) -> void:
	# Remove temp tile from board at clicked position
	board.remove_temp_tile(pos)
	print("[main] Removed tile from ", pos)
	
	# Restore the hand tile if it was tracked
	if pos in pos_to_hand_tile:
		var hand_tile = pos_to_hand_tile[pos]
		if hand_tile and is_instance_valid(hand_tile):
			# Restore tile to available state
			if hand_tile.has_method("set_temp_used"):
				hand_tile.set_temp_used(false)
			if hand_tile.has_method("deselect"):
				hand_tile.deselect()
			print("[main] Restored hand tile to available state")
		
		# Clear mappings
		hand_tile_to_pos.erase(hand_tile)
		pos_to_hand_tile.erase(pos)
	
	# Run validation and update board view
	_run_incremental_validation()
	_update_board_view()


func _on_hand_letter_selected(letter: String) -> void:
	# Mirror rack selection (for future debug UI integration)
	print("[main] Hand letter selected: ", letter)


func _on_hand_tile_selected(tile_node) -> void:
	# Deselect previously selected tile (only one at a time)
	if selected_hand_tile and selected_hand_tile != tile_node:
		if selected_hand_tile.has_method("deselect"):
			selected_hand_tile.deselect()
	
	# Store the selected tile
	selected_hand_tile = tile_node
	print("[main] Selected tile: ", tile_node.tile_data.letter if tile_node.tile_data else "?")


func _run_incremental_validation() -> void:
	# Validate current temp placements to enable/disable Play button
	var temp_positions = board.get_temp_positions()
	
	if temp_positions.size() == 0:
		last_overall_valid = false
		if main_hud and main_hud.has_method("set_play_button_enabled"):
			main_hud.set_play_button_enabled(false)
		return
	
	# Use validation helper to perform validation
	var result = validation_helper.run_incremental_validation(board, temp_positions)
	var combined = board.get_combined_grid_view()
	
	# Log validation results for each range (for debugging)
	var ranges = board.get_candidate_ranges_for_positions(temp_positions)
	for r in ranges:
		var word = validation_helper.extract_word_from_range(combined, r.start, r.end)
		var is_valid = word_checker.is_valid_word(word)
		print("[main] candidate: '", word, "' -> valid:", is_valid, " range:", r.start, r.end)
	
	print("[main] validation -> any_valid:", result.any_valid, " all_temp_covered:", result.all_temp_covered, " overall_valid:", result.is_valid)
	
	last_overall_valid = result.is_valid
	
	# Update Play button state
	if main_hud and main_hud.has_method("set_play_button_enabled"):
		main_hud.set_play_button_enabled(last_overall_valid)



func _update_board_view() -> void:
	if board_view:
		board_view.show_combined_grid(board.get_combined_grid_view(), board.get_temp_positions())


# ============================================================================
# Debug Methods (for DebugOverlay compatibility)
# ============================================================================

func validate_word(word: String) -> bool:
	# Validate a word against the dictionary (for debug overlay)
	if word.is_empty():
		return false
	return word_checker.is_valid_word(word)

func _on_remove_all_pressed() -> void:
	# Remove all temp tiles from board (debug overlay)
	board.clear_temp_tiles()
	print("[main] cleared all temp tiles")
	
	# Reset all hand tiles that were placed back to unplaced/unselected state
	for pos in pos_to_hand_tile.keys():
		var hand_tile = pos_to_hand_tile[pos]
		if hand_tile and is_instance_valid(hand_tile):
			if hand_tile.has_method("set_temp_used"):
				hand_tile.set_temp_used(false)
			if hand_tile.has_method("deselect"):
				hand_tile.deselect()
	
	# Clear mappings
	pos_to_hand_tile.clear()
	hand_tile_to_pos.clear()
	selected_hand_tile = null
	
	_run_incremental_validation()
	_update_board_view()

func _on_redraw_hand_pressed() -> void:
	# Redraw hand (return tiles to bag and draw new ones) (debug overlay)
	# Clear all temp tiles from board first (placed hand tiles)
	board.clear_temp_tiles()
	_update_board_view()
	
	# Clear mappings since we're resetting everything
	pos_to_hand_tile.clear()
	hand_tile_to_pos.clear()
	selected_hand_tile = null
	
	# Redraw hand
	if hand and hand.has_method("redraw_hand_returning"):
		var returned = hand.redraw_hand_returning()
		print("[main] Redrew hand, returned ", returned, " tiles to bag")
	else:
		print("[main] Hand node or redraw method not found")

func _on_print_rack_pressed() -> void:
	# Print current rack state to debug console (debug overlay)
	if not TileBag:
		print("[main] TileBag not available")
		return
	
	var total_count = TileBag.get_remaining_tile_count()
	var discard_count = TileBag.get_discarded_tile_count()
	var tile_counts = TileBag.get_tile_counts_by_letter()
	
	print("=== RACK STATE ===")
	print("Total tiles in rack: ", total_count)
	print("Discarded tiles: ", discard_count)
	print("Tiles by letter:")
	
	# Sort letters alphabetically for consistent output
	var letters = tile_counts.keys()
	letters.sort()
	for letter in letters:
		print("  ", letter, ": ", tile_counts[letter])
	print("==================")
