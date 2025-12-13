extends Node

# Debug helper for validating words and exercising BoardModel without autoloads.
# Usage (in the running Debug.tscn):
# var wt = get_tree().get_current_scene().get_node("WordTest")
# wt.validate_word("hello")
# wt.place_tile_for_test("A", 7, 7)

# Terminology:
# - `rack` in older code refers to the deck / tile bag (the pool of available tiles).
#   To avoid ambiguity, think of the rack as the tile bag/deck (server-side resource).
# - `HAND` refers to a player's drawn tiles displayed in the UI (a short-lived UI node).
#   In code: the `Hand` scene handles drawn tiles; `tile_bag` / `TileBag` is the rack/deck.
#
# Tile State Management Design:
# - Hand tiles and board tiles are the SAME object instances (mapped via pos_to_hand_tile)
# - States: unselected (default) → selected (blue tint) → placed (greyed, disabled)
# - State transitions are bidirectional: placed tiles can be removed and restored to hand
# - This design supports future drag-and-drop: tile instance moves from hand to board visually
# - All state changes propagate through the tile object (set_temp_used, select, deselect)
# wt.print_board()

var BoardScene = preload("res://scenes/board/Board.tscn")
var TileModelClass = preload("res://scripts/core/tile_model.gd")
var WordCheckerClass = preload("res://scripts/core/word_checker.gd")
var ValidationHelperClass = preload("res://scripts/logic/validation_helper.gd")
var LETTER_VALUES = {
	"A":1,"B":3,"C":3,"D":2,"E":1,"F":4,"G":2,"H":4,"I":1,"J":8,"K":5,"L":1,"M":3,
	"N":1,"O":1,"P":3,"Q":10,"R":1,"S":1,"T":1,"U":1,"V":4,"W":4,"X":8,"Y":4,"Z":10
}

var board: Node = null
var word_checker = null
var validation_helper = null
var ScoringClass = preload("res://scripts/logic/scoring.gd")
var scoring = null
var BoardViewClass = preload("res://scripts/ui/board_view.gd")
var board_view = null
var RoundManagerClass = preload("res://scripts/logic/round_manager.gd")
var round_manager = null
var main_hud = null

var last_overall_valid: bool = false
var last_valid_ranges: Array = []
var selected_hand_tile = null
var pos_to_hand_tile = {}
var hand_tile_to_pos = {}
var current_score: int = 0
var discard_count: int = 0

func _ready():
	# Instantiate Board scene (which manages BoardModel internally)
	board = BoardScene.instantiate()
	add_child(board)

	# Initialize word checker (add as child so dictionary loads in _ready)
	word_checker = WordCheckerClass.new()
	add_child(word_checker)
	
	# Initialize validation helper with word checker
	validation_helper = ValidationHelperClass.new(word_checker)
	
	# scoring instance (add as child so its _ready runs and it can add its helpers)
	scoring = ScoringClass.new()
	add_child(scoring)
	
	# round manager for gameplay loop
	round_manager = RoundManagerClass.new()
	add_child(round_manager)
	round_manager.start_round(1, 100, 10)  # Round 1, target 100, 10 plays
	
	# Ensure Debug UI (editor scene) is available before choosing the BoardView.
	_create_debug_ui()
	
	# Instance MainHUD to display score and game state
	var hud_path = "res://scenes/ui/MainHUD.tscn"
	if FileAccess.file_exists(hud_path):
		var hud_packed = load(hud_path)
		if hud_packed and hud_packed is PackedScene:
			var hud_inst = hud_packed.instantiate()
			var scene_root = get_tree().get_current_scene()
			if scene_root:
				scene_root.add_child(hud_inst)
			else:
				add_child(hud_inst)
			# Store MainHUD reference
			main_hud = hud_inst
			# Connect hand counter signal to MainHUD
			var hand_node = _find_debug("Hand")
			if hand_node and hand_node.has_signal("hand_count_changed"):
				hand_node.connect("hand_count_changed", Callable(hud_inst, "_on_hand_count_changed"))
	
	# Emit initial score
	EventBus.score_updated.emit(current_score)

	# board view (visual) - prefer an editor-provided BoardView under DebugUI
	var existing_board = _find_debug("BoardView")
	if existing_board:
		board_view = existing_board
	else:
		board_view = BoardViewClass.new()
		add_child(board_view)

	board_view.connect("cell_clicked", Callable(self, "_on_board_cell_clicked"))
	board_view.connect("cell_right_clicked", Callable(self, "_on_board_cell_right_clicked"))
	# Listen for rack/hand selection events
	if EventBus:
		if not EventBus.is_connected("hand_letter_selected", Callable(self, "_on_hand_letter_selected")):
			EventBus.connect("hand_letter_selected", Callable(self, "_on_hand_letter_selected"))
		if not EventBus.is_connected("hand_tile_selected", Callable(self, "_on_hand_tile_selected")):
			EventBus.connect("hand_tile_selected", Callable(self, "_on_hand_tile_selected"))
	
	print("[word_test] Ready")

	# Create a small runtime UI so you can click debug helpers when the Evaluator is unavailable.
	# This is non-destructive: it only adds UI nodes at runtime and does not change scenes on disk.
	_create_debug_ui()

