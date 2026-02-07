extends Node
class_name DragManager

## DragManager: Coordinates multi-tile drag operations.
## Handles visual positioning of all dragged tiles during drag.
## Separates drag logic from individual tile behavior.

# =============================================================================
# SIGNALS
# =============================================================================

signal drag_started(tiles: Array[Tile])
signal drag_ended(tiles: Array[Tile], success: bool)
signal drag_cancelled(tiles: Array[Tile])
signal drag_release_requested(lead_tile: Tile)  # Mouse released during drag

# =============================================================================
# STATE
# =============================================================================

var is_dragging: bool = false
var dragged_tiles: Array[Tile] = []
var lead_tile: Tile = null  # The tile being directly dragged

# Original state for restoration
var _original_parents: Dictionary = {}  # Tile -> Node
var _original_positions: Dictionary = {}  # Tile -> Vector2
var _original_indices: Dictionary = {}  # Tile -> int
var _relative_offsets: Dictionary = {}  # Tile -> Vector2 (offset from lead tile)

# Drag container for reparenting tiles during drag
var _drag_container: Control = null

# Configuration
const DRAG_Z_INDEX: int = 100
const TILE_SPACING: float = 68.0  # Spacing between tiles in drag preview


func _ready() -> void:
	# Create a container for dragged tiles (will be added to scene when needed)
	_drag_container = Control.new()
	_drag_container.name = "DragContainer"
	_drag_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_container.z_index = DRAG_Z_INDEX


func _input(event: InputEvent) -> void:
	# Catch mouse release during drag - tiles may not receive it after reparenting
	if is_dragging and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			print("[DragManager] Mouse released during drag")
			drag_release_requested.emit(lead_tile)


func _process(_delta: float) -> void:
	if is_dragging and lead_tile:
		_update_drag_positions()


# =============================================================================
# PUBLIC API
# =============================================================================

## Starts a multi-tile drag operation.
## Parameters:
##   lead: The tile being directly dragged by the user (must be in tiles array)
##   tiles: All tiles to drag (including lead tile)
func start_drag(lead: Tile, tiles: Array[Tile]) -> void:
	if is_dragging:
		cancel_drag()

	if tiles.is_empty():
		return

	if lead not in tiles:
		push_error("[DragManager] Lead tile must be in tiles array")
		return

	is_dragging = true
	lead_tile = lead
	dragged_tiles = tiles.duplicate()

	# Store original state and clear board cell references
	_store_original_state()

	# Calculate relative offsets from lead tile
	_calculate_relative_offsets()

	# Reparent tiles to drag container for unified movement
	_setup_drag_container()

	# Notify listeners
	drag_started.emit(dragged_tiles)
	EventBus.multi_drag_started.emit(dragged_tiles)

	print("[DragManager] Started drag with %d tiles (lead: %s)" % [tiles.size(), lead.letter])


## Ends the drag operation.
## Parameters:
##   success: Whether the drag resulted in successful placement
func end_drag(success: bool) -> void:
	if not is_dragging:
		return

	# Emit signals before cleanup
	drag_ended.emit(dragged_tiles, success)
	EventBus.multi_drag_ended.emit(dragged_tiles, success)

	print("[DragManager] Ended drag (success: %s)" % success)

	# Cleanup is handled by the caller (Main.gd) which will either
	# place tiles or restore them
	_cleanup_drag_state()


## Cancels the drag and restores tiles to original positions.
func cancel_drag() -> void:
	if not is_dragging:
		return

	print("[DragManager] Cancelling drag")

	# Restore tiles to original parents and positions
	_restore_tiles_to_original()

	drag_cancelled.emit(dragged_tiles)

	_cleanup_drag_state()


## Returns tiles to their original parents (for placement handling by Main).
## Call this before placing tiles or when restoring after failed drop.
func restore_tiles_to_parents() -> void:
	# Sort tiles by original index (descending) to maintain order when re-adding
	var tiles_with_indices: Array = []
	for tile in dragged_tiles:
		if is_instance_valid(tile):
			var idx: int = _original_indices.get(tile, -1)
			tiles_with_indices.append({"tile": tile, "index": idx})

	# Sort by index ascending so we add them in order
	tiles_with_indices.sort_custom(func(a, b): return a.index < b.index)

	for entry in tiles_with_indices:
		var tile: Tile = entry.tile
		var original_index: int = entry.index

		var original_parent: Node = _original_parents.get(tile)
		if original_parent and is_instance_valid(original_parent):
			if tile.get_parent() == _drag_container:
				_drag_container.remove_child(tile)
			if tile.get_parent():
				tile.get_parent().remove_child(tile)
			original_parent.add_child(tile)
			tile.position = _original_positions.get(tile, Vector2.ZERO)

			# Restore original child order if index was stored
			if original_index >= 0 and original_index < original_parent.get_child_count():
				original_parent.move_child(tile, original_index)

		# Restore cell binding if tile was on board (atomic state management)
		if tile.location == Tile.TileLocation.ON_BOARD:
			tile.restore_cell_binding()

		# Reset tile's internal drag state
		tile.force_end_drag()


