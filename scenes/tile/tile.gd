extends Button

# Tile: Represents a single letter tile with its value.
# Handles user interaction like selection and placement.
# Now uses Button for reliable input in CanvasLayer UI contexts.

signal tile_selected(tile)
signal tile_placed(tile, board_pos)
signal tile_right_clicked(tile)

var tile_data: TileModel
var is_selected: bool = false
var used_temp: bool = false

func _ready():
	print("[tile] _ready called as Button")
	# Connect button pressed signal
	pressed.connect(_on_pressed)
	# Enable gui_input for right-click detection
	gui_input.connect(_on_gui_input)

func _on_gui_input(event: InputEvent):
	# Prevent input handling on disabled or temporarily used tiles
	if disabled or used_temp:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			print("[tile] Right-clicked tile: ", tile_data.letter if tile_data else "?")
			emit_signal("tile_right_clicked", self)
			# Emit via EventBus so hand can listen
			if EventBus and EventBus.has_signal("hand_tile_right_clicked"):
				EventBus.emit_signal("hand_tile_right_clicked", self)

func _on_pressed():
	if not used_temp:
		select()

func set_tile_data(p_tile_data: TileModel):
	tile_data = p_tile_data
	text = tile_data.letter if tile_data else "?"

func select():
	print("[tile] select() called for letter: ", tile_data.letter if tile_data else "NO DATA")
	if used_temp:
		print("[tile] Cannot select - tile marked as used_temp")
		return
	is_selected = true
	modulate = Color(0.9, 0.9, 1.1)
	print("[tile] Emitting tile_selected signal")
	emit_signal("tile_selected", self)
	# Emit via EventBus so word_test.gd can listen
	if EventBus:
		print("[tile] Emitting hand_tile_selected via EventBus")
		EventBus.emit_signal("hand_tile_selected", self)

func deselect():
	is_selected = false
	if not used_temp:
		modulate = Color(1, 1, 1)
		disabled = false

func set_temp_used(flag: bool) -> void:
	used_temp = flag
	if used_temp:
		# grey out the tile visually and deselect it
		deselect()
		modulate = Color(0.6, 0.6, 0.6)
		disabled = true
	else:
		modulate = Color(1, 1, 1)
		disabled = false