func validate_word(word: String) -> bool:
	# Validate a word against the dictionary (for debug overlay compatibility)
	if word.is_empty():
		return false
	return word_checker.is_valid_word(word)

func place_tile_for_test(letter: String, x: int, y: int, hand_tile_node: Node = null) -> bool:
	# Create a simple TileModel-like object (use the preloaded TileModelClass)
	var tile = TileModelClass.new(letter, 1)
	var grid_pos = Vector2i(x, y)
	var ok = board.place_tile(tile, grid_pos, true)
	print("[word_test] place_tile (temp): ", letter, "@", grid_pos, " -> ", ok)

	# After placing, run incremental validation for the current temp placements
	_run_incremental_validation()

	# If this placement came from a concrete hand tile node, mark mappings
	if ok:
		if hand_tile_node != null:
			pos_to_hand_tile[grid_pos] = hand_tile_node
			hand_tile_to_pos[hand_tile_node] = grid_pos
			if hand_tile_node.has_method("set_temp_used"):
				hand_tile_node.set_temp_used(true)
			if hand_tile_node.has_method("deselect"):
				hand_tile_node.deselect()
			selected_hand_tile = null
		else:
			# If we succeeded in placing a temp tile, attempt to remove that tile from any on-screen Rack
			var scene_root = get_tree().get_current_scene()
			if scene_root:
				var rack = _find_node_compat(scene_root, "Rack")
				if rack and rack.has_method("remove_one_tile_by_letter"):
					var removed = rack.remove_one_tile_by_letter(letter)
					print("[word_test] removed from rack ->", removed)
			else:
				# fallback: look locally under this node
				var rack2 = _find_node_compat(self, "Rack")
				if rack2 and rack2.has_method("remove_one_tile_by_letter"):
					rack2.remove_one_tile_by_letter(letter)

	return ok

func _run_incremental_validation() -> void:
	var temp_positions = board.get_temp_positions()
	if temp_positions.size() == 0:
		print("[word_test] no temp positions")
		return

	# Use validation helper to perform validation
	var result = validation_helper.run_incremental_validation(board, temp_positions)
	var combined = board.get_combined_grid_view()
	
	# Log validation results for each range (for debugging)
	var ranges = board.get_candidate_ranges_for_positions(temp_positions)
	for r in ranges:
		var word = validation_helper.extract_word_from_range(combined, r.start, r.end)
		var is_valid = word_checker.is_valid_word(word)
		print("[word_test] candidate: ", word, " -> valid:", is_valid, " range:", r.start, r.end)
	
	print("[word_test] incremental validation -> any_valid:", result.any_valid, " all_temp_covered:", result.all_temp_covered, " overall_valid:", result.is_valid)

	# store last validation state for UI and evaluate button
	last_overall_valid = result.is_valid
	last_valid_ranges = result.valid_ranges

	# Update Play button state in MainHUD
	if main_hud and main_hud.has_method("set_play_button_enabled"):
		main_hud.set_play_button_enabled(last_overall_valid)

	# update board view visual
	if board_view:
		board_view.show_combined_grid(board.get_combined_grid_view(), board.get_temp_positions())

