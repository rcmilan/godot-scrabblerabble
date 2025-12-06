extends Node2D

# Board: Visual/scene wrapper for the logical BoardModel.
# Responsibilities:
# - Convert world/global positions to grid coordinates
# - Optionally snap tile visuals to cell centers
# - Provide a small API used by Tile nodes and other UI code

const BOARD_WIDTH := 15
const BOARD_HEIGHT := 15
@export var cell_size: int = 60 # pixels per cell; keep consistent with Rack TILE_SPACING

func _ready():
	# No heavy logic here; BoardModel (data) is handled by GameManager/BoardModel
	pass

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

