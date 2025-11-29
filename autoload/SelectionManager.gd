extends Node

# SelectionManager handles tile selection and placement logic.
# Tile selection: In RACK mode, use A/D to select tiles from rack. In BOARD mode, select tiles already placed on board by pressing SPACE on occupied cell.
# Placement flow: Select tile from rack or board, switch to BOARD mode, move cursor with WASD, place with SPACE.
# Highlight management: Highlights current selection in rack or board cursor position on board.

enum Mode { RACK, BOARD }

var current_mode: Mode = Mode.RACK
var rack_cursor: int = 0
var board_cursor: Vector2i = Vector2i(7, 7)
var selected_tile: Node2D = null
var selected_from_rack: bool = false
var selected_original_pos: Vector2i

@onready var rack: Node2D = get_node("/root/Main/Rack")
@onready var board: Node2D = get_node("/root/Main/Board")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match current_mode:
			Mode.RACK:
				handle_rack_input(event)
			Mode.BOARD:
				handle_board_input(event)

func handle_rack_input(event: InputEventKey) -> void:
	match event.keycode:
		KEY_A:
			rack_cursor = max(0, rack_cursor - 1)
			update_rack_highlight()
		KEY_D:
			rack_cursor = max(0, min(rack.get_tile_count() - 1, rack_cursor + 1))
			update_rack_highlight()
		KEY_W:
			# Switch to board mode
			var tile = rack.get_tile_at(rack_cursor)
			if tile and is_instance_valid(tile):
				current_mode = Mode.BOARD
				selected_tile = tile
				selected_from_rack = true
				rack.clear_highlights()
				update_board_highlight()
			else:
				print("DEBUG: No valid tile at rack cursor to select")
		KEY_SPACE:
			# Switch to board mode
			var tile = rack.get_tile_at(rack_cursor)
			if tile and is_instance_valid(tile):
				current_mode = Mode.BOARD
				selected_tile = tile
				selected_from_rack = true
				rack.clear_highlights()
				update_board_highlight()
			else:
				print("DEBUG: No valid tile at rack cursor to select")

func handle_board_input(event: InputEventKey) -> void:
	match event.keycode:
		KEY_W:
			board_cursor.y = clamp(board_cursor.y - 1, 0, 14)
			update_board_highlight()
		KEY_S:
			var new_y = board_cursor.y + 1
			if new_y > 14:
				current_mode = Mode.RACK
				board.clear_highlights()
				update_rack_highlight()
			else:
				board_cursor.y = new_y
				update_board_highlight()
		KEY_A:
			board_cursor.x = clamp(board_cursor.x - 1, 0, 14)
			update_board_highlight()
		KEY_D:
			board_cursor.x = clamp(board_cursor.x + 1, 0, 14)
			update_board_highlight()
		KEY_SPACE:
			# Place tile
			place_tile()
		KEY_TAB:
			# Cancel
			if selected_tile and is_instance_valid(selected_tile):
				selected_tile.deselect_tile()
				if selected_from_rack:
					pass  # do nothing
				else:
					board.place_tile(selected_tile, selected_original_pos)
			selected_tile = null
			selected_from_rack = false
			current_mode = Mode.RACK
			board.clear_highlights()
			update_rack_highlight()

func update_rack_highlight() -> void:
	rack_cursor = clamp(rack_cursor, 0, max(0, rack.get_tile_count() - 1))
	rack.selected_index = rack_cursor if rack_cursor >= 0 and rack_cursor < rack.get_tile_count() else -1
	rack.update_selection()

func update_board_highlight() -> void:
	board.clear_highlights()
	board.highlight_cell(board_cursor)

func place_tile() -> void:
	print("SelectionManager place_tile: selected_tile ", selected_tile.name if selected_tile else "null", " cursor ", board_cursor, " from_rack ", selected_from_rack)
	if not selected_tile or not is_instance_valid(selected_tile):
		print("DEBUG: Invalid state - place_tile called with null or invalid selected_tile")
		return
	var tile_at_cursor = board.get_tile_at(board_cursor)
	if tile_at_cursor:
		# Select the tile from board
		selected_tile = board.remove_tile(board_cursor)
		if not selected_tile or not is_instance_valid(selected_tile):
			print("DEBUG: No valid tile at board cursor to select")
			return
		selected_tile.select_tile()
		selected_from_rack = false
		selected_original_pos = board_cursor
		current_mode = Mode.BOARD
		update_board_highlight()
	else:
		# Place the selected tile
		if not selected_tile or not is_instance_valid(selected_tile):
			print("DEBUG: selected_tile became null or invalid before placement")
			return
		print("Before placement: selected_tile parent: ", selected_tile.get_parent())
		if selected_from_rack:
			selected_tile.get_parent().remove_child(selected_tile)
		if board.place_tile(selected_tile, board_cursor):
			print("Placement successful: tile placed at ", board_cursor)
			selected_tile.deselect_tile()
			if selected_from_rack:
				rack.tiles.erase(selected_tile)
				rack.update_visuals()
			selected_tile = null
			selected_from_rack = false
			board.clear_highlights()
			update_board_highlight()
		else:
			print("Placement failed: no tile to place or cell occupied.")
			if selected_tile and is_instance_valid(selected_tile):
				selected_tile.deselect_tile()
			if selected_tile and not selected_from_rack and is_instance_valid(selected_tile):
				board.place_tile(selected_tile, selected_original_pos)
			selected_tile = null
			selected_from_rack = false
			current_mode = Mode.RACK
			board.clear_highlights()
			update_rack_highlight()
