extends Node

var selected_tile: Tile = null


enum InteractionMode {
	IDLE,
	TILE_SELECTED
}

var interaction_mode: InteractionMode = InteractionMode.IDLE

#tilebag temporary testing
#var bag_config = load("res://Data/BagDistribution/bag_default.tres")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Tiles will be spawned dynamically by HandManager
	
	for cell in $Board/GridContainer.get_children():
		cell.cell_clicked.connect(_on_cell_clicked) # Replace with function body.
		cell.cell_hovered.connect(_on_cell_hovered)
		cell.cell_unhovered.connect(_on_cell_unhovered)
		
	# DEV: Auto-start game with default bag configuration
	var default_bag = load("res://Data/BagDistribution/bag_default.tres")
	GameManager.start_game(default_bag, 0)
	##test done!
	#if bag_config and bag_config.is_valid():
	#	print("[Main]: Tilebag config loaded successfully, number of tiles: ", bag_config.get_total_tiles())
	#else:
	#	push_error("[Main]: Failed to load and/or validate bag distribution")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	

func _on_tile_selected(tile: Tile) -> void:
	
	print("Main received tile_selected from:", tile.name)
	
	#Implementing state enums as explicit state checking
	#Player is holding a tile and clicks a board tile -> invalid play
	if interaction_mode == InteractionMode.TILE_SELECTED and tile.location == Tile.TileLocation.ON_BOARD:
		print(
			"Cannot place ",
			selected_tile.name,
			" on top of ",
			tile.name,
			" at ",
			tile.current_cell.name
		)
		return
		
	#Clicking a tile on the board
	if interaction_mode == InteractionMode.IDLE and tile.location == Tile.TileLocation.ON_BOARD:
		print(
			"This tile is placed on the board on cell:",
			tile.current_cell.name
		)
		return
		
	#Selection logic for game state TILE_SELECTED
	if interaction_mode == InteractionMode.TILE_SELECTED:
		if selected_tile == tile:
			tile.set_selected(false)
			selected_tile = null
			interaction_mode = InteractionMode.IDLE
			
			clear_all_cell_hovers()
			set_tile_hover_enabled(true)
			print("Tile: ", tile.name, " has been unselected.")
			return
		
		selected_tile.set_selected(false)
		
	
	#Selection logic for game state IDLE
	selected_tile = tile
	selected_tile.set_selected(true)
	interaction_mode = InteractionMode.TILE_SELECTED
	
	set_tile_hover_enabled(false)
	
	
func set_tile_hover_enabled(enabled: bool):
	for tile in $Hand.get_tiles():
		tile.allow_hover_feedback = enabled

	
func _on_tile_right_clicked(tile: Tile) -> void:
	if selected_tile != null:
		print("Cannot remove tile while another tile is selected")
		return
	
	if tile.current_cell == null:
		print("Right-clicked tile is current not on board")
		return
		
	return_tile_to_hand(tile)
	
func _on_cell_clicked(cell):
	if selected_tile == null:
		print("no tile selected")
		return 
		
	#This shoudln't ever trigger but it is defensive against unmapped clicking behavior
	if cell.occupied:
		print("cell already occupied by tile:", cell.name)
		return
		
	place_tile_on_cell(selected_tile,cell)
	
func place_tile_on_cell(tile: Tile, cell: BoardCell) -> void:
	
	if cell.occupied:
		return
	
	# If tile was on board, clear the old cell first
	if tile.location == Tile.TileLocation.ON_BOARD and tile.current_cell != null:
		var old_cell := tile.current_cell
		old_cell.occupied = false
		old_cell.tile = null
		print("Cleared old cell: ", old_cell.name)
	
	#Remove from previous parent (hand or board cell)
	tile.get_parent().remove_child(tile)
	cell.tile_anchor.add_child(tile)
	tile.position = Vector2.ZERO
	
	
	#Tile state control
	tile.current_cell = cell
	tile.location = Tile.TileLocation.ON_BOARD
	
	#update ownership state
	cell.occupied = true
	cell.tile = tile
	
	#Storing context on the tile
	
	tile.set_selected(false)	
	selected_tile = null
	interaction_mode = InteractionMode.IDLE
	
	
	set_tile_hover_enabled(true)
	clear_all_cell_hovers()
	EventBus.tile_placed.emit(tile, cell)
	print("Placed tile ", tile.name, " on cell ", cell.name)
	
	
