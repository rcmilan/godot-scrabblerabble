extends Control
class_name Tile

## A letter tile that can be placed on the board or held in hand.
## Supports click-to-select and drag-and-drop interactions.
## Manages its own visual state and emits signals for game events.
## Drag state machine is delegated to TileDragHelper.

# === Signals ===
signal tile_selected(tile: Tile)
signal tile_right_clicked(tile: Tile)
signal tile_drag_started(tile: Tile)
signal tile_drag_ended(tile: Tile)

# === Constants ===
const DRAG_Z_INDEX: int = 100      # Z-index while dragging
const SELECTED_SCALE: Vector2 = Vector2(1.05, 1.05)
const NORMAL_SCALE: Vector2 = Vector2(1.0, 1.0)
const SCALE_TWEEN_DURATION: float = 0.1

# === Enums ===

## Where the tile currently resides
enum TileLocation {
	IN_BAG,      # Not yet drawn
	IN_HAND,     # Player's hand
	ON_BOARD,    # Placed on board
	IN_DISCARD   # Discarded
}

# === Tile Data (from LetterTileData resource) ===
var tile_data: LetterTileData = null
var letter: String = ""
var base_points: int = 0

# === Tile Modifiers (for future features) ===
var point_modifier: int = 0        # Bonus/penalty to base points
var is_wild: bool = false          # Wild card tile
var is_locked: bool = false        # Cannot be moved once placed

# === Location State ===
var location: TileLocation = TileLocation.IN_BAG
var current_cell: BoardCell = null  # Only valid when ON_BOARD
var _cell_binding_suspended: bool = false  # True during drag operations

# === Selection State ===
var is_selected: bool = false
var allow_hover_feedback: bool = true
var selection_order: int = -1  # -1 = not selected

# === Drag State (delegated to TileDragHelper) ===
var _drag: TileDragHelper = null
var _original_z_index: int = 0

# === Pending initialization (applied in _ready) ===
var _pending_texture: Texture2D = null

# === Node References ===
@onready var border: Panel = $Border
@onready var texture_rect: TextureRect = $TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	_drag = TileDragHelper.new()
	_drag.drag_threshold_reached.connect(_on_drag_threshold_reached)
	_drag.drag_ended.connect(_on_drag_ended)

	# Apply pending texture if initialize() was called before _ready()
	if _pending_texture and texture_rect:
		texture_rect.texture = _pending_texture
		_pending_texture = null

	_update_visual()


func _process(_delta: float) -> void:
	# Only update position if we're the lead tile (directly dragged)
	# DragManager handles positioning for follower tiles
	if _drag.is_dragging() and _drag.is_lead_tile:
		global_position = get_global_mouse_position() - _drag.drag_offset


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


# === Public API ===

## Initialize tile with data from a LetterTileData resource.
func initialize(data: LetterTileData) -> void:
	if data == null:
		push_error("[Tile] initialize() called with null data!")
		name = "Tile_ERROR_NULL_%d" % get_instance_id()
		return

	# Strip whitespace from letter to handle data inconsistencies
	var clean_letter: String = data.letter.strip_edges() if data.letter else ""

	if clean_letter.is_empty():
		push_error("[Tile] LetterTileData has empty letter! Raw value: '%s'" % data.letter)
		name = "Tile_ERROR_EMPTY_%d" % get_instance_id()
		return

	tile_data = data
	letter = clean_letter
	base_points = data.base_points

	# Set unique name using instance ID to avoid Godot auto-renaming duplicates
	name = "Tile_%s_%d" % [letter, get_instance_id()]

	# Apply texture now if node is ready, otherwise store for _ready()
	if data.texture:
		if texture_rect:
			texture_rect.texture = data.texture
		else:
			_pending_texture = data.texture
	else:
		push_warning("[Tile] Letter '%s' is missing texture" % letter)

	print("[Tile] Initialized: %s (%d pts)" % [letter, base_points])


## Set the selected state of this tile.
func set_selected(value: bool) -> void:
	is_selected = value
	_update_visual()
	_animate_selection_scale()


## Set the selection order for multi-select.
func set_selection_order(order: int) -> void:
	selection_order = order


func _animate_selection_scale() -> void:
	var target_scale: Vector2 = SELECTED_SCALE if is_selected else NORMAL_SCALE
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", target_scale, SCALE_TWEEN_DURATION) \
		.set_ease(Tween.EASE_OUT)


## Get the total point value including modifiers.
func get_points() -> int:
	return base_points + point_modifier


## Check if this tile can be interacted with.
func can_interact() -> bool:
	return not is_locked and location != TileLocation.IN_BAG


# =============================================================================
# PLACEMENT STATE MANAGEMENT (DDD: Single responsibility for tile-cell binding)
# =============================================================================

## Atomically attaches this tile to a board cell.
## Updates both tile.current_cell and cell.tile to maintain consistency.
func attach_to_cell(cell: BoardCell) -> void:
	if cell == null:
		push_error("[Tile] Cannot attach to null cell")
		return

	# Detach from any existing cell first
	if current_cell != null and current_cell != cell:
		detach_from_cell()

	current_cell = cell
	cell.tile = self
	location = TileLocation.ON_BOARD
	_cell_binding_suspended = false
	print("[Tile] %s attached to cell %s" % [name, cell.name])


