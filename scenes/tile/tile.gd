extends Control
class_name Tile

## A letter tile that can be placed on the board or held in hand.
## Supports click-to-select and drag-and-drop interactions.
## Manages its own visual state and emits signals for game events.

# === Signals ===
signal tile_selected(tile: Tile)
signal tile_right_clicked(tile: Tile)
signal tile_drag_started(tile: Tile)
signal tile_drag_ended(tile: Tile)

# === Constants ===
const DRAG_THRESHOLD: float = 8.0  # Pixels before drag starts
const DRAG_Z_INDEX: int = 100      # Z-index while dragging
const SELECTED_SCALE: Vector2 = Vector2(1.05, 1.05)
const NORMAL_SCALE: Vector2 = Vector2(1.0, 1.0)
const SCALE_TWEEN_DURATION: float = 0.1

# === Enums ===

## Drag interaction state machine
enum DragState {
	IDLE,      # No interaction
	PRESSED,   # Mouse down, waiting for drag threshold
	DRAGGING   # Actively dragging
}

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

# === Selection State ===
var is_selected: bool = false
var allow_hover_feedback: bool = true
var selection_order: int = -1  # -1 = not selected

# === Drag State ===
var _drag_state: DragState = DragState.IDLE
var _drag_offset: Vector2 = Vector2.ZERO
var _press_position: Vector2 = Vector2.ZERO
var _original_z_index: int = 0
var _is_lead_tile: bool = false  # True if this tile is being directly dragged

# === Pending initialization (applied in _ready) ===
var _pending_texture: Texture2D = null

# === Node References ===
@onready var border: Panel = $Border
@onready var texture_rect: TextureRect = $TextureRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Apply pending texture if initialize() was called before _ready()
	if _pending_texture and texture_rect:
		texture_rect.texture = _pending_texture
		_pending_texture = null

	_update_visual()


func _process(_delta: float) -> void:
	# Only update position if we're the lead tile (directly dragged)
	# DragManager handles positioning for follower tiles
	if _drag_state == DragState.DRAGGING and _is_lead_tile:
		global_position = get_global_mouse_position() - _drag_offset


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


## Reset tile to initial state (for recycling).
func reset() -> void:
	is_selected = false
	is_locked = false
	point_modifier = 0
	current_cell = null
	location = TileLocation.IN_BAG
	selection_order = -1
	scale = NORMAL_SCALE
	_drag_state = DragState.IDLE
	_is_lead_tile = false
	_update_visual()


## Sets this tile as a follower in a multi-drag (not directly dragged).
func set_as_drag_follower() -> void:
	_drag_state = DragState.DRAGGING
	_is_lead_tile = false
	allow_hover_feedback = false


## Ends the drag state for follower tiles.
func end_drag_follower() -> void:
	_drag_state = DragState.IDLE
	_is_lead_tile = false
	allow_hover_feedback = true
	modulate = Color.WHITE


## Force-resets all drag state (called by DragManager when drag is cancelled externally).
func force_end_drag() -> void:
	_drag_state = DragState.IDLE
	_is_lead_tile = false
	allow_hover_feedback = true
	modulate = Color.WHITE
	z_index = 0


# === Private: Input Handling ===

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if event.is_pressed():
				_on_press(event.position)
			else:
				_on_release()
		MOUSE_BUTTON_RIGHT:
			if event.is_pressed():
				tile_right_clicked.emit(self)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	match _drag_state:
		DragState.DRAGGING:
			# Position updated in _process for smoother dragging
			pass
		DragState.PRESSED:
			var delta: Vector2 = event.position - _press_position
			if delta.length() >= DRAG_THRESHOLD:
				_start_drag()


func _on_press(pos: Vector2) -> void:
	_drag_state = DragState.PRESSED
	_press_position = pos
	_drag_offset = get_global_mouse_position() - global_position


func _on_release() -> void:
	match _drag_state:
		DragState.PRESSED:
			# Short click = selection
			tile_selected.emit(self)
		DragState.DRAGGING:
			_end_drag()

	_drag_state = DragState.IDLE
	allow_hover_feedback = true
	modulate = Color.WHITE


# === Private: Drag Operations ===

func _start_drag() -> void:
	_drag_state = DragState.DRAGGING
	_is_lead_tile = true  # We're the directly dragged tile
	allow_hover_feedback = false

	_original_z_index = z_index
	z_index = DRAG_Z_INDEX

	modulate = Color(1.2, 1.2, 1.2)

	var cell_info: String = String(current_cell.name) if current_cell else "none"
	print("[Tile] Drag start: %s | Location: %s | Cell: %s" % [
		name, TileLocation.keys()[location], cell_info
	])

	tile_drag_started.emit(self)


func _end_drag() -> void:
	z_index = _original_z_index
	_is_lead_tile = false

	var cell_info: String = String(current_cell.name) if current_cell else "none"
	print("[Tile] Drag end: %s | Location: %s | Cell: %s" % [
		name, TileLocation.keys()[location], cell_info
	])

	tile_drag_ended.emit(self)


# === Private: Visual Updates ===

func _update_visual() -> void:
	if border:
		border.visible = is_selected


# === Signal Handlers (connected in scene) ===

func _on_mouse_entered() -> void:
	if allow_hover_feedback and can_interact():
		modulate = Color(1.1, 1.1, 1.1)


func _on_mouse_exited() -> void:
	if allow_hover_feedback:
		modulate = Color.WHITE