func print_board():
	# Print combined view (includes temp placements) so debug reflects current placement state
	var combined = board.get_combined_grid_view()
	for y in range(combined.size()):
		var row = ""
		for x in range(combined[y].size()):
			var t = combined[y][x]
			row += (t.letter if t else ".")
		print(row)


func _create_debug_ui() -> void:
	# Prefer editor-instanced UI: try to instance the saved `DebugUI.tscn` when running.
	# This makes the debug UI editable in the Godot editor and avoids creating
	# runtime-only panels. If the saved DebugUI scene is missing, fall back to
	# a minimal CanvasLayer so the script remains non-destructive.
	var existing = get_node_or_null("DebugUI")
	if existing:
		call_deferred("_finalize_ui_layout")
		return

	var debug_ui_path = "res://scenes/debug/DebugUI.tscn"
	if FileAccess.file_exists(debug_ui_path):
		var packed = load(debug_ui_path)
		if packed and packed is PackedScene:
			var inst = packed.instantiate()
			inst.name = "DebugUI"
			var scene_root = get_tree().get_current_scene()
			if scene_root:
				scene_root.add_child(inst)
			else:
				add_child(inst)
			call_deferred("_finalize_ui_layout")
			return

	# Fallback: create an empty CanvasLayer so other code can still parent to DebugUI
	var layer = CanvasLayer.new()
	layer.name = "DebugUI"
	var scene_root_fallback = get_tree().get_current_scene()
	if scene_root_fallback:
		scene_root_fallback.add_child(layer)
	else:
		add_child(layer)
	call_deferred("_finalize_ui_layout")

func _on_validate_hello() -> void:
	var ok = validate_word("apple")
	print("[word_test][ui] validate 'apple' -> ", ok)

func _on_place_A() -> void:
	place_tile_for_test("A", 7, 7)

func _on_print_board() -> void:
	print_board()

func _on_print_rack_pressed() -> void:
	# Print current rack state to debug console
	if not TileBag:
		print("[word_test] TileBag not available")
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


func _on_place_button_pressed() -> void:
	var letter_node = _find_debug("LetterInput")
	var x_node = _find_debug("XInput")
	var y_node = _find_debug("YInput")
	if not letter_node or not x_node or not y_node:
		print("[word_test][ui] place inputs not found")
		return
	var letter = letter_node.text.strip_edges().to_upper()
	var xs = x_node.text.strip_edges()
	var ys = y_node.text.strip_edges()
	if letter == "" or xs == "" or ys == "":
		print("[word_test][ui] place: missing input")
		return
	var x = int(xs)
	var y = int(ys)
	place_tile_for_test(letter, x, y)
	# update Play button state
	if main_hud and main_hud.has_method("set_play_button_enabled"):
		main_hud.set_play_button_enabled(last_overall_valid)

	if board_view:
		board_view.show_combined_grid(board.get_combined_grid_view(), board.get_temp_positions())


func _on_letter_changed(new_text: String) -> void:
	var s = "A"
	if new_text.strip_edges() != "":
		s = new_text.strip_edges().to_upper()[0]
	var lbl = _find_debug("SelectedLetterLabel")
	if lbl:
		lbl.text = "Selected: " + str(s)