## Atomically detaches this tile from its current cell.
## Clears both tile.current_cell and cell.tile.
func detach_from_cell() -> void:
	if current_cell != null:
		var cell_name: String = current_cell.name
		current_cell.tile = null
		current_cell = null
		_cell_binding_suspended = false
		print("[Tile] %s detached from cell %s" % [name, cell_name])


## Suspends the cell binding during drag operations.
## Clears cell.tile but preserves current_cell reference for potential restoration.
func suspend_cell_binding() -> void:
	if current_cell != null and not _cell_binding_suspended:
		current_cell.tile = null
		_cell_binding_suspended = true
		print("[Tile] %s suspended binding from cell %s" % [name, current_cell.name])


## Restores the cell binding after a cancelled drag.
## Restores cell.tile from the preserved current_cell reference.
func restore_cell_binding() -> void:
	if current_cell != null and _cell_binding_suspended:
		current_cell.tile = self
		_cell_binding_suspended = false
		print("[Tile] %s restored binding to cell %s" % [name, current_cell.name])


## Checks if this tile has a valid, active cell binding.
func has_active_cell_binding() -> bool:
	return current_cell != null and not _cell_binding_suspended


## Moves tile to hand location, clearing any cell binding.
func move_to_hand() -> void:
	detach_from_cell()
	location = TileLocation.IN_HAND


## Moves tile to discard location.
func move_to_discard() -> void:
	detach_from_cell()
	location = TileLocation.IN_DISCARD


# =============================================================================
# RESET
# =============================================================================

## Reset tile to initial state (for recycling).
func reset() -> void:
	detach_from_cell()
	is_selected = false
	is_locked = false
	point_modifier = 0
	location = TileLocation.IN_BAG
	selection_order = -1
	scale = NORMAL_SCALE
	if _drag:
		_drag.force_end()
	_cell_binding_suspended = false
	_update_visual()


## Sets this tile as a follower in a multi-drag (not directly dragged).
## Returns false if the tile cannot be dragged (locked or non-interactable).
func set_as_drag_follower() -> bool:
	if not can_interact():
		return false

	if not _drag.set_as_follower():
		return false

	allow_hover_feedback = false
	return true


## Force-resets all drag state (called by DragManager for all tiles when drag ends).
func force_end_drag() -> void:
	_drag.force_end()
	allow_hover_feedback = true
	modulate = Color.WHITE
	z_index = 0


# === Private: Input Handling ===

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				if can_interact():
					_drag.on_press(event.position, get_global_mouse_position(), global_position)
			else:
				if _drag.on_release():
					# Was a click, not a drag
					tile_selected.emit(self)
				allow_hover_feedback = true
				modulate = Color.WHITE
		MOUSE_BUTTON_RIGHT:
			if event.is_pressed():
				tile_right_clicked.emit(self)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	# on_motion returns true if drag threshold was just reached
	_drag.on_motion(event.position)


# === Private: Drag Signal Handlers ===

func _on_drag_threshold_reached() -> void:
	# Safety check - should have been caught in on_press but double-check
	if not can_interact():
		_drag.force_end()
		return

	allow_hover_feedback = false

	_original_z_index = z_index
	z_index = DRAG_Z_INDEX

	modulate = Color(1.2, 1.2, 1.2)

	var cell_info: String = String(current_cell.name) if current_cell else "none"
	print("[Tile] Drag start: %s | Location: %s | Cell: %s | Locked: %s" % [
		name, TileLocation.keys()[location], cell_info, is_locked
	])

	tile_drag_started.emit(self)


func _on_drag_ended() -> void:
	z_index = _original_z_index

	var cell_info: String = String(current_cell.name) if current_cell else "none"
	print("[Tile] Drag end: %s | Location: %s | Cell: %s" % [
		name, TileLocation.keys()[location], cell_info
	])

	tile_drag_ended.emit(self)


# === Private: Visual Updates ===

const LOCKED_TINT: Color = Color(0.85, 0.85, 0.9, 1.0)  # Subtle blue-gray tint

func _update_visual() -> void:
	if border:
		border.visible = is_selected

	# Apply locked visual state
	if is_locked:
		modulate = LOCKED_TINT
	elif _drag == null or not _drag.is_dragging():
		modulate = Color.WHITE


## Call this when the locked state changes to update visuals.
func set_locked(value: bool) -> void:
	is_locked = value
	_update_visual()
	if is_locked:
		print("[Tile] %s is now locked" % name)


# === Signal Handlers (connected in scene) ===

func _on_mouse_entered() -> void:
	if allow_hover_feedback and can_interact():
		modulate = Color(1.1, 1.1, 1.1)


func _on_mouse_exited() -> void:
	if allow_hover_feedback:
		# Restore appropriate color based on locked state
		modulate = LOCKED_TINT if is_locked else Color.WHITE