func return_tile_to_hand(tile: Tile) -> void:
	if tile.current_cell == null:
		return
	
	var cell := tile.current_cell
	
	# Clearing cell
	cell.occupied = false
	cell.tile = null
	
	#Moving tile to hand
	cell.tile_anchor.remove_child(tile)
	$Hand.add_tile(tile)
	
	#Update tile state
	tile.current_cell = null
	tile.location = Tile.TileLocation.IN_HAND
	
	tile.set_selected(false)
	interaction_mode = InteractionMode.IDLE
	clear_all_cell_hovers()
	EventBus.tile_removed.emit(tile,cell)
	print("Returned tile: ", tile.name, ", from cell: ", cell.name, " to hand")
	
func cancel_drag_to_hand(tile: Tile) -> void:
	"""Returns tile to hand after cancelled drag attempt (never placed on board)"""
	# Remove from current parent (might be floating during drag)
	if tile.get_parent():
		tile.get_parent().remove_child(tile)
	
	# Add back to hand container
	$Hand.add_tile(tile)
	
	# Update tile state
	tile.location = Tile.TileLocation.IN_HAND
	tile.current_cell = null
	
	# Reset visuals and interaction state
	tile.modulate = Color.WHITE
	tile.set_selected(false)
	interaction_mode = InteractionMode.IDLE
	clear_all_cell_hovers()
	
	print("Cancelled drag for tile: ", tile.name, " - returned to hand")

func return_to_original_cell(tile: Tile) -> void:
	"""Returns dragged board tile back to its current cell after failed drop"""
	if tile.current_cell == null:
		print("ERROR: Board tile has no current_cell reference!")
		return
	
	var cell := tile.current_cell
	
	# Tile is already child of cell.tile_anchor, just snap position
	tile.position = Vector2.ZERO
	
	# Reset visuals
	tile.modulate = Color.WHITE
	
	print("Tile ", tile.name, " returned to original cell: ", cell.name)
	
func _on_cell_hovered(cell: BoardCell) -> void:
	if interaction_mode != InteractionMode.TILE_SELECTED:
		return
	
	if cell.occupied:
		cell.show_invalid_hover()
	else:
		cell.show_valid_hover()
		
func get_cell_under_mouse() -> BoardCell:
	var mouse_pos := get_viewport().get_mouse_position()
	
	for cell in $Board/GridContainer.get_children():
		if cell.get_global_rect().has_point(mouse_pos):
			return cell
	
	return null

func _on_cell_unhovered(cell: BoardCell) -> void:
	cell.clear_hover()
	
func clear_all_cell_hovers() -> void:
	for cell in $Board/GridContainer.get_children():
		cell.clear_hover()

func _on_tile_drag_ended(tile: Tile) -> void:
	var cell := get_cell_under_mouse()
	print("[MAIN] Drag ended - Tile: ", tile.name, " | Location: ", Tile.TileLocation.keys()[tile.location], " | Cell under mouse: ", cell.name if cell else "none", " | Occupied: ", cell.occupied if cell else "N/A")

	if cell == null:
		if tile.location == Tile.TileLocation.ON_BOARD:
			print("[MAIN] Tile ON_BOARD dropped outside - return to original cell")
			return_to_original_cell(tile)
		else:
			print("[MAIN] Tile IN_HAND dropped outside - cancel drag")
			cancel_drag_to_hand(tile)
		return

	if cell.occupied:
		print("[MAIN] Invalid drop on occupied cell:", cell.name)
		if tile.location == Tile.TileLocation.ON_BOARD:
			print("[MAIN] Tile ON_BOARD on occupied - return to original cell")
			return_to_original_cell(tile)
		else:
			print("[MAIN] Tile IN_HAND on occupied - cancel drag")
			cancel_drag_to_hand(tile)
		return

	print("[MAIN] Valid placement on cell:", cell.name)
	place_tile_on_cell(tile, cell)

## Temporary test for the event bus event handling
#func _input(event: InputEvent) -> void:
#	if event is InputEventKey and event.pressed:
#		if event.keycode == KEY_T:
#			print("Testing EventBus...")
#			EventBus.game_started.emit()
#			print("EventBus is working!")
