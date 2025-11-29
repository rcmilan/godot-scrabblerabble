extends Node

enum Mode { RACK, BOARD }

var current_mode: Mode = Mode.RACK
var rack_cursor: int = 0
var board_cursor: Vector2i = Vector2i(7, 7)

@onready var rack: Control = get_node("/root/Main/Rack")
@onready var board: Control = get_node("/root/Main/Board")

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
			rack_cursor = min(rack.get_tile_count() - 1, rack_cursor + 1)
			update_rack_highlight()
		KEY_SPACE:
			# Switch to board mode
			current_mode = Mode.BOARD
			rack.clear_highlights()
			update_board_highlight()

func handle_board_input(event: InputEventKey) -> void:
	match event.keycode:
		KEY_W:
			board_cursor.y = clamp(board_cursor.y - 1, 0, 14)
			update_board_highlight()
		KEY_S:
			board_cursor.y = clamp(board_cursor.y + 1, 0, 14)
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
			# Switch back to rack
			current_mode = Mode.RACK
			board.clear_highlights()
			update_rack_highlight()

func update_rack_highlight() -> void:
	rack.clear_highlights()
	if rack.get_tile_count() > 0:
		rack.highlight_tile(rack_cursor)

func update_board_highlight() -> void:
	board.clear_highlights()
	board.highlight_cell(board_cursor)

func place_tile() -> void:
	var tile = rack.get_tile_at(rack_cursor)
	if tile and board.place_tile(tile, board_cursor):
		rack.remove_tile(rack_cursor)
		rack_cursor = clamp(rack_cursor, 0, rack.get_tile_count() - 1)
		update_rack_highlight()