extends TileAnimationStrategy
class_name ReturnToHandAnimation

## Animation strategy for returning tiles from the board to the hand.
## Tiles smoothly glide from their board position to their hand position
## with a subtle scale bounce effect.

# =============================================================================
# CONFIGURATION
# =============================================================================

@export var overshoot_scale: Vector2 = Vector2(1.1, 1.1)
@export var start_alpha: float = 1.0


func _init() -> void:
	duration = 0.35
	ease_type = Tween.EASE_OUT
	trans_type = Tween.TRANS_BACK  # Slight overshoot for bounce feel
	stagger_delay = 0.03


# =============================================================================
# OVERRIDES
# =============================================================================

func get_start_position_offset() -> Vector2:
	# Position offset is calculated dynamically in TileAnimator
	# based on the tile's board position vs hand position
	return Vector2.ZERO


func get_start_properties() -> Dictionary:
	return {
		"scale": Vector2.ONE,
		"modulate": Color(1.0, 1.0, 1.0, start_alpha)
	}


func get_end_properties() -> Dictionary:
	return {
		"scale": Vector2.ONE,
		"modulate": Color.WHITE
	}


func on_animation_start(tile: Tile) -> void:
	# Disable interaction during animation
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Raise z-index to appear above other tiles
	tile.z_index = 50


func on_animation_complete(tile: Tile) -> void:
	# Re-enable interaction after animation
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	# Reset z-index
	tile.z_index = 0