func _on_remove_button_pressed() -> void:
	var x_node = _find_debug("XInput")
	var y_node = _find_debug("YInput")
	if not x_node or not y_node:
		print("[word_test][ui] remove inputs not found")
		return
	var xs = x_node.text.strip_edges()
	var ys = y_node.text.strip_edges()
	if xs == "" or ys == "":
		print("[word_test][ui] remove: missing input")
		return
	var pos = Vector2i(int(xs), int(ys))
	board.remove_temp_tile(pos)
	print("[word_test] removed temp tile at", pos)
	_run_incremental_validation()
	print_board()
	if board_view:
		board_view.show_combined_grid(board.get_combined_grid_view(), board.get_temp_positions())
	# Update Play button state
	if main_hud and main_hud.has_method("set_play_button_enabled"):
		main_hud.set_play_button_enabled(last_overall_valid)


func _on_remove_all_pressed() -> void:
	# Clear all temp tiles from board
	board.clear_temp_tiles()
	print("[word_test] cleared all temp tiles")
	
	# Reset all hand tiles that were placed back to unplaced/unselected state
	for pos in pos_to_hand_tile.keys():
		var h = pos_to_hand_tile[pos]
		if h and h.has_method("set_temp_used"):
			h.set_temp_used(false)
		if h and h.has_method("deselect"):
			h.deselect()
	
	# Clear mappings
	pos_to_hand_tile.clear()
	hand_tile_to_pos.clear()
	selected_hand_tile = null
	
	_run_incremental_validation()
	print_board()
	# Disable Play button (no tiles placed)
	if main_hud and main_hud.has_method("set_play_button_enabled"):
		main_hud.set_play_button_enabled(false)
	if board_view:
		board_view.show_combined_grid(board.get_combined_grid_view(), board.get_temp_positions())


func _on_discard_pressed() -> void:
	# Discard currently selected tile(s) and draw replacements.
	if not selected_hand_tile:
		print("[word_test] No tile selected to discard")
		return
	
	# Check if the selected tile is already placed on board
	if selected_hand_tile in hand_tile_to_pos:
		print("[word_test] Cannot discard - tile is placed on board. Remove it first.")
		return
	
	var hand_node = _find_debug("Hand")
	if hand_node and hand_node.has_method("discard_tiles"):
		# For now, discard single selected tile (future: support multi-select)
		var tiles_to_discard = [selected_hand_tile]
		var discarded = hand_node.discard_tiles(tiles_to_discard)
		if discarded > 0:
			discard_count += discarded
			print("[word_test] Discard button handled by hand.gd")
			selected_hand_tile = null
		else:
			print("[word_test] Failed to discard tile")
	else:
		print("[word_test] Hand node or discard method not found")


func _on_redraw_hand_pressed() -> void:
	# Clear all temp tiles from board first (placed hand tiles)
	board.clear_temp_tiles()
	if board_view:
		board_view.show_combined_grid(board.get_combined_grid_view(), board.get_temp_positions())
	
	# Clear mappings since we're resetting everything
	pos_to_hand_tile.clear()
	hand_tile_to_pos.clear()
	selected_hand_tile = null
	
	# Find Hand and call redraw_hand_returning to return tiles to bag and draw new hand
	var scene_root = get_tree().get_current_scene()
	var ui_root = null
	if scene_root:
		ui_root = scene_root.get_node_or_null("DebugUI")
	if not ui_root:
		ui_root = get_node_or_null("DebugUI")
	if ui_root:
		var hand = ui_root.get_node_or_null("Hand")
		if hand and hand.has_method("redraw_hand_returning"):
			hand.redraw_hand_returning()
			print("[word_test] board cleared and hand redrawn")


