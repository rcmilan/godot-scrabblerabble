extends Control

## Tile scene script for Scrabble game
## Handles drag & drop, keyboard input, and emits signals for tile interactions

# Signals
signal tile_selected(tile: Node2D)
signal tile_placed(board_pos: Vector2i)

# References to child nodes
@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

# Tile model instance
var tile_model: TileModel

# State variables
var is_selected: bool = false
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

# Constants for tile size
const TILE_SIZE: int = 64

func _ready() -> void:
	# Initialize tile if model is set
	if tile_model:
		update_visuals()

	# Set focus mode for keyboard input
	focus_mode = Control.FOCUS_ALL

func _input(event: InputEvent) -> void:
	if not is_selected:
		return

	# Handle keyboard input for movement and placement
	if event is InputEventKey and event.pressed:
		var direction: Vector2i = Vector2i.ZERO

		match event.keycode:
			KEY_W:
				direction = Vector2i.UP
			KEY_S:
				direction = Vector2i.DOWN
			KEY_A:
				direction = Vector2i.LEFT
			KEY_D:
				direction = Vector2i.RIGHT
			KEY_ENTER, KEY_SPACE:
				# Place tile at current position (assuming board coordinates)
				var board_pos: Vector2i = (global_position / TILE_SIZE).floor()
				emit_signal("tile_placed", board_pos)
				return

		if direction != Vector2i.ZERO:
			# Emit movement signal (assuming there's a selector system)
			# For simplicity, just move the tile
			global_position += Vector2(direction) * TILE_SIZE

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Select tile
			select_tile()
			# Start drag
			is_dragging = true
			drag_offset = get_global_mouse_position() - global_position
		else:
			# End drag
			is_dragging = false
			# Check if dropped on board (placeholder logic)
			var board_pos: Vector2i = (global_position / TILE_SIZE).floor()
			emit_signal("tile_placed", board_pos)

	elif event is InputEventMouseMotion and is_dragging:
		# Update position during drag
		global_position = get_global_mouse_position() - drag_offset

func select_tile() -> void:
	is_selected = true
	# Highlight tile (placeholder visual change)
	sprite.modulate = Color(1, 1, 0.5, 1)  # Yellow highlight
	emit_signal("tile_selected", self)

func deselect_tile() -> void:
	is_selected = false
	# Remove highlight
	sprite.modulate = Color(1, 1, 1, 1)  # Default

func set_tile_model(model: TileModel) -> void:
	tile_model = model
	update_visuals()


func update_visuals() -> void:
	if not is_instance_valid(label):
		push_warning("Label node is invalid; cannot update visuals.")
		return

	if tile_model:
		label.text = tile_model.letter
	else:
		label.text = ""
# Placeholder for drag data
func _get_drag_data(at_position: Vector2) -> Variant:
	return self

# Placeholder for drop validation
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return false