## Gets the current drag position (lead tile's global position).
func get_drag_position() -> Vector2:
	if lead_tile and is_instance_valid(lead_tile):
		return lead_tile.global_position
	return Vector2.ZERO


## Gets the tiles being dragged (returns a copy to prevent mutation issues).
func get_dragged_tiles() -> Array[Tile]:
	return dragged_tiles.duplicate()


## Gets the original parent of a tile.
func get_original_parent(tile: Tile) -> Node:
	return _original_parents.get(tile)


## Gets the original position of a tile.
func get_original_position(tile: Tile) -> Vector2:
	return _original_positions.get(tile, Vector2.ZERO)


# =============================================================================
# PRIVATE: STATE MANAGEMENT
# =============================================================================

func _store_original_state() -> void:
	_original_parents.clear()
	_original_positions.clear()
	_original_indices.clear()

	for tile in dragged_tiles:
		var parent: Node = tile.get_parent()
		_original_parents[tile] = parent
		_original_positions[tile] = tile.position
		if parent:
			_original_indices[tile] = tile.get_index()


func _calculate_relative_offsets() -> void:
	_relative_offsets.clear()

	if not lead_tile:
		return

	# For horizontal arrangement, tiles are spaced out to the right of lead
	var lead_index: int = dragged_tiles.find(lead_tile)

	for i in dragged_tiles.size():
		var tile: Tile = dragged_tiles[i]
		# Calculate horizontal offset based on position in array relative to lead
		var offset_index: int = i - lead_index
		_relative_offsets[tile] = Vector2(offset_index * TILE_SPACING, 0)


func _setup_drag_container() -> void:
	# Add drag container to the scene if not already
	var root: Node = get_tree().current_scene
	if _drag_container.get_parent() != root:
		if _drag_container.get_parent():
			_drag_container.get_parent().remove_child(_drag_container)
		root.add_child(_drag_container)

	# Reparent tiles to drag container
	for tile in dragged_tiles:
		var global_pos: Vector2 = tile.global_position

		# Suspend cell binding so the cell is available for placement
		# Uses atomic state management to ensure consistency
		if tile.location == Tile.TileLocation.ON_BOARD:
			tile.suspend_cell_binding()

		if tile.get_parent():
			tile.get_parent().remove_child(tile)
		_drag_container.add_child(tile)
		tile.global_position = global_pos
		tile.z_index = DRAG_Z_INDEX
		tile.modulate = Color(1.2, 1.2, 1.2)  # Highlight during drag


func _update_drag_positions() -> void:
	if not lead_tile or not is_instance_valid(lead_tile):
		return

	# Lead tile follows mouse (handled by Tile._process)
	# Other tiles maintain their relative offset from lead
	var lead_global_pos: Vector2 = lead_tile.global_position

	for tile in dragged_tiles:
		if tile == lead_tile:
			continue
		if not is_instance_valid(tile):
			continue

		var offset: Vector2 = _relative_offsets.get(tile, Vector2.ZERO)
		tile.global_position = lead_global_pos + offset


func _restore_tiles_to_original() -> void:
	# Sort tiles by original index ascending to maintain order when re-adding
	var tiles_with_indices: Array = []
	for tile in dragged_tiles:
		if is_instance_valid(tile):
			var idx: int = _original_indices.get(tile, -1)
			tiles_with_indices.append({"tile": tile, "index": idx})

	tiles_with_indices.sort_custom(func(a, b): return a.index < b.index)

	for entry in tiles_with_indices:
		var tile: Tile = entry.tile
		var original_index: int = entry.index
		var original_parent: Node = _original_parents.get(tile)
		var original_pos: Vector2 = _original_positions.get(tile, Vector2.ZERO)

		if tile.get_parent() == _drag_container:
			_drag_container.remove_child(tile)

		if original_parent and is_instance_valid(original_parent):
			original_parent.add_child(tile)
			tile.position = original_pos

			# Restore original child order if index was stored
			if original_index >= 0 and original_index < original_parent.get_child_count():
				original_parent.move_child(tile, original_index)

		# Restore cell binding if tile was on board (atomic state management)
		if tile.location == Tile.TileLocation.ON_BOARD:
			tile.restore_cell_binding()

		# Reset tile's internal drag state
		tile.force_end_drag()


func _cleanup_drag_state() -> void:
	# Remove drag container from scene
	if _drag_container.get_parent():
		_drag_container.get_parent().remove_child(_drag_container)

	is_dragging = false
	lead_tile = null
	dragged_tiles.clear()
	_original_parents.clear()
	_original_positions.clear()
	_original_indices.clear()
	_relative_offsets.clear()
