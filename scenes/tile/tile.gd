extends Node2D

# Tile: Represents a single letter tile with its value.
# Handles user interaction like selection and placement.

signal tile_selected(tile)
signal tile_placed(tile, board_pos)

var tile_data: TileModel
var is_selected: bool = false

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

# Placeholder visual elements (may be replaced by scene visuals)
@onready var _sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var _label: Label = $Label if has_node("Label") else null

func _ready():
	# If the scene did not include a label/sprite, create a simple label for debugging
	if not _label:
		_label = Label.new()
		add_child(_label)

	if tile_data and _label:
		_label.text = tile_data.letter

func set_tile_data(p_tile_data: TileModel):
	tile_data = p_tile_data
	if _label:
		_label.text = tile_data.letter

func select():
	is_selected = true
	modulate = Color(0.9, 0.9, 1.1)
	emit_signal("tile_selected", self)

func deselect():
	is_selected = false
	modulate = Color(1, 1, 1)

func _unhandled_input(event):
	# Mouse/drag handling
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# start dragging only if the mouse is over this tile
				var local_mouse = to_local(get_global_mouse_position())
				# simple bounds check based on cell size if available
				_drag_offset = position - local_mouse
				if is_selected:
					_dragging = true
			else:
				if _dragging:
					_dragging = false
					# On release, find the board and emit tile_placed with grid pos
					var board = get_tree().get_root().find_node("Board", true, false)
					if board:
						var grid_pos = board.world_to_grid(global_position)
						if board.is_valid_grid_pos(grid_pos):
							# Notify via EventBus so GameManager and other systems react
							EventBus.emit_signal("tile_placed", tile_data, grid_pos)
							emit_signal("tile_placed", self, grid_pos)
							# Snap visually to the grid
							board.snap_tile_to_grid(self, grid_pos)
							return
					# If we reach here, placement failed; return to origin or leave where released
					pass

	# Drag motion
	if event is InputEventMouseMotion and _dragging:
		global_position = get_global_mouse_position() + _drag_offset

	# Keyboard movement when selected
	if event is InputEventKey and event.pressed and is_selected:
		var board = get_tree().get_root().find_node("Board", true, false)
		var step = 60
		if board and board.has_method("cell_size") == false:
			# if board provides cell_size as export var
			step = board.cell_size if board.has_method("cell_size") == false else step

		match event.scancode:
			KEY_W, KEY_UP:
				global_position.y -= board.cell_size if board else step
			KEY_S, KEY_DOWN:
				global_position.y += board.cell_size if board else step
			KEY_A, KEY_LEFT:
				global_position.x -= board.cell_size if board else step
			KEY_D, KEY_RIGHT:
				global_position.x += board.cell_size if board else step
			KEY_SPACE:
				# Place at current position
				if board:
					var grid_pos = board.world_to_grid(global_position)
					if board.is_valid_grid_pos(grid_pos):
						EventBus.emit_signal("tile_placed", tile_data, grid_pos)
						emit_signal("tile_placed", self, grid_pos)
						board.snap_tile_to_grid(self, grid_pos)
