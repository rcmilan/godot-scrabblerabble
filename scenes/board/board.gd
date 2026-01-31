extends Control
class_name Board

## Board component responsible for managing the game grid.
## Dynamically generates cells based on configurable rows/columns.
## Provides methods to query cells by position and coordinates.

# === Signals ===
signal board_initialized(rows: int, columns: int)
signal cell_clicked(cell: BoardCell)
signal cell_hovered(cell: BoardCell)
signal cell_unhovered(cell: BoardCell)

# === Configuration ===
@export var rows: int = 8
@export var columns: int = 8
@export var cell_size: int = 64
@export var cell_spacing: int = 4

# === Debug ===
@export_group("Debug")
@export var debug_hover: bool = false
@export var debug_interval_frames: int = 30

# === Resources ===
const CELL_SCENE_PATH: String = "res://scenes/board/BoardCell.tscn"
var _cell_scene: PackedScene = null

# === Internal State ===
var _cells: Array[Array] = []  # 2D array: _cells[row][col]
var _hovered_cell: BoardCell = null
var _debug_frame_counter: int = 0

@onready var grid: GridContainer = $GridContainer


func _ready() -> void:
	_cell_scene = load(CELL_SCENE_PATH)
	if _cell_scene == null:
		push_error("[Board] Failed to load cell scene: %s" % CELL_SCENE_PATH)
		return

	_initialize_grid()


func _process(_delta: float) -> void:
	_handle_hover_detection()


# === Public API ===

## Returns the cell at the given grid coordinates, or null if out of bounds.
func get_cell(row: int, col: int) -> BoardCell:
	if row < 0 or row >= rows or col < 0 or col >= columns:
		return null
	return _cells[row][col]


## Returns the cell at the given world position, or null if none found.
func get_cell_at_position(pos: Vector2) -> BoardCell:
	for row in _cells:
		for cell in row:
			if cell.get_global_rect().has_point(pos):
				return cell
	return null


## Returns all cells as a flat array.
func get_all_cells() -> Array[BoardCell]:
	var result: Array[BoardCell] = []
	for row in _cells:
		for cell in row:
			result.append(cell)
	return result


## Returns the grid coordinates of a cell, or Vector2i(-1, -1) if not found.
func get_cell_coords(cell: BoardCell) -> Vector2i:
	for row_idx in range(rows):
		for col_idx in range(columns):
			if _cells[row_idx][col_idx] == cell:
				return Vector2i(col_idx, row_idx)
	return Vector2i(-1, -1)


## Returns a 2D array representing the current board state.
## Each element is either the Tile at that position or null.
func get_grid_state() -> Array[Array]:
	var state: Array[Array] = []
	for row_idx in range(rows):
		var row_state: Array = []
		for col_idx in range(columns):
			var cell: BoardCell = _cells[row_idx][col_idx]
			row_state.append(cell.tile if cell else null)
		state.append(row_state)
	return state


## Clears all tiles from the board.
func clear_board() -> void:
	for row in _cells:
		for cell in row:
			if cell.tile != null:
				cell.clear_tile()


## Resizes the board to new dimensions (recreates all cells).
func resize_board(new_rows: int, new_columns: int) -> void:
	rows = new_rows
	columns = new_columns
	_clear_grid()
	_initialize_grid()


## Adds a row to the bottom of the board.
func add_row() -> void:
	resize_board(rows + 1, columns)


## Adds a column to the right of the board.
func add_column() -> void:
	resize_board(rows, columns + 1)


# === Private Methods ===

func _initialize_grid() -> void:
	_clear_grid()

	# Configure grid container
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", cell_spacing)
	grid.add_theme_constant_override("v_separation", cell_spacing)

	# Generate cells
	_cells = []
	for row_idx in range(rows):
		var row: Array[BoardCell] = []
		for col_idx in range(columns):
			var cell: BoardCell = _create_cell(row_idx, col_idx)
			grid.add_child(cell)
			row.append(cell)
		_cells.append(row)

	_update_grid_size()
	board_initialized.emit(rows, columns)
	print("[Board] Initialized %dx%d grid with %d cells" % [rows, columns, rows * columns])


func _create_cell(row: int, col: int) -> BoardCell:
	var cell: BoardCell = _cell_scene.instantiate() as BoardCell
	cell.name = "Cell_%d_%d" % [row, col]
	cell.grid_position = Vector2i(col, row)

	# Connect signals
	cell.cell_clicked.connect(_on_cell_clicked)
	cell.cell_hovered.connect(_on_cell_hovered)
	cell.cell_unhovered.connect(_on_cell_unhovered)

	return cell


func _clear_grid() -> void:
	for child in grid.get_children():
		child.queue_free()
	_cells = []


func _update_grid_size() -> void:
	var total_width: int = columns * cell_size + (columns - 1) * cell_spacing
	var total_height: int = rows * cell_size + (rows - 1) * cell_spacing
	grid.custom_minimum_size = Vector2(total_width, total_height)


func _handle_hover_detection() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var cell: BoardCell = get_cell_at_position(mouse_pos)

	# Debug output
	if debug_hover:
		_debug_frame_counter += 1
		if _debug_frame_counter % debug_interval_frames == 0:
			if cell:
				print("[BOARD HOVER] Mouse: %s | Cell: %s | Occupied: %s" % [
					mouse_pos, cell.name, cell.is_occupied()
				])
			else:
				print("[BOARD HOVER] Mouse: %s | No cell under cursor" % mouse_pos)

	# Update hover state
	if cell != _hovered_cell:
		if _hovered_cell:
			_hovered_cell.clear_hover()
		_hovered_cell = cell


# === Signal Handlers ===

func _on_cell_clicked(cell: BoardCell) -> void:
	cell_clicked.emit(cell)


func _on_cell_hovered(cell: BoardCell) -> void:
	cell_hovered.emit(cell)


func _on_cell_unhovered(cell: BoardCell) -> void:
	cell_unhovered.emit(cell)
