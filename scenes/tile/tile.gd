extends Control
class_name Tile

signal tile_selected(tile)
signal tile_right_clicked(tile)
signal tile_drag_started(tile)
signal tile_drag_ended(tile)

const DRAG_THRESHOLD := 8.0 #pixels

enum DragState {
	NONE,
	PRESSED,
	DRAGGING
}

enum TileLocation{
	IN_HAND,
	ON_BOARD,
	IN_BAG,
	IN_DISCARD	
}

#Adding tile configuration
var tile_data: LetterTileData
var letter: String = ""
var base_points: int = 0

var location: TileLocation = TileLocation.IN_HAND
var is_selected := false
var current_cell: BoardCell = null
var allow_hover_feedback := true
var drag_state: DragState = DragState.NONE
var drag_offset : Vector2
var press_position: Vector2
var original_z_index: int  # Store z_index before drag


@onready var border: Panel = $Border
#@onready var letter_label: Label = $LetterLabel
#@onready var points_label: Label = $PointsLabel
@onready var texture_rect: TextureRect = $TextureRect


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP # Replace with function body.

func _gui_input(event: InputEvent) -> void:
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			_on_left_pressed(event)
		else:
			_on_left_released(event)
	
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
		print("Right-click on tile", name)
		tile_right_clicked.emit(self)

	elif event is InputEventMouseMotion:
		_on_mouse_motion(event)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if drag_state == DragState.DRAGGING:
		global_position = get_global_mouse_position()- drag_offset

func _on_mouse_entered():
	if not allow_hover_feedback:
		return
	modulate = Color(1.1, 1.1, 1.1)
	
func _on_mouse_exited():
	if not allow_hover_feedback:
		return
	modulate = Color.WHITE
	
func set_selected(value: bool):
	is_selected = value
	print("Trying to set tile as selected, tile:", name)
	update_visual()
	
func _start_drag() -> void:
	drag_state = DragState.DRAGGING
	allow_hover_feedback = false
	
	# Elevate z-index to render above other tiles
	original_z_index = z_index
	z_index = 100  # High value to ensure visibility

	modulate = Color(1.2, 1.2, 1.2) # visual feedback
	print("[DRAG START] Tile: ", name, " | Location: ", TileLocation.keys()[location], " | Current cell: ", current_cell.name if current_cell else "none")
	tile_drag_started.emit(self)
	
	
func _end_drag() -> void:
	# Restore original z-index
	z_index = original_z_index
	print("[DRAG END] Tile: ", name, " | Location: ", TileLocation.keys()[location], " | Current cell: ", current_cell.name if current_cell else "none")
	tile_drag_ended.emit(self)
	
func update_visual() -> void:
	border.visible = is_selected
	
func _on_left_pressed(event: InputEventMouseButton) -> void:
	drag_state = DragState.PRESSED
	press_position = event.position
	# Store offset from click point to tile's top-left corner
	drag_offset = get_global_mouse_position() - global_position
	
func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	if drag_state == DragState.DRAGGING:
		global_position = get_global_mouse_position() - drag_offset
		return

	if drag_state == DragState.PRESSED:
		var delta = event.position - press_position
		if max(abs(delta.x), abs(delta.y)) >= DRAG_THRESHOLD:
			_start_drag()
			
func _on_left_released(event: InputEventMouseButton) -> void:
	match drag_state:
		DragState.PRESSED:
			# This was a click
			tile_selected.emit(self)

		DragState.DRAGGING:
			_end_drag()

	drag_state = DragState.NONE
	allow_hover_feedback = true
	modulate = Color.WHITE
	

#Initializing the tile using configuration data
func initialize(data: LetterTileData) -> void:
	# Validate input data
	if data == null:
		push_error("Tile.initialize() called with null data!")
		return
	
	if data.letter.is_empty():
		push_error("LetterTileData has empty letter string!")
		return
	
	if data.texture == null:
		push_error("LetterTileData for letter '%s' is missing texture!" % data.letter)
		# Continue anyway - tile will work without visual, useful for testing
	
	# Store configuration
	tile_data = data
	letter = data.letter
	base_points = data.base_points
	
	# Update visual elements (with safety checks)	
	var tex_rect = get_node_or_null("TextureRect")
	if tex_rect:
		tex_rect.texture = data.texture
	else:
		push_warning("Tile is missing TextureRect node")
	
	# Confirmation message (can remove after testing)
	print("✓ Initialized tile: letter='%s', points=%d" % [letter, base_points])
	