func _on_evaluate_pressed() -> void:
	# Only allow evaluate if last validation said overall_valid
	if not last_overall_valid:
		print("[word_test] evaluate: current placement is not valid")
		return

	var combined = board.get_combined_grid_view()
	var breakdown = scoring.evaluate_board_with_breakdown(combined)
	print("[word_test] scoring breakdown:")
	print(breakdown)
	
	# Update score and emit signal
	var turn_score = breakdown.get("total_score", 0)
	current_score += turn_score
	EventBus.score_updated.emit(current_score)
	print("[word_test] turn score: ", turn_score, " | total score: ", current_score)

	# Count how many tiles were used (for refill)
	var tiles_used = pos_to_hand_tile.size()
	print("[word_test] Committing ", tiles_used, " tiles to board")

	# Commit temp tiles as the score is being accepted (use turn 0 for debug)
	board.commit_temp_tiles(0)
	print("[word_test] committed temp tiles")
	print_board()
	
	# Remove committed tiles from hand (they're now on the board permanently)
	# Note: We don't return them to bag or discard - they stay on board
	for tile_node in pos_to_hand_tile.values():
		if is_instance_valid(tile_node):
			# Remove from hand's internal tracking
			var hand_node = _find_debug("Hand")
			if hand_node and hand_node.has_method("remove_one_tile_by_node"):
				hand_node.remove_one_tile_by_node(tile_node)
	
	# Clear mappings
	pos_to_hand_tile.clear()
	hand_tile_to_pos.clear()
	selected_hand_tile = null
	
	# Refill hand from tile bag
	var hand_node = _find_debug("Hand")
	if hand_node and hand_node.has_method("refill_hand"):
		var refilled = hand_node.refill_hand()
		print("[word_test] Refilled ", refilled, " tiles to hand")
		EventBus.tiles_committed.emit(tiles_used)
	
	# Notify round manager of completed play
	if round_manager:
		round_manager.complete_play(turn_score, current_score)
	
	# Clear last validation and disable Play button
	last_overall_valid = false
	last_valid_ranges = []
	if main_hud and main_hud.has_method("set_play_button_enabled"):
		main_hud.set_play_button_enabled(false)
	if board_view:
		board_view.show_combined_grid(board.get_combined_grid_view(), board.get_temp_positions())


func _on_check_word_pressed() -> void:
	var input_node = _find_debug("WordInput")
	if input_node:
		var w = input_node.text.strip_edges()
		var ok = validate_word(w)
		print("[word_test][ui] validate '", w, "' -> ", ok)
		# Score the typed word using TileModel and LETTER_VALUES (no board multipliers)
		var score = _score_word_string(w)
		print("[word_test][ui] score for '", w, "' -> ", score)
	else:
		print("[word_test][ui] input node not found")


func _on_board_cell_clicked(pos: Vector2i) -> void:
	# If a concrete hand tile is selected, place that tile; otherwise use LetterInput
	if selected_hand_tile != null:
		if selected_hand_tile.tile_data:
			place_tile_for_test(selected_hand_tile.tile_data.letter, pos.x, pos.y, selected_hand_tile)
		return

	# No hand tile selected — only place if the LetterInput explicitly contains a letter.
	var letter_node = _find_debug("LetterInput")
	if not letter_node or not (letter_node is LineEdit):
		# No explicit letter selected; ignore click.
		return
	var text = letter_node.text.strip_edges()
	if text == "":
		# empty input -> ignore click
		return
	var letter = text.to_upper()[0]
	place_tile_for_test(str(letter), pos.x, pos.y)

	# Update Play button state
	if main_hud and main_hud.has_method("set_play_button_enabled"):
		main_hud.set_play_button_enabled(last_overall_valid)

	if board_view:
		board_view.show_combined_grid(board.get_combined_grid_view(), board.get_temp_positions())


func _on_alphabet_pressed(letter: String) -> void:
	# Set the LetterInput LineEdit and update SelectedLetterLabel
	var letter_node = _find_debug("LetterInput")
	if letter_node and letter_node is LineEdit:
		letter_node.text = str(letter)
	var lbl = _find_debug("SelectedLetterLabel")
	if lbl and lbl is Label:
		lbl.text = "Selected: " + str(letter)


func _on_hand_letter_selected(letter: String) -> void:
	# Mirror rack selection into the debug UI input controls
	_on_alphabet_pressed(letter)


