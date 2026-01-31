extends Control
class_name Main

## Main game controller responsible for coordinating game components.
## Manages tile selection, placement, and overall game interaction flow.

# === Signals ===
signal tile_placement_completed(tile: Tile, cell: BoardCell)
signal tile_returned_to_hand(tile: Tile)

# === Interaction State Machine ===
enum InteractionMode {
	IDLE,           # No tile selected, waiting for input
	TILE_SELECTED,  # Tile selected from hand, waiting for placement
	DRAGGING        # Tile being dragged
}

# === State ===
var selected_tile: Tile = null
var interaction_mode: InteractionMode = InteractionMode.IDLE

# === Node References ===
@onready var board: Board = $Board
@onready var hand: Control = $Hand


func _ready() -> void:
	_connect_board_signals()
	_start_game()


func _process(_delta: float) -> void:
	pass


# === Initialization ===

func _connect_board_signals() -> void:
	# Wait for board to initialize
	if not board.is_node_ready():
		await board.ready

	# Connect to board's forwarded signals
	board.cell_clicked.connect(_on_cell_clicked)
	board.cell_hovered.connect(_on_cell_hovered)
	board.cell_unhovered.connect(_on_cell_unhovered)


func _start_game() -> void:
	var default_bag: BagDistribution = load("res://Data/BagDistribution/bag_default.tres")
	GameManager.start_game(default_bag, 0)


# === Tile Selection Handlers ===

func _on_tile_selected(tile: Tile) -> void:
	print("[Main] Tile selected: %s" % tile.name)

	# Clicking a board tile while holding another tile
	if interaction_mode == InteractionMode.TILE_SELECTED and tile.location == Tile.TileLocation.ON_BOARD:
		print("[Main] Cannot stack tiles")
		return

	# Clicking a tile that's already on the board (info only)
	if interaction_mode == InteractionMode.IDLE and tile.location == Tile.TileLocation.ON_BOARD:
		print("[Main] Board tile at cell: %s" % tile.current_cell.name)
		return

	# Toggle selection if clicking the same tile
	if interaction_mode == InteractionMode.TILE_SELECTED:
		if selected_tile == tile:
			_deselect_tile()
			return
		# Deselect current tile before selecting new one
		selected_tile.set_selected(false)

	# Select the new tile
	selected_tile = tile
	selected_tile.set_selected(true)
	interaction_mode = InteractionMode.TILE_SELECTED
	_set_hand_tiles_hover_enabled(false)


func _on_tile_right_clicked(tile: Tile) -> void:
	if selected_tile != null:
		print("[Main] Cannot remove tile while another is selected")
		return

	if tile.current_cell == null:
		print("[Main] Tile is not on board")
		return

	return_tile_to_hand(tile)


func _on_tile_drag_ended(tile: Tile) -> void:
	var cell: BoardCell = _get_cell_under_mouse()

	var cell_name: String = String(cell.name) if cell else "none"
	print("[Main] Drag ended - Tile: %s | Location: %s | Cell: %s" % [
		tile.name,
		Tile.TileLocation.keys()[tile.location],
		cell_name
	])

	# Dropped outside board
	if cell == null:
		if tile.location == Tile.TileLocation.ON_BOARD:
			_return_to_original_cell(tile)
		else:
			_cancel_drag_to_hand(tile)
		return

	# Dropped on occupied cell
	if cell.is_occupied():
		print("[Main] Cannot drop on occupied cell: %s" % cell.name)
		if tile.location == Tile.TileLocation.ON_BOARD:
			_return_to_original_cell(tile)
		else:
			_cancel_drag_to_hand(tile)
		return

	# Valid placement
	print("[Main] Valid drop on cell: %s" % cell.name)
	place_tile_on_cell(tile, cell)


# === Cell Handlers ===

func _on_cell_clicked(cell: BoardCell) -> void:
	if selected_tile == null:
		print("[Main] No tile selected")
		return

	if cell.is_occupied():
		print("[Main] Cell occupied: %s" % cell.name)
		return

	place_tile_on_cell(selected_tile, cell)


