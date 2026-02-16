extends TileAnimationStrategy
class_name ShakeTileAnimation

## Animation strategy for indicating an illegal action.
## Tile shakes along a random direction to show the action cannot be performed.

# =============================================================================
# CONFIGURATION
# =============================================================================

@export var shake_distance: float = 8.0
@export var shake_count: int = 3


func _init() -> void:
	duration = 0.08  # Duration per shake direction
	ease_type = Tween.EASE_IN_OUT
	trans_type = Tween.TRANS_SINE
	stagger_delay = 0.0


# =============================================================================
# OVERRIDES
# =============================================================================

func get_start_position_offset() -> Vector2:
	return Vector2.ZERO


func get_start_properties() -> Dictionary:
	# NOTE: modulate is reset to WHITE here to clear any leftover tween state from
	# prior animations. Shake does not tween modulate — it only sets the initial
	# state. Modifier tint is reapplied by on_animation_complete → _update_visual().
	return {
		"scale": Vector2.ONE,
		"modulate": Color.WHITE
	}


func get_end_properties() -> Dictionary:
	# NOTE: modulate is reset to WHITE here to clear any leftover tween state from
	# prior animations. Shake does not tween modulate — it only sets the initial
	# state. Modifier tint is reapplied by on_animation_complete → _update_visual().
	return {
		"scale": Vector2.ONE,
		"modulate": Color.WHITE
	}


func on_animation_start(tile: Tile) -> void:
	# Disable interaction during animation
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE


func on_animation_complete(tile: Tile) -> void:
	# Re-enable interaction after animation
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