func _on_hand_tile_selected(tile_node) -> void:
	# Deselect the previously selected tile (only one tile can be selected at a time)
	if selected_hand_tile and selected_hand_tile != tile_node:
		if selected_hand_tile.has_method("deselect"):
			selected_hand_tile.deselect()
	
	# Store the concrete selected hand tile node for placement mapping
	selected_hand_tile = tile_node
	# Update debug UI selected label
	var lbl = _find_debug("SelectedLetterLabel")
	if lbl and lbl is Label and selected_hand_tile and selected_hand_tile.tile_data:
		lbl.text = "Selected: " + str(selected_hand_tile.tile_data.letter)


func _on_board_cell_right_clicked(pos: Vector2i) -> void:
	# Right-click removes a temp tile at the clicked position
	board.remove_temp_tile(pos)
	_run_incremental_validation()

	# If there was a mapped hand tile, restore it to available state
	if pos in pos_to_hand_tile:
		var h = pos_to_hand_tile[pos]
		if h:
			# Restore tile to clickable, unselected state
			if h.has_method("set_temp_used"):
				h.set_temp_used(false)
			if h.has_method("deselect"):
				h.deselect()
			print("[word_test] Restored hand tile: ", h.tile_data.letter if h.tile_data else "?")
		# Clear mappings
		hand_tile_to_pos.erase(h)
		pos_to_hand_tile.erase(pos)

	if board_view:
		board_view.show_combined_grid(board.get_combined_grid_view(), board.get_temp_positions())

	# Update Play button state
	if main_hud and main_hud.has_method("set_play_button_enabled"):
		main_hud.set_play_button_enabled(last_overall_valid)


func _score_word_string(word: String) -> int:
	if word.strip_edges().is_empty():
		return 0
	var total = 0
	# create TileModel instances and sum effective_letter_value
	var placement_multiplier_sum = 0
	for i in word.to_upper().split(""):
		if i == "":
			continue
		var ch = i
		var base = LETTER_VALUES.get(ch, 0)
		var tile = TileModelClass.new(ch, base)
		total += tile.effective_letter_value()
		placement_multiplier_sum += tile.placement_multiplier
	# Final multiplier comes from tiles themselves (sum of placement_multiplier)
	var final_mul = max(1, placement_multiplier_sum)
	return total * final_mul


func _on_viewport_resized() -> void:
	var vp = get_viewport()
	if not vp:
		return
	var size = vp.get_visible_rect().size
	var bottom_lbl = _find_debug("BottomHelp")
	if bottom_lbl:
		bottom_lbl.position = Vector2(10, size.y - 36)

	var panel = _find_debug("DebugPanel")
	if panel and board_view:
		var bx = panel.position.x + panel.size.x + 20
		var by = panel.position.y + 20
		board_view.position = Vector2(bx, by)

	# deferred layout finalizer (safe to call any time)
