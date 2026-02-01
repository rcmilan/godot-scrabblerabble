extends AnimationExecutor
class_name ShakeAnimationExecutor

## Executes shake animations for illegal action feedback.
## Tiles shake left-right and return to original position.


## Animates a shake effect on a single tile.
func execute(tile: Tile, strategy: ShakeTileAnimation) -> void:
	# Cancel any existing animation on this tile
	_context.cancel_tile_animation(tile)

	_context.is_animating = true
	var tiles_array: Array[Tile] = [tile]
	_context.emit_animation_started(tiles_array)

	# Store original position
	var original_position: Vector2 = tile.position

	# Notify strategy
	strategy.on_animation_start(tile)

	# Create sequential shake animation
	var tween: Tween = _context.create_tween()

	# Shake left-right multiple times
	for i in strategy.shake_count:
		# Move right
		tween.tween_property(tile, "position:x", original_position.x + strategy.shake_distance, strategy.duration) \
			.set_ease(strategy.ease_type) \
			.set_trans(strategy.trans_type)
		# Move left
		tween.tween_property(tile, "position:x", original_position.x - strategy.shake_distance, strategy.duration) \
			.set_ease(strategy.ease_type) \
			.set_trans(strategy.trans_type)

	# Return to original position
	tween.tween_property(tile, "position:x", original_position.x, strategy.duration) \
		.set_ease(strategy.ease_type) \
		.set_trans(strategy.trans_type)

	_register_tween(tile, tween)
	tween.finished.connect(_create_single_completion_callback(tile, strategy))

	print("[ShakeAnimationExecutor] Started shake for: %s" % tile.name)