func _on_cell_hovered(cell: BoardCell) -> void:
	if interaction_mode != InteractionMode.TILE_SELECTED:
		return

	if cell.is_occupied():
		cell.show_invalid_hover()
	else:
		cell.show_valid_hover()


func _on_cell_unhovered(cell: BoardCell) -> void:
	cell.clear_hover()


# === Tile Placement ===

func place_tile_on_cell(tile: Tile, cell: BoardCell) -> void:
	if cell.is_occupied():
		return

	# Clear old cell if tile was on board
	if tile.location == Tile.TileLocation.ON_BOARD and tile.current_cell != null:
		var old_cell: BoardCell = tile.current_cell
		old_cell.tile = null
		print("[Main] Cleared old cell: %s" % old_cell.name)

	# Reparent tile to cell
	tile.get_parent().remove_child(tile)
	cell.tile_anchor.add_child(tile)
	tile.position = Vector2.ZERO

	# Update tile state
	tile.current_cell = cell
	tile.location = Tile.TileLocation.ON_BOARD

	# Update cell state
	cell.tile = tile

	# Reset interaction state
	tile.set_selected(false)
	selected_tile = null
	interaction_mode = InteractionMode.IDLE

	_set_hand_tiles_hover_enabled(true)
	_clear_all_cell_hovers()

	EventBus.tile_placed.emit(tile, cell)
	tile_placement_completed.emit(tile, cell)
	print("[Main] Placed tile %s on cell %s" % [tile.name, cell.name])


func return_tile_to_hand(tile: Tile) -> void:
	if tile.current_cell == null:
		return

	var cell: BoardCell = tile.current_cell

	# Clear cell
	cell.tile = null

	# Move tile to hand
	cell.tile_anchor.remove_child(tile)
	hand.add_tile(tile)

	# Update tile state
	tile.current_cell = null
	tile.location = Tile.TileLocation.IN_HAND
	tile.set_selected(false)

	interaction_mode = InteractionMode.IDLE
	_clear_all_cell_hovers()

	EventBus.tile_removed.emit(tile, cell)
	tile_returned_to_hand.emit(tile)
	print("[Main] Returned tile %s from cell %s to hand" % [tile.name, cell.name])


# === Private Helpers ===

func _deselect_tile() -> void:
	if selected_tile != null:
		selected_tile.set_selected(false)
		selected_tile = null

	interaction_mode = InteractionMode.IDLE
	_clear_all_cell_hovers()
	_set_hand_tiles_hover_enabled(true)


func _set_hand_tiles_hover_enabled(enabled: bool) -> void:
	for tile in hand.get_tiles():
		tile.allow_hover_feedback = enabled


func _get_cell_under_mouse() -> BoardCell:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	return board.get_cell_at_position(mouse_pos)


func _clear_all_cell_hovers() -> void:
	for cell in board.get_all_cells():
		cell.clear_hover()


func _cancel_drag_to_hand(tile: Tile) -> void:
	"""Returns tile to hand after cancelled drag (tile was never on board)."""
	if tile.get_parent():
		tile.get_parent().remove_child(tile)

	hand.add_tile(tile)

	tile.location = Tile.TileLocation.IN_HAND
	tile.current_cell = null
	tile.modulate = Color.WHITE
	tile.set_selected(false)

	interaction_mode = InteractionMode.IDLE
	_clear_all_cell_hovers()

	print("[Main] Cancelled drag for tile: %s" % tile.name)


func _return_to_original_cell(tile: Tile) -> void:
	"""Returns dragged board tile back to its current cell."""
	if tile.current_cell == null:
		push_error("[Main] Board tile has no current_cell reference!")
		return

	tile.position = Vector2.ZERO
	tile.modulate = Color.WHITE

	print("[Main] Tile %s returned to cell: %s" % [tile.name, tile.current_cell.name])