func _finalize_ui_layout() -> void:
	var scene_root = get_tree().get_current_scene()
	var ui_root = null
	if scene_root:
		ui_root = scene_root.get_node_or_null("DebugUI")
	if not ui_root:
		ui_root = get_node_or_null("DebugUI")
	if not ui_root:
		return
	var layer = ui_root
	var panel = null
	if ui_root.has_node("DebugPanel"):
		panel = ui_root.get_node("DebugPanel")

	# compute board size reliably; fallback to exported cols/cell_size
	var board_size = Vector2(0, 0)
	if board_view:
		board_size = board_view.size
	if board_size == Vector2.ZERO and board_view and board_view.has_method("get_children"):
		# try exported properties
		var cols = 0
		var rows = 0
		var cell_size = 48
		if board_view.has_meta("cols") or ("cols" in board_view):
			cols = board_view.cols if "cols" in board_view else 0
		if board_view.has_meta("rows") or ("rows" in board_view):
			rows = board_view.rows if "rows" in board_view else 0
		if board_view.has_meta("cell_size") or ("cell_size" in board_view):
			cell_size = board_view.cell_size if "cell_size" in board_view else cell_size
		if cols > 0 and rows > 0:
			board_size = Vector2(cols * cell_size, rows * cell_size)

	# Right placement panel: prefer an editor-provided child under DebugUI.
	var placement_panel = null
	if ui_root.has_node("PlacementPanel"):
		placement_panel = ui_root.get_node("PlacementPanel")

	# Anchor the board to the top of the scene with padding and keep tiles relative
	var top_padding = 12
	var left_padding = 10
	if panel:
		left_padding = panel.position.x + panel.size.x + 20

	var viewport_size = get_viewport().get_visible_rect().size
	var board_x = max(8, (viewport_size.x - board_size.x) * 0.5)
	# If we have a placement_panel, avoid centering under it by centering in available area
	if placement_panel:
		var right_limit = viewport_size.x
		right_limit = placement_panel.position.x - 16
		var avail_w = right_limit - left_padding
		if avail_w > 0:
			board_x = left_padding + max(0, (avail_w - board_size.x) * 0.5)

	var board_pos = Vector2(board_x, top_padding)
	if board_view:
		board_view.position = board_pos

	if placement_panel:
		# place placement panel to the right of the board
		placement_panel.position = Vector2(board_pos.x + board_size.x + 16, board_pos.y)
		if panel:
			placement_panel.position.y = panel.position.y + (panel.size.y - placement_panel.size.y) * 0.5

	# Move the existing PlaceRow into the placement panel if present
	var old_place = null
	if ui_root.has_node("DebugPanel/DebugVBox/MainHBox/RightPlacement/PlaceRow"):
		old_place = ui_root.get_node("DebugPanel/DebugVBox/MainHBox/RightPlacement/PlaceRow")
	if old_place and old_place.get_parent() and placement_panel:
		old_place.get_parent().remove_child(old_place)
		placement_panel.add_child(old_place)

	# Left action panel: expect editor-inserted `LeftActionPanel` under DebugUI.
	var left_panel = null
	if ui_root.has_node("LeftActionPanel"):
		left_panel = ui_root.get_node("LeftActionPanel")
	if left_panel and panel:
		left_panel.position = Vector2(panel.position.x + 6, panel.position.y + (panel.size.y - left_panel.size.y) * 0.5)

	var old_left = null
	if ui_root.has_node("DebugPanel/DebugVBox/MainHBox/LeftActions"):
		old_left = ui_root.get_node("DebugPanel/DebugVBox/MainHBox/LeftActions")
	if old_left and old_left.get_parent() and left_panel:
		old_left.get_parent().remove_child(old_left)
		left_panel.add_child(old_left)

	# Remove the original (now-empty) RightPlacement container if present
	var old_right = null
	if ui_root.has_node("DebugPanel/DebugVBox/MainHBox/RightPlacement"):
		old_right = ui_root.get_node("DebugPanel/DebugVBox/MainHBox/RightPlacement")
	if old_right and old_right.get_parent():
		old_right.get_parent().remove_child(old_right)
		old_right.queue_free()

	# Wire controls for any panels we found/instantiated
	_wire_ui_controls(layer)

	# Hand: prefer an editor-provided Hand under DebugUI; otherwise instantiate the default Hand.tscn
	var hand_viewport = null
	if ui_root.has_node("Hand"):
		hand_viewport = ui_root.get_node("Hand")
	else:
		var hand_path = "res://scenes/hand/Hand.tscn"
		if FileAccess.file_exists(hand_path):
			var hs = load(hand_path)
			if hs and hs is PackedScene:
				hand_viewport = hs.instantiate()
				hand_viewport.name = "Hand"
				ui_root.add_child(hand_viewport)

	# Position hand centered directly below the board
	if hand_viewport and board_view:
		var hand_w = 700  # expected width for 10 tiles at 60px spacing
		var hand_h = 120
		if "rect_min_size" in hand_viewport:
			hand_w = hand_viewport.rect_min_size.x
			hand_h = hand_viewport.rect_min_size.y
		elif "size" in hand_viewport:
			hand_w = hand_viewport.size.x
			hand_h = hand_viewport.size.y

		# Center hand horizontally relative to board
		var board_center_x = board_view.position.x + board_size.x * 0.5
		var hand_x = board_center_x - hand_w * 0.5
		var hand_y = board_view.position.y + board_size.y + 16
		hand_viewport.position = Vector2(hand_x, hand_y)



