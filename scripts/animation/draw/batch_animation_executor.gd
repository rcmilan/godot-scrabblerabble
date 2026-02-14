extends AnimationExecutor
class_name BatchAnimationExecutor

## Executes batch animations with staggered timing.
## Used for draw animations and other batch property tweens.


## Animates a batch of tiles using the provided strategy.
func execute(tiles: Array[Tile], strategy: TileAnimationStrategy) -> void:
	_context.is_animating = true
	_context.emit_animation_started(tiles)

	# Wait for layout to calculate final positions
	await _context.get_tree().process_frame

	var completed_count_ref: Array = [0]  # Reference wrapper
	var total_tiles: int = tiles.size()

	for i in tiles.size():
		var tile: Tile = tiles[i]
		var delay: float = i * strategy.stagger_delay

		# Capture final position after layout
		var final_position: Vector2 = tile.position

		# Set starting state
		var start_offset: Vector2 = strategy.get_start_position_offset()
		var start_props: Dictionary = strategy.get_start_properties()

		tile.position = final_position + start_offset
		_apply_properties(tile, start_props)

		# Notify strategy of animation start
		strategy.on_animation_start(tile)

		# Create staggered animation
		var tween: Tween = _context.create_tween()
		tween.set_parallel(true)

		# Position animation
		tween.tween_property(tile, "position", final_position, strategy.duration) \
			.set_ease(strategy.ease_type) \
			.set_trans(strategy.trans_type) \
			.set_delay(delay)

		# Property animations
		var end_props: Dictionary = strategy.get_end_properties()
		for prop_name in end_props.keys():
			tween.tween_property(tile, prop_name, end_props[prop_name], strategy.duration) \
				.set_ease(strategy.ease_type) \
				.set_trans(strategy.trans_type) \
				.set_delay(delay)

		# Custom tweens (e.g. alpha fade that preserves modifier tint)
		strategy.build_custom_tweens(tile, tween, delay)

		_register_tween(tile, tween)

		# Track completion
		tween.finished.connect(
			_create_batch_completion_callback(tile, tiles, strategy, completed_count_ref, total_tiles)
		)

	print("[BatchAnimationExecutor] Started animation for %d tiles" % tiles.size())
