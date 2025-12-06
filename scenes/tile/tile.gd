extends Button

# Tile: Represents a single letter tile with its value.
# Handles user interaction like selection and placement.
# Now uses Button for reliable input in CanvasLayer UI contexts.

signal tile_selected(tile)
signal tile_placed(tile, board_pos)

var tile_data: TileModel
var is_selected: bool = false
var used_temp: bool = false

func _ready():
	print("[tile] _ready called as Button")
	# Connect button pressed signal
	pressed.connect(_on_pressed)
	# Set initial visual state
	if tile_data:
		text = tile_data.letter
		print("[tile] Button text set to: ", tile_data.letter)

func _on_pressed():
	print("[tile] Button pressed!")
	if not used_temp:
		select()

func set_tile_data(p_tile_data: TileModel):
	tile_data = p_tile_data
	text = tile_data.letter if tile_data else "?"
	print("[tile] set_tile_data called, letter: ", tile_data.letter if tile_data else "NONE")

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