func _wire_ui_controls(ui_root: Node) -> void:
	if not ui_root:
		return


	# Old UI controls removed - now in DebugOverlay or MainHUD
	# Minimal wiring needed here

	# Note: Most UI controls are now in DebugOverlay (F12 toggle)
	# or removed entirely. This wiring is minimal now.


	# TODO: Alphabet mini-keyboard will be moved to a toggleable debug panel
	# in the bottom-left corner of the screen. This will be part of an expanded
	# debug UI system that can be shown/hidden via a toggle button.
	# For now, this feature is commented out to clean up the UI.
	
	# Future implementation:
	# - Create a DebugTogglePanel in bottom-left corner with anchor/offset
	# - Add a "Show Debug Keyboard" toggle button
	# - Move alphabet grid creation into that toggleable panel
	# - Allow quick letter placement for testing without hand tiles
	
	## Alphabet mini-keyboard: create buttons A-Z (COMMENTED OUT)
	#var left_panel = _find_descendant(ui_root, "LeftActionPanel")
	#if left_panel:
	#	var alpha = _find_descendant(left_panel, "Alphabet")
	#	if not alpha:
	#		alpha = GridContainer.new()
	#		alpha.name = "Alphabet"
	#		alpha.columns = 7
	#		left_panel.add_child(alpha)
	#		# Create buttons A-Z
	#		for i in range(26):
	#			var ch = char(65 + i) # ASCII A..Z
	#			var b = Button.new()
	#			b.name = "Key_" + ch
	#			b.text = ch
	#			b.custom_minimum_size = Vector2(28, 28)
	#			# connect pressed with bound letter
	#			b.connect("pressed", Callable(self, "_on_alphabet_pressed").bind(ch))
	#			alpha.add_child(b)


func _find_descendant(root: Node, target_name: String) -> Node:
	if not root:
			return null
	# simple BFS
	var q: Array = [root]
	while q.size() > 0:
		var n = q.pop_front()
		if _node_name_matches(n.name, target_name):
			return n
		for c in n.get_children():
			q.append(c)
	return null


func _node_name_matches(node_name: String, target_name: String) -> bool:
	# Match exact name or names that include prefixes like 'DebugUI#LeftActionPanel'
	if node_name == target_name:
		return true
	# Some exported/instanced nodes in the editor show up with prefixes like 'Parent#Child'
	# so match by suffix as a fallback.
	if node_name.ends_with("#" + target_name):
		return true
	if node_name.ends_with(target_name):
		return true
	return false


func _find_debug(name: String) -> Node:
	# Try to find DebugUI under the current scene root first, then fall back to
	# this node's children. This allows DebugUI to be instanced at the scene
	# root (preferred) while keeping backwards compatibility.
	var scene_root = get_tree().get_current_scene()
	var ui = null
	if scene_root:
		ui = scene_root.get_node_or_null("DebugUI")
	if not ui:
		ui = get_node_or_null("DebugUI")
	if not ui:
		return null
	return _find_descendant(ui, name)


func _connect_pressed(ui_root: Node, node_name: String, method_name: String) -> void:
	if not ui_root:
		return
	var b = _find_descendant(ui_root, node_name)
	if b and b is Button:
		if not b.is_connected("pressed", Callable(self, method_name)):
			b.connect("pressed", Callable(self, method_name))


func _find_node_compat(root: Node, name: String) -> Node:
	# Some Node subclasses in various runtimes may not expose find_node; use it when available,
	# otherwise fall back to our BFS descendant search.
	if not root:
		return null
	if root.has_method("find_node"):
		# prefer the built-in (name, recursive=true, owned=false)
		return root.find_node(name, true, false)
	return _find_descendant(root, name)
