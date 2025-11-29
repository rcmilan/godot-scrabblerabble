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

@onready var selection_manager = get_node("/root/SelectionManager")

# Ghost sprite for placement preview
var ghost_preview: Sprite2D

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
	highlight_sprite.z_index = 5  # Highlight layer above board cells

	# Add ghost sprite
	ghost_preview = Sprite2D.new()
	ghost_preview.modulate = Color(1, 1, 1, 0.5)
	ghost_preview.z_index = 5  # Ghost preview layer above highlights
	ghost_preview.visible = false
	add_child(ghost_preview)

func _process(delta: float) -> void:
	if selection_manager.selected_tile and selection_manager.current_mode == selection_manager.Mode.BOARD:
		ghost_preview.visible = true
		ghost_preview.texture = selection_manager.selected_tile.get_node("Sprite2D").texture
		ghost_preview.position = selection_manager.board_cursor * CELL_SIZE
		ghost_preview.modulate = Color(1,1,1,0.5)
		ghost_preview.z_index = 5
	else:
		ghost_preview.visible = false

# Public interface to place a tile (delegates to model)
func place_tile(tile_visual: Node2D, grid_pos: Vector2i) -> bool:
	print("Board place_tile called for grid_pos ", grid_pos, " tile ", tile_visual.name if tile_visual else "null")
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
	add_child(tile)
	tile.position = grid_pos * CELL_SIZE
	tile.z_index = 1  # Tile layer above board cells, below highlights
	tile.visible = true
	tile.modulate = Color(1,1,1,1)
	tile.scale = Vector2(1,1)
	placed_tiles[grid_pos] = tile
	print("Tile placed at grid ", grid_pos, " position ", tile.position, " z_index ", tile.z_index)
	if tile.sprite and tile.sprite.texture:
		print("Tile sprite texture: ", tile.sprite.texture.resource_path)
	else:
		print("Tile sprite or texture null")
	print("Debug info: path=", tile.get_path(), " parent=", tile.get_parent(), " position=", tile.position, " z_index=", tile.z_index, " visible=", tile.visible, " modulate=", tile.modulate, " scale=", tile.scale, " texture_valid=", tile.get_node("Sprite2D").texture != null)
	print("Tile added: visible=", tile.visible, " modulate=", tile.modulate, " scale=", tile.scale, " position=", tile.position)
	assert(tile.visible, "Tile must be visible")
	assert(tile.modulate == Color(1,1,1,1), "Tile modulate must be white")
	assert(tile.scale == Vector2(1,1), "Tile scale must be 1")
	assert(tile.get_node("Sprite2D").texture != null, "Tile texture must be set")
	if OS.is_debug_build():
		var debug_rect = ColorRect.new()
		debug_rect.size = Vector2(CELL_SIZE, CELL_SIZE)
		debug_rect.color = Color(1, 0, 0, 0.5)
		debug_rect.position = Vector2(0, 0)
		tile.add_child(debug_rect)
		debug_rect.z_index = -1

# Get the tile at the given position
func get_tile_at(pos: Vector2i) -> Node2D:
	return placed_tiles.get(pos, null)

# Remove the tile at the given position
func remove_tile(grid_pos: Vector2i) -> Node2D:
	var tile = placed_tiles.get(grid_pos, null)
	if tile:
		placed_tiles.erase(grid_pos)
		remove_child(tile)
		board_model.remove_tile(grid_pos)
		update_status()
		return tile
	return null

# Highlight the cell at the given position
func highlight_cell(pos: Vector2i) -> void:
	highlight_sprite.position = pos * CELL_SIZE
	highlight_sprite.visible = true

# Clear all highlights
func clear_highlights() -> void:
	highlight_sprite.visible = false
