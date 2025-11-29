extends Node2D
class_name Board

const CELL_SIZE = 64

# Board is the visual controller for the game board.
# Architecture: Separates logic (BoardModel) from visuals (this Node2D).
# BoardModel handles the grid, tile placement, and word detection.
# This class manages the scene, instantiates BoardModel, and will eventually handle visuals.
# For now, visuals are minimal - just a placeholder.

@onready var board_model: BoardModel = BoardModel.new()

# Placeholder visual: a label showing board status
@onready var status_label: Label = Label.new()

# Placed tiles dictionary
var placed_tiles: Dictionary = {}  # Vector2i -> Node2D

# Highlight sprite for cursor
@onready var highlight_sprite: Sprite2D = Sprite2D.new()

func _ready() -> void:
	add_child(status_label)
	status_label.text = "Board initialized. Tiles placed: 0"
	status_label.position = Vector2(10, 10)
	# Initialize visual grid representation
	for i in range(15):
		for j in range(15):
			var cell_sprite = Sprite2D.new()
			cell_sprite.texture = load("res://assets/sprites/boardcell.png")
			cell_sprite.position = Vector2(i * CELL_SIZE, j * CELL_SIZE)
			add_child(cell_sprite)

	# Add highlight sprite
	highlight_sprite.texture = load("res://assets/sprites/boardcell.png")
	highlight_sprite.modulate = Color(1, 1, 0.5, 1)
	highlight_sprite.scale = Vector2(1.2, 1.2)
	highlight_sprite.visible = false
	add_child(highlight_sprite)
	highlight_sprite.z_index = 5

# Public interface to place a tile (delegates to model)
func place_tile(tile_visual: Node2D, grid_pos: Vector2i) -> bool:
	var success = board_model.place_tile(tile_visual.tile_model, grid_pos)
	if success:
		add_tile_visual(tile_visual, grid_pos)
		update_status()
	return success

# Get all words (delegates to model)
func get_all_words() -> Array:
	return board_model.get_all_words()

# Commit tiles after turn (delegates to model)
func commit_tiles() -> void:
	board_model.commit_tiles()

# Update placeholder status
func update_status() -> void:
	var words = get_all_words()
	status_label.text = "Words formed: %d" % words.size()

# Add tile visual to the board
func add_tile_visual(tile: Node2D, grid_pos: Vector2i) -> void:
	tile.position = grid_pos * CELL_SIZE
	add_child(tile)
	placed_tiles[grid_pos] = tile

# Get the tile at the given position
func get_tile_at(pos: Vector2i) -> Node2D:
	return placed_tiles.get(pos, null)

# Highlight the cell at the given position
func highlight_cell(pos: Vector2i) -> void:
	highlight_sprite.position = pos * CELL_SIZE
	highlight_sprite.visible = true

# Clear all highlights
func clear_highlights() -> void:
	highlight_sprite.visible = false
