class_name TileDragHelper
extends RefCounted

## TileDragHelper: Encapsulates drag state machine for a Tile.
## Handles press detection, drag threshold, and state transitions.
## Extracted from Tile.gd to reduce its complexity.

# =============================================================================
# SIGNALS
# =============================================================================

signal drag_threshold_reached
signal drag_ended

# =============================================================================
# ENUMS
# =============================================================================

enum DragState {
	IDLE,      # No interaction
	PRESSED,   # Mouse down, waiting for drag threshold
	DRAGGING   # Actively dragging
}

# =============================================================================
# STATE
# =============================================================================

var state: DragState = DragState.IDLE
var is_lead_tile: bool = false

var drag_offset: Vector2 = Vector2.ZERO
var _press_position: Vector2 = Vector2.ZERO

# =============================================================================
# CONSTANTS
# =============================================================================

const DRAG_THRESHOLD: float = 8.0  # Pixels before drag starts


# =============================================================================
# PUBLIC API
# =============================================================================

## Called when mouse button is pressed on the tile.
## Returns nothing — emits drag_threshold_reached if drag starts.
func on_press(pos: Vector2, global_mouse: Vector2, tile_global_pos: Vector2) -> void:
	state = DragState.PRESSED
	_press_position = pos
	drag_offset = global_mouse - tile_global_pos


## Called on mouse motion. Returns true if drag just started (threshold reached).
func on_motion(pos: Vector2) -> bool:
	if state != DragState.PRESSED:
		return false

	var delta: Vector2 = pos - _press_position
	if delta.length() >= DRAG_THRESHOLD:
		state = DragState.DRAGGING
		is_lead_tile = true
		drag_threshold_reached.emit()
		return true

	return false


## Called on mouse button release. Returns true if it was a click (not drag).
func on_release() -> bool:
	var was_click: bool = (state == DragState.PRESSED)

	if state == DragState.DRAGGING:
		drag_ended.emit()

	state = DragState.IDLE
	return was_click


## Force-resets all drag state (called by DragManager for all tiles when drag ends).
func force_end() -> void:
	state = DragState.IDLE
	is_lead_tile = false


## Sets this tile as a follower in a multi-drag.
## Returns false if not in IDLE state (already interacting).
func set_as_follower() -> bool:
	if state != DragState.IDLE:
		return false
	state = DragState.DRAGGING
	is_lead_tile = false
	return true


## Returns true if currently dragging.
func is_dragging() -> bool:
	return state == DragState.DRAGGING


## Returns true if in idle state.
func is_idle() -> bool:
	return state == DragState.IDLE
