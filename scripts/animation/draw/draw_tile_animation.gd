extends TileAnimationStrategy
class_name DrawTileAnimation

## Animation strategy for drawing tiles into the hand.
## Tiles animate from below the screen, scaling and fading in.

# =============================================================================
# CONFIGURATION
# =============================================================================

@export var vertical_offset: float = 200.0
@export var start_scale: Vector2 = Vector2(0.8, 0.8)
@export var start_alpha: float = 0.0


func _init() -> void:
	duration = 0.3
	ease_type = Tween.EASE_OUT
	trans_type = Tween.TRANS_CUBIC
	stagger_delay = 0.05


# =============================================================================
# OVERRIDES
# =============================================================================

func get_start_position_offset() -> Vector2:
	return Vector2(0, vertical_offset)


func get_start_properties() -> Dictionary:
	return {
		"scale": start_scale,
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


func on_animation_complete(tile: Tile) -> void:
	# Re-enable interaction after animation
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	# Restore modifier tint (draw animation tweens modulate to WHITE)
	tile._update_visual()
