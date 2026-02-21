extends TileAnimationStrategy
class_name DrawTileAnimation

## Animation strategy for drawing tiles into the hand.
## Tiles animate from below the screen, scaling and fading in.

# =============================================================================
# CONFIGURATION
# =============================================================================

@export var vertical_offset: float = 200.0
@export var start_scale: Vector2 = Vector2(0.8, 0.8)


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
	}


func get_end_properties() -> Dictionary:
	return {
		"scale": Vector2.ONE,
	}


func on_animation_start(tile: Tile) -> void:
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile._apply_modifier_visual()
	tile.modulate.a = 0.0


func build_custom_tweens(tile: Tile, tween: Tween, delay: float) -> void:
	# Tween only the alpha channel so modifier tint is preserved
	tween.tween_property(tile, "modulate:a", 1.0, duration) \
		.set_ease(ease_type) \
		.set_trans(trans_type) \
		.set_delay(delay)


func on_animation_complete(tile: Tile) -> void:
	# Re-enable interaction after animation
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile._update_visual()
