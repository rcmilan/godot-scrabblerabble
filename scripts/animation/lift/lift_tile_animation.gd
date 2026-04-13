extends TileAnimationStrategy
class_name LiftTileAnimation

## Animation strategy for the lift phase that precedes all other animations.
## Creates an anticipation beat: tiles scale up and move upward uniformly.
## All parameters are derived from HypeConfig at runtime.

func _init() -> void:
	var hype_config: HypeConfig = TileAnimator.hype_config if TileAnimator else null
	if hype_config:
		duration = hype_config.lift_duration
	else:
		duration = 0.12
	ease_type = Tween.EASE_OUT
	trans_type = Tween.TRANS_QUAD
	stagger_delay = 0.0  # All tiles lift together, no stagger


# =============================================================================
# OVERRIDES
# =============================================================================

func get_start_position_offset() -> Vector2:
	return Vector2.ZERO


func get_start_properties() -> Dictionary:
	return {
		"scale": Vector2.ONE,
	}


func get_end_properties() -> Dictionary:
	return {
		"scale": Vector2.ONE,
	}


func on_animation_start(tile: Tile) -> void:
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.z_index = 50
	# Pivot at center for symmetric scaling
	var tile_size: Vector2 = tile.size if tile.size != Vector2.ZERO else Vector2(64, 64)
	tile.pivot_offset = tile_size / 2.0


func on_animation_complete(tile: Tile) -> void:
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.z_index = 0
	tile.pivot_offset = Vector2.ZERO
	tile.scale = Vector2.ONE
	tile._update_visual()


func build_custom_tweens(tile: Tile, tween: Tween, delay: float) -> void:
	var hype_config: HypeConfig = TileAnimator.hype_config
	if not hype_config:
		return

	# Lift phase: scale and move are both part of the animation
	# Tween is already parallel, so add scale and Y-offset tweens
	var half_duration: float = duration / 2.0

	# Scale up then down
	tween.tween_property(tile, "scale", hype_config.lift_scale, half_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD).set_delay(delay)
	tween.tween_property(tile, "scale", Vector2.ONE, half_duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	# Move up then down (Y-axis only)
	tween.tween_property(tile, "position:y", tile.position.y + hype_config.lift_offset_y, half_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD).set_delay(delay)
	tween.tween_property(tile, "position:y", tile.position.y, half_duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
