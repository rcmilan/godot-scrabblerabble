extends Node2D

# Rack: Holds and manages the player's tiles for the current turn.

const RACK_SIZE = 7
const TILE_SPACING = 60 # Pixels between tiles

var _tiles = []
var _selected_tile = null

var TileScene = preload("res://scenes/tile/Tile.tscn")

func _ready():
	# Connect to the TileBag to receive new tiles
	# This assumes TileBag has a signal `tiles_drawn(new_tiles)`
	if TileBag:
		TileBag.connect("tiles_drawn", Callable(self, "_on_TileBag_tiles_drawn"))

	# Listen for turn_started so the rack can request a fresh hand
	EventBus.connect("turn_started", Callable(self, "_on_turn_started"))

func draw_new_hand():
	# Clear existing tiles
	for tile in _tiles:
		tile.queue_free()
	_tiles.clear()

	# Request new tiles from the TileBag
	if TileBag:
		TileBag.draw_tiles(RACK_SIZE)

func _on_TileBag_tiles_drawn(new_tile_data_array):
	for i in range(new_tile_data_array.size()):
		var tile_data = new_tile_data_array[i]
		var new_tile = TileScene.instance()
		new_tile.set_tile_data(tile_data)
		new_tile.position = Vector2(i * TILE_SPACING, 0)

		# Connect to the tile's selected signal
		new_tile.connect("tile_selected", Callable(self, "_on_tile_selected"))
		# Remove tile from rack when it's placed on board
		new_tile.connect("tile_placed", Callable(self, "_on_tile_placed"))

		add_child(new_tile)
		_tiles.append(new_tile)

func _on_tile_selected(selected_tile):
	if _selected_tile and _selected_tile != selected_tile:
		_selected_tile.deselect()

	_selected_tile = selected_tile
	# The tile itself handles the visual selection feedback.
	# The rack just needs to know which one is active.
	# Emit hand selection on the EventBus so other systems (e.g., debug UI) can react
	if EventBus and _selected_tile and _selected_tile.tile_data:
		EventBus.emit_signal("hand_letter_selected", _selected_tile.tile_data.letter)

func _on_tile_placed(placed_tile, grid_pos):
	# Remove the visual tile from the rack list if it exists there
	if placed_tile in _tiles:
		_tiles.erase(placed_tile)
	# Optionally free the tile node if the tile isn't already parented elsewhere
	if is_instance_valid(placed_tile):
		# keep the node in the scene for visual placement (Board.snap_tile_to_grid moved it)
		# If you want to remove the node after placement, uncomment the next line:
		# placed_tile.queue_free()
		pass

func _on_turn_started(turn_number):
	# Draw a new hand when a new turn starts
	draw_new_hand()


func remove_one_tile_by_letter(letter: String) -> bool:
	# Find the first tile in the rack with the given letter and remove it
	for t in _tiles:
		if t and t.tile_data and t.tile_data.letter == letter:
			# remove from tracking and free the node
			_tiles.erase(t)
			if is_instance_valid(t):
				t.queue_free()
			return true
	return false

# TODO: Implement logic to remove a tile from the rack when it's placed on the board.
