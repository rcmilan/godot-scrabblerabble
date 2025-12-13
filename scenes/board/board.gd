extends Node2D

# Board: Visual/scene wrapper that manages the logical BoardModel.
# Responsibilities:
# - Hold and manage BoardModel instance
# - Delegate board operations to the model
# - Convert world/global positions to grid coordinates
# - Optionally snap tile visuals to cell centers
# - Provide a centralized API for board operations

const BOARD_WIDTH := 11
const BOARD_HEIGHT := 11
@export var cell_size: int = 60 # pixels per cell; keep consistent with Rack TILE_SPACING

# Board model instance
var BoardModelClass = preload("res://scripts/core/board_model.gd")
var model = null

func _ready():
	# Initialize the board model
	model = BoardModelClass.new()
	add_child(model)  # Add to scene tree so _ready() gets called
	print("[board] Board model initialized")

func world_to_grid(global_pos: Vector2) -> Vector2i:
	# Convert a global position (tile.global_position) into a Vector2i grid coordinate
	var local = to_local(global_pos)
	var gx = int(floor(local.x / cell_size))
	var gy = int(floor(local.y / cell_size))
	return Vector2i(gx, gy)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	# Return the world position for the center of a cell
	var local_x = grid_pos.x * cell_size + cell_size * 0.5
	var local_y = grid_pos.y * cell_size + cell_size * 0.5
	return to_global(Vector2(local_x, local_y))

func is_valid_grid_pos(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < BOARD_WIDTH and grid_pos.y >= 0 and grid_pos.y < BOARD_HEIGHT

func snap_tile_to_grid(tile_node: Node2D, grid_pos: Vector2i) -> void:
	# Move the tile node to the center of the given grid cell
	var world = grid_to_world(grid_pos)
	tile_node.global_position = world

# ============================================================================
# BoardModel Delegation Methods
# ============================================================================

func place_tile(tile_data, grid_pos: Vector2i, temporary: bool = false) -> bool:
    # Place a tile on the board (delegates to model)
	if not model:
		print("[board] Error: model not initialized")
		return false
	return model.place_tile(tile_data, grid_pos, temporary)

func remove_temp_tile(grid_pos: Vector2i) -> void:
    # Remove a temporary tile from the board (delegates to model)
	if model:
		model.remove_temp_tile(grid_pos)

func clear_temp_tiles() -> void:
    # Clear all temporary tiles (delegates to model)
	if model:
		model.clear_temp_tiles()

func commit_temp_tiles(turn_id: int) -> void:
    # Commit temporary tiles to permanent (delegates to model)
	if model:
		model.commit_temp_tiles(turn_id)

func get_temp_positions() -> Array:
    # Get all temporary tile positions (delegates to model)
	if not model:
		return []
	return model.get_temp_positions()

func get_combined_grid_view() -> Array:
    # Get combined view of permanent and temporary tiles (delegates to model)
	if not model:
		return []
	return model.get_combined_grid_view()

func get_candidate_ranges_for_positions(positions: Array) -> Array:
    # Get candidate word ranges for given positions (delegates to model)
	if not model:
		return []
	return model.get_candidate_ranges_for_positions(positions)

func get_grid_state() -> Array:
    # Get the permanent grid state (delegates to model)
	if not model:
		return []
	return model.get_grid_state()
