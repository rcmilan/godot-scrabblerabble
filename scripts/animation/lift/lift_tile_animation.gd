extends TileAnimationStrategy
class_name LiftTileAnimation

## Animation strategy for the lift phase that precedes all other animations.
## Creates an anticipation beat: tiles scale up and move upward uniformly.
## All parameters are derived from HypeConfig at runtime.

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

	# Capture starting properties for the lift
	var hype_config: HypeConfig = TileAnimator.hype_config
	if hype_config:
		# Use the lift parameters from config
		duration = hype_config.lift_duration
		ease_type = Tween.EASE_OUT
		trans_type = Tween.TRANS_QUAD

		# Animate scale to lift_scale, then back to normal
		# Then move upward, then back
		tile.scale = Vector2.ONE


func on_animation_complete(tile: Tile) -> void:
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.z_index = 0
	tile.pivot_offset = Vector2.ZERO
	tile.scale = Vector2.ONE
	tile.position = tile.position  # Ensure final position is correct
	tile._update_visual()


func build_custom_tweens(tile: Tile, tween: Tween, delay: float) -> void:
	var hype_config: HypeConfig = TileAnimator.hype_config
	if not hype_config:
		return

	# Sequence: scale up, then down; offset up, then down
	# All happen in parallel during the lift_duration

	# Scale up to lift_scale, then back to normal
	var scaled_duration = hype_config.scale_duration(hype_config.lift_duration, 1.0)

	tween.set_trans(hype_config.lift_duration < 0.15 and Tween.TRANS_QUAD or Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(tile, "scale", hype_config.lift_scale, scaled_duration / 2.0).set_delay(delay)
	tween.tween_property(tile, "scale", Vector2.ONE, scaled_duration / 2.0)

	# Offset up, then back down (in parallel)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(tile, "position:y", tile.position.y + hype_config.lift_offset_y, scaled_duration / 2.0).set_delay(delay)
	tween.tween_property(tile, "position:y", tile.position.y, scaled_duration / 2.0)
